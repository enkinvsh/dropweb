param(
  [Parameter(Mandatory)]
  [ValidateSet('import-connect', 'invalid-subscription', 'broken-core', 'upgrade-previous-stable')]
  [string]$Scenario,
  [Parameter(Mandatory)][string]$CandidateDirectory,
  [string]$StableDirectory,
  [string]$StableTag = 'v0.8.5',
  [string]$StableSha256 = 'e3ea07156cda68b2f2cb384dda48a8144f291ec350a39e4ee2984a73ff8f4e01'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_obkatka.ps1')

$script:Checks = [System.Collections.Generic.List[object]]::new()
$script:Clock = [System.Diagnostics.Stopwatch]::StartNew()
$script:Result = 'FAIL'
$script:Phases = [ordered]@{}
$script:Metadata = [ordered]@{}
$script:PhaseDurations = [ordered]@{}
$script:LifecycleProbeTimeoutSeconds = 10
$script:Metadata['scm-stop-core-count-after-10s'] = $null
$script:Metadata['helper-kill-core-count-after-10s'] = $null
$script:Metadata['upgrade-old-identity-survivors'] = $null
$script:Metadata['forced-cleanup-required'] = $false
$script:Metadata['run-token-fingerprint'] = $null
$script:Metadata.runTokenStatus = 'not-available-before-wave-2'

function Add-E2ECheck {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][bool]$Passed,
    [Parameter(Mandatory)][string]$Detail,
    [switch]$NonFatal
  )

  $status = if ($Passed) { 'PASS' } else { 'FAIL' }
  $script:Checks.Add((New-ObkatkaCheck -Name $Name -Status $status -Detail $Detail))
  if (-not $Passed -and -not $NonFatal) { throw "$Name`: $Detail" }
}

function Get-CandidateInstaller {
  $installers = @(Get-ChildItem -LiteralPath $CandidateDirectory -Filter '*.exe' -Recurse)
  Add-E2ECheck -Name 'candidate-installer-count' -Passed ($installers.Count -eq 1) -Detail "count=$($installers.Count)"
  $installer = $installers[0]
  $hash = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-ObkatkaAtomicText -Path (Join-Path (Get-ObkatkaEvidenceRoot) 'installer.txt') -Content "sha256=$hash`n"
  $script:Checks.Add((New-ObkatkaCheck -Name 'candidate-installer-sha256' -Status 'PASS' -Detail $hash))
  return $installer
}

function Install-Candidate {
  $installer = Get-CandidateInstaller
  $clock = [System.Diagnostics.Stopwatch]::StartNew()
  $process = Install-ObkatkaInstaller -InstallerPath $installer.FullName
  $clock.Stop()
  $script:PhaseDurations.candidateInstallSeconds = [math]::Round($clock.Elapsed.TotalSeconds, 1)
  Add-E2ECheck -Name 'candidate-installer-exit' -Passed ($process.ExitCode -eq 0) -Detail "exit=$($process.ExitCode)"
  $paths = Get-ObkatkaInstalledPaths
  foreach ($path in @($paths.app, $paths.core, $paths.helper)) {
    Add-E2ECheck -Name "installed-$([IO.Path]::GetFileName($path))" -Passed (Test-Path -LiteralPath $path) -Detail $path
  }
  return $paths
}

function Assert-InstalledHelperIdentity {
  param([Parameter(Mandatory)][object]$Paths)

  $service = Get-Service DropwebHelperService -ErrorAction SilentlyContinue
  if ($service) {
    for ($attempt = 0; $attempt -lt 10 -and $service.Status -ne 'Running'; $attempt++) {
      Start-Sleep -Seconds 1
      $service.Refresh()
    }
  }
  Add-E2ECheck -Name 'helper-service-running' -Passed ($service -and $service.Status -eq 'Running') -Detail $(if ($service) { "status=$($service.Status)" } else { 'ABSENT' })
  $identity = Test-ObkatkaHelperIdentity -CorePath $Paths.core -ServiceName 'DropwebHelperService' -Port 47896
  $servicePath = Get-ObkatkaServiceExecutablePath $identity.service.PathName
  Add-E2ECheck -Name 'helper-service-path' -Passed ([string]::Equals($servicePath, $Paths.helper, [StringComparison]::OrdinalIgnoreCase)) -Detail $servicePath
  $serviceProcessPath = if ($identity.serviceProcessIdentity) { [string]$identity.serviceProcessIdentity.executablePath } else { '' }
  Add-E2ECheck -Name 'helper-service-process-path' -Passed ([string]::Equals($serviceProcessPath, $Paths.helper, [StringComparison]::OrdinalIgnoreCase)) -Detail $serviceProcessPath
  $serviceCreationTime = if ($identity.serviceProcessIdentity) { [uint64]$identity.serviceProcessIdentity.creationTime100ns } else { [uint64]0 }
  Add-E2ECheck -Name 'helper-service-process-creation-time' -Passed ($serviceCreationTime -gt 0) -Detail "creationTime100ns=$serviceCreationTime"
  Add-E2ECheck -Name 'helper-ping-core-token' -Passed $identity.pingMatches -Detail 'ping body equals installed core SHA256'
  Add-E2ECheck -Name 'helper-service-pid-owns-47896' -Passed $identity.pidOwnsPort -Detail "servicePid=$($identity.servicePid) listenerPids=$($identity.listenerPids -join ',')"
  return $identity
}

function ConvertTo-E2EHelperEvidence {
  param(
    [Parameter(Mandatory)][object]$Identity,
    [Parameter(Mandatory)][object]$Paths
  )

  return [ordered]@{
    serviceName = 'DropwebHelperService'
    configuredPath = Get-ObkatkaServiceExecutablePath ([string]$Identity.service.PathName)
    expectedPath = $Paths.helper
    process = $Identity.serviceProcessIdentity
    coreSha256 = $Identity.coreHash
    pingToken = $Identity.pingBody
    pingMatches = [bool]$Identity.pingMatches
  }
}

function Wait-E2EHelperRunning {
  param([Parameter(Mandatory)][int]$TimeoutSeconds)

  $clock = [Diagnostics.Stopwatch]::StartNew()
  while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    $service = Get-Service DropwebHelperService -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') { return $true }
    Start-Sleep -Milliseconds 250
  }
  $service = Get-Service DropwebHelperService -ErrorAction SilentlyContinue
  return [bool]($service -and $service.Status -eq 'Running')
}

function Start-E2EHelperCoreFixture {
  param([Parameter(Mandatory)][object]$Paths)

  $existing = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $Paths.core)
  if ($existing.Count -ne 0) {
    throw "helper core fixture requires zero exact-path cores; found $($existing.Count)"
  }

  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
  $acceptTask = $listener.AcceptTcpClientAsync()
  try {
    $body = [ordered]@{
      path = $Paths.core
      arg = [string]$port
      home_dir = $Paths.root
    } | ConvertTo-Json -Compress
    $response = Invoke-WebRequest -Uri 'http://127.0.0.1:47896/start' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 10 -ErrorAction Stop
    if (-not [string]::IsNullOrEmpty([string]$response.Content)) {
      throw "helper rejected lifecycle fixture: $($response.Content)"
    }
    if (-not $acceptTask.Wait(10000)) {
      throw 'helper-spawned core did not connect to lifecycle fixture'
    }
    $client = $acceptTask.Result
    $coreCount = Wait-ObkatkaExactPathProcessCount -ExecutablePath $Paths.core -ExpectedCount 1 -TimeoutSeconds 10
    if ($coreCount -ne 1) {
      $client.Dispose()
      throw "expected one helper-spawned exact-path core; found $coreCount"
    }
    $coreIdentity = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $Paths.core)[0]
    if ([uint64]$coreIdentity.creationTime100ns -eq 0) {
      $client.Dispose()
      throw 'helper-spawned core identity has no creationTime100ns'
    }
    return [pscustomobject]@{
      listener = $listener
      client = $client
      coreIdentity = $coreIdentity
    }
  } catch {
    $listener.Stop()
    throw
  }
}

