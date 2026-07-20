Set-StrictMode -Version Latest

$script:ObkatkaEvidenceRoot = if ($env:GITHUB_WORKSPACE) {
  Join-Path $env:GITHUB_WORKSPACE 'ci-evidence'
} else {
  Join-Path (Get-Location) 'ci-evidence'
}

function Initialize-ObkatkaEvidence {
  param([switch]$Reset)

  if ($Reset -and (Test-Path $script:ObkatkaEvidenceRoot)) {
    Remove-Item $script:ObkatkaEvidenceRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Force $script:ObkatkaEvidenceRoot | Out-Null
  return $script:ObkatkaEvidenceRoot
}

function Get-ObkatkaEvidenceRoot {
  return (Initialize-ObkatkaEvidence)
}

function New-ObkatkaCheck {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'NOT_PROVEN')][string]$Status,
    [Parameter(Mandatory)][string]$Detail
  )

  return [pscustomobject][ordered]@{
    name   = $Name
    status = $Status
    detail = $Detail
  }
}

function Write-ObkatkaAtomicText {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force $parent | Out-Null
  $temporaryPath = Join-Path $parent ('.{0}.{1}.tmp' -f (Split-Path -Leaf $Path), [guid]::NewGuid())
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($temporaryPath, $Content, $utf8)
  Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function ConvertTo-ObkatkaTableCell {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) { return '' }
  return (($Value.ToString() -replace '\|', '\|') -replace '[\r\n]+', ' ').Trim()
}

function Write-ObkatkaVerdict {
  param(
    [Parameter(Mandatory)][string]$Scenario,
    [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'NOT_PROVEN')][string]$Result,
    [Parameter(Mandatory)][object[]]$Checks,
    [AllowNull()][string]$FirstFailure,
    [Parameter(Mandatory)][object]$Durations,
    [string]$Sha = $env:GITHUB_SHA,
    [hashtable]$Phases = @{},
    [hashtable]$Metadata = @{}
  )

  $evidenceRoot = Initialize-ObkatkaEvidence
  if (-not $Sha) { $Sha = 'unknown' }
  if (-not $FirstFailure) {
    $failed = @($Checks | Where-Object { $_.status -eq 'FAIL' } | Select-Object -First 1)
    if ($failed.Count -gt 0) { $FirstFailure = $failed[0].name }
  }

  $verdict = [ordered]@{
    schema       = 1
    scenario     = $Scenario
    sha          = $Sha
    result       = $Result
    checks       = @($Checks)
    firstFailure = $FirstFailure
    durations    = $Durations
  }
  foreach ($phase in $Phases.GetEnumerator()) {
    $verdict[$phase.Key] = $phase.Value
  }
  foreach ($entry in $Metadata.GetEnumerator()) {
    $verdict[$entry.Key] = $entry.Value
  }
  $json = $verdict | ConvertTo-Json -Depth 10
  Write-ObkatkaAtomicText -Path (Join-Path $evidenceRoot 'verdict.json') -Content ($json + "`n")

  $durationSummary = if ($null -ne $Durations.totalSeconds) { '{0}s' -f $Durations.totalSeconds } else { 'n/a' }
  $shortSha = if ($Sha.Length -gt 7) { $Sha.Substring(0, 7) } else { $Sha }
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add("# Windows obkatka: $Scenario")
  $lines.Add('')
  $lines.Add("**$Result** · ``$shortSha`` · $durationSummary")
  if ($FirstFailure) {
    $lines.Add('')
    $lines.Add("**First failure:** $(ConvertTo-ObkatkaTableCell $FirstFailure)")
  }
  $lines.Add('')
  $lines.Add('| Check | Status | Detail |')
  $lines.Add('|---|:---:|---|')
  foreach ($check in $Checks) {
    $name = ConvertTo-ObkatkaTableCell $check.name
    $status = ConvertTo-ObkatkaTableCell $check.status
    $detail = ConvertTo-ObkatkaTableCell $check.detail
    $lines.Add("| $name | $status | $detail |")
  }
  $summary = ($lines -join "`n") + "`n"
  Write-ObkatkaAtomicText -Path (Join-Path $evidenceRoot 'summary.md') -Content $summary

  if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $summary -Encoding utf8
  }
}

