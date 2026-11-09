# render-and-validate.ps1 - AIDLC harness kit self-test.
#
# Renders a throwaway instance for every lifecycle profile (plus one variant with all integration
# toggles on) from harness/kit + tests/fixture/project.yaml, then validates each rendered instance
# with the kit's own validator. This is the development loop for the kit: edit a template, run this,
# and see whether the kit still produces a conforming instance. Without it, template and renderer
# changes land unverified - which is how the kit shipped with a truncated-extension renderer, an
# unparseable rendering helper, and a HARNESS-VERSION lookup that could never resolve.
#
# Runs on Windows PowerShell 5.1+ and PowerShell 7. The renderer itself still addresses files with
# Windows path separators, so instance rendering is exercised on Windows runners only; the static
# source policy in check-sources.ps1 is platform-neutral and runs everywhere.
#
# Usage: pwsh -File tests/render-and-validate.ps1 [-Profiles full,lean] [-KeepArtifacts]

param(
    [string[]]$Profiles = @('full', 'lean', 'headless', 'brownfield', 'micro'),
    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$repoRoot   = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repoRoot 'harness/scripts'
$fixturePath = Join-Path $repoRoot 'tests/fixture/project.yaml'
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('aidlc-kit-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
New-Item -ItemType Directory -Path $workRoot | Out-Null

$fails = @()
$lines = @()
function Get-Text([string]$Path) { return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path)) }
function Get-TextSafe([string]$Path) {
    # A missing artifact is a test failure, not a crash: return empty text so the assertions below
    # report which expectation went unmet.
    if (-not (Test-Path $Path)) { return '' }
    return Get-Text $Path
}
function Get-StableText([string]$Path) {
    # Content with generated date stamps removed and newlines normalized, so "re-render produced the
    # same instance" can be asserted without the test failing at midnight.
    $t = Get-TextSafe $Path
    return (($t -split "`r?`n" | Where-Object { $_ -notmatch '\d{4}-\d{2}-\d{2}' }) -join "`n")
}
function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

