# validate-harness.ps1 - structural + consistency validation of a harness instance.
# Read-only; safe to run anytime. Exits non-zero on FAIL. Writes a report to harness/reports/.
# Usage: pwsh -File harness\scripts\validate-harness.ps1 [-Root <repoRoot>] [-IncludeRuntime]

param(
    [string]$Root,
    [switch]$IncludeRuntime,
    [string]$ReportPath
)

$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = (Get-Location).Path }
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib-render.ps1')

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$Level, [string]$Check, [string]$Detail) {
    [void]$results.Add([pscustomobject]@{ Level = $Level; Check = $Check; Detail = $Detail })
}
function Pass($c, $d) { Add-Result 'PASS' $c $d }
function Fail($c, $d) { Add-Result 'FAIL' $c $d }
function Warn($c, $d) { Add-Result 'WARN' $c $d }

# ---- 1. Required files
foreach ($p in @('AGENTS.md','opencode.jsonc','project.yaml','.gitignore','README.md','harness\HARNESS-VERSION')) {
    if (Test-Path (Join-Path $Root $p)) { Pass "file:$p" 'present' } else { Fail "file:$p" 'missing' }
}
foreach ($d in @('.opencode\agents','.opencode\commands','docs\harness','docs\project','.github\ISSUE_TEMPLATE')) {
    if (Test-Path (Join-Path $Root $d)) { Pass "dir:$d" 'present' } else { Fail "dir:$d" 'missing' }
}

# ---- 2. BOM + placeholder leaks
# Scope rules:
#  - A BOM is a defect anywhere in the instance, kit and scripts included.
#  - An unresolved {{PLACEHOLDER}} is a defect only in GENERATED instance files. harness/kit/** and
#    *.tmpl are templates by design; harness/scripts/** contains the substitution code, which holds
#    literal token examples; docs/harness/** documents that same syntax. Scanning them as leaks
#    produced false failures, so the sweep is limited to what the renderer actually produced.
$leakFiles = @(); $bomFiles = @()
$sweepDirs = @('.opencode','.github','docs','harness\kit','harness\scripts')
$generatedRootFiles = @('AGENTS.md','opencode.jsonc','project.yaml','.gitignore','README.md')
function Get-InstanceRel([string]$FullPath) { return $FullPath.Substring($Root.Length).TrimStart('\','/') }
function Test-GeneratedPath([string]$Rel) {
    if ($Rel -match '^harness(\\|$)') { return $false }          # kit + scripts: source of truth
    if ($Rel -match '^docs\\harness(\\|$)') { return $false }    # core docs: document the syntax
    if ($Rel -match '\.tmpl$') { return $false }
    return $true
}
foreach ($rel in $generatedRootFiles) {
    $f = Join-Path $Root $rel
    if (-not (Test-Path $f)) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($f)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $bomFiles += $rel }
    if ((Read-TextRaw $f) -match '\{\{[A-Z0-9_]+\}\}') { $leakFiles += $rel }
}
foreach ($sd in $sweepDirs) {
    $full = Join-Path $Root $sd
    if (-not (Test-Path $full)) { continue }
    foreach ($f in (Get-ChildItem -File -Recurse $full -Include *.md,*.yml,*.yaml,*.jsonc,*.json,*.ps1 -ErrorAction SilentlyContinue)) {
        $rel = Get-InstanceRel $f.FullName
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $bomFiles += $rel }
        if ((Test-GeneratedPath $rel) -and (Read-TextRaw $f.FullName) -match '\{\{[A-Z0-9_]+\}\}') { $leakFiles += $rel }
    }
}
if ($bomFiles.Count -eq 0) { Pass 'encoding:bom' 'no BOMs in scanned files' } else { Warn 'encoding:bom' ('BOM found: ' + ($bomFiles -join ', ')) }
if ($leakFiles.Count -eq 0) { Pass 'placeholders' 'no unresolved placeholders in generated files' } else { Fail 'placeholders' ('leaks: ' + ($leakFiles -join ', ')) }

