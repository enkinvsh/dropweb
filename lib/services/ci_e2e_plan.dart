import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _schema = 1;
const _flag = '--ci-e2e-plan';
const _environmentKey = 'DROPWEB_CI_E2E';

String? resolveCiE2ePlanPath({
  required List<String> arguments,
  required Map<String, String> environment,
  required bool isDesktop,
}) {
  if (!isDesktop || environment[_environmentKey] != '1') return null;

  String? value;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument.startsWith('$_flag=')) {
      value = argument.substring(_flag.length + 1);
      break;
    }
    if (argument == _flag && index + 1 < arguments.length) {
      value = arguments[index + 1];
      break;
    }
  }
  return value != null && _isAbsolutePath(value) ? value : null;
}

bool _isAbsolutePath(String value) =>
    p.posix.isAbsolute(value) || p.windows.isAbsolute(value);

enum CiE2eOperation {
  importUrl,
  connect,
  waitFile,
  buildSupportBundle,
  disconnect,
  holdConnecting,
}

extension CiE2eOperationName on CiE2eOperation {
  String get value => switch (this) {
        CiE2eOperation.holdConnecting => 'holdConnecting',
        CiE2eOperation.importUrl => 'importUrl',
        CiE2eOperation.connect => 'connect',
        CiE2eOperation.waitFile => 'waitFile',
        CiE2eOperation.buildSupportBundle => 'buildSupportBundle',
        CiE2eOperation.disconnect => 'disconnect',
      };
}

final class CiE2ePlanStep {
  const CiE2ePlanStep({
    required this.operation,
    this.urlFile,
    this.expectHost,
    this.expectTun,
    this.checkpointPath,
    this.path,
    this.timeout,
    this.outPath,
    this.readyPath,
    this.releasePath,
  });

  final CiE2eOperation operation;
  final String? urlFile;
  final String? expectHost;
  final bool? expectTun;
  final String? checkpointPath;
  final String? path;
  final Duration? timeout;
  final String? outPath;
  final String? readyPath;
  final String? releasePath;

  String get opName => operation.value;
}

final class CiE2ePlan {
  const CiE2ePlan({
    required this.resultPath,
    required this.exitAfter,
    required this.stepTimeout,
    required this.steps,
  });

  final int schema = _schema;
  final String resultPath;
  final bool exitAfter;
  final Duration stepTimeout;
  final List<CiE2ePlanStep> steps;

  factory CiE2ePlan.parse(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const CiE2ePlanException(detail: 'plan is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CiE2ePlanException(detail: 'plan must be a JSON object');
    }

    final resultPath = decoded['resultPath'] is String
        ? decoded['resultPath'] as String
        : null;
    final exitAfter =
        decoded['exitAfter'] is bool ? decoded['exitAfter'] as bool : null;
    Never invalid(String detail) => throw CiE2ePlanException(
          detail: detail,
          resultPath: resultPath,
          exitAfter: exitAfter,
        );

    _rejectUnknownFields(
      decoded,
      const {
        'schema',
        'resultPath',
        'exitAfter',
        'stepTimeoutSeconds',
        'steps',
      },
      'top-level',
      invalid,
    );
    if (decoded['schema'] != _schema) invalid('schema must be 1');
    if (resultPath == null ||
        resultPath.isEmpty ||
        !_isAbsolutePath(resultPath)) {
      invalid('resultPath must be an absolute path');
    }
    if (exitAfter == null) invalid('exitAfter must be a boolean');
    final timeoutSeconds = decoded['stepTimeoutSeconds'];
    if (timeoutSeconds is! int || timeoutSeconds <= 0) {
      invalid('stepTimeoutSeconds must be a positive integer');
    }
    final rawSteps = decoded['steps'];
    if (rawSteps is! List<dynamic>) invalid('steps must be an array');

    return CiE2ePlan(
      resultPath: resultPath,
      exitAfter: exitAfter,
      stepTimeout: Duration(seconds: timeoutSeconds),
      steps: [
        for (var index = 0; index < rawSteps.length; index++)
          _parseStep(rawSteps[index], index, invalid),
      ],
    );
  }
}

