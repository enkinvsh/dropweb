import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/clash/core_readiness.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/core.dart';

class ClashService extends ClashHandlerInterface {
  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _readiness = CoreReadinessMachine(
      bind: _bindGeneration,
      spawn: _spawnAttempt,
      initialize: _initializeAttempt,
      teardown: _teardownAttempt,
      connectBackTimeout: const Duration(seconds: 18),
      retryBackoffs: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ],
      onConnectBackTimeout: (attempt) {
        commonPrint.log(
          '[boot] connect-back timeout gen=${attempt.generation} '
          'attempt=${attempt.attempt}',
        );
      },
      onPhaseChanged: (phase, attempt) {
        if (phase == CoreBootPhase.ready && attempt != null) {
          commonPrint.log(
            '[boot] core-ready gen=${attempt.generation} '
            'attempt=${attempt.attempt}',
          );
        }
      },
      onFailed: (error) => commonPrint.log('[boot] core-failed $error'),
    );
    unawaited(_initServer());
  }
  static ClashService? _instance;

  late final CoreReadinessMachine _readiness;
  Future<bool> Function()? _strictInitialize;
  bool _started = false;

  void configureStrictInitializer(Future<bool> Function() initializer) {
    _strictInitialize = initializer;
  }

  void start() {
    if (_started) return;
    _started = true;
    unawaited(
      reStart().catchError((Object _) => null),
    );
  }

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  Process? process;
  CoreBootAttempt? _processAttempt;
  CoreBootAttempt? _helperAttempt;
  CoreBootAttempt? _socketAttempt;
  CoreBootAttempt? _deathNotifiedAttempt;
  Socket? _activeSocket;
  bool _forceDirectSpawnForGeneration = false;

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
          "[boot] bridge-bind [core-bridge] server bound at ${server.address.address}:${server.port}");
      serverCompleter.complete(server);
      await for (final socket in server) {
        final attempt = _readiness.currentAttempt;
        if (attempt == null || !_readiness.canAcceptConnection(attempt)) {
          commonPrint.log(
            '[core-bridge] stale/unexpected connect-back ignored '
            'gen=${attempt?.generation ?? 0}',
          );
          await socket.close();
          continue;
        }
        await _destroySocket();
        _socketAttempt = attempt;
        socketCompleter.complete(socket);
        _activeSocket = socket;
        _listenToSocket(socket, attempt);
        if (!_readiness.acceptConnection(attempt)) {
          await _destroySocket();
          continue;
        }
        commonPrint.log(
          '[boot] connect-back ok [core-bridge] core connected back '
          'gen=${attempt.generation} attempt=${attempt.attempt}',
        );
      }
    }, (error, stack) {
      commonPrint.log(error.toString());
      if (!serverCompleter.isCompleted) {
        serverCompleter.completeError(error, stack);
      }
    });
  }

  void _listenToSocket(Socket socket, CoreBootAttempt attempt) {
    unawaited(socket.done.then(
      (_) => _onCoreDeath(
        attempt,
        'bridge socket closed',
        sourceSocket: socket,
      ),
      onError: (Object _) => _onCoreDeath(
        attempt,
        'bridge socket error',
        sourceSocket: socket,
      ),
    ));
    socket
        .transform(uint8ListToListIntConverter)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((data) {
      handleResult(
        ActionResult.fromJson(
          json.decode(data.trim()),
        ),
      );
    });
  }

  @override
  Future<void> reStart() => _readiness.restart();

  Future<void> _bindGeneration(int generation) async {
    final serverSocket = await serverCompleter.future;
    commonPrint.log(
      '[core-bridge] generation=$generation bridge=${serverSocket.port}',
    );
  }

  Future<void> _spawnAttempt(CoreBootAttempt attempt) async {
    _expectedTeardown = false;
    _deathNotifiedAttempt = null;
    _socketAttempt = attempt;
    final serverSocket = await serverCompleter.future;
    final arg = Platform.isWindows
        ? "${serverSocket.port}"
        : serverSocket.address.address;
    final helperReady = Platform.isWindows &&
        !_forceDirectSpawnForGeneration &&
        await _helperReadyWithGrace();
    commonPrint.log(
      '[core-bridge] spawn gen=${attempt.generation} '
      'attempt=${attempt.attempt} arg=$arg helperReady=$helperReady',
    );
    if (helperReady) {
      final isSuccess = await request.startCoreByHelper(arg);
      commonPrint.log("[core-bridge] startCoreByHelper -> $isSuccess");
      if (isSuccess) {
        commonPrint.log(
          '[boot] helper-start-accepted gen=${attempt.generation} '
          'attempt=${attempt.attempt}',
        );
        _coreStartedByHelper = true;
        _helperAttempt = attempt;
        return;
      }
      throw CoreBootException(
        phase: CoreBootPhase.spawning,
        generation: attempt.generation,
        attempt: attempt.attempt,
        cause: StateError('verified helper rejected core spawn'),
      );
    }
    _coreStartedByHelper = false;
    _helperAttempt = null;

    final homeDirPath = await appPath.homeDirPath;
    final environment = Map<String, String>.from(Platform.environment);
    // Set SAFE_PATHS to prevent "path is not subpath of home directory" errors
    // This ensures the core can access provider files before SetHomeDir is called
    environment['SAFE_PATHS'] = homeDirPath;

    commonPrint.log(
      '[boot] direct-spawn gen=${attempt.generation} '
      'attempt=${attempt.attempt}',
    );
    process = await Process.start(
      appPath.corePath,
      [
        arg,
      ],
      environment: environment,
    );
    _processAttempt = attempt;
    commonPrint.log("[core-bridge] core process spawned pid=${process?.pid}");
    // Watch THIS specific process's exit. Capture the instance so a late exit
    // from a previously-killed core (rapid restart) can't be misread as the
    // LIVE core dying — the identity guard inside the callback discards it.
    final spawnedProcess = process!;
    unawaited(spawnedProcess.exitCode.then((code) {
      _onCoreDeath(
        attempt,
        'process exit code=$code',
        sourceProcess: spawnedProcess,
      );
    }));
    process?.stdout.listen((_) {});
    process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
  }

  Future<void> _initializeAttempt(CoreBootAttempt attempt) async {
    final strictInitialize = _strictInitialize;
    if (strictInitialize == null) {
      throw StateError('strict core initializer is not configured');
    }
    final initialized = await strictInitialize();
    if (!initialized) {
      throw CoreBootException(
        phase: CoreBootPhase.initializing,
        generation: attempt.generation,
        attempt: attempt.attempt,
        cause: StateError('strict init/health roundtrip returned false'),
      );
    }
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
    commonPrint.log('[boot] helper-check');
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
    _activeSocket = null;
    _socketAttempt = null;
  }

  Future<void> _teardownAttempt(CoreBootAttempt attempt) async {
    _expectedTeardown = true;

    if (Platform.isWindows && identical(_helperAttempt, attempt)) {
      final result = await windows?.runOwnedHelperDestructiveOperation(
        operationName: 'helper-core-stop',
        operation: request.stopCoreByHelper,
      );
      if (result != null && !result.isAllowed) {
        _forceDirectSpawnForGeneration = true;
      } else if (result?.value != true) {
        throw StateError('owned helper child did not stop');
      }
      _helperAttempt = null;
      _coreStartedByHelper = false;
    }

    final directProcess = process;
    if (directProcess != null && identical(_processAttempt, attempt)) {
      directProcess.kill();
      try {
        await directProcess.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        throw StateError(
          'direct core did not exit after kill '
          'gen=${attempt.generation} attempt=${attempt.attempt}',
        );
      }
      if (identical(process, directProcess)) {
        process = null;
        _processAttempt = null;
      }
    }

    if (identical(_socketAttempt, attempt)) {
      await _destroySocket();
      if (!socketCompleter.isCompleted) {
        socketCompleter = Completer();
      }
    }
  }

  @override
  Future<bool> shutdown() async {
    final attempt = _readiness.currentAttempt;
    if (attempt != null) {
      await _teardownAttempt(attempt);
    } else {
      _expectedTeardown = true;
      await _destroySocket();
    }
    return true;
  }

  /// Invoked when the desktop core process exits or the bridge socket drops.
  /// During binding/spawn/connect/init, death belongs to the generation machine
  /// and consumes only that attempt's retry budget. Only a death after `ready`
  /// reaches ConnectService's existing one-restart-per-five-minutes self-heal.
  /// This split prevents the watchdog and observed-death recovery from launching
  /// competing respawn loops; stale generation callbacks fail both identity
  /// checks and cannot touch the current core.
  void _onCoreDeath(
    CoreBootAttempt attempt,
    String reason, {
    Process? sourceProcess,
    Socket? sourceSocket,
  }) {
    if (sourceProcess != null &&
        (!identical(sourceProcess, process) ||
            !identical(_processAttempt, attempt))) {
      return;
    }
    if (sourceSocket != null &&
        (!identical(sourceSocket, _activeSocket) ||
            !identical(_socketAttempt, attempt))) {
      return;
    }
    if (attempt.generation != _readiness.generation ||
        !identical(attempt, _readiness.currentAttempt)) {
      commonPrint.log(
        '[core-bridge] stale death ignored gen=${attempt.generation} '
        'attempt=${attempt.attempt}: $reason',
      );
      return;
    }
    if (_expectedTeardown) {
      commonPrint
          .log('[core-bridge] core teardown ($reason) — expected, ignoring');
      return;
    }

    if (_readiness.phase != CoreBootPhase.ready) {
      commonPrint.log(
        '[core-bridge] boot attempt died gen=${attempt.generation} '
        'attempt=${attempt.attempt}: $reason',
      );
      _readiness.reportAttemptFailure(attempt, StateError(reason));
      return;
    }

    if (identical(_deathNotifiedAttempt, attempt)) return;
    _deathNotifiedAttempt = attempt;

    commonPrint.log('[core-bridge] core died unexpectedly: $reason');
    // Replace the completed-but-dead completer so no invoke writes into the
    // corpse (a completed completer with a closed socket would hang every
    // request to its timeout). A fresh completer makes later sends await a
    // real reconnect from the restarted core.
    if (socketCompleter.isCompleted) {
      socketCompleter = Completer();
    }
    _activeSocket = null;
    // Notify the Dart side ONCE; the controller owns the bounded self-heal.
    onUnexpectedCoreDeath?.call(reason);
  }

  @override
  Future<void> ensureCoreReady({
    Duration timeout = const Duration(seconds: 90),
  }) =>
      _readiness.ensureReady(timeout: timeout);

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
    } catch (error) {
      commonPrint.log(
        '[bridge] desktop server preload failed — '
        'booting UI without a live core bridge: $error',
      );
      return false;
    }
  }
}

final clashService = system.isDesktop ? ClashService() : null;