function Close-E2EHelperCoreFixture {
  param([AllowNull()][object]$Fixture)

  if (-not $Fixture) { return }
  $Fixture.client.Dispose()
  $Fixture.listener.Stop()
}

function Invoke-HelperLifecycleProbes {
  param([Parameter(Mandatory)][object]$Paths)

  $before = Assert-InstalledHelperIdentity -Paths $Paths
  $script:Metadata.helperServiceBeforeProbes = ConvertTo-E2EHelperEvidence -Identity $before -Paths $Paths
  $scmFixture = $null
  try {
    $scmFixture = Start-E2EHelperCoreFixture -Paths $Paths
    [void](Write-ObkatkaInstallIdentitySnapshot -Paths $Paths -Label 'before SCM stop probe' -FileName 'identity-before-scm-stop.json')
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Stop-Service DropwebHelperService -ErrorAction Stop
    $remainingSeconds = [math]::Max(0, $script:LifecycleProbeTimeoutSeconds - [math]::Ceiling($clock.Elapsed.TotalSeconds))
    $coreCount = if ($remainingSeconds -gt 0) {
      Wait-ObkatkaExactPathProcessCount -ExecutablePath $Paths.core -ExpectedCount 0 -TimeoutSeconds ([int]$remainingSeconds)
    } else {
      @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $Paths.core).Count
    }
    $clock.Stop()
    $script:Metadata['scm-stop-core-count-after-10s'] = $coreCount
    Add-E2ECheck -Name 'scm-stop-core-count-after-10s' -Passed ($coreCount -eq 0 -and $clock.Elapsed.TotalSeconds -le $script:LifecycleProbeTimeoutSeconds) -Detail "count=$coreCount elapsedSeconds=$([math]::Round($clock.Elapsed.TotalSeconds, 2)) identity=$($scmFixture.coreIdentity | ConvertTo-Json -Compress)"
  } finally {
    Close-E2EHelperCoreFixture -Fixture $scmFixture
  }

  Start-Service DropwebHelperService -ErrorAction Stop
  Add-E2ECheck -Name 'scm-stop-helper-restarted' -Passed (Wait-E2EHelperRunning -TimeoutSeconds 10) -Detail 'service reached Running after explicit restart'
  $afterScm = Assert-InstalledHelperIdentity -Paths $Paths
  $script:Metadata.helperServiceAfterScmStop = ConvertTo-E2EHelperEvidence -Identity $afterScm -Paths $Paths

  $killFixture = $null
  try {
    $killFixture = Start-E2EHelperCoreFixture -Paths $Paths
    $helperBeforeKill = Assert-InstalledHelperIdentity -Paths $Paths
    $script:Metadata.helperServiceBeforeKill = ConvertTo-E2EHelperEvidence -Identity $helperBeforeKill -Paths $Paths
    [void](Write-ObkatkaInstallIdentitySnapshot -Paths $Paths -Label 'before helper kill probe' -FileName 'identity-before-helper-kill.json')
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Stop-Process -Id $helperBeforeKill.servicePid -Force -ErrorAction Stop
    $coreCount = Wait-ObkatkaExactPathProcessCount -ExecutablePath $Paths.core -ExpectedCount 0 -TimeoutSeconds $script:LifecycleProbeTimeoutSeconds
    $clock.Stop()
    $script:Metadata['helper-kill-core-count-after-10s'] = $coreCount
    Add-E2ECheck -Name 'helper-kill-core-count-after-10s' -Passed ($coreCount -eq 0 -and $clock.Elapsed.TotalSeconds -le $script:LifecycleProbeTimeoutSeconds) -Detail "count=$coreCount elapsedSeconds=$([math]::Round($clock.Elapsed.TotalSeconds, 2)) identity=$($killFixture.coreIdentity | ConvertTo-Json -Compress)"
    Add-E2ECheck -Name 'helper-kill-old-service-identity-gone' -Passed (-not (Test-ObkatkaProcessIdentityAlive -Identity $helperBeforeKill.serviceProcessIdentity)) -Detail ($helperBeforeKill.serviceProcessIdentity | ConvertTo-Json -Compress)
  } finally {
    Close-E2EHelperCoreFixture -Fixture $killFixture
  }

  $recoveryMode = 'failure-actions'
  if (-not (Wait-E2EHelperRunning -TimeoutSeconds 5)) {
    Start-Service DropwebHelperService -ErrorAction Stop
    $recoveryMode = 'explicit-start'
  }
  Add-E2ECheck -Name 'helper-kill-service-restored' -Passed (Wait-E2EHelperRunning -TimeoutSeconds 10) -Detail "mode=$recoveryMode"
  $afterKill = Assert-InstalledHelperIdentity -Paths $Paths
  $script:Metadata.helperServiceRecoveryMode = $recoveryMode
  $script:Metadata.helperServiceAfterKill = ConvertTo-E2EHelperEvidence -Identity $afterKill -Paths $Paths
  [void](Write-ObkatkaInstallIdentitySnapshot -Paths $Paths -Label 'after helper kill recovery' -FileName 'identity-after-helper-kill.json')
}

function Protect-ObkatkaSecretFile {
  param([Parameter(Mandatory)][string]$Path)

  $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  & icacls.exe $Path /inheritance:r /grant:r "${identity}:(R,W)" | Out-Null
  Add-E2ECheck -Name 'subscription-file-acl' -Passed ($LASTEXITCODE -eq 0) -Detail 'inheritance removed; current user only'
}

function Invoke-BundlePlan {
  param(
    [Parameter(Mandatory)][string]$AppPath,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$BundlePath
  )

  $planPath = Join-Path $WorkRoot 'bundle-plan.json'
  $resultPath = Join-Path $WorkRoot 'bundle-result.json'
  Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
  Write-ObkatkaPlan -Path $planPath -Plan ([ordered]@{
      schema = 1
      resultPath = $resultPath
      exitAfter = $true
      stepTimeoutSeconds = 120
      steps = @(
        [ordered]@{ op = 'buildSupportBundle'; outPath = $BundlePath }
      )
    })
  $process = Start-ObkatkaCiPlan -AppPath $AppPath -PlanPath $planPath
  $result = Read-ObkatkaJsonWhenReady -Path $resultPath -TimeoutSeconds 150
  [void](Wait-ObkatkaProcessExit -Process $process -TimeoutSeconds 30)
  return $result
}

function Assert-Bundle {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string[]]$RequiredPatterns = @('dropweb diagnostics')
  )

  Add-E2ECheck -Name 'support-bundle-exists' -Passed (Test-Path -LiteralPath $Path) -Detail 'production bundle path exists'
  $length = (Get-Item -LiteralPath $Path).Length
  Add-E2ECheck -Name 'support-bundle-size' -Passed ($length -le 32768) -Detail "bytes=$length"
  $content = Get-Content -LiteralPath $Path -Raw
  foreach ($pattern in $RequiredPatterns) {
    Add-E2ECheck -Name "support-bundle-contains-$($pattern -replace '[^a-zA-Z0-9]+','-')" -Passed ($content -match [regex]::Escape($pattern)) -Detail "required marker=$pattern"
  }
  return $content
}

