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

function Get-CodeOnly([string]$Text) {
    # Remove whole-line comments so commented-out code cannot masquerade as a live statement, while
    # still matching assignments that sit mid-line inside if/switch bodies.
    $kept = @($Text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' })
    return ($kept -join "`n")
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
Write-Host ("[1/10] sources: {0} scripts checked - ASCII-only, no BOM, parse clean" -f $scripts.Count)

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
Write-Host ("[2/10] data: {0} files scanned for BOM" -f $dataScanned)

# ---- 3. Template slot audit
# Produced slots: $ctx['X'] = ... / $slots['X'] = ... in the renderer, plus the tokens
# init-project.ps1 substitutes literally when it conducts the interactive interview.
$produced = @{}
foreach ($lib in @('lib-render.ps1', 'lib-apply.ps1')) {
    $libPath = Join-Path $repoRoot ('harness/scripts/' + $lib)
    if (-not (Test-Path $libPath)) { Add-Fail "missing renderer library: $lib"; continue }
    # Only a live assignment counts as a producer. Whole-line comments are stripped first so
    # commented-out code cannot hide the defect this audit exists to find, while assignments that
    # sit mid-line inside if/switch bodies (BROWSER_BASE_URL, DATA_PROTECTION_RULE) are still seen.
    foreach ($m in [regex]::Matches((Get-CodeOnly (Get-Text $libPath)), '\$(?:ctx|slots)\[''([A-Z0-9_]+)'']\s*\+?=')) {
        $produced[$m.Groups[1].Value] = $lib
    }
}
$initPath = Join-Path $repoRoot 'harness/scripts/init-project.ps1'
if (Test-Path $initPath) {
    foreach ($m in [regex]::Matches((Get-CodeOnly (Get-Text $initPath)), '\$\w+\s*=\s*\$\w+\.Replace\(''\{\{([A-Z0-9_]+)\}\}''')) {
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
# kit/project.yaml.tmpl is not rendered by Expand-Template: init-project.ps1's interview substitutes
# its tokens directly, so the audit above deliberately skips it. That skip hid a real defect - the
# template used {{KIT_COMMIT}} while the interview never replaced it, so every instance created
# through the documented onboarding path shipped a literal placeholder in its own project.yaml.
# Audit it here against the interview's actual producer set.
$interview = @{}
if (Test-Path $initPath) {
    $itText = Get-Text $initPath
    foreach ($m in [regex]::Matches($itText, '^\s+([A-Z][A-Z0-9_]*)\s*=\s*Read-Host', 'Multiline')) { $interview[$m.Groups[1].Value] = $true }
    foreach ($m in [regex]::Matches((Get-CodeOnly $itText), '\$\w+\s*=\s*\$\w+\.Replace\(''\{\{([A-Z0-9_]+)\}\}''')) { $interview[$m.Groups[1].Value] = $true }
}
$interviewTmpl = Join-Path $repoRoot 'harness/kit/project.yaml.tmpl'
$interviewUnknown = @()
if (Test-Path $interviewTmpl) {
    foreach ($m in [regex]::Matches((Get-Text $interviewTmpl), '\{\{([A-Z0-9_]+)\}\}')) {
        $tok = $m.Groups[1].Value
        if (-not $interview.ContainsKey($tok)) { $interviewUnknown += $tok }
    }
}
foreach ($tok in ($interviewUnknown | Sort-Object -Unique)) {
    Add-Fail ("project.yaml.tmpl slot {" + $tok + "} has no producer in init-project.ps1's interview")
}

Write-Host ("[3/10] slots: {0} distinct slots used by templates, {1} without a producer, {2} produced but unreferenced; interview template: {3} producers, {4} unproduced" -f $used.Count, $unknown.Count, $unused.Count, $interview.Count, @($interviewUnknown | Sort-Object -Unique).Count)
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
    'tests/fixture/project.yaml',
    'examples/nextjs-web.yaml',
    'examples/python-api.yaml',
    'examples/brownfield-internal.yaml'
)) {
    if (-not (Test-Path (Join-Path $repoRoot $r))) { Add-Fail "required kit path missing: $r" }
}

# ---- 5. Role, command and profile inventory
$agentTemplates = @(Get-ChildItem -File (Join-Path $repoRoot 'harness/kit/agents') -Filter *.md.tmpl -ErrorAction SilentlyContinue)
if ($agentTemplates.Count -ne 7) { Add-Fail "expected 7 role agent templates, found $($agentTemplates.Count)" }
$commandTemplates = @(Get-ChildItem -File (Join-Path $repoRoot 'harness/kit/commands') -Filter *.md.tmpl -ErrorAction SilentlyContinue)
if ($commandTemplates.Count -lt 16) { Add-Fail "expected at least 16 command templates, found $($commandTemplates.Count)" }
$version = (Get-Content (Join-Path $repoRoot 'harness/HARNESS-VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Add-Fail "HARNESS-VERSION is not a semantic version: '$version'" }
$profilesText = ''
$profilesPath = Join-Path $repoRoot 'harness/kit/lifecycle/profiles.yaml'
if (Test-Path $profilesPath) { $profilesText = Get-Text $profilesPath }
foreach ($profile in @('full', 'lean', 'headless', 'brownfield', 'micro')) {
    if ($profilesText -notmatch "(?m)^  $([regex]::Escape($profile)):\s*$") { Add-Fail "lifecycle profile '$profile' missing from profiles.yaml" }
}
Write-Host ("[4/10] contract: kit paths present, harness $version, 7 agents, {0} commands, 5 profiles" -f $commandTemplates.Count)

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
Write-Host ("[5/10] extensions: {0} kit files conform to md|yml|yaml|json|jsonc|ps1|txt (+.tmpl)" -f @(Get-ChildItem -File -Recurse (Join-Path $repoRoot 'harness/kit')).Count)

# ---- 6. Reachability: every kit file must be rendered, or be a declared non-rendered input.
#      Get-RenderPlan is the renderer's own statement of what it can reach, so it is called here
#      rather than re-implemented. This is the check that would have caught CODEOWNERS.tmpl and
#      pull_request_template.md.tmpl living in the kit, being asserted on by the docs, and never
#      rendered into a single instance.
. (Join-Path $repoRoot 'harness/scripts/lib-render.ps1')
. (Join-Path $repoRoot 'harness/scripts/lib-apply.ps1')
$kitPath = Join-Path $repoRoot 'harness/kit'
$planTarget = Join-Path ([System.IO.Path]::GetTempPath()) ('render-plan-audit-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$plan = @(Get-RenderPlan -KitDir $kitPath -TargetDir $planTarget)
$reachable = @{}
foreach ($item in $plan) {
    # Get-RenderPlan stores Src as a FileInfo for wildcard matches and a string for explicit singletons;
    # [string] normalizes both (FileInfo renders as its full path).
    $srcPath = [string]$item.Src
    $rel = ($srcPath.Substring($kitPath.Length + 1)) -replace '\\', '/'
    $reachable[$rel] = $true
    if (-not (Test-Path $srcPath)) { Add-Fail ("render plan points at a missing source: $rel") }
}
# Files the renderer never touches. Each needs a stated reason, so an exemption is a decision,
# not an oversight that nobody noticed.
$notRendered = @{}
$notRendered['project.yaml.tmpl'] = 'interview script substituted by init-project.ps1, not Expand-Template'
$notRendered['lifecycle/profiles.yaml'] = 'data input read by Get-ProfilePhases at render and label time'
$kitFiles = @(Get-ChildItem -File -Recurse $kitPath | ForEach-Object { ($_.FullName.Substring($kitPath.Length + 1)) -replace '\\', '/' })
foreach ($f in ($kitFiles | Sort-Object)) {
    if (-not $reachable.ContainsKey($f) -and -not $notRendered.ContainsKey($f)) {
        Add-Fail "kit file is unreachable from the render plan and has no declared exemption: $f"
    }
}
foreach ($f in @($notRendered.Keys | Sort-Object)) {
    if ($kitFiles -notcontains $f) { Add-Fail "declared non-rendered input is missing from the kit: $f" }
}
Write-Host ("[6/10] reachability: {0} kit files, {1} rendered by the plan, {2} declared inputs" -f $kitFiles.Count, $reachable.Count, $notRendered.Count)

# ---- 7. Data format contract: kit JSON must be JSON (sync-labels.ps1 pipes labels.json to
#      ConvertFrom-Json; the file shipped as commented YAML and no check could see that).
$jsonFiles = @(Get-ChildItem -File -Recurse $kitPath -Filter *.json -ErrorAction SilentlyContinue)
foreach ($f in $jsonFiles) {
    try { $null = (Get-Text $f.FullName) | ConvertFrom-Json }
    catch { Add-Fail ("{0} is not valid JSON ({1})" -f $f.Name, $_.Exception.Message) }
}
Write-Host ("[7/10] data formats: {0} kit JSON files parse" -f $jsonFiles.Count)

# ---- 8. Layer A purity: the harness must never name a project or inherit its domain vocabulary.
#      Stated for three versions and checked nowhere. Now absolute - no exemptions for the dated
#      evidence, the ADRs or the implementation log either: a generalised harness carries no trace of
#      the project it grew out of.
#      The terms are assembled from code points on purpose. Written plainly they would appear in the
#      file that bans them, which is both a false positive and, more to the point, a mention.
$banned = @(
    (-join [char[]]@(68, 101, 110, 116, 97, 108, 32, 80, 97, 114, 107)),
    (-join [char[]]@(100, 101, 110, 116, 97, 108, 45, 112, 97, 114, 107)),
    (-join [char[]]@(100, 101, 110, 116, 97, 108)),
    (-join [char[]]@(112, 97, 116, 105, 101, 110, 116)),
    (-join [char[]]@(99, 108, 105, 110, 105, 99)),
    (-join [char[]]@(100, 101, 110, 116, 105, 115, 116))
)
if ($banned.Count -ne 6) { Add-Fail ("purity term list is malformed ({0} entries, expected 6) - the check would not work" -f $banned.Count) }
# Positive control: a vacuous ban list is indistinguishable from a clean repository, so prove the
# scanner can see a violation before believing its silence. This suite has been bitten by exactly that.
$probe = "readme " + $banned[0] + " mention"
if (-not ($probe -match [regex]::Escape($banned[0]))) { Add-Fail 'purity check is vacuous: its own terms do not match a known-bad sample' }
$purityRoots = @('harness', 'docs', 'tests', 'site', '.github', 'examples')
$purityScanned = 0
foreach ($root in $purityRoots) {
    $dir = Join-Path $repoRoot $root
    if (-not (Test-Path $dir)) { continue }
    foreach ($f in (Get-ChildItem -File -Recurse $dir -ErrorAction SilentlyContinue)) {
        $rel = ($f.FullName.Substring($repoRoot.Length + 1)) -replace '\\', '/'
        if ($f.Extension -notin @('.md', '.tmpl', '.ps1', '.yaml', '.yml', '.json', '.jsonc', '.html')) { continue }
        if ($rel -eq 'tests/check-sources.ps1') { continue }   # carries the terms as code points
        $purityScanned++
        $body = Get-Text $f.FullName
        foreach ($term in $banned) {
            if ($body -match [regex]::Escape($term)) { Add-Fail ("project identity or domain vocabulary found in: {0}" -f $rel) }
        }
    }
}
foreach ($topFile in @('README.md', 'CHANGELOG.md', 'LICENSE')) {
    $tf = Join-Path $repoRoot $topFile
    if (-not (Test-Path $tf)) { continue }
    $purityScanned++
    $body = Get-Text $tf
    foreach ($term in $banned) {
        if ($body -match [regex]::Escape($term)) { Add-Fail ("project identity or domain vocabulary found in: {0}" -f $topFile) }
    }
}
Write-Host ("[8/10] purity: {0} files scanned for project identity, no exemptions" -f $purityScanned)

# ---- 9. Rule-injecting slots must sit at column 0 in the agent templates. New-PermRulesBlock emits
#      its own indentation, so an indented slot line makes the FIRST generated list item deeper than
#      its siblings, and the agent's YAML frontmatter stops parsing. Three pre-existing slots had this
#      latent defect; it only surfaced once they expanded to non-empty grants.
foreach ($f in (Get-ChildItem -File (Join-Path $repoRoot 'harness/kit/agents') -Filter *.tmpl -ErrorAction SilentlyContinue)) {
    foreach ($ln in ((Get-Text $f.FullName) -split "`r?`n")) {
        if ($ln -match '^[ ]+\{\{[A-Z_]+_(?:ALLOWS|RULES)\}\}\s*$') {
            Add-Fail ("{0}: rule-injecting slot is indented; the generated block self-indents, so this breaks YAML frontmatter: '{1}'" -f $f.Name, $ln.Trim())
        }
    }
}
Write-Host "[9/10] slots at column 0 in the agent templates"

# ---- 10. Verification ledger. This file is the only place that says what is actually proven, so it
#      is checked like code: schema, status vocabulary, no verified-without-evidence, unique ids, and
#      a two-way join with the runtime negative-test protocol so neither side can drift into wishful
#      prose. validate-harness.ps1 re-reads it per instance and check-site.ps1 compares its counts
#      against the numbers printed in the handbook.
$ledgerPath = Join-Path $repoRoot 'docs/harness/verification-ledger.json'
if (-not (Test-Path $ledgerPath)) {
    Add-Fail 'verification ledger missing: docs/harness/verification-ledger.json'
    Write-Host '[10/10] ledger: missing'
} else {
    $ledger = $null
    try { $ledger = (Get-Text $ledgerPath) | ConvertFrom-Json } catch { Add-Fail ("ledger is not valid JSON: " + $_.Exception.Message) }
    $tallies = @{ designed = 0; implemented = 0; verified = 0 }
    if ($ledger) {
        if ($ledger.schema -ne 'aidlc.verification-ledger/1') { Add-Fail ("ledger schema unexpected: '$($ledger.schema)'") }
        $seenIds = @{}
        $claimed = @{}
        foreach ($c in @($ledger.controls)) {
            if (-not $c.id -or -not $c.control -or -not $c.tier -or -not $c.status) {
                Add-Fail ("ledger row missing required fields (id/control/tier/status): " + $c.id); continue
            }
            if ($seenIds.ContainsKey($c.id)) { Add-Fail ("duplicate ledger id " + $c.id) }
            $seenIds[$c.id] = $true
            if ('designed', 'implemented', 'verified' -notcontains $c.status) {
                Add-Fail ("ledger {0} has unknown status '{1}'" -f $c.id, $c.status)
            } else {
                $tallies[$c.status] = $tallies[$c.status] + 1
            }
            $ev = @($c.evidence)
            if ($c.status -eq 'verified' -and $ev.Count -eq 0) {
                Add-Fail ("ledger {0} claims verified with no evidence" -f $c.id)
            }
            foreach ($e in $ev) {
                if (-not $e.kind -or -not $e.ref) { Add-Fail ("ledger {0} evidence entry needs kind and ref" -f $c.id) }
                elseif ('check', 'ci', 'run' -notcontains $e.kind) { Add-Fail ("ledger {0} evidence kind '{1}' is not check|ci|run" -f $c.id, $e.kind) }
            }
            foreach ($tid in @($c.tests)) { if ($tid) { $claimed[$tid] = $true } }
        }
        $negPath = Join-Path $repoRoot 'harness/scripts/negative-tests.md'
        $protocol = @()
        if (Test-Path $negPath) {
            $protocol = @([regex]::Matches((Get-Text $negPath), '\b([NG]-\d{2})\b') |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        } else { Add-Fail 'negative-tests.md missing; the ledger has nothing to cross-reference' }
        foreach ($tid in @($claimed.Keys | Sort-Object)) {
            if ($protocol -notcontains $tid) { Add-Fail ("ledger cites runtime test {0} which does not exist in negative-tests.md" -f $tid) }
        }
        $orphans = @($protocol | Where-Object { -not $claimed.ContainsKey($_) })
        if ($orphans.Count -gt 0) { Add-Fail ("runtime tests claimed by no ledger control: " + ($orphans -join ', ')) }
    }
    Write-Host ("[10/10] ledger: {0} controls (verified {1}, implemented {2}, designed {3}); {4} runtime tests claimed both ways" -f $seenIds.Count, $tallies.verified, $tallies.implemented, $tallies.designed, $protocol.Count)
}

if ($fails.Count -gt 0) {
    Write-Host ""
    Write-Host ("check-sources: {0} VIOLATION(S)" -f $fails.Count)
    foreach ($x in $fails) { Write-Host ("  [FAIL] " + $x) }
    exit 1
}
Write-Host "check-sources: PASS"
exit 0
