<#
  Sort-Readings.ps1 - files a course's downloaded readings into session folders.
  Works for any course: the reading list comes from readings.csv in the course folder
  (columns Session|Folder|Type|Code|Title, pipe-separated).

  Run it from the course folder (company laptops block .ps1 files, so load it like this):
    & ([scriptblock]::Create((Get-Content .\Sort-Readings.ps1 -Raw)))           # sort + checklist
    & ([scriptblock]::Create((Get-Content .\Sort-Readings.ps1 -Raw))) -Check    # checklist only

  Matching, in order: (0) the download address Windows keeps with each file
  (Harvard links contain /items/<code>-), (1) the code in the file name,
  (2) the title in the file name, (3) the title inside the PDF.
  Files that match nothing stay in Downloads. Nothing is overwritten.
#>
param(
  [string]$Inbox = (Join-Path $env:USERPROFILE 'Downloads'),
  [string]$Dest  = (Get-Location).Path,
  [switch]$Check,
  [switch]$Yes
)

$csv = Join-Path $Dest 'readings.csv'
if (-not (Test-Path -LiteralPath $csv)) { Write-Host "No readings.csv in $Dest - run this from the course folder." -ForegroundColor Red; return }
$readings = Get-Content -LiteralPath $csv -Encoding UTF8 | ConvertFrom-Csv -Delimiter '|'

function Norm([string]$s) { ($s.ToLower() -replace '[^a-z0-9]', '') }
function CodeRx([string]$c) { '(?i)(^|[^a-z0-9])' + [regex]::Escape($c) + '([^a-z0-9]|$)' }
foreach ($r in $readings) { $r | Add-Member NoteProperty Key (Norm ($r.Title -replace '^(?i)the\s+', '')) -Force }

function Find-Reading($file) {
  try {
    $zone = Get-Content -LiteralPath $file.FullName -Stream Zone.Identifier -ErrorAction Stop | Out-String
    foreach ($r in $readings) { if ($zone -match ('(?i)/items/' + [regex]::Escape($r.Code) + '-')) { return $r } }
  } catch { }
  foreach ($r in $readings) { if ($file.BaseName -match (CodeRx $r.Code)) { return $r } }
  $n = Norm $file.BaseName
  foreach ($r in $readings) { if ($r.Key.Length -ge 8 -and $n.Contains($r.Key)) { return $r } }
  if ($file.Extension -ieq '.pdf' -and $file.Length -lt 50MB) {
    try {
      $text = Norm ([Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($file.FullName)))
      foreach ($r in $readings) { if ($r.Key.Length -ge 12 -and $text.Contains($r.Key)) { return $r } }
    } catch { }
  }
  return $null
}

if (-not $Check) {
  $plan = @()
  Get-ChildItem -LiteralPath $Inbox -File | Where-Object { $_.Extension -match '^\.(pdf|htm|html|xlsx?|docx?|pptx?)$' } | ForEach-Object {
    $r = Find-Reading $_
    if ($r) {
      $name = 'S{0:D2} - {1} - {2} ({3}){4}' -f [int]$r.Session, $r.Type, ($r.Title -replace '[\\/:*?"<>|]', '-'), $r.Code, $_.Extension.ToLower()
      $plan += [pscustomobject]@{ From = $_.FullName; Folder = Join-Path $Dest $r.Folder; To = $name }
    }
  }
  if ($plan.Count -eq 0) { Write-Host "No readings for this course found in $Inbox" -ForegroundColor Yellow }
  else {
    Write-Host "`nWill move $($plan.Count) file(s):`n" -ForegroundColor Cyan
    $plan | ForEach-Object { Write-Host ("  {0}`n     -> {1}\{2}" -f (Split-Path $_.From -Leaf), (Split-Path $_.Folder -Leaf), $_.To) }
    if ($Yes -or ((Read-Host "`nProceed? (Y/N)") -match '^[Yy]')) {
      foreach ($p in $plan) {
        New-Item -ItemType Directory -Force -Path $p.Folder | Out-Null
        $target = Join-Path $p.Folder $p.To
        if (Test-Path -LiteralPath $target) { Write-Host "  skip (already filed): $($p.To)"; continue }
        Move-Item -LiteralPath $p.From -Destination $target
      }
      Write-Host 'Done.' -ForegroundColor Green
    }
  }
}

# Checklist: searches every subfolder, so files saved by hand count too.
$files = Get-ChildItem -LiteralPath $Dest -Recurse -File
$dl    = Get-ChildItem -LiteralPath $Inbox -File
$ok = 0; $rows = @()
Write-Host ''
foreach ($r in $readings) {
  $rx = CodeRx $r.Code
  $f = $files | Where-Object { $_.Name -match $rx } | Select-Object -First 1
  $s = 'S{0:D2}' -f [int]$r.Session
  if ($f) {
    $ok++; $st = 'OK'
    $warn = if ($f.Length -lt 20KB) { "  <- only $([int]($f.Length/1KB)) KB, open it to check" } else { '' }
    Write-Host ("{0} OK       {1,-11} {2}{3}" -f $s, $r.Code, $f.FullName.Replace($Dest, '.'), $warn) -ForegroundColor Green
  } elseif ($d = $dl | Where-Object { $_.Name -match $rx } | Select-Object -First 1) {
    $st = 'IN DOWNLOADS'
    Write-Host ("{0} IN DOWNLOADS, not filed: {1}" -f $s, $d.Name) -ForegroundColor Yellow
  } else {
    $st = 'MISSING'
    Write-Host ("{0} MISSING  {1,-11} [{2}] {3}" -f $s, $r.Code, $r.Type, $r.Title) -ForegroundColor Red
  }
  $rows += [pscustomobject]@{ Session = $r.Session; Type = $r.Type; Code = $r.Code; Title = $r.Title; Status = $st }
}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $Dest '_checklist.csv')
Write-Host "`n$ok of $($readings.Count) filed." -ForegroundColor Cyan
if ($ok -gt 0) {
  $have = @($rows | Where-Object Status -eq 'OK' | ForEach-Object { "'$($_.Code)'" }) -join ', '
  Write-Host "For a rerun of download-auto.js:  const DONE = [$have];" -ForegroundColor DarkGray
}
$partial = $dl | Where-Object { $_.Extension -in '.crdownload', '.partial', '.tmp' }
if ($partial) { Write-Host "Unfinished downloads: $($partial.Name -join ', ')" -ForegroundColor Yellow }
