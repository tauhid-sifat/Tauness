# sync-labels.ps1 - create/update the governed GitHub label taxonomy (owner shell, requires gh auth with repo scope).
# Usage: pwsh -File harness/scripts/sync-labels.ps1 [-DryRun] [-Repo owner/name]

param(
    [switch]$DryRun,
    [string]$Repo
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib-render.ps1')

$repoRoot = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $repoRoot            # harness/scripts -> harness -> repo root
$cfg = Get-ProjectConfig (Join-Path $repoRoot 'project.yaml')
$labelsJson = Get-Content (Join-Path $repoRoot 'harness/kit/github/labels.json') -Raw | ConvertFrom-Json

$labels = New-Object System.Collections.ArrayList
foreach ($t in @($labelsJson.labels.type))        { [void]$labels.Add(@{ n = "type:$t";        c = $labelsJson.colors.type }) }
foreach ($p in @($labelsJson.labels.priority))    { [void]$labels.Add(@{ n = "priority:$p";    c = $labelsJson.colors.priority }) }
foreach ($r in @($labelsJson.labels.risk))        { [void]$labels.Add(@{ n = "risk:$r";        c = $labelsJson.colors.risk }) }
foreach ($s in @($labelsJson.labels.statusless))  { [void]$labels.Add(@{ n = $s;               c = $labelsJson.colors.statusless }) }
foreach ($a in @($cfg['lifecycle.areas']))        { [void]$labels.Add(@{ n = "area:$a";        c = $labelsJson.colors.area }) }

$profiles = Join-Path $repoRoot 'harness/kit/lifecycle/profiles.yaml'
foreach ($ph in (Get-ProfilePhases -ProfilesPath $profiles -ProfileName $cfg['lifecycle.profile'])) {
    [void]$labels.Add(@{ n = "phase-$($ph.Id)"; c = $labelsJson.colors.phase })
}

Write-Host "Labels ($($labels.Count)) for profile '$($cfg['lifecycle.profile'])':"
foreach ($l in $labels) { Write-Host ("  {0}  [{1}]" -f $l.n, $l.c) }
if ($DryRun) { exit 0 }

$repoArg = @()
if ($Repo) { $repoArg = @('--repo', $Repo) }
foreach ($l in $labels) {
    gh label create $l.n --color ($l.c -replace '#','') --force @repoArg
    if ($LASTEXITCODE -ne 0) { Write-Warning "Failed: $($l.n)"; }
}
Write-Host "Label sync complete."
