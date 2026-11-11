# lib-render.ps1 - shared rendering engine for the AIDLC harness kit.
# Requires Windows PowerShell 5.1+ (no PS7-only syntax). UTF-8 output WITHOUT BOM.
# Source files must stay ASCII-only: PS 5.1 decodes BOM-less UTF-8 with the ANSI codepage, so any
# non-ASCII literal can break parsing. Emit needed glyphs from code points ([char]0x2192) instead.
# Parses the constrained project.yaml subset: `key: value`, inline arrays `[a, b]`,
# quoted strings, two nesting levels via indentation, `#` comments.
# Nothing here deletes files; writers refuse existing targets unless -Force.

Set-StrictMode -Version 2

function Get-Utf8NoBom { param([string]$Text)
    New-Object System.Text.UTF8Encoding($false)
}

function Write-TextUtf8 { param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (Get-Utf8NoBom -Text $Text))
}

function Read-TextRaw { param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Test-ProjectYamlValue { param([string]$v)
    # normalized leaf parse: strips quotes, splits inline arrays
    $t = $v.Trim()
    if ($t -eq '') { return '' }
    if ($t.StartsWith('[') -and $t.EndsWith(']')) {
        $inner = $t.Substring(1, $t.Length - 2)
        if ($inner.Trim() -eq '') { return @() }
        return ($inner -split ',' | ForEach-Object { ($_ -replace '^\s*["'']|["'']\s*$','').Trim() })
    }
    return ($t -replace '^["'']|["'']$','')
}

function Get-ProjectConfig { param([string]$Path)
    # Indentation-aware parser for the constrained project.yaml subset:
    #  - top-level keys at indent 0 with empty value open a section
    #  - leaf keys (indent > 0) under the current section store as "section.key"
    #  - inline arrays [a, "b"] and quoted scalars supported; list items (- x) ignored
    #  - trailing comments (space + #) stripped; comments/blank lines skipped
    $cfg = @{}
    $section = ''
    foreach ($line in (Read-TextRaw $Path) -split "`r?`n") {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^\s*-') { continue }                       # list item content
        if ($line -match '^([A-Za-z0-9_\-]+):\s*(.*)$') {
            # indent-0 line: section header or top-level scalar. Strip any trailing
            # comment BEFORE testing for empty, or a header like `stack:  # ...`
            # is mistaken for a scalar and the section never opens.
            $key = $Matches[1]; $val = Test-ProjectYamlComment $Matches[2]
            if ($val.Trim() -eq '') { $section = $key }
            else { $cfg[$key] = Test-ProjectYamlValue $val }
            continue
        }
        if ($line -match '^\s+([A-Za-z0-9_\-]+):\s*(.*)$') {
            # indented leaf under current section
            $key = $Matches[1]; $val = Test-ProjectYamlComment $Matches[2]
            if ($val.Trim() -eq '') { continue }                     # nested list header (e.g. rules:)
            $full = if ($section) { "$section.$key" } else { $key }
            $cfg[$full] = Test-ProjectYamlValue $val
        }
    }
    return $cfg
}

function Test-ProjectYamlComment { param([string]$v)
    # strip trailing comment: preceded by whitespace. A value that IS a comment
    # (after `key:\s*` ate the gap, a header comment arrives as `#...` with no
    # leading space) counts as empty so the section still opens.
    if ($v.Trim().StartsWith('#')) { return '' }
    if ($v -match '^(.*?)\s+#.*$') { return $Matches[1] }
    return $v
}

function Get-ProfilePhases { param([string]$ProfilesPath, [string]$ProfileName)
    # Minimal parser for harness/kit/lifecycle/profiles.yaml (controlled format).
    $text = Read-TextRaw $ProfilesPath
    $lines = $text -split "`r?`n"
    $inProfiles = $false; $inTarget = $false; $depth = 0; $phases = @()
    $cur = $null
    foreach ($line in $lines) {
        if ($line -match '^profiles:') { $inProfiles = $true; continue }
        if (-not $inProfiles) { continue }
        if ($line -match "^  $([regex]::Escape($ProfileName)):\s*$") { $inTarget = $true; continue }
        if ($inTarget) {
            if ($line -match '^  [A-Za-z0-9_-]+:\s*$') { break }              # next profile
            if ($line -match '^\s*-\s*id:\s*([^\s,]+)\s*$' -and $line -notmatch '\{') {
                $cur = [pscustomobject]@{ Id = $Matches[1]; Name = '' }
                $phases += $cur
                continue
            }
            if ($line -match '^\s*name:\s*(.+?)\s*$' -and $line -notmatch '\{' -and $cur) {
                $cur.Name = (Test-ProjectYamlValue $Matches[1]); continue
            }
            if ($line -match '^\s*-\s*\{\s*id:\s*([^,]+),\s*name:\s*(".*?"|[^,]+),') {
                $phases += [pscustomobject]@{ Id = $Matches[1].Trim(); Name = (Test-ProjectYamlValue $Matches[2]) }
            }
        }
    }
    return $phases
}

function New-RenderContext { param([hashtable]$Cfg, [string]$KitDir, [string]$ProfilesPath)
    $ctx = @{}
    $ctx['PROJECT_NAME']   = $Cfg['project.name']
    $ctx['PROJECT_SLUG']   = $Cfg['project.slug']
    $ctx['ID_PREFIX']      = $Cfg['project.id_prefix']
    $ctx['ONE_LINE_PROJECT_DESCRIPTION'] = $Cfg['project.description']
    $ctx['OWNER_LOGIN']    = $Cfg['owner.login']
    $ctx['LIFECYCLE_PROFILE'] = $Cfg['lifecycle.profile']
    # HARNESS-VERSION lives beside the kit (harness/HARNESS-VERSION), not inside it.
    # Check the kit dir first so a bundled copy still works, then the harness root.
    $versionFile = Join-Path $KitDir 'HARNESS-VERSION'
    if (-not (Test-Path $versionFile)) { $versionFile = Join-Path (Split-Path -Parent $KitDir) 'HARNESS-VERSION' }
    if (-not (Test-Path $versionFile)) { throw "HARNESS-VERSION not found near kit: $KitDir" }
    $ctx['KIT_VERSION']    = (Read-TextRaw $versionFile).Trim()
    $ctx['RENDER_DATE']    = (Get-Date -Format 'yyyy-MM-dd')
    $ctx['MODEL_WORK']     = $Cfg['models.default']
    $ctx['MODEL_REVIEW']   = $Cfg['models.reviewer']
    $ctx['MODEL_READINESS']= $Cfg['models.readiness']
    if ($Cfg['stack.browser']) { $ctx['BROWSER_BASE_URL'] = $Cfg['stack.browser'] } else { $ctx['BROWSER_BASE_URL'] = 'http://127.0.0.1:0' }
    $ctx['STACK_NAME']     = $Cfg['stack.name']

    $areas = @($Cfg['lifecycle.areas'])
    $ctx['AREA_OPTIONS_YAML'] = ($areas | ForEach-Object { '"' + $_ + '"' }) -join ', '

    $phases = Get-ProfilePhases -ProfilesPath $ProfilesPath -ProfileName $Cfg['lifecycle.profile']
    if ($phases.Count -eq 0) { throw ("profile phases empty: " + $Cfg['lifecycle.profile']) }
    $quoted = ($phases | ForEach-Object { '"' + $_.Id + ' ' + $_.Name + '"' }) -join ', '
    $ctx['PHASE_OPTIONS_YAML'] = $quoted
    # Rendered docs keep the typographic arrow (U+2192) between phase ids. Script sources must
    # stay ASCII-only for Windows PowerShell 5.1 (BOM-less UTF-8 decodes via the ANSI codepage
    # there, and U+2192's bytes contain an apostrophe that breaks string literals), so the
    # character is emitted from its code point rather than written as a literal.
    $arrow = [string][char]0x2192
    $ctx['PHASE_LIST'] = ($phases | ForEach-Object { $_.Id }) -join (' ' + $arrow + ' ')
    $y = ''
    foreach ($p in $phases) {
        $y += ('  - { id: "' + $p.Id + '", name: "' + $p.Name + '", status: not_started }' + "`r`n")
    }
    $ctx['PHASE_LIST_YAML'] = $y.TrimEnd()

    switch ("$($Cfg['data_policy.sensitivity'])") {
        'regulated' { $ctx['DATA_PROTECTION_RULE'] = 'Data policy: REGULATED. Do not send sensitive data to external AI, scraping, browser, or research services until the owner records the applicable legal regime and approves each external flow.' }
        'personal'  { $ctx['DATA_PROTECTION_RULE'] = 'Data policy: PERSONAL data present. Do not send personal data to external AI, scraping, browser, or research services without explicit owner approval; minimize and redact by default.' }
        'business'  { $ctx['DATA_PROTECTION_RULE'] = 'Data policy: BUSINESS-sensitive. Internal data stays inside Git and approved tools; external services receive only public content.' }
        default     { $ctx['DATA_PROTECTION_RULE'] = 'Data policy: PUBLIC. Still never place secrets or credentials in any tool input, document, or bundle.' }
    }
    if ($Cfg['data_policy.rule_override']) { $ctx['DATA_PROTECTION_RULE'] = "Data policy: $($Cfg['data_policy.sensitivity']). " + $Cfg['data_policy.rule_override'] }
    $ctx['SESSION_MOVE_RULE'] = 'Do not move OpenCode sessions outside this project directory; if the installed OpenCode predates the 2.2.6 external-directory approval fix, treat session_move as prohibited for governed work.'

    # design-tool rules rendering
    if ("$($Cfg['integrations.design_system_tools'])" -eq 'true') {
        $ctx['DESIGN_TOOL_RULES'] = '- Project-specific tool routing lives in the Designer agent and docs/harness/skills-inventory.md.'
    } else {
        $ctx['DESIGN_TOOL_RULES'] = '- This project has no UI design tooling enabled; the DESIGN.md rules apply only if a design system artifact is introduced.'
    }

    # model table
    $ctx['MODEL_TABLE'] = "| PM, BA, Designer, Developer, QA | $($Cfg['models.default']) |`r`n| Code Reviewer, Security Monitor | $($Cfg['models.reviewer']) |"

    return $ctx
}

function New-PermRulesBlock {
    param([string]$Action, [string[]]$Values, [string]$Effect, [int]$Indent = 2)
    # Builds YAML permission-rule lines for agent templates: each value -> 4 lines,
    # values get a trailing * wildcard when they are shell command prefixes.
    $pad = ' ' * $Indent
    $out = ''
    foreach ($v in $Values) {
        if ([string]::IsNullOrWhiteSpace($v)) { continue }
        $res = $v
        if ($Action -eq 'shell' -and $res -notmatch '\*') { $res = $res + '*' }
        $out += ($pad + '- action: "' + $Action + '"' + "`r`n")
        $out += ($pad + '  resource: "' + ($res -replace '"','\"') + '"' + "`r`n")
        $out += ($pad + '  effect: "' + $Effect + '"' + "`r`n")
    }
    return $out.TrimEnd()
}

function Get-McpRenderBlocks { param([hashtable]$Cfg, [ref]$DenyOut, [ref]$ServersOut)
    $denies = ''
    # integration-toggled servers: ask when enabled, deny when disabled
    foreach ($pair in @(@('firecrawl','web_research'), @('browseros','browser_live'))) {
        $srv = $pair[0]; $tog = $pair[1]
        $on = ("$($Cfg["integrations.$tog"])" -eq 'true')
        $effect = if ($on) { 'ask' } else { 'deny' }
        $denies += ('    { "action": "' + $srv + '_*", "resource": "*", "effect": "' + $effect + '" },' + "`r`n")
    }
    # explicit deny list from project.yaml (composio_*, jira_*, pencil_*, ...)
    if ($Cfg['integrations.mcp_deny']) {
        foreach ($extra in @($Cfg['integrations.mcp_deny'])) {
            if ([string]::IsNullOrWhiteSpace($extra)) { continue }
            $denies += ('    { "action": "' + $extra + '", "resource": "*", "effect": "deny" },' + "`r`n")
        }
    }
    $DenyOut.Value = $denies   # keep trailing comma; lib-apply trims only if nothing follows

    $servers = ''
    if ("$($Cfg['integrations.open_knowledge'])" -eq 'true') {
        $okn = if ($Cfg['integrations.open_knowledge_path']) { $Cfg['integrations.open_knowledge_path'] } else { 'okn.exe' }
        $servers = ('      "project-knowledge": { "type": "local", "command": ["' + $okn + '", "mcp", "docs/project"], "enabled": false },' + "`r`n")
        $servers += ('      "harness-knowledge": { "type": "local", "command": ["' + $okn + '", "mcp", "docs/harness"], "enabled": false }')
    }
    $ServersOut.Value = $servers
}

function Get-StackDenyRules { param([hashtable]$Cfg)
    $out = ''
    foreach ($cli in @($Cfg['stack.deploy_commands'])) {
        if ([string]::IsNullOrWhiteSpace($cli)) { continue }
        $out += ('    { "action": "shell", "resource": "' + $cli + ' *", "effect": "deny" },' + "`r`n")
        $out += ('    { "action": "shell", "resource": "' + $cli + '", "effect": "deny" },' + "`r`n")
    }
    return $out.TrimEnd(",`r`n".ToCharArray())
}

function Get-SourceDenyRules { param([hashtable]$Cfg)
    # Source directories are denied for edit at the project level; only the Developer agent
    # re-allows them ({{DEVELOPER_SOURCE_ALLOWS}}). This closes the gap where the base `* * allow`
    # left application code editable by the orchestrator, QA and the reviewer. Each rule keeps a
    # trailing comma so the rendered JSONC stays valid ahead of the shell section.
    $out = ''
    foreach ($sd in @($Cfg['stack.source_dirs'])) {
        if ([string]::IsNullOrWhiteSpace($sd)) { continue }
        $out += ('    { "action": "edit", "resource": "' + $sd + '", "effect": "deny" },' + "`r`n")
    }
    return $out.TrimEnd("`r`n".ToCharArray())
}

function Get-StackPolicyDenies { param([hashtable]$Cfg)
    $out = ''
    foreach ($cli in @($Cfg['stack.deploy_commands'])) {
        if ([string]::IsNullOrWhiteSpace($cli)) { continue }
        $out += (",`r`n    { `"action`": `"tool.use`", `"resource`": `"shell:" + $cli + '*", "effect": "deny" }')
    }
    foreach ($h in @($Cfg['stack.hard_deny_commands'])) {
        if ([string]::IsNullOrWhiteSpace($h)) { continue }
        $out += (",`r`n    { `"action`": `"tool.use`", `"resource`": `"shell:" + $h + '*", "effect": "deny" }')
    }
    return $out
}

function Get-KitCommit {
    param([string]$KitDir, [string]$TargetDir)
    # Provenance rule. Only the kit's own repository can attest which kit commit is being rendered.
    # A rendered instance contains a *copy* of the kit, so git there reports the instance commit -
    # stamping that as the kit commit would make two instances of the same kit claim different
    # provenance, and re-applying an upgrade would silently rewrite its own history. So: inside an
    # instance, carry forward the stamp it already recorded; otherwise resolve from the kit repo;
    # otherwise say 'unknown' rather than invent something.
    $recorded = 'unknown'
    if ($TargetDir) {
        $py = Join-Path $TargetDir 'project.yaml'
        if (Test-Path $py) {
            foreach ($line in ((Read-TextRaw $py) -split "`r?`n")) {
                if ($line -match '^\s*rendered_from_commit:\s*(.+?)\s*$') {
                    $v = ($Matches[1] -replace '^["\x27]|["\x27]$', '').Trim()
                    if ($v -and $v -notmatch '\{\{') { $recorded = $v }
                }
            }
        }
    }
    if ($recorded -ne 'unknown') { return $recorded }

    $probeDir = Split-Path -Parent $KitDir
    $sha = ''
    $top = ''
    try { $sha = (& git -C $probeDir rev-parse --short HEAD 2>$null) } catch { $sha = '' }
    try { $top = (& git -C $probeDir rev-parse --show-toplevel 2>$null) } catch { $top = '' }
    if (-not $sha) { return 'unknown' }
    # A repository whose root holds project.yaml is an instance, not the kit home: its HEAD says
    # nothing about the kit. Refuse to attribute it.
    if ($top -and (Test-Path (Join-Path $top 'project.yaml'))) { return 'unknown' }
    return ([string]$sha).Trim()
}

function Expand-Template { param([string]$Text, [hashtable]$Ctx, [ref]$LeakList)
    $result = $Text
    foreach ($k in $Ctx.Keys) { $result = $result.Replace('{{' + $k + '}}', [string]$Ctx[$k]) }
    # leftover placeholders are collected, not left silently
    $ms = [regex]::Matches($result, '\{\{[A-Z0-9_]+\}\}')
    $leaks = @()
    foreach ($m in $ms) { $leaks += $m.Value }
    if ($leaks.Count -gt 0 -and $LeakList) { $LeakList.Value = $leaks | Sort-Object -Unique }
    return $result
}
