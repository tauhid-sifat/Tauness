# check-sources.ps1 - kit source policy: the static checks that must hold on every platform.
#
# Why each check exists - every one is a defect this kit actually shipped with:
#   * BOM-less UTF-8 script files containing non-ASCII literals do NOT parse under Windows
#     PowerShell 5.1, which decodes them with the ANSI codepage. U+2192 decodes to bytes that
#     contain an apostrophe and silently breaks string literals. The kit claims 5.1+ support, so
#     script sources must be ASCII-only; glyphs needed in rendered output must be emitted from
#     code points (see lib-render.ps1 PHASE_LIST).
#   * One stray quote in a rendering helper makes the renderer unrunnable, and nothing notices
#     until a human executes it. Tokenizing every script catches that without running it.
#   * A .tmpl truncated by the wrong character count produces silently mangled instance files
#     (business-analyst.m, bug.ym), so the slot audit also asserts the kit contract by name.
#   * Templates read explicitly as UTF-8 may not carry a BOM: it would flow into generated files.
#
# Usage: pwsh -File tests/check-sources.ps1     (exit 0 = clean, exit 1 = violations)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fails = @()
function Add-Fail([string]$What) { $script:fails += $What }

function Get-Text([string]$Path) {
    # Explicit UTF-8 decode, independent of the host's ANSI codepage.
    return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path))
}

# ---- 1. Script sources: ASCII-only, no BOM, parse cleanly (kit scripts and test scripts alike)
$allowedExt = @('md', 'yml', 'yaml', 'json', 'jsonc', 'ps1', 'txt')
$scriptDirs = @((Join-Path $repoRoot 'harness/scripts'), $PSScriptRoot)
$scripts = @()
foreach ($sd in $scriptDirs) { $scripts += @(Get-ChildItem -File $sd -Filter *.ps1 -ErrorAction SilentlyContinue) }
if ($scripts.Count -eq 0) { Add-Fail 'no PowerShell scripts found under harness/scripts or tests' }
foreach ($f in $scripts) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Add-Fail ("{0}: has a UTF-8 BOM" -f $f.Name)
    }
    $text = Get-Text $f.FullName
    $bad = @([regex]::Matches($text, '[^\x00-\x7F]'))
    if ($bad.Count -gt 0) {
        $codes = @($bad | ForEach-Object { 'U+' + ('{0:X4}' -f [int][char]$_.Value) } | Sort-Object -Unique)
        Add-Fail ("{0}: {1} non-ASCII characters ({2}); PS 5.1 cannot parse this file - emit glyphs from code points instead" -f $f.Name, $bad.Count, ($codes -join ', '))
    }
    $errs = $null
    [System.Management.Automation.PSParser]::Tokenize($text, [ref]$errs) | Out-Null
    if (@($errs).Count -gt 0) {
        $first = @($errs)[0]
        Add-Fail ("{0}: parse error at line {1}, column {2}: {3}" -f $f.Name, $first.Token.StartLine, $first.Token.StartColumn, $first.Message)
    }
}
Write-Host ("[1/5] sources: {0} scripts checked - ASCII-only, no BOM, parse clean" -f $scripts.Count)

# ---- 2. Data files: no BOM in the kit, core docs, or fixtures
$dataRoots = @('harness', 'docs/harness', 'tests')
$dataScanned = 0
foreach ($rel in $dataRoots) {
    $dir = Join-Path $repoRoot $rel
    if (-not (Test-Path $dir)) { continue }
    foreach ($f in (Get-ChildItem -File -Recurse $dir -ErrorAction SilentlyContinue)) {
        $dataScanned++
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Add-Fail ("{0}: has a UTF-8 BOM" -f $f.FullName.Substring($repoRoot.Length + 1))
        }
    }
}
Write-Host ("[2/5] data: {0} files scanned for BOM" -f $dataScanned)

# ---- 3. Template slot audit
# Produced slots: $ctx['X'] = ... / $slots['X'] = ... in the renderer, plus the tokens
# init-project.ps1 substitutes literally when it conducts the interactive interview.
$produced = @{}
foreach ($lib in @('lib-render.ps1', 'lib-apply.ps1')) {
    $libPath = Join-Path $repoRoot ('harness/scripts/' + $lib)
    if (-not (Test-Path $libPath)) { Add-Fail "missing renderer library: $lib"; continue }
    foreach ($m in [regex]::Matches((Get-Text $libPath), '\$(?:ctx|slots)\[''([A-Z0-9_]+)'']\s*\+?=')) {
        $produced[$m.Groups[1].Value] = $lib
    }
}
$initPath = Join-Path $repoRoot 'harness/scripts/init-project.ps1'
if (Test-Path $initPath) {
    foreach ($m in [regex]::Matches((Get-Text $initPath), "'\{\{([A-Z0-9_]+)\}\}'")) {
        $produced[$m.Groups[1].Value] = 'init-project.ps1'
    }
}