CiE2ePlanStep _parseStep(
  Object? raw,
  int index,
  Never Function(String detail) invalid,
) {
  if (raw is! Map<String, dynamic>) {
    invalid('step $index must be an object');
  }
  final op = switch (raw['op']) {
    'holdConnecting' => CiE2eOperation.holdConnecting,
    'importUrl' => CiE2eOperation.importUrl,
    'connect' => CiE2eOperation.connect,
    'waitFile' => CiE2eOperation.waitFile,
    'buildSupportBundle' => CiE2eOperation.buildSupportBundle,
    'disconnect' => CiE2eOperation.disconnect,
    _ => invalid('step $index has unknown op'),
  };
  final allowed = switch (op) {
    CiE2eOperation.holdConnecting => const {
        'op',
        'readyPath',
        'releasePath',
      },
    CiE2eOperation.importUrl => const {'op', 'urlFile', 'expectHost'},
    CiE2eOperation.connect => const {'op', 'expectTun', 'checkpointPath'},
    CiE2eOperation.waitFile => const {'op', 'path', 'timeoutSeconds'},
    CiE2eOperation.buildSupportBundle => const {'op', 'outPath'},
    CiE2eOperation.disconnect => const {'op'},
  };
  _rejectUnknownFields(raw, allowed, op.value, invalid);

  String requiredAbsolutePath(String field) {
    final value = raw[field];
    if (value is! String || value.isEmpty || !_isAbsolutePath(value)) {
      invalid('${op.value}.$field must be an absolute path');
    }
    return value;
  }

  return switch (op) {
    CiE2eOperation.holdConnecting => CiE2ePlanStep(
        operation: op,
        readyPath: requiredAbsolutePath('readyPath'),
        releasePath: requiredAbsolutePath('releasePath'),
      ),
    CiE2eOperation.importUrl => CiE2ePlanStep(
        operation: op,
        urlFile: requiredAbsolutePath('urlFile'),
        expectHost: switch (raw['expectHost']) {
          final String host when host.isNotEmpty => host.toLowerCase(),
          _ => invalid('importUrl.expectHost must be a non-empty string'),
        },
      ),
    CiE2eOperation.connect => CiE2ePlanStep(
        operation: op,
        expectTun: switch (raw['expectTun']) {
          final bool value => value,
          _ => invalid('connect.expectTun must be a boolean'),
        },
        checkpointPath: switch (raw['checkpointPath']) {
          null => null,
          String() => requiredAbsolutePath('checkpointPath'),
          _ => invalid('connect.checkpointPath must be an absolute path'),
        },
      ),
    CiE2eOperation.waitFile => CiE2ePlanStep(
        operation: op,
        path: requiredAbsolutePath('path'),
        timeout: switch (raw['timeoutSeconds']) {
          final int seconds when seconds > 0 => Duration(seconds: seconds),
          _ => invalid('waitFile.timeoutSeconds must be a positive integer'),
        },
      ),
    CiE2eOperation.buildSupportBundle => CiE2ePlanStep(
        operation: op,
        outPath: requiredAbsolutePath('outPath'),
      ),
    CiE2eOperation.disconnect => CiE2ePlanStep(operation: op),
  };
}

void _rejectUnknownFields(
  Map<String, dynamic> value,
  Set<String> allowed,
  String scope,
  Never Function(String detail) invalid,
) {
  final unknown = value.keys.where((key) => !allowed.contains(key)).toList()
    ..sort();
  if (unknown.isNotEmpty) invalid('unknown $scope field: ${unknown.first}');
}

final class CiE2ePlanException implements Exception {
  const CiE2ePlanException({
    required this.detail,
    this.resultPath,
    this.exitAfter,
  });

  final String detail;
  final String? resultPath;
  final bool? exitAfter;
  String get firstFailure => 'plan-invalid';

  @override
  String toString() => detail;
}

enum CiE2eResultStatus { pass, fail }

enum CiE2eStepStatus { pass, fail }

final class CiE2eStepOutcome {
  const CiE2eStepOutcome._({
    required this.status,
    required this.checks,
    required this.ports,
    this.failedCheck,
    this.detail,
  });

  factory CiE2eStepOutcome.pass({
    Map<String, Object?> checks = const {},
    Map<String, int> ports = const {},
    String? detail,
  }) =>
      CiE2eStepOutcome._(
        status: CiE2eStepStatus.pass,
        checks: checks,
        ports: ports,
        detail: detail,
      );

