import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/windows_conflict.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:path/path.dart';
import 'package:win32/win32.dart';

class Windows {
  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
    try {
      _uxtheme = DynamicLibrary.open('uxtheme.dll');
    } catch (e) {
      // Ignore if uxtheme.dll is not available
    }
  }
  static Windows? _instance;
  late DynamicLibrary _shell32;
  late DynamicLibrary _uxtheme;

  /// Kernel-level kill for last-resort exit watchdogs. Bypasses CRT teardown
  /// and DLL PROCESS_DETACH entirely — exit(0) with live engine/plugin
  /// threads is exactly the "Unknown Hard Error" crash on Windows, and
  /// re-posting WM_QUIT is a no-op when the message loop is wedged.
  Never forceExit() {
    TerminateProcess(GetCurrentProcess(), 0);
    // TerminateProcess never returns for the calling process, but the
    // analyzer can't know that.
    exit(0);
  }

  bool isDarkMode() {
    try {
      final keyPath =
          r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
              .toNativeUtf16();
      final valueName = 'AppsUseLightTheme'.toNativeUtf16();

      final phkResult = calloc<HKEY>();
      var result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        keyPath,
        0,
        KEY_READ,
        phkResult,
      );

      calloc.free(keyPath);

      if (result != ERROR_SUCCESS) {
        calloc.free(valueName);
        calloc.free(phkResult);
        return false;
      }

      final hKey = phkResult.value;
      calloc.free(phkResult);

      final data = calloc<DWORD>();
      final dataSize = calloc<DWORD>();
      dataSize.value = sizeOf<DWORD>();

      result = RegQueryValueEx(
        hKey,
        valueName,
        nullptr,
        nullptr,
        data.cast(),
        dataSize,
      );

      calloc.free(valueName);
      RegCloseKey(hKey);

      if (result != ERROR_SUCCESS) {
        calloc.free(data);
        calloc.free(dataSize);
        return false;
      }

      final isLightMode = data.value != 0;
      calloc.free(data);
      calloc.free(dataSize);

      return !isLightMode;
    } catch (e) {
      return false;
    }
  }

  void enableDarkModeForApp() {
    try {
      final isDark = isDarkMode();
      if (!isDark) return;

      try {
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        final moduleName = 'uxtheme.dll'.toNativeUtf16();

        final getProcAddressFunc = kernel32.lookupFunction<
            IntPtr Function(IntPtr hModule, Pointer<Utf8> lpProcName),
            int Function(
                int hModule, Pointer<Utf8> lpProcName)>('GetProcAddress');

        final getModuleHandleFunc = kernel32.lookupFunction<
            IntPtr Function(Pointer<Utf16> lpModuleName),
            int Function(Pointer<Utf16> lpModuleName)>('GetModuleHandleW');

        final uxthemeHandle = getModuleHandleFunc(moduleName);
        calloc.free(moduleName);

        if (uxthemeHandle != 0) {
          final ordinal135 = Pointer<Utf8>.fromAddress(135);
          final setPreferredAppModePtr =
              getProcAddressFunc(uxthemeHandle, ordinal135);

          if (setPreferredAppModePtr != 0) {
            final setPreferredAppMode =
                Pointer<NativeFunction<Int32 Function(Int32)>>.fromAddress(
                        setPreferredAppModePtr)
                    .asFunction<int Function(int)>();
            setPreferredAppMode(1);
          } else {
            final ordinal133 = Pointer<Utf8>.fromAddress(133);
            final allowDarkModePtr =
                getProcAddressFunc(uxthemeHandle, ordinal133);

            if (allowDarkModePtr != 0) {
              final allowDarkModeForApp =
                  Pointer<NativeFunction<Int32 Function(Int32)>>.fromAddress(
                          allowDarkModePtr)
                      .asFunction<int Function(int)>();
              allowDarkModeForApp(1); // TRUE
            }
          }

          // Ordinal 136 = FlushMenuThemes
          final ordinal136 = Pointer<Utf8>.fromAddress(136);
          final flushMenuThemesPtr =
              getProcAddressFunc(uxthemeHandle, ordinal136);

          if (flushMenuThemesPtr != 0) {
            final flushMenuThemes =
                Pointer<NativeFunction<Void Function()>>.fromAddress(
                        flushMenuThemesPtr)
                    .asFunction<void Function()>();
            flushMenuThemes();
          }
        }
      } catch (e) {}
    } catch (e) {}
  }

  void applyDarkModeToMenu(int hwnd) {
    if (hwnd == 0) return;

    try {
      final isDark = isDarkMode();

      final themeName = isDark ? 'DarkMode_Explorer'.toNativeUtf16() : nullptr;

      try {
        final setWindowTheme = _uxtheme.lookupFunction<
            Int32 Function(IntPtr hwnd, Pointer<Utf16> pszSubAppName,
                Pointer<Utf16> pszSubIdList),
            int Function(int hwnd, Pointer<Utf16> pszSubAppName,
                Pointer<Utf16> pszSubIdList)>('SetWindowTheme');

        setWindowTheme(hwnd, themeName, nullptr);
      } catch (e) {}

      if (themeName != nullptr) {
        calloc.free(themeName);
      }
    } catch (e) {}
  }

  bool runas(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final shellExecute = _shell32.lookupFunction<
        Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd),
        int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd)>('ShellExecuteW');

    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      1,
    );

    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);

    commonPrint.log("windows runas: $command $arguments resultCode:$result");

    if (result < 42) {
      return false;
    }
    return true;
  }

  /// Executable path of a running PID, via CIM/WMI. Null when the process is
  /// gone or the path is inaccessible. Kept isolated so the parsing is trivial
  /// (the value is a single line) and the ownership decision stays pure.
  Future<String?> _pidExecutablePath(int pid) async {
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-CimInstance Win32_Process -Filter "ProcessId=$pid").ExecutablePath',
      ]);
      final out = res.stdout.toString().trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Detect and resolve a conflict on our fixed helper port (47896).
  ///
  /// Fast path: if the port answers /ping with OUR core hash it is our own
  /// healthy helper — leave it ([HelperPortConflictResult.healthy]).
  ///
  /// Otherwise we identify the PID LISTENING on the port and gather POSITIVE
  /// ownership evidence: (1) the holder's own executable is our installed
  /// `{app}\DropwebHelperService.exe`, or (2) our DropwebHelperService's
  /// binPath is that exe AND the SCM reports it as the holder PID. Only on
  /// proof do we kill it ([freedOurs]). A FOREIGN holder (a separately
  /// installed FlClashX, or anything unrelated) is LEFT ALONE — we log an
  /// actionable conflict and return [foreignHeld] so callers do NOT assume the
  /// port is free. We never kill by process name and never kill an
  /// unidentified PID.
  Future<HelperPortConflictResult> resolveHelperPortConflict() async {
    if (await request.pingHelper()) {
      commonPrint.log(
          "[helper-conflict] port $helperPort held by our healthy helper — keeping");
      return HelperPortConflictResult.healthy;
    }

    final netstat = await Process.run('netstat', ['-ano']);
    final holders =
        WindowsConflict.listeningPids(netstat.stdout.toString(), helperPort);
    if (holders.isEmpty) {
      commonPrint.log(
          "[helper-conflict] port $helperPort is free — nothing holding it");
      return HelperPortConflictResult.free;
    }

    final ourHelperPath = appPath.helperPath;

    // Service evidence (gathered once): does OUR DropwebHelperService point at
    // our helper binary, and which PID does the SCM say it is running as?
    final qc = await Process.run('sc', ['qc', appHelperService]);
    final serviceBinPath =
        WindowsConflict.serviceBinPath(qc.stdout.toString());
    int? servicePid;
    final serviceOwnership = WindowsConflict.helperServiceOwnership(
      scQcOutput: qc.stdout.toString(),
      ourHelperPath: ourHelperPath,
    );
    if (serviceOwnership == HelperServiceOwnership.owned) {
      final qex = await Process.run('sc', ['queryex', appHelperService]);
      servicePid =
          WindowsConflict.serviceQueryexPid(qex.stdout.toString());
    }

    for (final pid in holders) {
      final exePath = await _pidExecutablePath(pid);
      final isOurs = WindowsConflict.holderIsOurStaleHelper(
        pidExePath: exePath,
        ourHelperPath: ourHelperPath,
        serviceBinPathValue: serviceBinPath,
        servicePid: servicePid,
        holderPid: pid,
      );
      if (isOurs) {
        commonPrint.log(
            "[helper-conflict] port $helperPort held by a STALE copy of our "
            "helper (pid=$pid, exe=$exePath) — freeing it for our service");
        final kill =
            await Process.run('taskkill', ['/PID', pid.toString(), '/F']);
        if (kill.exitCode != 0) {
          // Could not kill our own stale helper (already gone, or elevation
          // denied). The port may still be occupied — report it as still held
          // so the caller does not assume it was freed.
          commonPrint.log(
              "[helper-conflict] taskkill /PID $pid failed (exit=${kill.exitCode}): "
              "${kill.stderr.toString().trim()} — port $helperPort may still be held");
          return HelperPortConflictResult.foreignHeld;
        }
        return HelperPortConflictResult.freedOurs;
      }
      commonPrint.log(
          "[helper-conflict] port $helperPort held by a FOREIGN process "
          "(pid=$pid, exe=${exePath ?? 'unknown'}) — leaving it untouched. Our "
          "helper cannot bind the port, so this launch runs WITHOUT the "
          "privileged helper: TUN mode is unavailable (system-proxy / "
          "proxy-only fallback), not a guaranteed direct core spawn");
    }

    return HelperPortConflictResult.foreignHeld;
  }

  /// Poll the helper until it verifiably answers /ping with OUR core hash.
  /// Replaces the old fixed 300/500ms sleeps after `sc start`, which raced
  /// SCM service startup + the helper's HTTP bind and made the caller fall
  /// back to an unprivileged core spawn on first launch. A token [mismatch]
  /// aborts immediately — waiting cannot turn a stale/foreign helper into
  /// ours, and burning the full timeout there would stall every core restart.
  Future<bool> waitHelperReady(
    Duration timeout, {
    bool tolerateMismatch = false,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final result = await request.pingHelperDetailed();
      switch (result) {
        case HelperPingResult.ok:
          return true;
        case HelperPingResult.mismatch:
          if (!tolerateMismatch) {
            commonPrint.log(
                "[helper] ping answered with a foreign core hash — not our helper, not waiting");
            return false;
          }
          // Post-install poll: we JUST issued sc create/start for OUR binary —
          // a foreign hash here is the old helper mid-replacement still
          // answering. Keep polling until the deadline for the new one.
          if (DateTime.now().isAfter(deadline)) {
            commonPrint.log(
                "[helper] still answering with a foreign core hash after ${timeout.inMilliseconds}ms");
            return false;
          }
          await Future.delayed(const Duration(milliseconds: 300));
        case HelperPingResult.unreachable:
          if (DateTime.now().isAfter(deadline)) {
            commonPrint.log(
                "[helper] not ready within ${timeout.inMilliseconds}ms");
            return false;
          }
          await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<WindowsHelperServiceStatus> checkService() async {
    // final qcResult = await Process.run('sc', ['qc', appHelperService]);
    // final qcOutput = qcResult.stdout.toString();
    // if (qcResult.exitCode != 0 || !qcOutput.contains(appPath.helperPath)) {
    //   return WindowsHelperServiceStatus.none;
    // }
    final result = await Process.run('sc', ['query', appHelperService]);
    if (result.exitCode != 0) {
      return WindowsHelperServiceStatus.none;
    }
    final output = result.stdout.toString();
    if (output.contains("RUNNING") && await request.pingHelper()) {
      return WindowsHelperServiceStatus.running;
    }
    return WindowsHelperServiceStatus.presence;
  }

  Future<HelperServiceOwnership> checkHelperServiceOwnership() async {
    ProcessResult? regResult;
    try {
      regResult = await Process.run('reg', [
        'query',
        r'HKLM\SYSTEM\CurrentControlSet\Services\DropwebHelperService',
        '/v',
        'ImagePath',
      ]);
    } catch (_) {
      regResult = null;
    }

    final regOutput =
        regResult?.exitCode == 0 ? regResult!.stdout.toString() : '';
    final regImagePath =
        WindowsConflict.serviceImagePathFromRegQuery(regOutput);
    if (regImagePath != null) {
      return WindowsConflict.helperServiceOwnership(
        regQueryOutput: regOutput,
        scQcOutput: '',
        ourHelperPath: appPath.helperPath,
      );
    }

    ProcessResult scResult;
    try {
      scResult = await Process.run('sc', ['qc', appHelperService]);
    } catch (_) {
      return HelperServiceOwnership.unknown;
    }
    if (scResult.exitCode != 0) return HelperServiceOwnership.unknown;

    final scOutput = scResult.stdout.toString();
    final ownership = WindowsConflict.helperServiceOwnership(
      regQueryOutput: regOutput,
      scQcOutput: scOutput,
      ourHelperPath: appPath.helperPath,
    );
    if (ownership == HelperServiceOwnership.unknown &&
        regResult?.exitCode == 0) {
      final rawOutput = '$regOutput\n$scOutput';
      final rawHead =
          rawOutput.length <= 160 ? rawOutput : rawOutput.substring(0, 160);
      final head = rawHead.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
      commonPrint.log('[helper] ownership parse failed head=$head');
    }
    return ownership;
  }

  Future<HelperDestructiveOperationResult<T>>
      runOwnedHelperDestructiveOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
  }) async {
    final ownership = await checkHelperServiceOwnership();
    final result = await WindowsConflict.runOwnedHelperDestructiveOperation(
      ownership: ownership,
      operation: operation,
    );
    final conflict = result.conflict;
    if (conflict != null) {
      commonPrint.log(
        '[boot] helper-check conflict operation=$operationName: $conflict',
      );
    }
    return result;
  }

  /// Install the helper service (requires UAC elevation).
  /// This should only be called when the service is not installed.
  /// After installation, sets security descriptor to allow non-admin users
  /// to start/stop the service without UAC.
  Future<bool> installService() async {
    final status = await checkService();

    if (status == WindowsHelperServiceStatus.running) {
      return true;
    }

    final conflict = await resolveHelperPortConflict();
    if (conflict == HelperPortConflictResult.foreignHeld) {
      // A foreign process holds 47896 and we will NOT kill it. Our helper
      // cannot bind the port, so creating/starting the service is pointless —
      // bail without pretending the helper is available. The caller
      // (authorizeCore) then returns an error: this launch has no privileged
      // helper, so TUN mode is unavailable and the app falls back to
      // system-proxy / proxy-only operation. It is NOT a guaranteed direct
      // core spawn.
      commonPrint.log(
          "[helper] port $helperPort held by a foreign process — skipping "
          "helper service install; launch continues without the privileged "
          "helper (TUN unavailable, proxy-only fallback)");
      return false;
    }

    final command = [
      "/c",
      if (status == WindowsHelperServiceStatus.presence) ...[
        "sc",
        "stop",
        appHelperService,
        "&",
        "sc",
        "delete",
        appHelperService,
        "&",
        // `sc delete` is async: SCM only *marks* the service for deletion and
        // an immediate `sc create` races it (error 1072, "marked for
        // deletion"), which would skip `&& sc start` and doom the poll below.
        // Give SCM a moment to settle. `ping -n 2 127.0.0.1` ≈ 1s sleep that,
        // unlike `timeout /t`, works without interactive console stdin.
        "ping",
        "-n",
        "2",
        "127.0.0.1",
        ">",
        "nul",
        "&",
      ],
      "sc",
      "create",
      appHelperService,
      'binPath= "${appPath.helperPath}"',
      'start= auto',
      "&&",
      "sc",
      "start",
      appHelperService,
    ].join(" ");

    Future<bool> executeInstall() async {
      final res = runas("cmd.exe", command);
      if (!res) {
        // UAC denied or ShellExecute failed — no point polling.
        return false;
      }
      // runas() returns as soon as the elevated cmd is LAUNCHED — sc create,
      // sc start, the SCM state transition and the helper's HTTP bind all
      // happen after it. The old fixed 300ms sleep lost that race on nearly
      // every first launch, so the follow-up restartCore() spawned an
      // unprivileged core and TUN silently died until an app restart. Poll for
      // verified readiness instead; 15s bounds slow disks/AV scanning.
      return waitHelperReady(const Duration(seconds: 15), tolerateMismatch: true);
    }

    if (status != WindowsHelperServiceStatus.presence) {
      return executeInstall();
    }
    final guarded = await runOwnedHelperDestructiveOperation(
      operationName: 'service-reinstall',
      operation: executeInstall,
    );
    return guarded.value ?? false;
  }

  /// Try to start an existing service without UAC.
  /// Returns true if the service was started successfully or is already running.
  /// Returns false if the service is not installed or failed to start.
  Future<bool> tryStartExistingService() async {
    final status = await checkService();

    if (status == WindowsHelperServiceStatus.running) {
      return true;
    }

    if (status == WindowsHelperServiceStatus.none) {
      return false;
    }

    // Service exists but not running - try to start it without elevation
    final result = await Process.run('sc', ['start', appHelperService]);

    if (result.exitCode == 0) {
      // `sc start` returns before the service reports RUNNING and before the
      // helper binds its HTTP port — poll for verified readiness instead of
      // the old fixed 500ms sleep.
      return waitHelperReady(const Duration(seconds: 8));
    }

    return false;
  }

  /// Register the service - will request UAC only if service is not installed.
  /// If the service is already installed, it will try to start it without UAC.
  Future<bool> registerService() async {
    // First, try to start existing service without UAC
    if (await tryStartExistingService()) {
      return true;
    }

    // Service not installed or couldn't start - need to install with UAC
    return installService();
  }

  Future<bool> startService() async {
    final status = await checkService();

    if (status == WindowsHelperServiceStatus.running) {
      return true;
    }

    if (status == WindowsHelperServiceStatus.none) {
      return false;
    }

    final result = await Process.run('sc', ['start', appHelperService]);

    if (result.exitCode == 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    return false;
  }

  Future<bool> stopService() async {
    final status = await checkService();

    if (status == WindowsHelperServiceStatus.none) {
      return true;
    }

    final guarded = await runOwnedHelperDestructiveOperation(
      operationName: 'service-stop',
      operation: () async {
        final result = await Process.run('sc', ['stop', appHelperService]);
        if (result.exitCode != 0) return false;
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
    );
    return guarded.value ?? false;
  }

  Future<bool> registerTask(String appName) async {
    final taskXml = '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger/>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"${Platform.resolvedExecutable}"</Command>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, "task.xml");
    await File(taskPath).create(recursive: true);
    await File(taskPath)
        .writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
    final commandLine = [
      '/Create',
      '/TN',
      appName,
      '/XML',
      "%s",
      '/F',
    ].join(" ");
    return runas(
      'schtasks',
      commandLine.replaceFirst("%s", taskPath),
    );
  }
}

final windows = Platform.isWindows ? Windows() : null;
