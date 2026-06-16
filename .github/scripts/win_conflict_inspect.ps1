param([string]$Label = "")
$ErrorActionPreference = 'SilentlyContinue'
Write-Host "============================================================"
Write-Host "INSPECT: $Label"
Write-Host "============================================================"

# Targeted candidate install dirs — do NOT recurse all of Program Files (slow on CI).
$dirs = @(
  'C:\Program Files\dropweb',
  'C:\Program Files\FlClashX',
  'C:\Program Files (x86)\dropweb',
  'C:\Program Files (x86)\FlClashX'
)
Write-Host "-- candidate install dirs --"
foreach ($d in $dirs) {
  if (Test-Path $d) {
    $exes = (Get-ChildItem $d -Filter *.exe -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ', '
    Write-Host ("  EXISTS  {0}   exe:[{1}]" -f $d, $exes)
  } else {
    Write-Host ("  absent  {0}" -f $d)
  }
}

Write-Host "-- Uninstall registry entries (dropweb / FlClash) [key | name | ver | InstallLocation] --"
$keys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($k in $keys) {
  Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
    $key = $_.PSChildName
    $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
    if ($p.DisplayName -match 'dropweb|FlClash') {
      Write-Host ("  [{0}] '{1}' v{2} @ {3}" -f $key, $p.DisplayName, $p.DisplayVersion, $p.InstallLocation)
    }
  }
}

Write-Host "-- Helper services --"
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Helper|Clash|dropweb' } | ForEach-Object { Write-Host "  $($_.Name) = $($_.Status)" }

Write-Host "-- Ports 47890 / 47896 / 7890 --"
(netstat -ano | Select-String ':47890|:47896|:7890') | ForEach-Object { Write-Host "  $_" }
Write-Host ""
