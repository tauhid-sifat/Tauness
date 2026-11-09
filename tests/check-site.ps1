# check-site.ps1 - site validator for the GitHub Pages handbook.
#
# Why: the handbook states counts and describes controls. Prose that quietly drifts from the kit is the
# doc-drift defect ADR-H-008 exists to stop, and a broken anchor or an unbalanced tag is a defect a reader
# finds instead of a test. This asserts structure and the claims that can be counted.
#
# Usage: pwsh -File tests/check-site.ps1     (exit 0 = clean, exit 1 = violations)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$siteDir  = Join-Path $repoRoot 'site'
$fails = @()
function Add-Fail([string]$What) { $script:fails += $What }
function Get-Text([string]$Path) { return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path)) }

if (-not (Test-Path $siteDir)) { Write-Host 'check-site: no site/ directory'; exit 1 }
$pages = @(Get-ChildItem -File $siteDir -Filter *.html)
if ($pages.Count -eq 0) { Write-Host 'check-site: site/ contains no pages'; exit 1 }

foreach ($f in $pages) {
    $name = $f.Name
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { Add-Fail "$name has a UTF-8 BOM" }
    $html = Get-Text $f.FullName

    # ---- document skeleton
    foreach ($pair in @(@('<!DOCTYPE html',''), @('<html','</html>'), @('<head','</head>'), @('<body','</body>'), @('<main','</main>'), @('<nav','</nav>'))) {
        if ($pair[1] -eq '') {
            if ($html -notmatch '<!DOCTYPE\s+html') { Add-Fail "${name}: missing DOCTYPE" }
        } elseif ([regex]::Matches($html, [regex]::Escape($pair[0])).Count -ne [regex]::Matches($html, [regex]::Escape($pair[1])).Count) {
            Add-Fail "${name}: unbalanced $($pair[0]) / $($pair[1])"
        }
    }
    if ($html -notmatch '<meta\s+name="viewport"') { Add-Fail "${name}: no viewport meta" }
    if ($html -notmatch '<title>[^<]+</title>') { Add-Fail "${name}: missing or empty title" }

    # ---- element pairing (hand-written HTML: a dropped close tag is the common break)
    foreach ($t in @('table','thead','tbody','tr','td','th','pre','code','ol','ul','li','div','p','h2','h3','h4','a','span','svg','footer')) {
        $open = ([regex]::Matches($html, "<$t(\s|>)")).Count
        $close = ([regex]::Matches($html, "</$t>")).Count
        if ($t -eq 'a' -or $t -eq 'span' -or $t -eq 'code' -or $t -eq 'td' -or $t -eq 'th' -or $t -eq 'li' -or $t -eq 'p') {
            if ($open -ne $close) { Add-Fail "${name}: $t opened $open times, closed $close" }
        } elseif ($open -ne $close) {
            Add-Fail "${name}: <$t> opened $open times, closed $close"
        }
    }

    # ---- anchors: every in-page link target must exist
    $ids = @([regex]::Matches($html, 'id="([A-Za-z0-9_-]+)"') | ForEach-Object { $_.Groups[1].Value })
    $dupes = @($ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    foreach ($d in $dupes) { Add-Fail "${name}: duplicate id `"$d`"" }
    $links = @([regex]::Matches($html, 'href="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $anchors = @($links | Where-Object { $_.startsWith('#') } | ForEach-Object { $_.Substring(1) } | Sort-Object -Unique)
    $missing = @($anchors | Where-Object { $ids -notcontains $_ })
    foreach ($m in $missing) { Add-Fail "${name}: link href=`"#$m`" has no matching id" }

    # ---- cross-page links and remote hosts
    foreach ($l in $links) {
        if ($l -like 'data:*' -or $l -like 'mailto:*') { continue }
        if ($l -eq 'LICENSE') {
            if (-not (Test-Path (Join-Path $repoRoot 'LICENSE'))) { Add-Fail "${name}: links to LICENSE but the file is missing" }
            continue
        }
        if ($l -match '^https?://') {
            if ($l -match '^https?://(www\.)?github\.com/tauhid-sifat/([A-Za-z0-9_.-]+)' -and $Matches[2] -eq 'Tauness') { continue }
            if ($l -notmatch '^https?://(github\.com|opencode\.ai|docs\.github\.com)') { Add-Fail "${name}: unexpected external host in link $l" }
            continue
        }
        if ($l.startsWith('#')) { continue }
        $target = Join-Path $siteDir ($l -split '#')[0]
        if (-not (Test-Path $target)) { Add-Fail "${name}: page link resolves to no file: $l" }
    }

    # ---- no template or placeholder debris left in a published page
    if ($html -match '<!--\s*[A-Z_]+\s*-->') { Add-Fail "${name}: placeholder comment left in page: $($Matches[0])" }
    if ($html -match '\{\{[A-Z0-9_]+\}\}') { Add-Fail "${name}: unresolved template slot in page: $($Matches[0])" }

    # ---- SVG annotations must fit their note box: text drawn outside the viewBox is silently
    #      clipped (a 132-character note in a 500px box was cut on the live page). This is a coarse
    #      guard, not a layout engine: .dg-s text measured 4.1-4.8 px per character in Chromium, so
    #      anything more than 40px past the box on a 4.8 estimate is a real overflow. Tighter
    #      constants false-positive on legitimate notes; the margin is deliberate.
    foreach ($note in [regex]::Matches($html, '<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)" rx="4" class="dg-note"/>')) {
        $noteW = [int]$note.Groups[3].Value
        $after = $html.Substring($note.Index + $note.Length, [Math]::Min(600, $html.Length - $note.Index - $note.Length))
        foreach ($t in [regex]::Matches($after, '^<text x="\d+" y="\d+" class="dg-s" text-anchor="middle">([^<]*)</text>')) {
            $text = [System.Net.WebUtility]::HtmlDecode($t.Groups[1].Value)
            $estimate = [int]($text.Length * 4.8)
            if ($estimate - $noteW -gt 40) {
                Add-Fail "${name}: note text overflows its ${noteW}px box (about ${estimate}px): $text"
            }
        }
    }
}

# ---- the handbook's version stamp must equal the kit version
$version = (Get-Content (Join-Path $repoRoot 'harness/HARNESS-VERSION') -Raw).Trim()
$index = Join-Path $siteDir 'index.html'
if (Test-Path $index) {
    $html = Get-Text $index
    if ($html -notmatch ('kit <code>' + [regex]::Escape($version) + '</code>')) { Add-Fail "index.html footer version stamp is not kit $version" }
    if ($html -notmatch ('kit ' + [regex]::Escape($version))) { Add-Fail "index.html nav brand stamp is not kit $version" }

    # ---- counted claims: tables must have as many rows as the handbook asserts
    function Get-FirstTableRows([string]$SectionId) {
        $m = [regex]::Match($html, 'id="' + [regex]::Escape($SectionId) + '"')
        if (-not $m.Success) { return -1 }
        $tail = $html.Substring($m.Index)
        $nextH2 = [regex]::Match($tail.Substring(1), '<h2\s')
        if ($nextH2.Success) { $tail = $tail.Substring(0, $nextH2.Index + 1) }
        $tbl = [regex]::Match($tail, '<table>[\s\S]*?</table>')
        if (-not $tbl.Success) { return -1 }
        return @([regex]::Matches($tbl.Value, '<tr>')).Count - 1   # minus the header row
    }
    $claims = @(
        @{ id = 'roles';      want = 7;  label = 'role agents in the roles table' },
        @{ id = 'commands';   want = 16; label = 'commands in the commands table' },
        @{ id = 'lifecycle';  want = 8;  label = 'phases in the lifecycle table (7 canonical + 0-intake)' },
        @{ id = 'gaps';       want = 10; label = 'rows in the not-yet-proven table' }
    )
    foreach ($c in $claims) {
        $rows = Get-FirstTableRows $c.id
        if ($rows -lt 0) { Add-Fail "section #$($c.id) or its first table not found" }
        elseif ($rows -ne $c.want) { Add-Fail "$($c.label): handbook shows $rows, expected $($c.want)" }
    }

    # the delegation matrix must mirror validate-harness.ps1's expected matrix
    $delegateRows = @([regex]::Matches($html, '(?s)id="roles".*?</table>\s*<h3>Delegation matrix.*?<table>([\s\S]*?)</table>') | ForEach-Object { @([regex]::Matches($_.Groups[1].Value, '<tr>')).Count - 1 })
    if ($delegateRows.Count -eq 0 -or $delegateRows[0] -ne 7) { Add-Fail "delegation matrix rows: expected 7, found $($delegateRows[0])" }

    # honesty section must stay present and must not be watered down to nothing. These are the items
    # that are genuinely outstanding right now; asserting their wording means a future edit that
    # quietly deletes a caveat fails the gate instead of shipping a more flattering page.
    # The U+2260 in "approved != implemented != verified" is built from its code point because this
    # script's own source must stay ASCII-only (the rule check-sources.ps1 enforces).
    $ne = [string][char]0x2260
    $musts = @('N-01 to N-30', 'Windows-only', 'deliberately not enabled', '53 PASS / 0 WARN / 0 FAIL',
               'only knows the terms it was given', 'never been executed',
               ('approved ' + $ne + ' implemented ' + $ne + ' verified'))
    foreach ($must in $musts) {
        if ($html -notmatch [regex]::Escape($must)) { Add-Fail "index.html no longer states: $must" }
    }
}

if ($fails.Count -gt 0) {
    Write-Host ''
    Write-Host ("check-site: {0} VIOLATION(S)" -f $fails.Count)
    foreach ($x in $fails) { Write-Host ('  [FAIL] ' + $x) }
    exit 1
}
Write-Host ("check-site: PASS ({0} page(s), kit {1})" -f $pages.Count, $version)
exit 0