function Wait-ObkatkaPath {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][int]$TimeoutSeconds,
    [int]$PollMilliseconds = 250
  )

  $clock = [System.Diagnostics.Stopwatch]::StartNew()
  while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    if (Test-Path -LiteralPath $Path) { return $true }
    Start-Sleep -Milliseconds $PollMilliseconds
  }
  return (Test-Path -LiteralPath $Path)
}

function Read-ObkatkaJsonWhenReady {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][int]$TimeoutSeconds
  )

  if (-not (Wait-ObkatkaPath -Path $Path -TimeoutSeconds $TimeoutSeconds)) {
    throw "timed out waiting for JSON result: $Path"
  }
  return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 20)
}

function Wait-ObkatkaProcessExit {
  param(
    [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory)][int]$TimeoutSeconds
  )

  try {
    return $Process.WaitForExit($TimeoutSeconds * 1000)
  } catch {
    return $false
  }
}

function Write-ObkatkaPlan {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][System.Collections.IDictionary]$Plan
  )

  Write-ObkatkaAtomicText -Path $Path -Content (($Plan | ConvertTo-Json -Depth 20 -Compress) + "`n")
}

function Start-ObkatkaCiPlan {
  param(
    [Parameter(Mandatory)][string]$AppPath,
    [Parameter(Mandatory)][string]$PlanPath
  )

  $previous = $env:DROPWEB_CI_E2E
  $env:DROPWEB_CI_E2E = '1'
  try {
    return Start-Process -FilePath $AppPath -ArgumentList ('--ci-e2e-plan="{0}"' -f $PlanPath) -PassThru
  } finally {
    if ($null -eq $previous) {
      Remove-Item Env:DROPWEB_CI_E2E -ErrorAction SilentlyContinue
    } else {
      $env:DROPWEB_CI_E2E = $previous
    }
  }
}

function Install-ObkatkaInstaller {
  param([Parameter(Mandatory)][string]$InstallerPath)

  return Start-Process -FilePath $InstallerPath -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NORESTARTAPPLICATIONS','/NOICONS','/NOCANCEL' -Wait -PassThru
}

function Get-ObkatkaInstalledPaths {
  $entry = Get-ObkatkaUninstallEntry -NamePattern '(?i)^dropweb'
  if (-not $entry) { throw 'dropweb uninstall entry is absent' }
  $root = [string]$entry.InstallLocation
  if (-not $root) { $root = 'C:\Program Files\dropweb' }
  $root = $root.TrimEnd('\')
  return [pscustomobject][ordered]@{
    entry  = $entry
    root   = $root
    app    = Join-Path $root 'dropweb.exe'
    core   = Join-Path $root 'DropwebCore.exe'
    helper = Join-Path $root 'DropwebHelperService.exe'
  }
}

function Get-ObkatkaNormalizedRoutes {
  return @(
    Get-NetRoute -ErrorAction Stop |
      Where-Object { $_.State -eq 'Alive' } |
      ForEach-Object {
        '{0}|{1}|{2}|{3}|{4}' -f $_.AddressFamily, $_.DestinationPrefix, $_.NextHop, $_.InterfaceIndex, $_.RouteMetric
      } |
      Sort-Object -Unique
  )
}

function Get-ObkatkaAdapterState {
  return @(
    Get-NetAdapter -IncludeHidden -ErrorAction Stop |
      Select-Object Name, InterfaceDescription, Status, ifIndex, InterfaceGuid, MacAddress, LinkSpeed |
      Sort-Object ifIndex
  )
}

function Write-ObkatkaNetworkSnapshot {
  param(
    [Parameter(Mandatory)][string]$FileName,
    [Parameter(Mandatory)][string]$Label
  )

  $snapshot = [ordered]@{
    label      = $Label
    capturedAt = [DateTime]::UtcNow.ToString('o')
    adapters   = @(Get-ObkatkaAdapterState)
    routes     = @(Get-NetRoute -ErrorAction Stop | Select-Object AddressFamily, DestinationPrefix, NextHop, InterfaceIndex, RouteMetric, State, PolicyStore | Sort-Object InterfaceIndex, DestinationPrefix)
  }
  Write-ObkatkaAtomicText -Path (Join-Path (Initialize-ObkatkaEvidence) $FileName) -Content (($snapshot | ConvertTo-Json -Depth 8) + "`n")
  return $snapshot
}

function Get-ObkatkaEgressIp {
  param([int]$TimeoutSeconds = 20)

  $response = Invoke-WebRequest -Uri 'https://api.ipify.org' -NoProxy -TimeoutSec $TimeoutSeconds -ErrorAction Stop
  return ([string]$response.Content).Trim()
}

function ConvertTo-ObkatkaMaskedIp {
  param([Parameter(Mandatory)][string]$Address)

  if ($Address -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)$') {
    return "$($Matches[1]).$($Matches[2]).x.x"
  }
  if ($Address.Contains(':')) {
    $parts = @($Address.Split(':') | Where-Object { $_ })
    return (($parts | Select-Object -First 3) -join ':') + ':x:x'
  }
  return '[masked]'
}