function Publish-SafeBundle {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [string[]]$RequiredPatterns = @('dropweb diagnostics'),
    [string[]]$ForbiddenValues = @()
  )

  $content = Assert-Bundle -Path $SourcePath -RequiredPatterns $RequiredPatterns
  foreach ($forbidden in @($ForbiddenValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    Add-E2ECheck -Name 'support-bundle-secret-redaction' -Passed (-not $content.Contains($forbidden)) -Detail 'forbidden credential material absent'
  }
  Copy-Item -LiteralPath $SourcePath -Destination (Join-Path (Get-ObkatkaEvidenceRoot) 'support-bundle.txt') -Force
  return $content
}

function Remove-UnsafeEvidence {
  param([string[]]$ForbiddenValues)

  $hits = [System.Collections.Generic.List[string]]::new()
  foreach ($file in @(Get-ChildItem -LiteralPath (Get-ObkatkaEvidenceRoot) -File -Recurse -ErrorAction SilentlyContinue)) {
    if ($file.Extension -match '^\.(png|jpg|jpeg|gif)$') { continue }
    try {
      $content = [IO.File]::ReadAllText($file.FullName)
      foreach ($forbidden in @($ForbiddenValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        if ($content.Contains($forbidden)) {
          $hits.Add($file.Name)
          Remove-Item -LiteralPath $file.FullName -Force
          break
        }
      }
    } catch {}
  }
  return @($hits)
}

function Get-AllDropwebLogContent {
  $log = Find-ObkatkaAppLog
  Add-E2ECheck -Name 'app-log-produced' -Passed ($null -ne $log) -Detail $(if ($log) { $log.FullName } else { 'ABSENT' })
  $logRoot = Split-Path -Parent $log.FullName
  return (@(Get-ChildItem -LiteralPath $logRoot -Filter '*.log' -File | Sort-Object Name | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n")
}

function Add-BootChecks {
  $log = Find-ObkatkaAppLog
  foreach ($check in @(Test-ObkatkaBootLog -LogPath $log.FullName -RequireHelperSpawn -RequireCoreInit)) {
    $script:Checks.Add($check)
  }
  $failed = @($script:Checks | Where-Object { $_.status -eq 'FAIL' })
  if ($failed.Count -gt 0) { throw "$($failed[0].name): $($failed[0].detail)" }
}

function Complete-E2EScenario {
  param([Parameter(Mandatory)][string]$ScenarioName)

  try { Export-ObkatkaSnapshot -Label "$ScenarioName final" } catch { Write-Host "::warning::final snapshot failed: $($_.Exception.Message)" }
  $script:Clock.Stop()
  $failed = @($script:Checks | Where-Object { $_.status -eq 'FAIL' })
  if ($failed.Count -eq 0) { $script:Result = 'PASS' }
  $firstFailure = if ($failed.Count -gt 0) { $failed[0].name } else { $null }
  $script:PhaseDurations.totalSeconds = [math]::Round($script:Clock.Elapsed.TotalSeconds, 1)
  $phaseTable = @{}
  foreach ($phase in $script:Phases.GetEnumerator()) { $phaseTable[$phase.Key] = $phase.Value }
  $metadataTable = @{}
  foreach ($entry in $script:Metadata.GetEnumerator()) { $metadataTable[$entry.Key] = $entry.Value }
  Write-ObkatkaVerdict -Scenario $ScenarioName -Result $script:Result -Checks @($script:Checks) -FirstFailure $firstFailure -Durations ([pscustomobject]$script:PhaseDurations) -Phases $phaseTable -Metadata $metadataTable
  return ($script:Result -eq 'PASS')
}

function Invoke-ImportConnect {
  $script:Phases = [ordered]@{ boot = 'FAIL'; import = 'FAIL'; proxy = 'FAIL'; tun = 'FAIL' }
  $workRoot = Join-Path $env:RUNNER_TEMP 'dropweb-import-connect'
  New-Item -ItemType Directory -Force $workRoot | Out-Null
  $appProcess = $null
  $baselineIp = $null
  $tunIp = $null
  $baselineRoutes = @()
  $baselineAdapters = @()
  $newAdapters = @()
  $subscription = ''
  $secretPathSegment = ''
  $paths = $null

  try {
    Initialize-ObkatkaEvidence -Reset | Out-Null
    Export-ObkatkaSnapshot -Label 'import-connect baseline'
    $script:Checks.Add((New-ObkatkaCheck -Name 'runner-image' -Status 'PASS' -Detail "$env:ImageOS/$env:ImageVersion; $([Environment]::OSVersion.VersionString)"))
    $baselineAdapters = @(Get-ObkatkaAdapterState)
    $baselineRoutes = @(Get-ObkatkaNormalizedRoutes)
    Write-ObkatkaNetworkSnapshot -FileName 'network-before.json' -Label 'before install/connect' | Out-Null
    (& route.exe print) | Set-Content (Join-Path (Get-ObkatkaEvidenceRoot) 'route-before.txt') -Encoding utf8
    $baselineIp = Get-ObkatkaEgressIp
    Write-ObkatkaAtomicText -Path (Join-Path (Get-ObkatkaEvidenceRoot) 'egress-before.txt') -Content "$baselineIp`n"
    Add-E2ECheck -Name 'baseline-direct-egress' -Passed (-not [string]::IsNullOrWhiteSpace($baselineIp)) -Detail (ConvertTo-ObkatkaMaskedIp $baselineIp)

    $paths = Install-Candidate
    [void](Assert-InstalledHelperIdentity -Paths $paths)
    [void](Write-ObkatkaInstallIdentitySnapshot -Paths $paths -Label 'candidate exact install' -FileName 'identity-after-install.json')
    Invoke-HelperLifecycleProbes -Paths $paths
    $subscription = [string]$env:CI_TEST_SUBSCRIPTION_URL
    Add-E2ECheck -Name 'subscription-secret-present' -Passed (-not [string]::IsNullOrWhiteSpace($subscription)) -Detail 'repository secret is non-empty'
    $subscriptionUri = [Uri]$subscription
    Add-E2ECheck -Name 'subscription-host-contract' -Passed ($subscriptionUri.Host -ceq 'sub.dropweb.org') -Detail $subscriptionUri.Host
    $secretPathSegment = @($subscriptionUri.Segments | ForEach-Object { $_.Trim('/') } | Where-Object { $_ })[-1]
    $urlFile = Join-Path $workRoot 'subscription-url.txt'
    [IO.File]::WriteAllText($urlFile, $subscription, [Text.UTF8Encoding]::new($false))
    Protect-ObkatkaSecretFile -Path $urlFile

    $planPath = Join-Path $workRoot 'plan.json'
    $resultPath = Join-Path $workRoot 'result.json'
    $checkpointPath = Join-Path $workRoot 'connected.json'
    $probeDonePath = Join-Path $workRoot 'probe-done.flag'
    $bundlePath = Join-Path $workRoot 'support-bundle.txt'
    Write-ObkatkaPlan -Path $planPath -Plan ([ordered]@{
        schema = 1
        resultPath = $resultPath
        exitAfter = $true
        stepTimeoutSeconds = 180
        steps = @(
          [ordered]@{ op = 'importUrl'; urlFile = $urlFile; expectHost = 'sub.dropweb.org' },
          [ordered]@{ op = 'connect'; expectTun = $true; checkpointPath = $checkpointPath },
          [ordered]@{ op = 'waitFile'; path = $probeDonePath; timeoutSeconds = 120 },
          [ordered]@{ op = 'buildSupportBundle'; outPath = $bundlePath },
          [ordered]@{ op = 'disconnect' }
        )
      })

    $journeyClock = [System.Diagnostics.Stopwatch]::StartNew()
    $appProcess = Start-ObkatkaCiPlan -AppPath $paths.app -PlanPath $planPath
    if (-not (Wait-ObkatkaPath -Path $checkpointPath -TimeoutSeconds 120)) {
      $failureDetail = 'checkpoint absent'
      if (Test-Path -LiteralPath $resultPath) {
        $earlyResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json -Depth 20
        Copy-Item -LiteralPath $resultPath -Destination (Join-Path (Get-ObkatkaEvidenceRoot) 'plan-result.json') -Force
        $failureDetail = "planResult=$($earlyResult.result) firstFailure=$($earlyResult.firstFailure)"
      }
      [void](Find-ObkatkaAppLog)
      throw "connect checkpoint did not appear: $failureDetail"
    }
    $checkpoint = Get-Content -LiteralPath $checkpointPath -Raw | ConvertFrom-Json -Depth 20
    Add-E2ECheck -Name 'connect-checkpoint-status' -Passed ($checkpoint.status -ceq 'PASS') -Detail "status=$($checkpoint.status)"
    Add-E2ECheck -Name 'tun-requested' -Passed ($checkpoint.requestedTun -eq $true) -Detail "requested=$($checkpoint.requestedTun)"
    Add-E2ECheck -Name 'tun-effective-observed' -Passed ($checkpoint.effectiveTunObserved -eq $true) -Detail "effective=$($checkpoint.effectiveTunObserved)"
    Add-E2ECheck -Name 'tun-listener-clean' -Passed ($checkpoint.tunListenerFailed -eq $false) -Detail "listenerFailed=$($checkpoint.tunListenerFailed)"
    Add-E2ECheck -Name 'connect-start-completed' -Passed ($checkpoint.startCompleted -eq $true) -Detail "startCompleted=$($checkpoint.startCompleted)"

    $baselineGuids = @($baselineAdapters | ForEach-Object { [string]$_.InterfaceGuid })
    $newAdapters = @(Get-ObkatkaAdapterState | Where-Object { $_.Status -eq 'Up' -and $baselineGuids -notcontains [string]$_.InterfaceGuid })
    Add-E2ECheck -Name 'tun-new-up-adapter' -Passed ($newAdapters.Count -gt 0) -Detail $(if ($newAdapters.Count -gt 0) { ($newAdapters | ForEach-Object { "$($_.Name)/if$($_.ifIndex)" }) -join ',' } else { 'no new Up adapter' })
    Write-ObkatkaNetworkSnapshot -FileName 'network-up.json' -Label 'connected' | Out-Null
    (& route.exe print) | Set-Content (Join-Path (Get-ObkatkaEvidenceRoot) 'route-up.txt') -Encoding utf8
    $tunRoutes = foreach ($adapter in $newAdapters) { Get-NetRoute -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue }
    Add-E2ECheck -Name 'tun-routes-present' -Passed (@($tunRoutes).Count -gt 0) -Detail "routeCount=$(@($tunRoutes).Count)"
    $tunAddresses = foreach ($adapter in $newAdapters) { Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue }
    Add-E2ECheck -Name 'tun-interface-addresses-present' -Passed (@($tunAddresses).Count -gt 0) -Detail "addressCount=$(@($tunAddresses).Count)"

    $tunIp = Get-ObkatkaEgressIp
    Write-ObkatkaAtomicText -Path (Join-Path (Get-ObkatkaEvidenceRoot) 'egress-tun.txt') -Content "$tunIp`n"
    Add-E2ECheck -Name 'tun-system-egress-changed' -Passed ($tunIp -and $tunIp -cne $baselineIp) -Detail "baseline=$(ConvertTo-ObkatkaMaskedIp $baselineIp) tun=$(ConvertTo-ObkatkaMaskedIp $tunIp)"
    $dns = @(Resolve-DnsName -Name 'api.ipify.org' -ErrorAction Stop)
    Add-E2ECheck -Name 'tun-dns-resolution' -Passed ($dns.Count -gt 0) -Detail "answers=$($dns.Count)"
    $dns | Format-Table -AutoSize | Out-String -Width 4096 | Set-Content (Join-Path (Get-ObkatkaEvidenceRoot) 'dns-up.txt') -Encoding utf8

    $mixedPort = [int]$checkpoint.ports.mixed
    $socksPort = [int]$checkpoint.ports.socks
    $proxyPort = if ($checkpoint.mixedListening -eq $true -and $mixedPort -gt 0) { $mixedPort } elseif ($checkpoint.socksListening -eq $true -and $socksPort -gt 0) { $socksPort } else { 0 }
    Add-E2ECheck -Name 'proxy-socks-listening' -Passed ($proxyPort -gt 0) -Detail "mixedPort=$mixedPort mixedListening=$($checkpoint.mixedListening) socksPort=$socksPort socksListening=$($checkpoint.socksListening) selected=$proxyPort"
    $proxyIp = (& curl.exe -sS --max-time 20 --proxy "socks5h://127.0.0.1:$proxyPort" 'https://api.ipify.org').Trim()
    $curlExit = $LASTEXITCODE
    Write-ObkatkaAtomicText -Path (Join-Path (Get-ObkatkaEvidenceRoot) 'egress-proxy.txt') -Content "$proxyIp`n"
    Add-E2ECheck -Name 'proxy-probe-succeeds' -Passed ($curlExit -eq 0 -and -not [string]::IsNullOrWhiteSpace($proxyIp)) -Detail "curlExit=$curlExit ip=$(ConvertTo-ObkatkaMaskedIp $proxyIp)"
    Add-E2ECheck -Name 'proxy-egress-changed' -Passed ($proxyIp -and $proxyIp -cne $baselineIp) -Detail "baseline=$(ConvertTo-ObkatkaMaskedIp $baselineIp) proxy=$(ConvertTo-ObkatkaMaskedIp $proxyIp)"
    Save-ObkatkaScreenshot -Name 'import-connect-connected' | Out-Null

    Write-ObkatkaAtomicText -Path $probeDonePath -Content "done`n"
    $planResult = Read-ObkatkaJsonWhenReady -Path $resultPath -TimeoutSeconds 180
    Copy-Item -LiteralPath $resultPath -Destination (Join-Path (Get-ObkatkaEvidenceRoot) 'plan-result.json') -Force
    $journeyClock.Stop()
    $script:PhaseDurations.journeySeconds = [math]::Round($journeyClock.Elapsed.TotalSeconds, 1)
    Add-E2ECheck -Name 'plan-result-pass' -Passed ($planResult.result -ceq 'PASS' -and $null -eq $planResult.firstFailure) -Detail "result=$($planResult.result) firstFailure=$($planResult.firstFailure)"
    $importStep = @($planResult.steps | Where-Object { $_.op -eq 'importUrl' })[0]
    Add-E2ECheck -Name 'import-step-pass' -Passed ($importStep.status -ceq 'PASS') -Detail "status=$($importStep.status)"
    foreach ($property in $importStep.checks.PSObject.Properties) {
      Add-E2ECheck -Name "import-$($property.Name)" -Passed ($property.Value -eq $true) -Detail "$($property.Name)=$($property.Value)"
    }

    [void](Publish-SafeBundle -SourcePath $bundlePath -ForbiddenValues @($subscription, $secretPathSegment))
    Add-BootChecks
    $allLogs = Get-AllDropwebLogContent
    $fatal = Test-ObkatkaNegativePatterns -Content $allLogs -Patterns @(
      'tun listener failed to start',
      '\[tun\] listener failed to start after updateConfig',
      'realign budget exhausted',
      'degrading to TUN-off',
      'PlatformDispatcher',
      'Unhandled exception'
    )
    Add-E2ECheck -Name 'all-app-logs-fatal-patterns' -Passed $fatal.passed -Detail $fatal.detail
    [void](Assert-InstalledHelperIdentity -Paths $paths)

    $exited = Wait-ObkatkaProcessExit -Process $appProcess -TimeoutSeconds 30
    Add-E2ECheck -Name 'app-exited-after-plan' -Passed $exited -Detail "pid=$($appProcess.Id)"
    Start-Sleep -Seconds 3
    $leftoverAppIdentities = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.app)
    $leftoverCoreIdentities = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.core)
    Add-E2ECheck -Name 'post-exit-no-app-or-core-processes' -Passed ($leftoverAppIdentities.Count -eq 0 -and $leftoverCoreIdentities.Count -eq 0) -Detail "appCount=$($leftoverAppIdentities.Count) coreCount=$($leftoverCoreIdentities.Count)"
    $remainingNewUp = foreach ($adapter in $newAdapters) {
      Get-ObkatkaAdapterState | Where-Object {
        [string]$_.InterfaceGuid -eq [string]$adapter.InterfaceGuid -and $_.Status -eq 'Up'
      }
    }
    Add-E2ECheck -Name 'tun-adapter-gone-or-down' -Passed (@($remainingNewUp).Count -eq 0) -Detail "remainingUp=$(@($remainingNewUp).Count)"
    $afterRoutes = @(Get-ObkatkaNormalizedRoutes)
    $routeDiff = @(Compare-Object -ReferenceObject $baselineRoutes -DifferenceObject $afterRoutes)
    Add-E2ECheck -Name 'routes-restored' -Passed ($routeDiff.Count -eq 0) -Detail "differenceCount=$($routeDiff.Count)"
    Write-ObkatkaNetworkSnapshot -FileName 'network-after.json' -Label 'after disconnect/exit' | Out-Null
    (& route.exe print) | Set-Content (Join-Path (Get-ObkatkaEvidenceRoot) 'route-after.txt') -Encoding utf8
    $afterIp = Get-ObkatkaEgressIp
    Write-ObkatkaAtomicText -Path (Join-Path (Get-ObkatkaEvidenceRoot) 'egress-after.txt') -Content "$afterIp`n"
    Add-E2ECheck -Name 'direct-egress-restored' -Passed ($afterIp -ceq $baselineIp) -Detail "before=$(ConvertTo-ObkatkaMaskedIp $baselineIp) after=$(ConvertTo-ObkatkaMaskedIp $afterIp)"

    $script:Phases.boot = 'PASS'
    $script:Phases.import = 'PASS'
    $script:Phases.proxy = 'PASS'
    $script:Phases.tun = 'PASS'
    $script:Metadata.requestedTun = $true
    $script:Metadata.effectiveTun = $true
    $script:Metadata.egress = [ordered]@{ baseline = ConvertTo-ObkatkaMaskedIp $baselineIp; tun = ConvertTo-ObkatkaMaskedIp $tunIp }
  } catch {
    Write-Host "::error::$($_.Exception.Message)"
    if (@($script:Checks | Where-Object { $_.status -eq 'FAIL' }).Count -eq 0) {
      $script:Checks.Add((New-ObkatkaCheck -Name 'scenario-exception' -Status 'FAIL' -Detail $_.Exception.Message))
    }
  } finally {
    Remove-Item -LiteralPath (Join-Path $workRoot 'subscription-url.txt') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $workRoot 'support-bundle.txt') -Force -ErrorAction SilentlyContinue
    $ownedCoreCount = if ($paths) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.core).Count } else { 0 }
    if (($appProcess -and -not $appProcess.HasExited) -or $ownedCoreCount -gt 0) {
      $script:Metadata['forced-cleanup-required'] = $true
      Stop-ObkatkaAppProcesses
    }
  }
  $unsafeEvidence = @(Remove-UnsafeEvidence -ForbiddenValues @($subscription, $secretPathSegment))
  if ($unsafeEvidence.Count -gt 0) {
    $script:Checks.Add((New-ObkatkaCheck -Name 'evidence-secret-scan' -Status 'FAIL' -Detail "unsafe files removed: $($unsafeEvidence -join ',')"))
  } else {
    $script:Checks.Add((New-ObkatkaCheck -Name 'evidence-secret-scan' -Status 'PASS' -Detail 'no subscription credential material in upload tree'))
  }
  $script:Checks.Add((New-ObkatkaCheck -Name 'forced-cleanup-required' -Status $(if ($script:Metadata['forced-cleanup-required']) { 'FAIL' } else { 'PASS' }) -Detail "required=$($script:Metadata['forced-cleanup-required'])"))
  return (Complete-E2EScenario -ScenarioName 'import-connect')
}

