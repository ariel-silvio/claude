<#
  Sort-MPDE.ps1 - files the readings for "Managing People in Digital Era"
  (EMBA-EN SEP-2025, 3rd term) into session folders with clean names.

  How to use:
    1. Download the readings from the syllabus links, one by one, into your
       Downloads folder. Keep whatever names they come with.
    2. Right-click this file > "Run with PowerShell"
       (or in a terminal:  powershell -ExecutionPolicy Bypass -File .\Sort-MPDE.ps1)
    3. It shows what it will move, asks Y/N, then moves and renames.
       Re-run any time; it only touches new matching files.

  A file is matched by (1) the HBP product code in its name, e.g. 620066,
  (2) the reading title in its name, or (3) the title inside the PDF metadata.
  Files that match nothing are left untouched.
#>
param(
  [string]$Inbox = (Join-Path $env:USERPROFILE 'Downloads'),
  [string]$Dest  = (Join-Path $env:USERPROFILE 'Documents\EMBA\T3 - Managing People in Digital Era'),
  [switch]$Yes
)

$readings = @'
Session|Folder|Type|Code|Title
1|S01 - The Era of Human Capital|RA|F1407E|It's Time to Split HR
1|S01 - The Era of Human Capital|PC|HK1164|PremiumSoft - Need for Strategic Human Resource Management
2|S02 - New Ways of Working - Remote Model|PC|620066|GitLab and the Future of All-Remote Work (A)
2|S02 - New Ways of Working - Remote Model|PC|620117|GitLab and the Future of All-Remote Work (B)
3|S03 - Getting the Talent You Need|PC|HR41A|LinkedIn and Modern Recruiting (A)
3|S03 - Getting the Talent You Need|RA|R0905F|The Definitive Guide to Recruiting in Good Times and Bad
3|S03 - Getting the Talent You Need|RA|S24061|Why Employees Quit
3|S03 - Getting the Talent You Need|RA|R0605E|Are Leaders Portable
3|S03 - Getting the Talent You Need|PC|8926|Welcome Back - Do We Hire a Boomerang Employee
4|S04 - Compensation|RA|98309|Six Dangerous Myths About Pay
4|S04 - Compensation|RA|S23032|The Obstacles to Creating Good Jobs
4|S04 - Compensation|PC|422045|Winning Business at Russell Reynolds (A)
4|S04 - Compensation|RA|BH525|What Monetary Rewards Can and Cannot Do
5|S05 - Performance Management|PC|913501|Performance Management at Vitality Health Enterprises
5|S05 - Performance Management|RA|R1610D|The Performance Management Revolution
6|S06 - Diversity in Tech Jobs|PC|W20880|DESSA - Growing a Diverse and Inclusive AI Company
6|S06 - Diversity in Tech Jobs|RA|R1607C|Why Diversity Programs Fail
7|S07 - AI in the Workplace|PC|8898|Managing AI Workslop at Escape Velocity
7|S07 - AI in the Workplace|PC|8900|How Do We Manage Growth at Escape Velocity
7|S07 - AI in the Workplace|RA|H07GYQ|What Is Psychological Safety
7|S07 - AI in the Workplace|RA|H08WGF|The Perils of Using AI to Replace Entry-Level Jobs
8|S08 - 21st Century Work Organization|PC|818077|Transformation at ING (A) - Agile
8|S08 - 21st Century Work Organization|RA|H082JA|The Challenges of Becoming a Less Hierarchical Company
10|S10 - Difficult Decisions on People|TN|419039|Note on Managing Workforce Reductions
10|S10 - Difficult Decisions on People|PC|HRO010220|Rogers Stirk Harbour and Partners
'@ | ConvertFrom-Csv -Delimiter '|'

function Norm([string]$s) { ($s.ToLower() -replace '[^a-z0-9]', '') }

# Title keys: the full title without leading "the", punctuation and spaces.
# Full length on purpose: GitLab (A) and (B) differ only in the last letter.
foreach ($r in $readings) {
  $r | Add-Member NoteProperty Key (Norm ($r.Title -replace '^(?i)the\s+', ''))
}

function Find-Reading($file) {
  $name = $file.BaseName
  $nname = Norm $name
  foreach ($r in $readings) {                       # 1) product code
    if ($name -match ('(?i)(^|[^a-z0-9])' + [regex]::Escape($r.Code) + '([^a-z0-9]|$)')) { return $r }
  }
  foreach ($r in $readings) {                       # 2) title in file name
    if ($nname.Contains($r.Key)) { return $r }
  }
  if ($file.Extension -ieq '.pdf' -and $file.Length -lt 50MB) {   # 3) PDF metadata
    try {
      $bytes = [IO.File]::ReadAllBytes($file.FullName)
      $text  = Norm ([Text.Encoding]::GetEncoding(28591).GetString($bytes))
      foreach ($r in $readings) { if ($text.Contains($r.Key)) { return $r } }
    } catch { }
  }
  return $null
}

$plan = @()
$files = Get-ChildItem -LiteralPath $Inbox -File |
         Where-Object { $_.Extension -match '^\.(pdf|htm|html|xlsx?|docx?)$' }
foreach ($f in $files) {
  $r = Find-Reading $f
  if ($r) {
    $safeTitle = ($r.Title -replace '[\\/:*?"<>|]', '-')
    $newName = 'S{0:D2} - {1} - {2} ({3}){4}' -f [int]$r.Session, $r.Type, $safeTitle, $r.Code, $f.Extension.ToLower()
    $plan += [pscustomobject]@{ From = $f.FullName; Folder = Join-Path $Dest $r.Folder; To = $newName; Code = $r.Code }
  }
}

if ($plan.Count -eq 0) {
  Write-Host "No matching readings found in $Inbox" -ForegroundColor Yellow
} else {
  Write-Host "`nWill move $($plan.Count) file(s) into $Dest :`n" -ForegroundColor Cyan
  $plan | ForEach-Object { Write-Host ("  {0}`n     -> {1}\{2}" -f (Split-Path $_.From -Leaf), (Split-Path $_.Folder -Leaf), $_.To) }
  $go = $Yes -or ((Read-Host "`nProceed? (Y/N)") -match '^[Yy]')
  if ($go) {
    foreach ($p in $plan) {
      New-Item -ItemType Directory -Force -Path $p.Folder | Out-Null
      $target = Join-Path $p.Folder $p.To
      if (Test-Path -LiteralPath $target) { Write-Host "  skip (already there): $($p.To)"; continue }
      Move-Item -LiteralPath $p.From -Destination $target
    }
    Write-Host "Done." -ForegroundColor Green
  }
}

# Checklist: what is filed and what is still missing.
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$status = foreach ($r in $readings) {
  $dir = Join-Path $Dest $r.Folder
  $have = (Test-Path -LiteralPath $dir) -and
          (Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -like "*($($r.Code)).*" })
  [pscustomobject]@{ Session = $r.Session; Type = $r.Type; Code = $r.Code; Title = $r.Title; Status = $(if ($have) { 'OK' } else { 'MISSING' }) }
}
$status | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $Dest '_checklist.csv')
$missing = @($status | Where-Object Status -eq 'MISSING')
Write-Host "`nChecklist: $($readings.Count - $missing.Count)/$($readings.Count) filed." -ForegroundColor Cyan
$missing | ForEach-Object { Write-Host ("  missing  S{0:D2} {1} {2}" -f [int]$_.Session, $_.Code, $_.Title) }
if (-not $Yes) { Read-Host "`nPress Enter to close" | Out-Null }
