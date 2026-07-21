import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum CoreBootPhase {
  idle,
  binding,
  spawning,
  waitingForConnect,
  initializing,
  ready,
  failed,
}

final class CoreBootAttempt {
  const CoreBootAttempt({
    required this.generation,
    required this.attempt,
  });

  final int generation;
  final int attempt;
}

final class CoreBridgeExpectation {
  const CoreBridgeExpectation({
    required this.runToken,
    this.corePid,
    this.coreCreationTime100ns,
  });

  final String runToken;
  final int? corePid;
  final int? coreCreationTime100ns;
}

final class CoreBridgeHello {
  const CoreBridgeHello({
    required this.runToken,
    required this.corePid,
    required this.coreCreationTime100ns,
  });

  final String runToken;
  final int corePid;
  final int coreCreationTime100ns;
}

final class CoreBridgeHandshakeException implements Exception {
  const CoreBridgeHandshakeException(this.message);

  final String message;

  @override
  String toString() => 'core bridge handshake failed: $message';
}

CoreBridgeHello admitCoreBridgeHello({
  required String line,
  required CoreBridgeExpectation expectation,
  required CoreBootAttempt attempt,
  required CoreBootAttempt? currentAttempt,
}) {
  if (!identical(attempt, currentAttempt)) {
    throw const CoreBridgeHandshakeException('stale boot attempt');
  }
  final Object? value;
  try {
    value = jsonDecode(line);
  } on FormatException {
    throw const CoreBridgeHandshakeException('first frame is not JSON');
  }
  if (value is! Map<String, dynamic> ||
      value['type'] != 'dropweb-core-hello' ||
      value['protocol'] != 1) {
    throw const CoreBridgeHandshakeException('first frame is not a core hello');
  }
  final runToken = value['runToken'];
  final corePid = value['corePid'];
  final coreCreationTime100ns = value['coreCreationTime100ns'];
  if (runToken is! String ||
      corePid is! int ||
      corePid <= 0 ||
      coreCreationTime100ns is! int ||
      coreCreationTime100ns <= 0) {
    throw const CoreBridgeHandshakeException('hello identity is malformed');
  }
  if (runToken != expectation.runToken ||
      (expectation.corePid != null && corePid != expectation.corePid) ||
      (expectation.coreCreationTime100ns != null &&
          coreCreationTime100ns != expectation.coreCreationTime100ns)) {
    throw const CoreBridgeHandshakeException('hello identity mismatch');
  }
  return CoreBridgeHello(
    runToken: runToken,
    corePid: corePid,
    coreCreationTime100ns: coreCreationTime100ns,
  );
}

final class CoreBootException implements Exception {
  CoreBootException({
    required this.phase,
    required this.generation,
    required this.attempt,
    this.cause,
    String? executablePath,
    int? osErrorCode,
  })  : executablePath = executablePath ??
            (cause is ProcessException ? cause.executable : null),
        osErrorCode =
            osErrorCode ?? (cause is ProcessException ? cause.errorCode : null);

  final CoreBootPhase phase;
  final int generation;
  final int attempt;
  final Object? cause;
  final String? executablePath;
  final int? osErrorCode;

  String get diagnosticPhase => switch (phase) {
        CoreBootPhase.waitingForConnect => 'connect-back',
        CoreBootPhase.spawning => 'spawn',
        CoreBootPhase.initializing => 'core-init',
        _ => phase.name,
      };

  @override
  String toString() {
    final executable = executablePath == null ? '' : ' path=$executablePath';
    final code = osErrorCode == null ? '' : ' osErrorCode=$osErrorCode';
    final detail = cause == null ? '' : ' cause=$cause';
    return 'VPN core did not answer during $diagnosticPhase '
        '(generation=$generation attempt=$attempt)$executable$code$detail';
  }
}

typedef CoreBootBind = Future<void> Function(int generation);
typedef CoreBootSpawn = Future<void> Function(CoreBootAttempt attempt);
typedef CoreBootInitialize = Future<void> Function(CoreBootAttempt attempt);
typedef CoreBootTeardown = Future<void> Function(CoreBootAttempt attempt);
typedef CoreBootPhaseChanged = void Function(
  CoreBootPhase phase,
  CoreBootAttempt? attempt,
);