function Invoke-InvalidSubscription {
  $script:Phases = [ordered]@{ boot = 'FAIL'; import = 'FAIL'; proxy = 'NOT_PROVEN'; tun = 'NOT_PROVEN' }
  $workRoot = Join-Path $env:RUNNER_TEMP 'dropweb-invalid-subscription'
  New-Item -ItemType Directory -Force $workRoot | Out-Null
  $serverJob = $null
  $paths = $null
  try {
    Initialize-ObkatkaEvidence -Reset | Out-Null
    $paths = Install-Candidate
    $port = Get-Random -Minimum 18000 -Maximum 26000
    $serverJob = Start-Job -ScriptBlock {
      param($Port)
      $listener = [Net.HttpListener]::new()
      $listener.Prefixes.Add("http://127.0.0.1:$Port/")
      $listener.Start()
      try {
        $context = $listener.GetContext()
        $payload = [Text.Encoding]::UTF8.GetBytes('not: a: valid: clash config')
        $context.Response.StatusCode = 200
        $context.Response.ContentType = 'text/plain'
        $context.Response.ContentLength64 = $payload.Length
        $context.Response.OutputStream.Write($payload, 0, $payload.Length)
        $context.Response.OutputStream.Close()
      } finally {
        $listener.Stop()
      }
    } -ArgumentList $port
    Start-Sleep -Seconds 1
    $urlFile = Join-Path $workRoot 'invalid-url.txt'
    [IO.File]::WriteAllText($urlFile, "http://127.0.0.1:$port/sub", [Text.UTF8Encoding]::new($false))
    Protect-ObkatkaSecretFile -Path $urlFile
    $resultPath = Join-Path $workRoot 'result.json'
    $bundlePath = Join-Path $workRoot 'support-bundle.txt'
    $planPath = Join-Path $workRoot 'plan.json'
    Write-ObkatkaPlan -Path $planPath -Plan ([ordered]@{
        schema = 1; resultPath = $resultPath; exitAfter = $true; stepTimeoutSeconds = 120
        steps = @(
          [ordered]@{ op = 'importUrl'; urlFile = $urlFile; expectHost = '127.0.0.1' },
          [ordered]@{ op = 'buildSupportBundle'; outPath = $bundlePath }
        )
      })
    $app = Start-ObkatkaCiPlan -AppPath $paths.app -PlanPath $planPath
    $planResult = Read-ObkatkaJsonWhenReady -Path $resultPath -TimeoutSeconds 150
    Copy-Item -LiteralPath $resultPath -Destination (Join-Path (Get-ObkatkaEvidenceRoot) 'plan-result.json') -Force
    [void](Wait-ObkatkaProcessExit -Process $app -TimeoutSeconds 30)
    Add-E2ECheck -Name 'invalid-plan-result-fail' -Passed ($planResult.result -ceq 'FAIL') -Detail "result=$($planResult.result)"
    Add-E2ECheck -Name 'invalid-first-failure-import' -Passed ([string]$planResult.firstFailure -match '^importUrl:') -Detail "firstFailure=$($planResult.firstFailure)"
    $importStep = @($planResult.steps | Where-Object { $_.op -eq 'importUrl' })[0]
    Add-E2ECheck -Name 'invalid-import-validate-present' -Passed ($importStep.checks.validateOnce -eq $true) -Detail "validateOnce=$($importStep.checks.validateOnce)"
    Add-E2ECheck -Name 'invalid-import-no-profile-commit' -Passed ($importStep.checks.profileCommitOnce -eq $false) -Detail "profileCommitOnce=$($importStep.checks.profileCommitOnce)"
    Add-E2ECheck -Name 'invalid-import-no-profile-apply' -Passed ($importStep.checks.profileApplyOnce -eq $false) -Detail "profileApplyOnce=$($importStep.checks.profileApplyOnce)"
    $logContent = Get-AllDropwebLogContent
    Add-E2ECheck -Name 'invalid-add-profile-failed-logged' -Passed ($logContent -match 'Add Profile Failed') -Detail 'expected import error marker present'
    Add-E2ECheck -Name 'invalid-no-platform-dispatcher' -Passed ($logContent -notmatch 'PlatformDispatcher') -Detail 'no detached unhandled error'
    $bundleResult = Invoke-BundlePlan -AppPath $paths.app -WorkRoot $workRoot -BundlePath $bundlePath
    Add-E2ECheck -Name 'invalid-bundle-plan-pass' -Passed ($bundleResult.result -ceq 'PASS') -Detail "result=$($bundleResult.result)"
    [void](Publish-SafeBundle -SourcePath $bundlePath -RequiredPatterns @('dropweb diagnostics', '[import] validate') -ForbiddenValues @("http://127.0.0.1:$port/sub"))
    $script:Phases.boot = 'PASS'
    $script:Phases.import = 'PASS'
  } catch {
    Write-Host "::error::$($_.Exception.Message)"
    if (@($script:Checks | Where-Object { $_.status -eq 'FAIL' }).Count -eq 0) {
      $script:Checks.Add((New-ObkatkaCheck -Name 'scenario-exception' -Status 'FAIL' -Detail $_.Exception.Message))
    }
  } finally {
    if ($serverJob) { Stop-Job $serverJob -ErrorAction SilentlyContinue; Remove-Job $serverJob -Force -ErrorAction SilentlyContinue }
    $ownedAppCount = if ($paths) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.app).Count } else { 0 }
    $ownedCoreCount = if ($paths) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.core).Count } else { 0 }
    if ($ownedAppCount -gt 0 -or $ownedCoreCount -gt 0) {
      $script:Metadata['forced-cleanup-required'] = $true
      Stop-ObkatkaAppProcesses
    }
  }
  $script:Checks.Add((New-ObkatkaCheck -Name 'forced-cleanup-required' -Status $(if ($script:Metadata['forced-cleanup-required']) { 'FAIL' } else { 'PASS' }) -Detail "required=$($script:Metadata['forced-cleanup-required'])"))
  return (Complete-E2EScenario -ScenarioName 'diagnostics-negative-invalid-subscription')
}