# Used slots: every template the render plan processes. kit/project.yaml.tmpl is excluded on
# purpose: it is not rendered by Expand-Template, it is the interview script consumed by
# init-project.ps1's own substitution loop, so its tokens are keyed to $vals, not to $ctx.
$used = @{}
$kitDir = Join-Path $repoRoot 'harness/kit'
if (Test-Path $kitDir) {
    foreach ($f in (Get-ChildItem -File -Recurse $kitDir -ErrorAction SilentlyContinue)) {
        if ($f.Name -eq 'project.yaml.tmpl') { continue }
        foreach ($m in [regex]::Matches((Get-Text $f.FullName), '\{\{([A-Z0-9_]+)\}\}')) {
            $tok = $m.Groups[1].Value
            if (-not $used.ContainsKey($tok)) { $used[$tok] = @() }
            $used[$tok] += $f.Name
        }
    }
}
$unknown = @($used.Keys | Where-Object { -not $produced.ContainsKey($_) } | Sort-Object)
foreach ($tok in $unknown) {
    Add-Fail ("template slot {{{0}}} has no producer in the renderer (used by: {1})" -f $tok, (($used[$tok] | Sort-Object -Unique) -join ', '))
}
$unused = @($produced.Keys | Where-Object { -not $used.ContainsKey($_) } | Sort-Object)
Write-Host ("[3/5] slots: {0} distinct slots used by templates, {1} without a producer, {2} produced but unreferenced" -f $used.Count, $unknown.Count, $unused.Count)
if ($unused.Count -gt 0) { Write-Host ("       produced but not referenced by rendered templates (project.yaml.tmpl consumes these at interview time): " + ($unused -join ', ')) }

# ---- 4. Core kit contract, asserted by name
foreach ($r in @(
    'harness/HARNESS-VERSION',
    'harness/README.md',
    'harness/kit/AGENTS.md.tmpl',
    'harness/kit/gitignore.tmpl',
    'harness/kit/README-project.md.tmpl',
    'harness/kit/project.yaml.tmpl',
    'harness/kit/config/opencode.jsonc.tmpl',
    'harness/kit/lifecycle/profiles.yaml',
    'harness/kit/github/labels.json',
    'harness/kit/github/workflows/harness-validation.yml',
    'harness/scripts/init-project.ps1',
    'harness/scripts/apply-harness-change.ps1',
    'harness/scripts/validate-harness.ps1',
    'harness/scripts/sync-labels.ps1',
    'harness/scripts/lib-render.ps1',
    'harness/scripts/lib-apply.ps1',
    'docs/harness/architecture-specification.md',
    'docs/harness/agent-specifications.md',
    'docs/harness/workflow-and-governance.md',
    'docs/harness/security-and-permissions.md',
    'docs/harness/github-governance.md',
    'docs/harness/knowledge-management.md',
    'docs/harness/project-initialization.md',
    'docs/harness/using-the-harness.md',
    'docs/harness/open-decisions.md',
    'docs/harness/implementation-roadmap.md',
    'docs/harness/skills-inventory.md',
    'docs/harness/opencode-capability-matrix.md',
    'docs/harness/repository-structure.md',
    'tests/fixture/project.yaml'
)) {
    if (-not (Test-Path (Join-Path $repoRoot $r))) { Add-Fail "required kit path missing: $r" }
}

# ---- 5. Role, command and profile inventory
$agentTemplates = @(Get-ChildItem -File (Join-Path $repoRoot 'harness/kit/agents') -Filter *.md.tmpl -ErrorAction SilentlyContinue)
if ($agentTemplates.Count -ne 7) { Add-Fail "expected 7 role agent templates, found $($agentTemplates.Count)" }
$commandTemplates = @(Get-ChildItem -File (Join-Path $repoRoot 'harness/kit/commands') -Filter *.md.tmpl -ErrorAction SilentlyContinue)
if ($commandTemplates.Count -lt 15) { Add-Fail "expected at least 15 command templates, found $($commandTemplates.Count)" }
$version = (Get-Content (Join-Path $repoRoot 'harness/HARNESS-VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Add-Fail "HARNESS-VERSION is not a semantic version: '$version'" }
$profilesText = ''
$profilesPath = Join-Path $repoRoot 'harness/kit/lifecycle/profiles.yaml'
if (Test-Path $profilesPath) { $profilesText = Get-Text $profilesPath }
foreach ($profile in @('full', 'lean', 'headless', 'brownfield', 'micro')) {
    if ($profilesText -notmatch "(?m)^  $([regex]::Escape($profile)):\s*$") { Add-Fail "lifecycle profile '$profile' missing from profiles.yaml" }
}
Write-Host ("[4/5] contract: kit paths present, harness $version, 7 agents, {0} commands, 5 profiles" -f $commandTemplates.Count)

# Kit file names must be truncation-safe: the renderer strips the .tmpl suffix by character count,
# so anything left over must be a real, expected extension (CODEOWNERS.tmpl correctly leaves no
# extension at all; business-analyst.m would not).
$mangled = @(Get-ChildItem -File -Recurse (Join-Path $repoRoot 'harness/kit') -ErrorAction SilentlyContinue | Where-Object {
    $leaf = $_.Name
    if ($leaf.EndsWith('.tmpl')) { $leaf = $leaf.Substring(0, $leaf.Length - 5) }
    $ext = [System.IO.Path]::GetExtension($leaf).TrimStart('.')
    if ($ext -eq '') { return $false }
    return -not ($allowedExt -contains $ext.ToLowerInvariant())
})
foreach ($m in $mangled) { Add-Fail ("unexpected file extension: " + $m.Name) }
Write-Host ("[5/5] extensions: {0} kit files conform to md|yml|yaml|json|jsonc|ps1|txt (+.tmpl)" -f @(Get-ChildItem -File -Recurse (Join-Path $repoRoot 'harness/kit')).Count)

if ($fails.Count -gt 0) {
    Write-Host ""
    Write-Host ("check-sources: {0} VIOLATION(S)" -f $fails.Count)
    foreach ($x in $fails) { Write-Host ("  [FAIL] " + $x) }
    exit 1
}
Write-Host "check-sources: PASS"
exit 0