final class CoreReadinessMachine {
  CoreReadinessMachine({
    required CoreBootBind bind,
    required CoreBootSpawn spawn,
    required CoreBootInitialize initialize,
    required CoreBootTeardown teardown,
    required Duration connectBackTimeout,
    required List<Duration> retryBackoffs,
    CoreBootPhaseChanged? onPhaseChanged,
    void Function(CoreBootAttempt attempt)? onConnectBackTimeout,
    void Function(CoreBootException error)? onFailed,
  })  : _bind = bind,
        _spawn = spawn,
        _initialize = initialize,
        _teardown = teardown,
        _connectBackTimeout = connectBackTimeout,
        _retryBackoffs = List.unmodifiable(retryBackoffs),
        _onPhaseChanged = onPhaseChanged,
        _onConnectBackTimeout = onConnectBackTimeout,
        _onFailed = onFailed;

  final CoreBootBind _bind;
  final CoreBootSpawn _spawn;
  final CoreBootInitialize _initialize;
  final CoreBootTeardown _teardown;
  final Duration _connectBackTimeout;
  final List<Duration> _retryBackoffs;
  final CoreBootPhaseChanged? _onPhaseChanged;
  final void Function(CoreBootAttempt attempt)? _onConnectBackTimeout;
  final void Function(CoreBootException error)? _onFailed;

  CoreBootPhase _phase = CoreBootPhase.idle;
  int _generation = 0;
  CoreBootAttempt? _currentAttempt;
  Completer<void>? _connectionCompleter;
  Completer<void>? _attemptFailureCompleter;
  Completer<void>? _readinessCompleter;
  Future<void>? _runInFlight;
  bool _terminalFailureEmitted = false;

  CoreBootPhase get phase => _phase;
  int get generation => _generation;
  CoreBootAttempt? get currentAttempt => _currentAttempt;

  Future<void> restart() {
    final inFlight = _runInFlight;
    if (inFlight != null &&
        _phase != CoreBootPhase.ready &&
        _phase != CoreBootPhase.failed) {
      return _readinessCompleter!.future;
    }

    final previousAttempt = _currentAttempt;
    final generation = ++_generation;
    final readinessCompleter = Completer<void>();
    _readinessCompleter = readinessCompleter;
    _terminalFailureEmitted = false;

    final trackedRun = readinessCompleter.future;
    _runInFlight = trackedRun;
    final operation = _runGeneration(generation, previousAttempt);
    unawaited(readinessCompleter.future.catchError((Object _) {}));
    unawaited(
      operation.then<void>(
        (_) {
          if (!readinessCompleter.isCompleted) {
            readinessCompleter.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!readinessCompleter.isCompleted) {
            readinessCompleter.completeError(error, stackTrace);
          }
        },
      ).whenComplete(() {
        if (identical(_runInFlight, trackedRun)) {
          _runInFlight = null;
        }
      }),
    );
    return readinessCompleter.future;
  }

  Future<void> ensureReady({
    Duration timeout = const Duration(seconds: 90),
  }) {
    final readiness =
        _phase == CoreBootPhase.idle ? restart() : _readinessCompleter!.future;
    return readiness.timeout(
      timeout,
      onTimeout: () => throw CoreBootException(
        phase: _phase,
        generation: _generation,
        attempt: _currentAttempt?.attempt ?? 0,
        cause: TimeoutException('core readiness await timed out', timeout),
      ),
    );
  }

  bool canAcceptConnection(CoreBootAttempt attempt) =>
      _isCurrent(attempt) &&
      (_phase == CoreBootPhase.spawning ||
          _phase == CoreBootPhase.waitingForConnect);

  bool acceptConnection(CoreBootAttempt attempt) {
    if (!canAcceptConnection(attempt)) {
      return false;
    }
    final completer = _connectionCompleter;
    if (completer == null || completer.isCompleted) return false;
    completer.complete();
    return true;
  }