function Invoke-BrokenCore {
  $script:Phases = [ordered]@{ boot = 'FAIL'; import = 'FAIL'; proxy = 'NOT_PROVEN'; tun = 'NOT_PROVEN' }
  $workRoot = Join-Path $env:RUNNER_TEMP 'dropweb-broken-core'
  New-Item -ItemType Directory -Force $workRoot | Out-Null
  $renamedCore = $null
  $paths = $null
  try {
    Initialize-ObkatkaEvidence -Reset | Out-Null
    $paths = Install-Candidate
    $renamedCore = "$($paths.core).ci-broken"
    Move-Item -LiteralPath $paths.core -Destination $renamedCore -Force
    Add-E2ECheck -Name 'broken-core-renamed' -Passed (-not (Test-Path -LiteralPath $paths.core) -and (Test-Path -LiteralPath $renamedCore)) -Detail 'installed core intentionally unavailable'
    $urlFile = Join-Path $workRoot 'unused-url.txt'
    [IO.File]::WriteAllText($urlFile, 'http://127.0.0.1:9/sub', [Text.UTF8Encoding]::new($false))
    $resultPath = Join-Path $workRoot 'result.json'
    $bundlePath = Join-Path $workRoot 'support-bundle.txt'
    $planPath = Join-Path $workRoot 'plan.json'
    Write-ObkatkaPlan -Path $planPath -Plan ([ordered]@{
        schema = 1; resultPath = $resultPath; exitAfter = $true; stepTimeoutSeconds = 100
        steps = @(
          [ordered]@{ op = 'importUrl'; urlFile = $urlFile; expectHost = '127.0.0.1' },
          [ordered]@{ op = 'buildSupportBundle'; outPath = $bundlePath }
        )
      })
    $app = Start-ObkatkaCiPlan -AppPath $paths.app -PlanPath $planPath
    $planResult = Read-ObkatkaJsonWhenReady -Path $resultPath -TimeoutSeconds 120
    Copy-Item -LiteralPath $resultPath -Destination (Join-Path (Get-ObkatkaEvidenceRoot) 'plan-result.json') -Force
    $exited = Wait-ObkatkaProcessExit -Process $app -TimeoutSeconds 30
    Add-E2ECheck -Name 'broken-core-app-exited' -Passed $exited -Detail "pid=$($app.Id)"
    Add-E2ECheck -Name 'broken-core-plan-result-fail' -Passed ($planResult.result -ceq 'FAIL') -Detail "result=$($planResult.result)"
    Add-E2ECheck -Name 'broken-core-import-blocked-by-bootstrap' -Passed ([string]$planResult.firstFailure -eq 'importUrl:bootstrap') -Detail "firstFailure=$($planResult.firstFailure)"
    $logContent = Get-AllDropwebLogContent
    $spawnCount = ([regex]::Matches($logContent, '\[core-bridge\] spawn gen=', [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
    Add-E2ECheck -Name 'broken-core-spawn-attempt-logged' -Passed ($spawnCount -ge 1) -Detail "spawnAttempts=$spawnCount"
    Add-E2ECheck -Name 'broken-core-retries-logged' -Passed ($spawnCount -ge 4) -Detail "spawnAttempts=$spawnCount"
    Add-E2ECheck -Name 'broken-core-terminal-spawn-phase' -Passed ($logContent -match '\[boot\] core-failed .* during spawn') -Detail 'terminal boot journal identifies spawn phase'
    Add-E2ECheck -Name 'broken-core-typed-exception' -Passed ($logContent -match 'CoreBootException') -Detail 'typed CoreBootException present'
    Add-E2ECheck -Name 'broken-core-no-platform-dispatcher' -Passed ($logContent -notmatch 'PlatformDispatcher') -Detail 'no detached unhandled error'

    Move-Item -LiteralPath $renamedCore -Destination $paths.core -Force
    $renamedCore = $null
    $bundleResult = Invoke-BundlePlan -AppPath $paths.app -WorkRoot $workRoot -BundlePath $bundlePath
    Add-E2ECheck -Name 'broken-core-bundle-plan-pass' -Passed ($bundleResult.result -ceq 'PASS') -Detail "result=$($bundleResult.result)"
    [void](Publish-SafeBundle -SourcePath $bundlePath -RequiredPatterns @('dropweb diagnostics', '[boot]', 'CoreBootException') -ForbiddenValues @('http://127.0.0.1:9/sub'))
    $leftoverApps = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.app)
    $leftoverCores = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.core)
    Add-E2ECheck -Name 'broken-core-no-owned-processes' -Passed ($leftoverApps.Count -eq 0 -and $leftoverCores.Count -eq 0) -Detail "appCount=$($leftoverApps.Count) coreCount=$($leftoverCores.Count)"
    $script:Phases.boot = 'PASS'
    $script:Phases.import = 'PASS'
  } catch {
    Write-Host "::error::$($_.Exception.Message)"
    if (@($script:Checks | Where-Object { $_.status -eq 'FAIL' }).Count -eq 0) {
      $script:Checks.Add((New-ObkatkaCheck -Name 'scenario-exception' -Status 'FAIL' -Detail $_.Exception.Message))
    }
  } finally {
    $ownedAppCount = if ($paths) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.app).Count } else { 0 }
    $ownedCoreCount = if ($paths -and (Test-Path -LiteralPath $paths.core)) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $paths.core).Count } else { 0 }
    if ($ownedAppCount -gt 0 -or $ownedCoreCount -gt 0) {
      $script:Metadata['forced-cleanup-required'] = $true
      Stop-ObkatkaAppProcesses
    }
    if ($renamedCore -and (Test-Path -LiteralPath $renamedCore)) {
      Move-Item -LiteralPath $renamedCore -Destination ($renamedCore -replace '\.ci-broken$','') -Force -ErrorAction SilentlyContinue
    }
  }
  $script:Checks.Add((New-ObkatkaCheck -Name 'forced-cleanup-required' -Status $(if ($script:Metadata['forced-cleanup-required']) { 'FAIL' } else { 'PASS' }) -Detail "required=$($script:Metadata['forced-cleanup-required'])"))
  return (Complete-E2EScenario -ScenarioName 'diagnostics-negative-broken-core')
}