# ---- 3. Config structure
$cfg = Get-ProjectConfig (Join-Path $Root 'project.yaml')
$cfgJsonRaw = Read-TextRaw (Join-Path $Root 'opencode.jsonc')
$cfgJson = $cfgJsonRaw -replace '(?m)^\s*//.*$','' -replace '/\*[\s\S]*?\*/',''
$parsed = $null
try { $parsed = $cfgJson | ConvertFrom-Json } catch { Fail 'config:json' ("JSONC parse: " + $_.Exception.Message) }
if ($parsed) {
    Pass 'config:json' 'JSONC parses'
    if (@($parsed.permissions).Count -ge 20) { Pass 'config:permissions' ("{0} rules" -f @($parsed.permissions).Count) } else { Fail 'config:permissions' 'too few rules' }
    if (@($parsed.policies).Count -ge 10) { Pass 'config:policies' ("{0} hard-deny policies" -f @($parsed.policies).Count) } else { Fail 'config:policies' 'policies missing/short - delegation-proof layer absent' }
    $shellDeny = @($parsed.permissions | Where-Object { $_.action -eq 'shell' -and $_.resource -eq '*' -and $_.effect -eq 'deny' })
    if ($shellDeny.Count -ge 1) { Pass 'config:shell-deny' 'shell deny-by-default present' } else { Fail 'config:shell-deny' 'shell is not deny-by-default' }
    foreach ($need in @('AGENTS.md','opencode.jsonc','.opencode/**','docs/harness/**','DESIGN.md')) {
        $hit = @($parsed.permissions | Where-Object { $_.action -eq 'edit' -and $_.resource -eq $need -and $_.effect -eq 'deny' })
        if ($hit.Count -ge 1) { Pass "config:protect:$need" 'denied' } else { Fail "config:protect:$need" 'NOT denied' }
    }
    if ($parsed.mcp -and $parsed.mcp.servers) { Pass 'config:mcp-shape' 'modern mcp.servers form' }
    elseif ($parsed.mcp) { Fail 'config:mcp-shape' 'deprecated top-level mcp entries - must use mcp.servers' }
    else { Pass 'config:mcp-shape' 'no mcp section (nothing enabled)' }
    if ($parsed.experimental -and $parsed.experimental.subagent_depth -eq 2) { Pass 'config:depth' 'subagent_depth 2' } else { Warn 'config:depth' 'subagent_depth != 2 (check intended profile)' }
}