  bool reportAttemptFailure(CoreBootAttempt attempt, Object error) {
    if (!_isCurrent(attempt) ||
        (_phase != CoreBootPhase.spawning &&
            _phase != CoreBootPhase.waitingForConnect &&
            _phase != CoreBootPhase.initializing)) {
      return false;
    }
    final completer = _attemptFailureCompleter;
    if (completer == null || completer.isCompleted) return false;
    completer.completeError(error);
    return true;
  }

  Future<void> _runGeneration(
    int generation,
    CoreBootAttempt? previousAttempt,
  ) async {
    _setPhase(
      CoreBootPhase.binding,
      CoreBootAttempt(generation: generation, attempt: 0),
    );
    final bindingAttempt = CoreBootAttempt(
      generation: generation,
      attempt: 0,
    );
    try {
      if (previousAttempt != null) {
        await _teardown(previousAttempt);
      }
      await _bind(generation);
    } catch (error) {
      _fail(
        _asBootException(error, bindingAttempt, CoreBootPhase.binding),
        bindingAttempt,
      );
    }

    final totalAttempts = _retryBackoffs.length + 1;
    for (var attemptNumber = 1;
        attemptNumber <= totalAttempts;
        attemptNumber++) {
      final attempt = CoreBootAttempt(
        generation: generation,
        attempt: attemptNumber,
      );
      _currentAttempt = attempt;
      _connectionCompleter = Completer<void>();
      _attemptFailureCompleter = Completer<void>();
      unawaited(
        _attemptFailureCompleter!.future.catchError((Object _) {}),
      );

      CoreBootException? failure;
      try {
        _setPhase(CoreBootPhase.spawning, attempt);
        await _spawn(attempt);
        _throwIfStale(attempt);

        _setPhase(CoreBootPhase.waitingForConnect, attempt);
        try {
          await Future.any<void>([
            _connectionCompleter!.future,
            _attemptFailureCompleter!.future,
          ]).timeout(_connectBackTimeout);
        } on TimeoutException catch (error) {
          if (_isCurrent(attempt)) {
            _onConnectBackTimeout?.call(attempt);
          }
          throw error;
        }
        _throwIfStale(attempt);

        _setPhase(CoreBootPhase.initializing, attempt);
        await Future.any<void>([
          _initialize(attempt),
          _attemptFailureCompleter!.future,
        ]);
        _throwIfStale(attempt);

        _setPhase(CoreBootPhase.ready, attempt);
        return;
      } catch (error) {
        if (!_isCurrent(attempt)) return;
        failure = _asBootException(error, attempt, _phase);
      }

      try {
        await _teardown(attempt);
      } catch (error) {
        failure = _asBootException(error, attempt, failure.phase);
        _fail(failure, attempt);
      }

      if (attemptNumber == totalAttempts) {
        _fail(failure, attempt);
      }

      await Future<void>.delayed(_retryBackoffs[attemptNumber - 1]);
      _throwIfStale(attempt);
    }
  }

  Never _fail(CoreBootException error, CoreBootAttempt attempt) {
    if (!_terminalFailureEmitted) {
      _terminalFailureEmitted = true;
      _setPhase(CoreBootPhase.failed, attempt);
      _onFailed?.call(error);
    }
    throw error;
  }

  CoreBootException _asBootException(
    Object error,
    CoreBootAttempt attempt,
    CoreBootPhase phase,
  ) {
    if (error is CoreBootException &&
        error.generation == attempt.generation &&
        error.attempt == attempt.attempt) {
      return error;
    }
    return CoreBootException(
      phase: phase,
      generation: attempt.generation,
      attempt: attempt.attempt,
      cause: error,
    );
  }

  bool _isCurrent(CoreBootAttempt attempt) =>
      attempt.generation == _generation && identical(attempt, _currentAttempt);

  void _throwIfStale(CoreBootAttempt attempt) {
    if (!_isCurrent(attempt)) {
      throw StateError('stale core boot callback');
    }
  }

  void _setPhase(CoreBootPhase phase, CoreBootAttempt? attempt) {
    _phase = phase;
    _onPhaseChanged?.call(phase, attempt);
  }
}