function Invoke-UpgradePreviousStable {
  $script:Phases = [ordered]@{ boot = 'FAIL'; import = 'NOT_PROVEN'; proxy = 'NOT_PROVEN'; tun = 'NOT_PROVEN' }
  $stablePaths = $null
  $candidatePaths = $null
  $stableApp = $null
  $candidateApp = $null
  $oldCoreIdentities = @()
  try {
    Initialize-ObkatkaEvidence -Reset | Out-Null
    Add-E2ECheck -Name 'stable-directory-present' -Passed (-not [string]::IsNullOrWhiteSpace($StableDirectory) -and (Test-Path -LiteralPath $StableDirectory)) -Detail 'pinned stable artifact directory exists'
    $stableInstallers = @(Get-ChildItem -LiteralPath $StableDirectory -Filter '*.exe' -Recurse)
    Add-E2ECheck -Name 'stable-installer-count' -Passed ($stableInstallers.Count -eq 1) -Detail "count=$($stableInstallers.Count)"
    $stableInstaller = $stableInstallers[0]
    $stableHash = (Get-FileHash -LiteralPath $stableInstaller.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-E2ECheck -Name 'stable-installer-pinned-sha256' -Passed ($stableHash -ceq $StableSha256) -Detail "tag=$StableTag sha256=$stableHash"
    $script:Metadata.stableTag = $StableTag
    $script:Metadata.stableInstallerSha256 = $stableHash
    $stableInstall = Install-ObkatkaInstaller -InstallerPath $stableInstaller.FullName
    Add-E2ECheck -Name 'stable-installer-exit' -Passed ($stableInstall.ExitCode -eq 0) -Detail "exit=$($stableInstall.ExitCode)"
    $stablePaths = Get-ObkatkaInstalledPaths
    $oldCoreHash = (Get-FileHash -LiteralPath $stablePaths.core -Algorithm SHA256).Hash.ToLowerInvariant()
    $oldAppHash = (Get-FileHash -LiteralPath $stablePaths.app -Algorithm SHA256).Hash.ToLowerInvariant()
    $stableIdentity = Test-ObkatkaHelperIdentity -CorePath $stablePaths.core -ServiceName 'DropwebHelperService' -Port 47896
    Add-E2ECheck -Name 'stable-helper-token' -Passed $stableIdentity.pingMatches -Detail 'stable helper matches stable core'

    $stableApp = Start-Process -FilePath $stablePaths.app -PassThru
    Start-Sleep -Seconds 20
    Add-E2ECheck -Name 'stable-bare-launch-alive' -Passed (-not $stableApp.HasExited) -Detail "pid=$($stableApp.Id)"
    $oldCoreCount = Wait-ObkatkaExactPathProcessCount -ExecutablePath $stablePaths.core -ExpectedCount 1 -TimeoutSeconds 10
    Add-E2ECheck -Name 'stable-exact-core-running-before-upgrade' -Passed ($oldCoreCount -eq 1) -Detail "count=$oldCoreCount"
    $oldCoreIdentities = @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $stablePaths.core)
    Add-E2ECheck -Name 'stable-core-identity-has-creation-time' -Passed ($oldCoreIdentities.Count -eq 1 -and [uint64]$oldCoreIdentities[0].creationTime100ns -gt 0) -Detail ($oldCoreIdentities | ConvertTo-Json -Compress)
    $script:Metadata.upgradeOldCoreIdentities = $oldCoreIdentities
    [void](Write-ObkatkaInstallIdentitySnapshot -Paths $stablePaths -Label 'stable live before candidate overinstall' -FileName 'identity-before-upgrade.json')

    # Silent CI uses /SUPPRESSMSGBOXES, so an in-use prompt auto-aborts with exit 5
    # when the tray app resists Restart Manager. Interactive upgrades keep Inno's
    # normal close-applications prompt; live-GUI overinstall remains a manual field scenario.
    $gracefulClose = $stableApp.CloseMainWindow()
    $stableAppExited = Wait-ObkatkaProcessExit -Process $stableApp -TimeoutSeconds 5
    if (-not $stableAppExited) {
      Stop-Process -Id $stableApp.Id -Force -ErrorAction SilentlyContinue
      $stableAppExited = Wait-ObkatkaProcessExit -Process $stableApp -TimeoutSeconds 10
    }
    Add-E2ECheck -Name 'stable-app-closed-before-upgrade' -Passed $stableAppExited -Detail "graceful=$gracefulClose pid=$($stableApp.Id)"

    $preCandidateLog = Find-ObkatkaAppLog
    $preCandidateLineCount = if ($preCandidateLog) { @(Get-Content -LiteralPath $preCandidateLog.FullName).Count } else { 0 }

    $candidateInstaller = Get-CandidateInstaller
    $candidateInstall = Install-ObkatkaInstaller -InstallerPath $candidateInstaller.FullName
    Add-E2ECheck -Name 'candidate-overinstall-exit' -Passed ($candidateInstall.ExitCode -eq 0) -Detail "exit=$($candidateInstall.ExitCode)"
    $candidatePaths = Get-ObkatkaInstalledPaths
    [void](Write-ObkatkaInstallIdentitySnapshot -Paths $candidatePaths -Label 'candidate after overinstall' -FileName 'identity-after-upgrade.json')
    $versionLine = (Select-String -LiteralPath (Join-Path $env:GITHUB_WORKSPACE 'pubspec.yaml') -Pattern '^version:\s*(\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value
    $candidateVersion = $versionLine.Split('+')[0]
    Add-E2ECheck -Name 'upgrade-uninstall-entry-candidate-version' -Passed ([string]$candidatePaths.entry.DisplayVersion -match [regex]::Escape($candidateVersion)) -Detail "displayVersion=$($candidatePaths.entry.DisplayVersion) expected=$candidateVersion"
    $newCoreHash = (Get-FileHash -LiteralPath $candidatePaths.core -Algorithm SHA256).Hash.ToLowerInvariant()
    $newAppHash = (Get-FileHash -LiteralPath $candidatePaths.app -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-E2ECheck -Name 'upgrade-core-hash-rotated' -Passed ($newCoreHash -cne $oldCoreHash) -Detail "old=$oldCoreHash new=$newCoreHash"
    Add-E2ECheck -Name 'upgrade-app-hash-rotated' -Passed ($newAppHash -cne $oldAppHash) -Detail "old=$oldAppHash new=$newAppHash"
    $candidateIdentity = Test-ObkatkaHelperIdentity -CorePath $candidatePaths.core -ServiceName 'DropwebHelperService' -Port 47896
    Add-E2ECheck -Name 'upgrade-helper-token-new-core' -Passed $candidateIdentity.pingMatches -Detail 'helper ping equals candidate core SHA256'
    Add-E2ECheck -Name 'upgrade-helper-token-not-old-core' -Passed ($candidateIdentity.pingBody -cne $oldCoreHash) -Detail 'helper token rotated'
    $oldIdentitySurvivors = @($oldCoreIdentities | Where-Object { Test-ObkatkaProcessIdentityAlive -Identity $_ })
    $script:Metadata['upgrade-old-identity-survivors'] = $oldIdentitySurvivors.Count
    $script:Metadata.upgradeOldIdentitySurvivorDetails = $oldIdentitySurvivors
    Add-E2ECheck -Name 'upgrade-no-leftover-old-processes' -Passed ($oldIdentitySurvivors.Count -eq 0) -Detail "captured=$($oldCoreIdentities.Count) survivors=$($oldIdentitySurvivors.Count)"

    $candidateApp = Start-Process -FilePath $candidatePaths.app -PassThru
    Start-Sleep -Seconds 25
    Add-E2ECheck -Name 'candidate-bare-launch-alive' -Passed (-not $candidateApp.HasExited) -Detail "pid=$($candidateApp.Id)"
    $candidateLog = Find-ObkatkaAppLog
    Add-E2ECheck -Name 'candidate-app-log-produced' -Passed ($null -ne $candidateLog) -Detail $(if ($candidateLog) { $candidateLog.FullName } else { 'ABSENT' })
    $candidateLines = @(Get-Content -LiteralPath $candidateLog.FullName | Select-Object -Skip $preCandidateLineCount)
    $candidateLogPath = Join-Path (Get-ObkatkaEvidenceRoot) 'candidate-app.log'
    Write-ObkatkaAtomicText -Path $candidateLogPath -Content (($candidateLines -join "`n") + "`n")
    foreach ($check in @(Test-ObkatkaBootLog -LogPath $candidateLogPath -RequireHelperSpawn -RequireCoreInit)) {
      $script:Checks.Add($check)
    }
    $failedBoot = @($script:Checks | Where-Object { $_.status -eq 'FAIL' })
    if ($failedBoot.Count -gt 0) { throw "$($failedBoot[0].name): $($failedBoot[0].detail)" }
    $candidateContent = $candidateLines -join "`n"
    Add-E2ECheck -Name 'candidate-loadingRun-health' -Passed ($candidateContent -notmatch '\[loadingRun\] error/timeout|PlatformDispatcher|Unhandled exception') -Detail 'no candidate loadingRun or unhandled fatal marker'
    Stop-Process -Id $candidateApp.Id -ErrorAction SilentlyContinue
    $candidateExited = Wait-ObkatkaProcessExit -Process $candidateApp -TimeoutSeconds 10
    Add-E2ECheck -Name 'candidate-app-stopped-by-exact-pid' -Passed $candidateExited -Detail "pid=$($candidateApp.Id)"
    $candidateCoreCount = Wait-ObkatkaExactPathProcessCount -ExecutablePath $candidatePaths.core -ExpectedCount 0 -TimeoutSeconds 10
    Add-E2ECheck -Name 'candidate-core-exited-after-app' -Passed ($candidateCoreCount -eq 0) -Detail "count=$candidateCoreCount"
    $script:Phases.boot = 'PASS'
    $script:Metadata.oldCoreSha256 = $oldCoreHash
    $script:Metadata.newCoreSha256 = $newCoreHash
  } catch {
    Write-Host "::error::$($_.Exception.Message)"
    if (@($script:Checks | Where-Object { $_.status -eq 'FAIL' }).Count -eq 0) {
      $script:Checks.Add((New-ObkatkaCheck -Name 'scenario-exception' -Status 'FAIL' -Detail $_.Exception.Message))
    }
  } finally {
    $ownedAppPath = if ($candidatePaths) { $candidatePaths.app } elseif ($stablePaths) { $stablePaths.app } else { $null }
    $ownedCorePath = if ($candidatePaths) { $candidatePaths.core } elseif ($stablePaths) { $stablePaths.core } else { $null }
    $ownedAppIdentities = if ($ownedAppPath) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $ownedAppPath) } else { @() }
    $ownedCoreIdentities = if ($ownedCorePath) { @(Get-ObkatkaExactPathProcessIdentities -ExecutablePath $ownedCorePath) } else { @() }
    $ownedAppCount = $ownedAppIdentities.Count
    $ownedCoreCount = $ownedCoreIdentities.Count
    if ($ownedAppCount -gt 0 -or $ownedCoreCount -gt 0) {
      $script:Metadata['forced-cleanup-required'] = $true
      foreach ($ownedIdentity in @($ownedAppIdentities + $ownedCoreIdentities)) {
        Stop-Process -Id $ownedIdentity.pid -Force -ErrorAction SilentlyContinue
      }
    }
  }
  $script:Checks.Add((New-ObkatkaCheck -Name 'forced-cleanup-required' -Status $(if ($script:Metadata['forced-cleanup-required']) { 'FAIL' } else { 'PASS' }) -Detail "required=$($script:Metadata['forced-cleanup-required'])"))
  return (Complete-E2EScenario -ScenarioName 'upgrade-previous-stable')
}

$passed = switch ($Scenario) {
  'import-connect' { Invoke-ImportConnect }
  'invalid-subscription' { Invoke-InvalidSubscription }
  'broken-core' { Invoke-BrokenCore }
  'upgrade-previous-stable' { Invoke-UpgradePreviousStable }
}

if (-not $passed) { exit 1 }