  factory CiE2eStepOutcome.fail({
    required String failedCheck,
    Map<String, Object?> checks = const {},
    Map<String, int> ports = const {},
    String? detail,
  }) =>
      CiE2eStepOutcome._(
        status: CiE2eStepStatus.fail,
        failedCheck: failedCheck,
        checks: checks,
        ports: ports,
        detail: detail,
      );

  final CiE2eStepStatus status;
  final String? failedCheck;
  final Map<String, Object?> checks;
  final Map<String, int> ports;
  final String? detail;
}

final class CiE2eStepResult {
  const CiE2eStepResult({
    required this.op,
    required this.status,
    required this.durationMs,
    required this.checks,
    this.detail,
  });

  final String op;
  final CiE2eStepStatus status;
  final int durationMs;
  final Map<String, Object?> checks;
  final String? detail;

  Map<String, Object?> toJson() => {
        'op': op,
        'status': status == CiE2eStepStatus.pass ? 'PASS' : 'FAIL',
        'durationMs': durationMs,
        'checks': _safeMap(checks),
        'detail': _safeDetail(detail),
      };
}

final class CiE2ePlanResult {
  const CiE2ePlanResult({
    required this.result,
    required this.firstFailure,
    required this.steps,
    required this.appVersion,
    required this.ports,
  });

  final int schema = _schema;
  final CiE2eResultStatus result;
  final String? firstFailure;
  final List<CiE2eStepResult> steps;
  final String appVersion;
  final Map<String, int> ports;

  Map<String, Object?> toJson() => {
        'schema': schema,
        'result': result == CiE2eResultStatus.pass ? 'PASS' : 'FAIL',
        'firstFailure': firstFailure,
        'steps': steps.map((step) => step.toJson()).toList(),
        'appVersion': appVersion,
        'ports': ports,
      };
}

typedef CiE2eStepFunction = Future<CiE2eStepOutcome> Function(
  CiE2ePlanStep step,
);

final class CiE2ePlanExecutor {
  const CiE2ePlanExecutor({
    required this.appVersion,
    required this.stepFunctions,
  });

  final String appVersion;
  final Map<CiE2eOperation, CiE2eStepFunction> stepFunctions;

  Future<CiE2ePlanResult> execute(CiE2ePlan plan) async {
    final results = <CiE2eStepResult>[];
    final ports = <String, int>{};
    String? firstFailure;

    for (final step in plan.steps) {
      final stopwatch = Stopwatch()..start();
      CiE2eStepOutcome outcome;
      try {
        final stepFunction = stepFunctions[step.operation];
        if (stepFunction == null) {
          outcome = CiE2eStepOutcome.fail(
            failedCheck: 'unbound',
            checks: const {'stepBound': false},
            detail: 'step function is not bound',
          );
        } else {
          outcome = await stepFunction(step).timeout(plan.stepTimeout);
          if (step.operation == CiE2eOperation.connect &&
              step.checkpointPath != null) {
            try {
              await writeCiE2eJsonAtomically(
                step.checkpointPath!,
                _connectCheckpoint(outcome),
              );
            } catch (_) {
              outcome = CiE2eStepOutcome.fail(
                failedCheck: 'checkpoint-write',
                checks: {...outcome.checks, 'checkpointWritten': false},
                ports: outcome.ports,
                detail: 'connect checkpoint could not be written',
              );
            }
          }
        }
      } on TimeoutException {
        outcome = CiE2eStepOutcome.fail(
          failedCheck: 'timeout',
          checks: const {'completedBeforeTimeout': false},
          detail: 'step timed out',
        );
      } catch (error) {
        outcome = CiE2eStepOutcome.fail(
          failedCheck: 'exception',
          checks: const {'completedWithoutException': false},
          detail: 'step threw ${error.runtimeType}',
        );
      }
      stopwatch.stop();
      ports.addAll(outcome.ports);
      results.add(
        CiE2eStepResult(
          op: step.opName,
          status: outcome.status,
          durationMs: stopwatch.elapsedMilliseconds,
          checks: outcome.checks,
          detail: outcome.detail,
        ),
      );
      if (outcome.status == CiE2eStepStatus.fail) {
        firstFailure = '${step.opName}:${outcome.failedCheck}';
        break;
      }
    }

    return CiE2ePlanResult(
      result: firstFailure == null
          ? CiE2eResultStatus.pass
          : CiE2eResultStatus.fail,
      firstFailure: firstFailure,
      steps: results,
      appVersion: appVersion,
      ports: ports,
    );
  }
}