try {
    Write-Host '== AIDLC harness kit self-test =='
    Write-Host "work root: $workRoot"

    & (Join-Path $PSScriptRoot 'check-sources.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'check-sources.ps1 reported violations (see output above)' }
    if (-not (Test-Path $fixturePath)) { throw "fixture missing: $fixturePath" }

    $fixtureText = Get-Text $fixturePath

    $variants = @()
    foreach ($p in $Profiles) { $variants += [pscustomobject]@{ Name = 'profile-' + $p; Profile = $p; AllIntegrations = $false } }
    $variants += [pscustomobject]@{ Name = 'profile-full-all-integrations'; Profile = 'full'; AllIntegrations = $true }

    $requiredFiles = @(
        'AGENTS.md', 'opencode.jsonc', 'project.yaml', '.gitignore', 'README.md',
        (Join-Path 'harness' 'HARNESS-VERSION'),
        (Join-Path 'harness/kit' 'project.yaml.tmpl'),
        (Join-Path 'docs/harness' 'architecture-specification.md'),
        (Join-Path 'docs/project/status' 'phase-state.md'),
        (Join-Path 'docs/project' 'traceability.md'),
        (Join-Path 'docs/project/decisions' 'decision-register.md'),
        (Join-Path '.github/ISSUE_TEMPLATE' 'bug.yml'),
        (Join-Path '.github/workflows' 'ci.yml'),
        (Join-Path '.github/workflows' 'harness-validation.yml'),
        (Join-Path '.github' 'CODEOWNERS'),
        (Join-Path '.github' 'pull_request_template.md'),
        (Join-Path '.opencode/agents' 'project-manager.md'),
        (Join-Path '.opencode/commands' 'pm.md'),
        (Join-Path '.opencode/commands' 'improve-harness.md')
    )
    $requiredPassMarkers = @(
        '[PASS] agents:count', '[PASS] commands:count', '[PASS] placeholders',
        '[PASS] phase-state', '[PASS] config:policies', '[PASS] config:shell-deny',
        '[PASS] encoding:bom', '[PASS] secrets:scan', '[PASS] doc:architecture-specification'
    )

    foreach ($v in $variants) {
        $tag = ($v.Name -replace '[^A-Za-z0-9_.-]', '_')
        $dir = Join-Path $workRoot $tag
        $cfg = Join-Path $workRoot ($tag + '.project.yaml')

        $text = $fixtureText.Replace('profile: "full"', ('profile: "' + $v.Profile + '"'))
        # The fixture states a literal kit version because project.yaml is copied verbatim into the
        # instance (an unresolved placeholder there is a leak). The runner rewrites it to the real
        # version and the instance stamp is asserted below, so bumping HARNESS-VERSION needs no
        # fixture edit and a mismatch still fails.
        $kitVersion = (Get-Content (Join-Path $repoRoot 'harness/HARNESS-VERSION') -Raw).Trim()
        $text = $text.Replace('kit_version: "1.0.0"', ('kit_version: "' + $kitVersion + '"'))
        if ($v.AllIntegrations) {
            foreach ($k in @('github_projects_v2', 'open_knowledge', 'browser_live', 'web_research', 'design_system_tools')) {
                $text = $text.Replace(($k + ': false'), ($k + ': true'))
            }
        }
        Write-Utf8NoBom $cfg $text

        # ---- render. The kit scripts report through Write-Host, which is the information stream
        #      and never enters the output pipeline, so the assertions below read the artifacts and
        #      exit codes rather than parsing child stdout. Streams 6 and 2 are folded into stdout
        #      and discarded to keep this test's own output readable.
        $initExit = 0
        try {
            & (Join-Path $scriptsDir 'init-project.ps1') -Target $dir -Config $cfg 6>&1 2>&1 | Out-Null
            $initExit = $LASTEXITCODE
        } catch {
            $fails += ("{0}: init-project.ps1 threw: {1}" -f $v.Name, $_.Exception.Message)
            continue
        }
        if ($initExit -ne 0) { $fails += ("{0}: init-project.ps1 exit {1} (2 = placeholder leak)" -f $v.Name, $initExit) }
        if ($initExit -eq 2) { $fails += ("{0}: render reported unresolved placeholders" -f $v.Name) }

        # generated files only: the instance also carries a copy of harness/ (kit + scripts)
        $generated = @(Get-ChildItem -File -Recurse $dir -ErrorAction SilentlyContinue |
            Where-Object { (($_.FullName.Substring($dir.Length + 1)) -replace '\\', '/') -notlike 'harness/*' })
        if ($generated.Count -lt 55) { $fails += ("{0}: only {1} files rendered (expected the full kit)" -f $v.Name, $generated.Count) }

        # ---- artifact names: the renderer strips the .tmpl suffix by character count, so a
        #      regression there shows up as truncated extensions or leftover templates
        foreach ($r in $requiredFiles) {
            if (-not (Test-Path (Join-Path $dir $r))) { $fails += ("{0}: rendered instance is missing {1}" -f $v.Name, $r) }
        }
        # Generated files must not carry truncated or leftover template names. The copied harness/
        # tree legitimately holds *.tmpl sources, so only the generated set is scanned here.
        $badNames = @($generated | Where-Object { $_.Name -match '\.(m|ym|yam)$' -or $_.Name.EndsWith('.tmpl') })
        if ($badNames.Count -gt 0) {
            $fails += ("{0}: {1} file(s) with truncated or leftover template names: {2}" -f $v.Name, $badNames.Count, (($badNames | ForEach-Object { $_.Name } | Select-Object -First 6) -join ', '))
        }

        $agentCount = @(Get-ChildItem -File (Join-Path $dir '.opencode/agents') -Filter *.md -ErrorAction SilentlyContinue).Count
        if ($agentCount -ne 7) { $fails += ("{0}: expected 7 rendered role agents, found {1}" -f $v.Name, $agentCount) }
        $cmdCount = @(Get-ChildItem -File (Join-Path $dir '.opencode/commands') -Filter *.md -ErrorAction SilentlyContinue).Count
        if ($cmdCount -ne 16) { $fails += ("{0}: expected 16 rendered commands, found {1}" -f $v.Name, $cmdCount) }
        $issueCount = @(Get-ChildItem -File (Join-Path $dir '.github/ISSUE_TEMPLATE') -Filter *.yml -ErrorAction SilentlyContinue).Count
        if ($issueCount -lt 11) { $fails += ("{0}: expected at least 11 issue forms, found {1}" -f $v.Name, $issueCount) }
        $coreDocCount = @(Get-ChildItem -File (Join-Path $dir 'docs/harness') -Filter *.md -ErrorAction SilentlyContinue).Count
        if ($coreDocCount -lt 13) { $fails += ("{0}: core docs not copied into the instance (found {1} in docs/harness)" -f $v.Name, $coreDocCount) }

        # ---- profile actually reached the instance
        $phaseState = ''
        $phasePath = Join-Path $dir 'docs/project/status/phase-state.md'
        if (Test-Path $phasePath) { $phaseState = Get-Text $phasePath }
        if ($phaseState -notmatch [regex]::Escape($v.Profile)) { $fails += ("{0}: profile '{1}' not present in phase-state.md" -f $v.Name, $v.Profile) }
        $agentsMd = Get-TextSafe (Join-Path $dir 'AGENTS.md')
        if ($agentsMd -notmatch [regex]::Escape($v.Profile)) { $fails += ("{0}: profile '{1}' not present in AGENTS.md" -f $v.Name, $v.Profile) }

        # ---- integration toggles must change rendered enforcement, not just docs
        if ($v.AllIntegrations) {
            $openCode = Get-TextSafe (Join-Path $dir 'opencode.jsonc')
            if ($openCode -notmatch 'firecrawl_\*.*"ask"') { $fails += ("{0}: web_research=true did not render firecrawl_* as ask" -f $v.Name) }
            if ($openCode -notmatch 'browseros_\*.*"ask"') { $fails += ("{0}: browser_live=true did not render browseros_* as ask" -f $v.Name) }
            if ($openCode -notmatch 'project-knowledge') { $fails += ("{0}: open_knowledge=true did not render the mcp.servers block" -f $v.Name) }
            if ($openCode -notmatch 'composio_\*.*"deny"') { $fails += ("{0}: integrations.mcp_deny entries were not rendered as denies" -f $v.Name) }
            $designer = Get-TextSafe (Join-Path $dir '.opencode/agents/designer.md')
            if ($designer -notmatch 'impeccable') { $fails += ("{0}: design_system_tools=true did not grant the Designer its tooling" -f $v.Name) }
            $qa = Get-TextSafe (Join-Path $dir '.opencode/agents/qa-engineer.md')
            if ($qa -notmatch 'browseros-neo') { $fails += ("{0}: browser_live=true did not grant QA the live-browser skill" -f $v.Name) }
        } else {
            $openCode = Get-TextSafe (Join-Path $dir 'opencode.jsonc')
            if ($openCode -notmatch 'firecrawl_\*.*"deny"') { $fails += ("{0}: web_research=false must render firecrawl_* as deny" -f $v.Name) }
        }

        # deploy CLIs must reach both the permission and the delegation-proof policy layer
        $openCodeAll = Get-TextSafe (Join-Path $dir 'opencode.jsonc')
        if ($openCodeAll -notmatch 'vercel') { $fails += ("{0}: stack.deploy_commands did not render vercel denies" -f $v.Name) }
        if ($openCodeAll -notmatch 'tool.use.*shell:vercel') { $fails += ("{0}: deploy CLI missing from the policies (tool.use) layer" -f $v.Name) }

        # ---- governance artifacts the documentation promises must actually be produced. CODEOWNERS
        #      is what makes "only the owner merges" a GitHub-side control (negative test G-02); both
        #      files sat in the kit and were rendered into nothing until the render plan was audited.
        $ownersText = Get-TextSafe (Join-Path $dir '.github/CODEOWNERS')
        if ($ownersText -notmatch '@example-owner') { $fails += ("{0}: CODEOWNERS missing or does not name the project owner" -f $v.Name) }
        if ($ownersText -notmatch '/docs/project/decisions/') { $fails += ("{0}: CODEOWNERS does not route decision history to the owner" -f $v.Name) }
        $prTpl = Get-TextSafe (Join-Path $dir '.github/pull_request_template.md')
        if ($prTpl -notmatch 'Req: FIX-REQ-') { $fails += ("{0}: PR template missing or rendered without the project ID prefix" -f $v.Name) }
        $projYaml = Get-TextSafe (Join-Path $dir 'project.yaml')
        if ($projYaml -notmatch ('kit_version: "' + [regex]::Escape($kitVersion) + '"')) { $fails += ("{0}: instance kit_version stamp is not {1}" -f $v.Name, $kitVersion) }
        # Provenance must be attested and must match between the record and the generated files.
        if ($projYaml -match 'rendered_from_commit:\s*\{\{') { $fails += ("{0}: project.yaml still carries an unsubstituted commit placeholder" -f $v.Name) }
        if ($projYaml -notmatch '(?m)^\s*rendered_from_commit: "?[a-f0-9]{7,40}"?\s*$') { $fails += ("{0}: project.yaml does not record an attested kit commit" -f $v.Name) }
        if ((Get-TextSafe (Join-Path $dir 'opencode.jsonc')) -notmatch 'commit [a-f0-9]{7,40}') { $fails += ("{0}: opencode.jsonc baseline does not name a kit commit" -f $v.Name) }

        # ---- validate with the kit's own validator; results come from the report it writes
        $before = $fails.Count
        $resultLine = ''
        $vExit = 0
        try {
            & (Join-Path $scriptsDir 'validate-harness.ps1') -Root $dir 6>&1 2>&1 | Out-Null
            $vExit = $LASTEXITCODE
        } catch {
            $fails += ("{0}: validate-harness.ps1 threw: {1}" -f $v.Name, $_.Exception.Message)
            continue
        }

        $repFile = $null
        $repDir = Join-Path $dir 'harness/reports'
        if (Test-Path $repDir) {
            $found = @(Get-ChildItem -File $repDir -Filter 'validate-*.md' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
            if ($found.Count -gt 0) { $repFile = $found[$found.Count - 1].FullName }
        }
        if (-not $repFile) {
            $fails += ("{0}: validator wrote no report under harness/reports - it did not run" -f $v.Name)
        } else {
            $rep = Get-Text $repFile
            foreach ($l in ($rep -split "`r?`n")) { if ($l -match '^\*\*Result: ') { $resultLine = $l } }
            if (-not $resultLine) { $fails += ("{0}: validation report has no Result line: {1}" -f $v.Name, $repFile) }
            if ($resultLine -match '(\d+) FAIL' -and [int]$Matches[1] -gt 0) { $fails += ("{0}: {1}" -f $v.Name, $resultLine) }
            if ($vExit -ne 0) {
                $fails += ("{0}: validate-harness.ps1 exit {1}" -f $v.Name, $vExit)
                foreach ($fl in ($rep -split "`r?`n" | Where-Object { $_ -match '^\[FAIL\]' })) { $fails += ("{0}: {1}" -f $v.Name, $fl) }
            }
            # A check that silently errored out records neither PASS nor FAIL, so require the
            # markers that matter rather than trusting a clean exit code alone.
            foreach ($marker in $requiredPassMarkers) {
                if ($rep -notmatch [regex]::Escape($marker)) { $fails += ("{0}: validator recorded no '{1}' - that check was skipped, not passed" -f $v.Name, $marker) }
            }
        }

        # ---- upgrade path: apply-harness-change.ps1 re-renders an instance from the kit. "Upgrades
        #      propagate mechanically" is the kit's central promise and this path had zero coverage.
        $applyBackup = Join-Path $workRoot ($tag + '.apply-backup')
        $agentsBefore = Get-StableText (Join-Path $dir 'AGENTS.md')
        $configBefore = Get-StableText (Join-Path $dir 'opencode.jsonc')
        $applyDryExit = -1
        $applyThrew = $false
        Push-Location $dir
        try {
            & (Join-Path $scriptsDir 'apply-harness-change.ps1') -DryRun 6>&1 2>&1 | Out-Null
            $applyDryExit = $LASTEXITCODE
            & (Join-Path $scriptsDir 'apply-harness-change.ps1') -Force -BackupDir $applyBackup 6>&1 2>&1 | Out-Null
        } catch {
            $applyThrew = $true
            $fails += ("{0}: apply-harness-change.ps1 threw: {1}" -f $v.Name, $_.Exception.Message)
        } finally { Pop-Location }
        if ($applyDryExit -ne 0) { $fails += ("{0}: apply -DryRun exit {1}" -f $v.Name, $applyDryExit) }
        if (-not $applyThrew) {
            # The success path sets no exit code, so completion is proven from the artifacts the
            # script promises: a backup copy of every file it overwrites.
            foreach ($b in @('AGENTS.md', 'opencode.jsonc', (Join-Path '.opencode\agents' 'project-manager.md'), (Join-Path '.github' 'CODEOWNERS'), (Join-Path '.github' 'pull_request_template.md'))) {
                if (-not (Test-Path (Join-Path $applyBackup $b))) { $fails += ("{0}: apply overwrote {1} without backing it up first" -f $v.Name, $b) }
            }
            if ((Get-StableText (Join-Path $dir 'AGENTS.md')) -ne $agentsBefore) { $fails += ("{0}: re-apply changed AGENTS.md - rendering is not deterministic" -f $v.Name) }
            if ((Get-StableText (Join-Path $dir 'opencode.jsonc')) -ne $configBefore) { $fails += ("{0}: re-apply changed opencode.jsonc - rendering is not deterministic" -f $v.Name) }
            # an upgrade must not degrade the instance
            & (Join-Path $scriptsDir 'validate-harness.ps1') -Root $dir 6>&1 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $fails += ("{0}: instance no longer validates after re-apply (exit {1})" -f $v.Name, $LASTEXITCODE) }
            $afterCmds = @(Get-ChildItem -File (Join-Path $dir '.opencode/commands') -Filter *.md -ErrorAction SilentlyContinue).Count
            if ($afterCmds -ne 16) { $fails += ("{0}: after re-apply the instance has {1} commands, expected 16" -f $v.Name, $afterCmds) }
            if (-not (Test-Path (Join-Path $dir '.github/CODEOWNERS'))) { $fails += ("{0}: re-apply removed CODEOWNERS" -f $v.Name) }

        # ---- workflow and issue-form YAML must be loadable. A flow mapping containing an Actions
        #      expression (env: { TOKEN: ${{ ... }} }) is not parseable YAML and GitHub rejects it,
        #      so a workflow written that way ships in every instance and never runs - which is
        #      exactly what pr-policy.yml.tmpl did until 1.1.1.
        $yamlBad = @()
        foreach ($yf in (Get-ChildItem -File -Recurse (Join-Path $dir '.github') -Filter *.yml -ErrorAction SilentlyContinue)) {
            $txt = Get-Text $yf.FullName
            $flow = @([regex]::Matches($txt, '(?m)^.*\{[^}\n]*\$\{\{[^}\n]*\}.*$'))
            if ($flow.Count -gt 0) {
                $yamlBad += ("{0}: flow mapping containing an expression: {1}" -f $yf.Name, $flow[0].Value.Trim())
            }
            if ($txt -match '(?<!\$)\{\{[A-Z0-9_]{3,}\}\}') {
                $yamlBad += ("{0}: unresolved template slot" -f $yf.Name)
            }
        }
        foreach ($y in $yamlBad) { $fails += ("{0}: {1}" -f $v.Name, $y) }
        $ghYamlCount = @(Get-ChildItem -File -Recurse (Join-Path $dir '.github') -Filter *.yml -ErrorAction SilentlyContinue).Count
        if ($ghYamlCount -lt 16) { $fails += ("{0}: only {1} .github YAML files rendered, expected 16 (12 forms + 4 workflows)" -f $v.Name, $ghYamlCount) }
        }

        if ($fails.Count -eq $before) { $lines += ("  [ok]   {0}: {1}" -f $v.Name, $resultLine) }
        else { $lines += ("  [fail] {0}: {1} new failure(s)" -f $v.Name, ($fails.Count - $before)) }
    }

    Write-Host ''
    foreach ($l in $lines) { Write-Host $l }

    if ($fails.Count -gt 0) {
        Write-Host ''
        Write-Host ("kit self-test: {0} FAILURE(S)" -f $fails.Count)
        foreach ($f in ($fails | Select-Object -Unique)) { Write-Host ('  [FAIL] ' + $f) }
        exit 1
    }
    Write-Host ("kit self-test: PASS ({0} variants)" -f $variants.Count)
    exit 0
}
finally {
    if ($KeepArtifacts) {
        Write-Host "rendered instances kept at: $workRoot"
    } elseif (Test-Path $workRoot) {
        Remove-Item $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