# ---- 4. Agent consistency + delegation matrix drift
$expectedMatrix = @{
    'project-manager'  = @('business-analyst','designer','developer','qa-engineer','code-reviewer','security-monitor')
    'business-analyst' = @('designer','developer','code-reviewer')
    'designer'         = @('business-analyst','developer')
    'developer'        = @('designer','qa-engineer','security-monitor')
    'qa-engineer'      = @('developer','designer','security-monitor')
    'code-reviewer'    = @()
    'security-monitor' = @('code-reviewer','developer')
}
$skillDirs = @()
foreach ($sd in @('.opencode\skills','.agents\skills')) {
    $full = Join-Path $Root $sd
    if (Test-Path $full) { $skillDirs += (Get-ChildItem -Directory -Recurse $full | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object { $_.Name }) }
}
$globalKnownSkills = @('browseros-neo','impeccable','pinokio','idea-validator','opencode','report','academic-paper','academic-paper-reviewer','academic-pipeline','deep-research','sr-screener','firecrawl','firecrawl-search','firecrawl-scrape','firecrawl-map','firecrawl-crawl','firecrawl-download','firecrawl-agent','firecrawl-interact','firecrawl-monitor','firecrawl-parse','firecrawl-research-index','firecrawl-developer-index','firecrawl-alexandria')
$agentModels = @{}
foreach ($af in (Get-ChildItem -File (Join-Path $Root '.opencode\agents\*.md') -ErrorAction SilentlyContinue)) {
    $t = Read-TextRaw $af.FullName
    $id = $af.BaseName
    if ($t -notmatch '(?m)^description:') { Fail "agent:$id" 'missing description' }
    if ($t -notmatch '(?m)^mode: (primary|subagent|all)') { Fail "agent:$id" 'missing/invalid mode' }
    if ($t -match '(?m)^model: (\S+)') { $agentModels[$id] = $Matches[1] } else { Warn "agent:$id" 'no model (inherits)' }
    if ($t -match '(?m)^steps: (\d+)') { } else { Warn "agent:$id" 'no steps budget' }
    if ($t -match 'general|explore' ) {
        $subAllow = [regex]::Matches($t, '(?s)action:\s*"subagent"\s*\n\s*resource:\s*"([^"]+)"\s*\n\s*effect:\s*"allow"')
        foreach ($m in $subAllow) {
            if ($m.Groups[1].Value -in @('general','explore')) { Fail "agent:$id:delegation" ("allows built-in '" + $m.Groups[1].Value + "' (OD-21)") }
        }
    }
    # collect subagent allows and compare to matrix
    $allows = @([regex]::Matches($t, '(?s)action:\s*"subagent"\s*\n\s*resource:\s*"([^"]+)"\s*\n\s*effect:\s*"allow"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notin @('general','explore') })
    if ($expectedMatrix.ContainsKey($id)) {
        $expect = $expectedMatrix[$id]
        $extra = @($allows | Where-Object { $_ -notin $expect })
        $missing = @($expect | Where-Object { $_ -notin $allows })
        if ($extra.Count -eq 0 -and $missing.Count -eq 0) { Pass "agent:$id:delegation" ("matrix ok: " + ($allows -join ',')) }
        else { Fail "agent:$id:delegation" ("extra=[" + ($extra -join ',') + "] missing=[" + ($missing -join ',') + "]") }
    }
    # skill allow sanity
    $skAllow = @([regex]::Matches($t, '(?s)action:\s*"skill"\s*\n\s*resource:\s*"([^"]+)"\s*\n\s*effect:\s*"allow"') | ForEach-Object { $_.Groups[1].Value })
    foreach ($s in $skAllow) {
        if ($s -eq '*') { Fail "agent:$id:skills" 'wildcard skill allow' }
        elseif (($skillDirs -notcontains $s) -and ($globalKnownSkills -notcontains $s)) { Warn "agent:$id:skill:$s" 'skill not found in project tree or known globals - verify installed' }
    }
    # MCP override check: agents must not allow MCP tools the project denies
    $mcpAllow = @([regex]::Matches($t, '(?m)^  - action:\s*"((?:firecrawl|browseros|composio|jira|pencil)_\*)"') | ForEach-Object { $_.Groups[1].Value })
    if ($mcpAllow.Count -gt 0) { Fail "agent:$id:mcp-override" ('agent re-allows denied MCP: ' + ($mcpAllow -join ',')) }
}
$agentCount = @(Get-ChildItem -File (Join-Path $Root '.opencode\agents\*.md') -ErrorAction SilentlyContinue).Count
if ($agentCount -eq 7) { Pass 'agents:count' '7 role agents' } else { Fail 'agents:count' "expected 7 role agents, found $agentCount" }

# ---- 5. Model routing vs project.yaml
foreach ($id in $agentModels.Keys) {
    $want = if ($id -in @('code-reviewer','security-monitor')) { $cfg['models.reviewer'] } else { $cfg['models.default'] }
    if ($agentModels[$id] -ne $want) { Warn "model:$id" ("agent has {0}, project.yaml says {1}" -f $agentModels[$id], $want) }
}
if ($agentModels.Count -eq 7) { Pass 'models:bound' 'all agents declare a model' }

# ---- 6. Commands reference existing agents
foreach ($cf in (Get-ChildItem -File (Join-Path $Root '.opencode\commands\*.md') -ErrorAction SilentlyContinue)) {
    $t = Read-TextRaw $cf.FullName
    if ($t -match '(?m)^agent:\s*(\S+)') {
        $ag = $Matches[1]
        if (-not (Test-Path (Join-Path $Root ".opencode\agents\$ag.md"))) { Fail "command:$($cf.BaseName)" ("references missing agent '$ag'") }
    }
}
$cmdCount = @(Get-ChildItem -File (Join-Path $Root '.opencode\commands\*.md') -ErrorAction SilentlyContinue).Count
if ($cmdCount -ge 16) { Pass 'commands:count' "$cmdCount commands" } else { Warn 'commands:count' "$cmdCount (< 16 expected after full generation)" }

# ---- 7. Core docs completeness (instance copies)
foreach ($d in @('architecture-specification','agent-specifications','workflow-and-governance','security-and-permissions','github-governance','knowledge-management','project-initialization','using-the-harness','open-decisions','implementation-roadmap','skills-inventory','opencode-capability-matrix','repository-structure')) {
    if (Test-Path (Join-Path $Root "docs\harness\$d.md")) { Pass "doc:$d" 'present' } else { Fail "doc:$d" 'missing' }
}

# ---- 8. Phase state + register + traceability shape
$ps = Join-Path $Root 'docs\project\status\phase-state.md'
if (Test-Path $ps) {
    $t = Read-TextRaw $ps
    foreach ($k in @('current_phase','status','profile','phase_list')) { if ($t -notmatch "(?m)^$k(\s*):") { Fail 'phase-state' "missing key $k" } }
    Pass 'phase-state' 'shape ok'
} else { Fail 'phase-state' 'missing' }
if (Test-Path (Join-Path $Root 'docs\project\traceability.md')) { Pass 'traceability' 'present' }
if (Test-Path (Join-Path $Root 'docs\project\decisions\decision-register.md')) { Pass 'decision-register' 'present' }

# ---- 9. No secrets by pattern (tracked-ish scan of instance text files)
$secretHits = @()
foreach ($f in (Get-ChildItem -File -Recurse $Root -Include *.md,*.yml,*.jsonc,*.json,*.ps1 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|harness\\reports|node_modules)\\' })) {
    $t = $null; try { $t = Read-TextRaw $f.FullName } catch { continue }
    if ($t -match 'gh[ps]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|sk-[A-Za-z0-9]{30,}') { $secretHits += $f.FullName.Substring($Root.Length+1) }
}
if ($secretHits.Count -eq 0) { Pass 'secrets:scan' 'no secret patterns in instance text files' } else { Fail 'secrets:scan' ('hits: ' + ($secretHits -join ', ')) }

# ---- 10. Runtime (owner-run only; requires opencode on PATH and model readiness = verified)
if ($IncludeRuntime) {
    if ("$($cfg['models.readiness'])" -eq 'gated') { Warn 'runtime' 'models.readiness=gated - run opencode debug only (no model calls); negative tests need readiness=verified' }
    $dbg = & opencode debug agents 2>&1
    if ($LASTEXITCODE -eq 0) {
        Pass 'runtime:debug-agents' 'opencode debug agents exit 0'
        foreach ($id in $expectedMatrix.Keys) { if ($dbg -notmatch '"' + $id + '"') { Fail 'runtime:agent-missing' $id } }
    } else { Fail 'runtime:debug-agents' 'opencode debug agents failed - config invalid' }
    $dc = & opencode debug config 2>&1
    if ($LASTEXITCODE -eq 0) { Pass 'runtime:debug-config' 'parses' } else { Fail 'runtime:debug-config' 'parse error' }
}

# ---- report
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $ReportPath) { $ReportPath = Join-Path $Root "harness\reports\validate-$stamp.md" }
$lines = @("# Harness validation report", "> Root: $Root - $(Get-Date -Format 's') - kit $((Read-TextRaw (Join-Path $Root 'harness\HARNESS-VERSION') -ErrorAction SilentlyContinue).Trim())", "")
$fails = @($results | Where-Object Level -eq 'FAIL'); $warns = @($results | Where-Object Level -eq 'WARN'); $passes = @($results | Where-Object Level -eq 'PASS')
$lines += ("**Result: {0} PASS - {1} WARN - {2} FAIL**" -f $passes.Count, $warns.Count, $fails.Count)
$lines += ''
foreach ($r in $results) { $lines += ("[{0}] {1} - {2}" -f $r.Level, $r.Check, $r.Detail) }
New-Item -ItemType Directory -Path (Split-Path -Parent $ReportPath) -Force | Out-Null
Write-TextUtf8 -Path $ReportPath -Text ($lines -join "`r`n")
foreach ($r in $results | Where-Object { $_.Level -ne 'PASS' }) { Write-Host ("[{0}] {1} - {2}" -f $r.Level, $r.Check, $r.Detail) }
Write-Host ("validate-harness: {0} PASS / {1} WARN / {2} FAIL - report: {3}" -f $passes.Count, $warns.Count, $fails.Count, $ReportPath)
if ($fails.Count -gt 0) { exit 1 } else { exit 0 }