Future<CiE2eStepOutcome> runCiE2eWaitFile(
  CiE2ePlanStep step, {
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  final file = File(step.path!);
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < step.timeout!) {
    if (await file.exists()) {
      return CiE2eStepOutcome.pass(checks: const {'fileAppeared': true});
    }
    await Future<void>.delayed(pollInterval);
  }
  if (await file.exists()) {
    return CiE2eStepOutcome.pass(checks: const {'fileAppeared': true});
  }
  return CiE2eStepOutcome.fail(
    failedCheck: 'file-timeout',
    checks: const {'fileAppeared': false},
    detail: 'waitFile timed out',
  );
}

Map<String, Object?> _connectCheckpoint(CiE2eStepOutcome outcome) => {
      'status': outcome.status == CiE2eStepStatus.pass ? 'PASS' : 'FAIL',
      'ports': outcome.ports,
      'requestedTun': outcome.checks['tunRequested'],
      'effectiveTunObserved': outcome.checks['tunEffective'],
      'tunListenerFailed': outcome.checks['tunListenerFailed'],
      'startCompleted': outcome.checks['startCompleted'],
      'mixedListening': outcome.checks['mixedListening'],
      'socksListening': outcome.checks['socksListening'],
    };

Map<String, Object?> evaluateCiE2eImportJournal(
  String journal,
  String attemptMarker, {
  String? endMarker,
}) {
  final markerIndex = journal.indexOf(attemptMarker);
  final endIndex = markerIndex == -1 || endMarker == null
      ? -1
      : journal.indexOf(endMarker, markerIndex + attemptMarker.length);
  final endMarkerFound = endMarker == null || endIndex != -1;
  final attempt = markerIndex == -1
      ? ''
      : journal.substring(
          markerIndex,
          endIndex == -1 ? journal.length : endIndex + endMarker!.length,
        );
  const validate = '[import] validate';
  const commit = '[import] profile-commit';
  const apply = '[import] profile-apply';
  const failure = 'Add Profile Failed';
  int count(String value) => value.allMatches(attempt).length;
  final validateIndex = attempt.indexOf(validate);
  final commitIndex = attempt.indexOf(commit);
  final applyIndex = attempt.indexOf(apply);
  final validateOnce = count(validate) == 1;
  final commitOnce = count(commit) == 1;
  final applyOnce = count(apply) == 1;
  final noFailure = !attempt.contains(failure);

  return {
    'journalMarkerFound': markerIndex != -1,
    if (endMarker != null) 'journalEndMarkerFound': endMarkerFound,
    'validateOnce': validateOnce,
    'profileCommitOnce': commitOnce,
    'profileApplyOnce': applyOnce,
    'journalOrder': markerIndex != -1 &&
        validateOnce &&
        commitOnce &&
        applyOnce &&
        endMarkerFound &&
        noFailure &&
        validateIndex < commitIndex &&
        commitIndex < applyIndex,
    'noAddProfileFailed': noFailure,
  };
}

Map<String, Object?> planInvalidResult(CiE2ePlanException error) => {
      'schema': _schema,
      'result': 'FAIL',
      'firstFailure': error.firstFailure,
      'detail': _safeDetail(error.detail),
    };

Future<void> writeCiE2eResultAtomically(
  String resultPath,
  CiE2ePlanResult result,
) =>
    writeCiE2eJsonAtomically(resultPath, result.toJson());

Future<void> writeCiE2eJsonAtomically(
  String resultPath,
  Map<String, Object?> result,
) async {
  final target = File(resultPath);
  await target.parent.create(recursive: true);
  final temporary = File(
    '$resultPath.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await temporary.writeAsString(jsonEncode(result), flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(resultPath);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Map<String, Object?> _safeMap(Map<String, Object?> value) => {
      for (final entry in value.entries)
        entry.key: switch (entry.value) {
          null || bool() || num() => entry.value,
          _ => '[REDACTED]',
        },
    };

String? _safeDetail(String? value) {
  if (value == null) return null;
  return value.replaceAll(
    RegExp(r'\b[a-zA-Z][a-zA-Z0-9+.-]*://\S+'),
    '[REDACTED_URL]',
  );
}
