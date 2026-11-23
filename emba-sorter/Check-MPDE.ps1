$list = @'
S01|F1407E|It's Time to Split HR
S01|HK1164|PremiumSoft
S01|McKinsey|The CEO's Guide to Competing Through HR (optional)
S02|620066|GitLab (A)
S02|620117|GitLab (B)
S03|HR41A|LinkedIn and Modern Recruiting (A)
S03|R0905F|The Definitive Guide to Recruiting
S03|S24061|Why Employees Quit
S03|R0605E|Are Leaders Portable
S03|8926|Welcome Back - Boomerang Employee (web)
S04|98309|Six Dangerous Myths About Pay
S04|S23032|The Obstacles to Creating Good Jobs
S04|422045|Winning Business at Russell Reynolds (A)
S04|BH525|What Monetary Rewards Can and Cannot Do
S04|9860951596|Compensation and Performance (library)
S04|5374564411|Promise and Peril in Pay-for-Performance (library)
S05|913501|Performance Management at Vitality Health
S05|R1610D|The Performance Management Revolution
S05|5745726069|Behind the Mask (library)
S06|W20880|DESSA
S06|R1607C|Why Diversity Programs Fail
S06|7547961585|Getting Results with Talent Analytics (library)
S07|8898|Managing AI Workslop at Escape Velocity (web)
S07|8900|How Do We Manage Growth at Escape Velocity (web)
S07|H07GYQ|What Is Psychological Safety
S07|H08WGF|The Perils of Using AI to Replace Entry-Level Jobs
S08|818077|Transformation at ING (A)
S08|H082JA|Challenges of Becoming a Less Hierarchical Company
S10|419039|Note on Managing Workforce Reductions
S10|HRO010220|Rogers Stirk Harbour and Partners (IE)
S10|HBSWK|Cut Payroll Costs (optional)
'@ -split "`r?`n" | Where-Object { $_ -match '\|' }

$here  = (Get-Location).Path
$files = Get-ChildItem -LiteralPath $here -Recurse -File
$dl    = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'Downloads') -File
$ok = 0; $todo = 0
foreach ($l in $list) {
  $s, $c, $t = $l.Trim().Split('|')
  $rx = '(?i)(^|[^a-z0-9])' + [regex]::Escape($c) + '([^a-z0-9]|$)'
  $f = $files | Where-Object { $_.Name -match $rx } | Select-Object -First 1
  if ($f) {
    $ok++
    $warn = if ($f.Length -lt 20KB) { '  <- only ' + [int]($f.Length/1KB) + ' KB, open it to check' } else { '' }
    Write-Host ("{0} OK       {1,-11} {2}{3}" -f $s, $c, $f.FullName.Replace($here, '.'), $warn) -ForegroundColor Green
  } else {
    $todo++
    $d = $dl | Where-Object { $_.Name -match $rx } | Select-Object -First 1
    if ($d) { Write-Host ("{0} IN DOWNLOADS, not filed yet: {1}  (run the sorter)" -f $s, $d.Name) -ForegroundColor Yellow }
    else    { Write-Host ("{0} MISSING  {1,-11} {2}" -f $s, $c, $t) -ForegroundColor Red }
  }
}
Write-Host "`n$ok of $($list.Count) filed, $todo to do." -ForegroundColor Cyan
$partial = $dl | Where-Object { $_.Extension -in '.crdownload', '.partial', '.tmp' }
if ($partial) { Write-Host "Unfinished downloads in Downloads: $($partial.Name -join ', ')" -ForegroundColor Yellow }
