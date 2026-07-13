import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/core.dart';
import 'package:dropweb/state.dart';

class ClashService extends ClashHandlerInterface {

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    unawaited(_initServer());
    reStart();
  }
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  /// In-flight reStart operation. Concurrent callers AWAIT it instead of
  /// no-op'ing: the realign self-heal in AppController._requestAdmin assumes
  /// a completed restartCore() actually restarted the core — the old
  /// `isStarting` bool guard silently dropped the second call (boot race with
  /// the constructor's unawaited reStart()), burning realign attempts with
  /// zero effect.
  Future<void>? _restartInFlight;

  Process? process;

  /// Whether the CURRENT core process was spawned via the privileged Windows
  /// helper service (SYSTEM) rather than directly by this (non-elevated)
  /// process. TUN on Windows only works on a helper-spawned core, and
  /// checkIsAdmin() only says "helper service is up" — it says NOTHING about
  /// how the live core was started. AppController._requestAdmin reads this to
  /// self-heal (restart the core through the helper) instead of poisoning the
  /// session with tun.enable=true on a core that can't create the adapter.
  bool _coreStartedByHelper = false;

  bool get coreStartedByHelper => _coreStartedByHelper;

  /// True while WE are tearing the core down (shutdown/reStart). Distinguishes
  /// an intentional teardown from a genuine crash inside [_onCoreDeath]: the
  /// same signals (process exit, bridge socket close) fire in both cases, but
  /// only an UNEXPECTED death should trigger self-heal / an error to the user.
  bool _expectedTeardown = false;

  /// Injected by AppController to self-heal on unexpected core death. Nullable
  /// and set from the controller so ClashService need not import the controller
  /// — that would be an upward layering violation (service → controller).
  void Function(String reason)? onUnexpectedCoreDeath;

  Future<void> _initServer() async {
    runZonedGuarded(() async {
      final address = !Platform.isWindows
          ? InternetAddress(
              unixSocketPath,
              type: InternetAddressType.unix,
            )
          : InternetAddress(
              localhost,
              type: InternetAddressType.IPv4,
            );
      await _deleteSocketFile();
      final server = await ServerSocket.bind(
        address,
        0,
        shared: true,
      );
      commonPrint.log(
          "[core-bridge] server bound at ${server.address.address}:${server.port}");
      serverCompleter.complete(server);
      await for (final socket in server) {
        commonPrint.log("[core-bridge] core connected back to bridge");
        await _destroySocket();
        socketCompleter.complete(socket);
        // The bridge socket dropping is the ONLY death signal we have for a
        // helper-spawned core (no local Process handle — the SYSTEM helper owns
        // the child). It also covers a direct-spawned core crash. `done`
        // completes on both graceful close and error; `_onCoreDeath` filters
        // out our own teardown.
        unawaited(socket.done.then(
          (_) => _onCoreDeath('bridge socket closed'),
          onError: (Object _) => _onCoreDeath('bridge socket error'),
        ));
        socket
            .transform(uint8ListToListIntConverter)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (data) {
            handleResult(
              ActionResult.fromJson(
                json.decode(data.trim()),
              ),
            );
          },
        );
      }
    }, (error, stack) {
      commonPrint.log(error.toString());
      if (error is SocketException) {
        globalState.showNotifier(error.toString());
        // globalState.appController.restartCore();
      }
    });
  }

  @override
  Future<void> reStart() {
    final inFlight = _restartInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final op = _reStart().whenComplete(() {
      _restartInFlight = null;
    });
    _restartInFlight = op;
    return op;
  }

  Future<void> _reStart() async {
    // Tear down the PREVIOUS core unconditionally, BEFORE resetting the
    // socket completer (so _destroySocket can actually close a connected
    // socket instead of leaking it). The old `if (process != null)` guard
    // only covered direct-spawned cores: a helper-spawned core (process ==
    // null, the SYSTEM helper owns the child) was silently orphaned, and a
    // subsequent direct spawn then produced two cores fighting over the
    // proxy/controller ports. shutdown() is null-safe on both paths and
    // stopCoreByHelper() fails fast (connection refused) when no helper is
    // listening.
    await shutdown();
    socketCompleter = Completer();
    final serverSocket = await serverCompleter.future;
    final arg = Platform.isWindows
        ? "${serverSocket.port}"
        : serverSocket.address.address;
    final helperReady = Platform.isWindows && await _helperReadyWithGrace();
    commonPrint.log("[core-bridge] reStart: arg=$arg helperReady=$helperReady");
    if (helperReady) {
      final isSuccess = await request.startCoreByHelper(arg);
      commonPrint.log("[core-bridge] startCoreByHelper -> $isSuccess");
      if (isSuccess) {
        _coreStartedByHelper = true;
        // Spawn complete: any teardown from here on is unexpected. The
        // helper-spawned core has no Process handle here, so its death is
        // observed solely via the bridge socket `done` (see _initServer).
        _expectedTeardown = false;
        return;
      }
    }
    _coreStartedByHelper = false;

    final homeDirPath = await appPath.homeDirPath;
    final environment = Map<String, String>.from(Platform.environment);
    // Set SAFE_PATHS to prevent "path is not subpath of home directory" errors
    // This ensures the core can access provider files before SetHomeDir is called
    environment['SAFE_PATHS'] = homeDirPath;

    process = await Process.start(
      appPath.corePath,
      [
        arg,
      ],
      environment: environment,
    );
    commonPrint.log("[core-bridge] core process spawned pid=${process?.pid}");
    // Watch THIS specific process's exit. Capture the instance so a late exit
    // from a previously-killed core (rapid restart) can't be misread as the
    // LIVE core dying — the identity guard inside the callback discards it.
    final spawnedProcess = process!;
    unawaited(spawnedProcess.exitCode.then((code) {
      if (!identical(spawnedProcess, process)) {
        return;
      }
      _onCoreDeath('process exit code=$code');
    }));
    process?.stdout.listen((_) {});
    process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
    // Spawn complete: any teardown from here on is unexpected.
    _expectedTeardown = false;
  }

  /// Decide whether to route the core spawn through the privileged helper.
  /// Instant answers when possible: RUNNING+ping → yes; service not installed
  /// → no (first-ever launch must not pay any delay). When the service exists
  /// but isn't answering yet — the boot/logon race (SCM auto-start vs app
  /// auto-launch) or a just-issued `sc start` — give it a short bounded grace
  /// instead of instantly condemning the whole session to an unprivileged
  /// core. waitHelperReady aborts immediately on a token mismatch, so a stale
  /// helper left over from a previous app version costs one ping, not 5s.
  Future<bool> _helperReadyWithGrace() async {
    final status = await windows?.checkService();
    if (status == WindowsHelperServiceStatus.running) {
      return true;
    }
    if (status == null || status == WindowsHelperServiceStatus.none) {
      return false;
    }
    return await windows?.waitHelperReady(const Duration(seconds: 5)) ?? false;
  }

  @override
  Future<bool> destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  Future<void> sendMessage(String message) async {
    final socket = await socketCompleter.future;
    socket.writeln(message);
  }

  Future<void> _deleteSocketFile() async {
    if (!Platform.isWindows) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  Future<bool> shutdown() async {
    // Mark this teardown as ours: the process-exit and bridge-socket-close
    // signals about to fire must NOT be treated as a crash by _onCoreDeath.
    // Reset to false only once a fresh core has been (re)spawned in _reStart.
    _expectedTeardown = true;
    if (Platform.isWindows) {
      await request.stopCoreByHelper();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    return true;
  }

  /// Invoked when the desktop core process exits or the bridge socket drops.
  /// Filters our OWN teardown (shutdown/reStart) from a genuine crash: only an
  /// unexpected death resets the socket and notifies the controller so the UI
  /// can self-heal instead of lying "connected" while every invoke times out.
  void _onCoreDeath(String reason) {
    if (_expectedTeardown || _restartInFlight != null) {
      commonPrint
          .log('[core-bridge] core teardown ($reason) — expected, ignoring');
      return;
    }
    commonPrint.log('[core-bridge] core died unexpectedly: $reason');
    // Replace the completed-but-dead completer so no invoke writes into the
    // corpse (a completed completer with a closed socket would hang every
    // request to its timeout). A fresh completer makes later sends await a
    // real reconnect from the restarted core.
    if (socketCompleter.isCompleted) {
      socketCompleter = Completer();
    }
    // Notify the Dart side ONCE; the controller owns the bounded self-heal.
    onUnexpectedCoreDeath?.call(reason);
  }

  @override
  Future<bool> preload() async {
    try {
      await serverCompleter.future.timeout(const Duration(seconds: 15));
      return true;
    } on TimeoutException {
      commonPrint.log(
        '[bridge] desktop server preload timed out after 15s — '
        'booting UI without a live core bridge',
      );
      return false;
    }
  }
}

final clashService = system.isDesktop ? ClashService() : null;