function Stop-ObkatkaAppProcesses {
  param([int]$GraceSeconds = 10)

  & taskkill.exe /IM dropweb.exe 2>$null | Out-Null
  $clock = [System.Diagnostics.Stopwatch]::StartNew()
  while ($clock.Elapsed.TotalSeconds -lt $GraceSeconds -and (Get-Process dropweb -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 250
  }
  foreach ($name in @('dropweb', 'DropwebCore')) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
  $forceClock = [System.Diagnostics.Stopwatch]::StartNew()
  while ($forceClock.Elapsed.TotalSeconds -lt 5 -and (Get-Process dropweb, DropwebCore -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 250
  }
}

function Add-ObkatkaSnapshotSection {
  param(
    [Parameter(Mandatory)][string]$FileName,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $path = Join-Path (Initialize-ObkatkaEvidence) $FileName
  $header = "`n===== $Label @ $([DateTime]::UtcNow.ToString('o')) =====`n"
  Add-Content -LiteralPath $path -Value ($header + $Content.TrimEnd() + "`n") -Encoding utf8
}

function Get-ObkatkaProtocolHandler {
  param([Parameter(Mandatory)][string]$Scheme)

  $roots = @(
    "HKCU:\Software\Classes\$Scheme",
    "HKLM:\Software\Classes\$Scheme"
  )
  foreach ($root in $roots) {
    $commandPath = Join-Path $root 'shell\open\command'
    if (Test-Path $commandPath) {
      $command = (Get-Item -LiteralPath $commandPath -ErrorAction Stop).GetValue('')
      return [pscustomobject]@{ root = $root; command = [string]$command }
    }
  }
  return $null
}

function Get-ObkatkaListenerPids {
  param([Parameter(Mandatory)][int]$Port)

  $pids = foreach ($line in (& netstat.exe -ano -p tcp 2>$null)) {
    if ($line -match (':{0}\s+.*LISTENING\s+(\d+)\s*$' -f $Port)) {
      [int]$Matches[1]
    }
  }
  $uniquePids = @($pids | Sort-Object -Unique)
  Write-Output -NoEnumerate $uniquePids
}

function Get-ObkatkaServiceExecutablePath {
  param([AllowNull()][string]$PathName)

  if (-not $PathName) { return '' }
  if ($PathName -match '^\s*"([^"]+\.exe)"') { return $Matches[1] }
  if ($PathName -match '^\s*(.+?\.exe)(?:\s|$)') { return $Matches[1] }
  return $PathName.Trim().Trim('"')
}

function Export-ObkatkaSnapshot {
  param([Parameter(Mandatory)][string]$Label)

  $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'dropweb|FlClash|Clash|Helper' } |
    Select-Object Name, State, StartMode, ProcessId, PathName |
    Sort-Object Name | Format-Table -AutoSize | Out-String -Width 4096
  Add-ObkatkaSnapshotSection -FileName 'services.txt' -Label $Label -Content $services

  $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'dropweb|FlClash|Clash|Helper' } |
    Select-Object Name, ProcessId, ParentProcessId, ExecutablePath, CommandLine |
    Sort-Object Name, ProcessId | Format-Table -AutoSize | Out-String -Width 4096
  Add-ObkatkaSnapshotSection -FileName 'processes.txt' -Label $Label -Content $processes

  $ports = (& netstat.exe -ano 2>$null) -join "`n"
  Add-ObkatkaSnapshotSection -FileName 'ports.txt' -Label $Label -Content $ports

  $protocolLines = foreach ($scheme in @('dropweb', 'flclash', 'clashx')) {
    $handler = Get-ObkatkaProtocolHandler -Scheme $scheme
    if ($handler) {
      '{0} | {1} | {2}' -f $scheme, $handler.root, $handler.command
    } else {
      "$scheme | ABSENT"
    }
  }
  Add-ObkatkaSnapshotSection -FileName 'protocols.txt' -Label $Label -Content ($protocolLines -join "`n")
}

function Get-ObkatkaUninstallEntry {
  param([Parameter(Mandatory)][string]$NamePattern)

  $keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  )
  foreach ($key in $keys) {
    foreach ($child in @(Get-ChildItem $key -ErrorAction SilentlyContinue)) {
      $properties = Get-ItemProperty $child.PSPath -ErrorAction SilentlyContinue
      $displayNameProperty = if ($properties) { $properties.PSObject.Properties['DisplayName'] } else { $null }
      $displayName = if ($displayNameProperty) { [string]$displayNameProperty.Value } else { '' }
      if ($properties -and $displayName -match $NamePattern) {
        return $properties
      }
    }
  }
  return $null
}

