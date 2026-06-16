param([string]$Label = "")
$ErrorActionPreference = 'SilentlyContinue'
Write-Host "============================================================"
Write-Host "INSPECT: $Label"
Write-Host "============================================================"

Write-Host "-- dropweb.exe locations --"
Get-ChildItem 'C:\Program Files','C:\Program Files (x86)' -Recurse -Filter dropweb.exe -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.FullName)" }

Write-Host "-- FlClashX.exe locations --"
Get-ChildItem 'C:\Program Files','C:\Program Files (x86)' -Recurse -Filter FlClashX.exe -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.FullName)" }

Write-Host "-- Uninstall registry entries (dropweb / FlClash) --"
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
