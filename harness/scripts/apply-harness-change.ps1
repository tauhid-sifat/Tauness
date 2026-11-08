# apply-harness-change.ps1 — owner-run harness application inside an instance repository.
# Regenerates the generated instance files from harness/kit + project.yaml.
# This IS the owner-approval mechanism for harness changes (AGENTS.md §2): agents propose,
# the owner applies. Creates a timestamped backup of every file it overwrites.
# Usage: pwsh -File harness\scripts\apply-harness-change.ps1 [-DryRun] [-Force] [-BackupDir <path>]

param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$AcceptStagedDocs,
    [string]$BackupDir
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Location).Path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib-render.ps1')
. (Join-Path $scriptDir 'lib-apply.ps1')

$kitDir = Join-Path $repoRoot 'harness\kit'
$py = Join-Path $repoRoot 'project.yaml'
if (-not (Test-Path $kitDir)) { throw "Not a harness instance: $kitDir missing" }
if (-not (Test-Path $py)) {
    $staged = Join-Path $repoRoot 'harness\staging\instance\project.yaml'
    if (Test-Path $staged) {
        Copy-Item $staged $py
        Write-Host "No root project.yaml — placed staged copy ($staged) at repo root first."
    } else { throw "project.yaml missing at repo root (and no staged copy found)" }
}

# preview plan
$plan = @(Get-RenderPlan -KitDir $kitDir -TargetDir $repoRoot | Where-Object { $_.Scope -eq 'instance' })
Write-Host "Harness change apply — plan ($($plan.Count) generated files)"
Write-Host "Kit version: $((Read-TextRaw (Join-Path $repoRoot 'harness\HARNESS-VERSION')).Trim())"
if (-not $Force) {
    Write-Host "`nExisting files will be SKIPPED unless -Force (never deleted). Re-run with -DryRun for a silent plan."
}

if ($DryRun) {
    foreach ($p in $plan) {
        $state = if (Test-Path $p.Dst) { 'UPDATE' } else { 'CREATE' }
        Write-Host ("  {0}  {1}" -f $state, $p.Dst.Substring($repoRoot.Length + 1))
    }
    exit 0
}

# backup everything we might touch
if (-not $BackupDir) { $BackupDir = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-apply-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
foreach ($p in $plan) {
    if (Test-Path $p.Dst) {
        $rel = $p.Dst.Substring($repoRoot.Length + 1)
        $bd = Join-Path $BackupDir $rel
        $d = Split-Path -Parent $bd
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Copy-Item $p.Dst $bd -Force
    }
}
Write-Host "Backup of overwritten files: $BackupDir"

$result = Invoke-HarnessRender -KitDir $kitDir -ProjectYamlPath $py -TargetDir $repoRoot -Scope 'instance' -Force:$Force
Write-Host "Rendered: $($result.Rendered) files; skipped: $($result.Skipped)"
if ($result.Leaks.Count -gt 0) { Write-Warning ("Unresolved placeholders: " + ($result.Leaks -join ' | ')); exit 2 }

# Optional: accept staged core-doc rewrites (owner-reviewed documents)
if ($AcceptStagedDocs) {
    $staged = Join-Path $repoRoot 'harness\staging\docs-harness'
    if (Test-Path $staged) {
        foreach ($f in (Get-ChildItem -File -Recurse $staged)) {
            $rel = $f.FullName.Substring($staged.Length + 1)
            $dst = Join-Path (Join-Path $repoRoot 'docs\harness') $rel
            $d = Split-Path -Parent $dst
            if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            if ((Test-Path $dst) -and -not $Force) { Write-Host "SKIP doc exists (use -Force): $rel"; continue }
            if (Test-Path $dst) {
                $bd = Join-Path $BackupDir ("docs\harness\" + $rel)
                $bdir = Split-Path -Parent $bd
                if (-not (Test-Path $bdir)) { New-Item -ItemType Directory -Path $bdir -Force | Out-Null }
                Copy-Item $dst $bd -Force
            }
            Copy-Item $f.FullName $dst -Force
            Write-Host "STAGED-DOC: $rel"
        }
    } else { Write-Warning "No staged docs at $staged" }
}

Write-Host @"

Verify now (owner shell):
  opencode debug config   # parses with the new rules
  opencode debug agents   # 7 agents, models, modes
  pwsh -File harness\scripts\validate-harness.ps1
Then commit: git add -A ; git commit -m 'Apply AIDLC harness <version>' ; open a PR or push per policy.
"@
