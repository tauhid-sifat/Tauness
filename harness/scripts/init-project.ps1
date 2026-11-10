# init-project.ps1 - create a new harness-managed project (or configure an existing folder).
# Usage (owner PowerShell, or the PM after writing project.yaml):
#   pwsh -File init-project.ps1 -Target <path> [-Config <project.yaml>] [-InsideRepo] [-Force] [-DryRun]
# Safety: never deletes; refuses to overwrite existing files unless -Force; -DryRun lists the plan.

param(
    [Parameter(Mandatory)][string]$Target,
    [string]$Config,
    [switch]$InsideRepo,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib-render.ps1')
. (Join-Path $scriptDir 'lib-apply.ps1')

$homeRoot = Split-Path -Parent $scriptDir          # the harness/ directory
$kitDir   = Join-Path $homeRoot 'kit'
# Resolve-Path returns nothing for a path that does not exist yet, and a new target is the normal
# case for init. Keep the requested path so the directory can be created instead of binding $null.
$requestedTarget = $Target
$resolvedTarget = Resolve-Path $requestedTarget -ErrorAction SilentlyContinue
if ($resolvedTarget) {
    $Target = $resolvedTarget.Path
} else {
    if ($InsideRepo) { throw "InsideRepo target must exist: $requestedTarget" }
    New-Item -ItemType Directory -Path $requestedTarget | Out-Null
    $Target = (Resolve-Path $requestedTarget).Path
}

# safety gate: a fresh project target must not be an existing git repo unless -InsideRepo
$isRepo = Test-Path (Join-Path $Target '.git')
if ($isRepo -and -not $InsideRepo) { throw "Target is an existing repository. Use -InsideRepo to configure in place, or choose a new folder." }

if (-not $Config) {
    Write-Host "No -Config given: opening interactive configuration."
    $Config = Join-Path $Target 'project.yaml'
    $tmpl = Read-TextRaw (Join-Path $kitDir 'project.yaml.tmpl')
    # interactive interview: minimal required fields, defaults shown in comments
    $vals = [ordered]@{
        PROJECT_NAME = Read-Host 'Project name'
        PROJECT_SLUG = Read-Host 'Repository/branch slug (kebab-case)'
        ID_PREFIX    = Read-Host 'ID prefix (2-4 uppercase letters)'
        ONE_LINE_PROJECT_DESCRIPTION = Read-Host 'One-line description'
        OWNER_GITHUB_LOGIN = Read-Host 'GitHub owner login'
        GIT_REMOTE_URL = Read-Host 'Git remote URL (blank for now)'
        LIFECYCLE_PROFILE = Read-Host 'Lifecycle profile: full|lean|headless|brownfield|micro'
        AREA_LIST = Read-Host 'Areas, comma-separated (e.g. web, api, data, auth, infra, docs)'
        STACK_NAME = Read-Host 'Stack description'
        SOURCE_GLOBS = Read-Host 'Source dirs (e.g. src/**, tests/**)'
        DEV_COMMAND_LIST = Read-Host 'Developer commands (comma-separated exact prefixes)'
        QA_COMMAND_LIST = Read-Host 'QA commands (comma-separated)'
        REVIEW_COMMAND_LIST = Read-Host 'Reviewer commands (comma-separated; blank ok)'
        SECURITY_COMMAND_LIST = Read-Host 'Security audit commands (comma-separated; blank ok)'
        HARD_DENY_LIST = Read-Host 'Extra hard-denied command prefixes (comma-separated; blank ok)'
        DEPLOY_CLI_LIST = Read-Host 'Deploy CLIs that must never run locally (comma-separated; blank ok)'
        BROWSER_BASE_URL = Read-Host 'Local browser base URL (e.g. http://localhost:3000; blank ok)'
        STACK_SKILLS_LIST = Read-Host 'Extra developer skill IDs (comma-separated; blank ok)'
        SKILLS_SHARED = Read-Host 'Skills every role may load (comma-separated; blank ok)'
        DATA_SENSITIVITY = Read-Host 'Data sensitivity: public|business|personal|regulated'
        SENSITIVE_DATA_LABEL = Read-Host 'Sensitive data label (e.g. customer, client, user)'
        USE_PROJECTS_V2 = Read-Host 'Use GitHub Projects v2? true/false'
        USE_LIVE_BROWSER = Read-Host 'Enable live-browser integration? true/false'
        USE_DESIGN_TOOLS = Read-Host 'Enable design-system tools (Hallmark/Impeccable)? true/false'
        MODEL_WORK = Read-Host 'Work model ID (provider/model)'
        MODEL_REVIEW = Read-Host 'Review model ID (provider/model)'
        MODEL_READINESS = Read-Host 'Model readiness: verified|gated'
    }
    $text = $tmpl
    foreach ($k in $vals.Keys) {
        $v = $vals[$k]
        if ($k -in @('AREA_LIST','SOURCE_GLOBS','DEV_COMMAND_LIST','QA_COMMAND_LIST','REVIEW_COMMAND_LIST','SECURITY_COMMAND_LIST','HARD_DENY_LIST','DEPLOY_CLI_LIST','STACK_SKILLS_LIST','SKILLS_SHARED')) {
            if ($v) { $v = ($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', ' }
        }
        $text = $text.Replace('{{' + $k + '}}', $v)
    }
    $text = $text.Replace('{{KIT_VERSION}}', (Read-TextRaw (Join-Path $homeRoot 'HARNESS-VERSION')).Trim())
    $text = $text.Replace('{{RENDER_TIMESTAMP}}', (Get-Date -Format 's'))
    # KIT_COMMIT lives in project.yaml.tmpl but was never substituted here, so every instance created
    # through this interview shipped a literal {{KIT_COMMIT}} in its project.yaml - which
    # validate-harness.ps1 then reported as a placeholder leak.
    $text = $text.Replace('{{KIT_COMMIT}}', (Get-KitCommit -KitDir $kitDir -TargetDir $Target))
    Write-Host "`n--- project.yaml preview ---`n"
    Write-Host $text
    $yes = Read-Host "`nWrite this project.yaml to the target? (yes/no)"
    if ($yes -ne 'yes') { Write-Host 'Aborted. Nothing was written.'; exit 1 }
    if ($DryRun) { Write-Host '(dry-run: project.yaml not written)'; exit 0 }
    Write-TextUtf8 -Path $Config -Text $text
}

$result = Invoke-HarnessRender -KitDir $kitDir -ProjectYamlPath $Config -TargetDir $Target -DocsHarnessPath (Join-Path (Split-Path -Parent $homeRoot) 'docs/harness') -DryRun:$DryRun -Force:$Force

if (-not $DryRun) {
    if (-not (Test-Path (Join-Path $Target 'project.yaml'))) {
        Copy-Item $Config (Join-Path $Target 'project.yaml')
    }
    # Make the instance's own record match what its generated files were actually rendered from.
    # Without this, a -Config file carrying any kit_version / rendered_from_commit value would be
    # copied verbatim while opencode.jsonc was stamped with the real ones - two provenances in one
    # instance, and re-apply would then preserve the wrong one.
    $pyDst = Join-Path $Target 'project.yaml'
    if (Test-Path $pyDst) {
        $pyText = Read-TextRaw $pyDst
        $pyText = $pyText -replace '(?m)^(\s*rendered_from_commit:\s*).+$', ('$1"' + $result.Commit + '"')
        $pyText = $pyText -replace '(?m)^(\s*kit_version:\s*).+$', ('$1"' + $result.KitVersion + '"')
        Write-TextUtf8 -Path $pyDst -Text $pyText
    }
    Write-Host "`nRendered kit into: $Target ($($result.Rendered) files, $($result.Skipped) skipped)"
    if ($result.Leaks.Count -gt 0) {
        Write-Warning ("Unresolved placeholders: " + ($result.Leaks -join ' | '))
        exit 2
    }
    Write-Host @"

Next steps (owner):
  1. cd $Target; git init -b main (if new); review rendered files; commit 'Initialize from AIDLC harness'.
  2. Validate: pwsh -File harness/scripts/validate-harness.ps1
  3. GitHub: create the private repo, push, then pwsh -File harness/scripts/sync-labels.ps1
  4. Open OpenCode here -> /status shows the lifecycle; begin Phase 1 via /pm.
"@
} else {
    Write-Host "Dry run: $($result.Rendered) files would be rendered into $Target"
}