function Test-ObkatkaHelperIdentity {
  param(
    [Parameter(Mandatory)][string]$CorePath,
    [Parameter(Mandatory)][string]$ServiceName,
    [Parameter(Mandatory)][int]$Port
  )

  $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
  $coreHash = if (Test-Path $CorePath) {
    (Get-FileHash -LiteralPath $CorePath -Algorithm SHA256).Hash.ToLowerInvariant()
  } else {
    ''
  }
  $pingBody = ''
  $pingError = $null
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/ping" -TimeoutSec 5 -ErrorAction Stop
    $pingBody = ([string]$response.Content).Trim().ToLowerInvariant()
  } catch {
    $pingError = $_.Exception.Message
  }
  $listenerPids = Get-ObkatkaListenerPids -Port $Port
  $servicePid = if ($service) { [int]$service.ProcessId } else { 0 }
  $pingMatches = $coreHash -and ($pingBody -ceq $coreHash)
  $pidOwnsPort = $servicePid -gt 0 -and $listenerPids -contains $servicePid

  $serviceState = if ($service) { $service.State } else { 'ABSENT' }
  $pingEvidence = @(
    "service=$ServiceName",
    "state=$serviceState",
    "servicePid=$servicePid",
    "listenerPids=$($listenerPids -join ',')",
    "corePath=$CorePath",
    "coreSha256=$coreHash",
    "pingBody=$pingBody",
    "pingError=$pingError"
  ) -join "`n"
  Add-ObkatkaSnapshotSection -FileName 'helper-ping.txt' -Label "$ServiceName identity" -Content $pingEvidence

  return [pscustomobject]@{
    service       = $service
    servicePid    = $servicePid
    listenerPids  = $listenerPids
    coreHash      = $coreHash
    pingBody      = $pingBody
    pingMatches   = [bool]$pingMatches
    pidOwnsPort   = [bool]$pidOwnsPort
    pingError     = $pingError
  }
}

function Find-ObkatkaAppLog {
  param([string]$AppPattern = 'dropweb')

  $evidenceRoot = Initialize-ObkatkaEvidence
  $logDirectories = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
  if ($env:APPDATA -and (Test-Path $env:APPDATA)) {
    foreach ($directory in @(Get-ChildItem $env:APPDATA -Directory -Recurse -Depth 4 -ErrorAction SilentlyContinue)) {
      if ($directory.Name -match $AppPattern) {
        $logs = Join-Path $directory.FullName 'logs'
        if (Test-Path $logs) {
          $logDirectories.Add((Get-Item $logs))
        }
      }
    }
  }

  $uniqueDirectories = @($logDirectories | Sort-Object FullName -Unique)
  $discoveredPaths = @($uniqueDirectories | ForEach-Object { $_.FullName })
  Add-ObkatkaSnapshotSection -FileName 'app-log-discovery.txt' -Label 'log discovery' -Content ($discoveredPaths -join "`n")
  $destination = Join-Path $evidenceRoot 'app-logs'
  New-Item -ItemType Directory -Force $destination | Out-Null
  foreach ($directory in $uniqueDirectories) {
    Copy-Item (Join-Path $directory.FullName '*') $destination -Recurse -Force -ErrorAction SilentlyContinue
  }

  $logs = foreach ($directory in $uniqueDirectories) {
    Get-ChildItem $directory.FullName -File -Filter '*.log' -ErrorAction SilentlyContinue
  }
  $latest = @($logs | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
  if ($latest.Count -eq 0) { return $null }
  return $latest[0]
}

function Test-ObkatkaOrderedMarkers {
  param(
    [Parameter(Mandatory)][string]$Content,
    [Parameter(Mandatory)][object[]]$Groups
  )

  $cursor = 0
  $selected = [System.Collections.Generic.List[string]]::new()
  foreach ($group in $Groups) {
    $patterns = if ($group -is [string]) { @([string]$group) } else { @($group) }
    $bestMatch = $null
    $bestPattern = $null
    foreach ($pattern in $patterns) {
      $matcher = [regex]::new([string]$pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      $candidate = $matcher.Match($Content, $cursor)
      if ($candidate.Success -and ($null -eq $bestMatch -or $candidate.Index -lt $bestMatch.Index)) {
        $bestMatch = $candidate
        $bestPattern = [string]$pattern
      }
    }
    if ($null -eq $bestMatch) {
      return [pscustomobject]@{
        passed   = $false
        detail   = "missing ordered marker after offset ${cursor}: $($patterns -join ' OR ')"
        selected = @($selected)
      }
    }
    $selected.Add($bestPattern)
    $cursor = $bestMatch.Index + $bestMatch.Length
  }

  return [pscustomobject]@{
    passed   = $true
    detail   = "ordered markers: $($selected -join ' -> ')"
    selected = @($selected)
  }
}

function Test-ObkatkaNegativePatterns {
  param(
    [Parameter(Mandatory)][string]$Content,
    [Parameter(Mandatory)][string[]]$Patterns
  )

  $hits = [System.Collections.Generic.List[string]]::new()
  foreach ($pattern in $Patterns) {
    if ([regex]::IsMatch($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $hits.Add($pattern)
    }
  }
  return [pscustomobject]@{
    passed = $hits.Count -eq 0
    detail = if ($hits.Count -eq 0) { 'no fatal patterns found' } else { "fatal matches: $($hits -join ', ')" }
    hits   = @($hits)
  }
}

function Test-ObkatkaLoadingRunBalance {
  param([Parameter(Mandatory)][string]$Content)

  $starts = ([regex]::Matches($Content, '\[loadingRun\] start', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
  $ends = ([regex]::Matches($Content, '\[loadingRun\] done', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
  return [pscustomobject]@{
    passed = $starts -le $ends
    detail = "start=$starts done=$ends"
    starts = $starts
    ends   = $ends
  }
}

function Test-ObkatkaBootLog {
  param(
    [Parameter(Mandatory)][string]$LogPath,
    [switch]$RequireHelperSpawn,
    [switch]$RequireCoreInit
  )

  $content = Get-Content -LiteralPath $LogPath -Raw -ErrorAction Stop
  $logLines = @(Get-Content -LiteralPath $LogPath -ErrorAction Stop)
  $bootLines = @($logLines | Where-Object { $_ -match '\[boot\]|\[loadingRun\]' })
  Write-ObkatkaAtomicText -Path (Join-Path (Initialize-ObkatkaEvidence) 'boot.txt') -Content (($bootLines -join "`n") + "`n")
  $groups = @(
    '\[boot\] bridge-bind',
    '\[boot\] helper-check',
    @('\[boot\] helper-start-accepted', '\[boot\] direct-spawn'),
    '\[boot\] connect-back ok',
    '\[boot\] core-ready'
  )
  if ($RequireCoreInit) { $groups += '\[boot\] core-init' }
  $ordered = Test-ObkatkaOrderedMarkers -Content $content -Groups $groups
  # core-ready is the authoritative final marker. With no profile, core-init may
  # legitimately no-op and is intentionally not required on untouched first boot.
  $spawnBranch = if ($ordered.selected -contains '\[boot\] direct-spawn') { 'direct-spawn' } elseif ($ordered.selected -contains '\[boot\] helper-start-accepted') { 'helper-start-accepted' } else { 'unknown' }
  $fatal = Test-ObkatkaNegativePatterns -Content $content -Patterns @(
    '\[boot\].*timeout',
    'CoreBootException',
    'tun listener failed to start',
    '\[tun\] listener failed to start after updateConfig',
    '\[loadingRun\] error/timeout',
    'helper-check conflict',
    'ownership parse failed',
    'realign budget exhausted',
    'degrading to TUN-off',
    'PlatformDispatcher',
    'Unhandled exception'
  )
  $loading = Test-ObkatkaLoadingRunBalance -Content $content
  $coreErrorLines = @($logLines | Where-Object {
      $_ -match 'CoreBootException|tun listener failed to start|helper-check conflict|ownership parse failed|realign budget exhausted|degrading to TUN-off|PlatformDispatcher|Unhandled exception'
    })
  Write-ObkatkaAtomicText -Path (Join-Path (Initialize-ObkatkaEvidence) 'core-errors.txt') -Content (($coreErrorLines -join "`n") + "`n")

  return @(
    (New-ObkatkaCheck -Name 'boot-journal-order' -Status $(if ($ordered.passed) { 'PASS' } else { 'FAIL' }) -Detail $ordered.detail)
    (New-ObkatkaCheck -Name 'boot-spawn-branch' -Status $(if (-not $RequireHelperSpawn -or $spawnBranch -eq 'helper-start-accepted') { 'PASS' } else { 'FAIL' }) -Detail $spawnBranch)
    (New-ObkatkaCheck -Name 'boot-fatal-patterns' -Status $(if ($fatal.passed) { 'PASS' } else { 'FAIL' }) -Detail $fatal.detail)
    (New-ObkatkaCheck -Name 'loadingRun-balance' -Status $(if ($loading.passed) { 'PASS' } else { 'FAIL' }) -Detail $loading.detail)
  )
}

function Save-ObkatkaScreenshot {
  param([string]$Name = 'desktop')

  try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
      $path = Join-Path (Initialize-ObkatkaEvidence) "$Name.png"
      $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
      Write-Host "screenshot: $path"
      return $path
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  } catch {
    Write-Host "::warning::opportunistic screenshot failed: $($_.Exception.Message)"
    return $null
  }
}
