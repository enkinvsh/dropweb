import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/services/ci_e2e_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('resolveCiE2ePlanPath', () {
    test('accepts equals and two-token forms only with desktop CI marker', () {
      expect(
        resolveCiE2ePlanPath(
          arguments: [r'--ci-e2e-plan=C:\ci\plan.json'],
          environment: const {'DROPWEB_CI_E2E': '1'},
          isDesktop: true,
        ),
        r'C:\ci\plan.json',
      );
      expect(
        resolveCiE2ePlanPath(
          arguments: [r'--ci-e2e-plan', r'C:\ci\plan.json'],
          environment: const {'DROPWEB_CI_E2E': '1'},
          isDesktop: true,
        ),
        r'C:\ci\plan.json',
      );
    });

    test('is inert unless every activation condition is present', () {
      expect(
        resolveCiE2ePlanPath(
          arguments: [r'--ci-e2e-plan=C:\ci\plan.json'],
          environment: const {},
          isDesktop: true,
        ),
        isNull,
      );
      expect(
        resolveCiE2ePlanPath(
          arguments: [r'--ci-e2e-plan=C:\ci\plan.json'],
          environment: const {'DROPWEB_CI_E2E': '1'},
          isDesktop: false,
        ),
        isNull,
      );
      expect(
        resolveCiE2ePlanPath(
          arguments: const ['--ci-e2e-plan', 'relative-plan.json'],
          environment: const {'DROPWEB_CI_E2E': '1'},
          isDesktop: true,
        ),
        isNull,
      );
    });
  });

  group('CiE2ePlan schema', () {
    test('parses the frozen schema 1 plan', () {
      final plan = CiE2ePlan.parse(_validPlanJson());

      expect(plan.schema, 1);
      expect(plan.resultPath, r'C:\ci\result.json');
      expect(plan.exitAfter, isTrue);
      expect(plan.stepTimeout, const Duration(seconds: 120));
      expect(
        plan.steps.map((step) => step.operation),
        [
          CiE2eOperation.importUrl,
          CiE2eOperation.connect,
          CiE2eOperation.buildSupportBundle,
          CiE2eOperation.disconnect,
        ],
      );
      expect(plan.steps.first.urlFile, r'C:\ci\sub_url.txt');
      expect(plan.steps.first.expectHost, 'sub.dropweb.org');
      expect(plan.steps[1].expectTun, isTrue);
      expect(plan.steps[2].outPath, r'C:\ci\support-bundle.txt');
    });

    test('rejects an unknown top-level field', () {
      expect(
        () => CiE2ePlan.parse(_validPlanJson(extraTopLevel: {'future': true})),
        throwsA(
          isA<CiE2ePlanException>().having(
            (error) => error.detail,
            'detail',
            contains('unknown top-level field'),
          ),
        ),
      );
    });

    test('rejects an unknown step field', () {
      expect(
        () => CiE2ePlan.parse(
          _validPlanJson(importExtra: {'subscriptionUrl': 'not-allowed'}),
        ),
        throwsA(
          isA<CiE2ePlanException>().having(
            (error) => error.detail,
            'detail',
            contains('unknown importUrl field'),
          ),
        ),
      );
    });

    test('rejects an unknown operation', () {
      final raw = jsonDecode(_validPlanJson()) as Map<String, dynamic>;
      (raw['steps'] as List<dynamic>)[0] = {'op': 'futureOperation'};

      expect(
        () => CiE2ePlan.parse(jsonEncode(raw)),
        throwsA(
          isA<CiE2ePlanException>().having(
            (error) => error.detail,
            'detail',
            contains('unknown op'),
          ),
        ),
      );
    });

    test('rejects schema 2', () {
      final raw = jsonDecode(_validPlanJson()) as Map<String, dynamic>
        ..['schema'] = 2;

      expect(
        () => CiE2ePlan.parse(jsonEncode(raw)),
        throwsA(
          isA<CiE2ePlanException>().having(
            (error) => error.detail,
            'detail',
            contains('schema must be 1'),
          ),
        ),
      );
    });

    test('rejects a missing resultPath', () {
      final raw = jsonDecode(_validPlanJson()) as Map<String, dynamic>
        ..remove('resultPath');

      expect(
        () => CiE2ePlan.parse(jsonEncode(raw)),
        throwsA(
          isA<CiE2ePlanException>()
              .having(
                  (error) => error.firstFailure, 'firstFailure', 'plan-invalid')
              .having((error) => error.resultPath, 'resultPath', isNull),
        ),
      );
    });
  });

  group('CiE2ePlanExecutor', () {
    test('runs steps in order and assembles a passing result', () async {
      final calls = <String>[];
      final executor = CiE2ePlanExecutor(
        appVersion: '0.8.6+2050000005',
        stepFunctions: {
          for (final operation in CiE2eOperation.values)
            operation: (step) async {
              calls.add(step.opName);
              return CiE2eStepOutcome.pass(
                checks: {'observed': true},
                ports: step.operation == CiE2eOperation.connect
                    ? const {'mixed': 7890, 'socks': 7891}
                    : const {},
              );
            },
        },
      );

      final result = await executor.execute(CiE2ePlan.parse(_validPlanJson()));

      expect(calls, [
        'importUrl',
        'connect',
        'buildSupportBundle',
        'disconnect',
      ]);
      expect(result.result, CiE2eResultStatus.pass);
      expect(result.firstFailure, isNull);
      expect(result.steps, hasLength(4));
      expect(
        result.steps.map((step) => step.status),
        everyElement(CiE2eStepStatus.pass),
      );
      expect(result.appVersion, '0.8.6+2050000005');
      expect(result.ports, {'mixed': 7890, 'socks': 7891});
    });

    test('stops at the first failed step', () async {
      final calls = <String>[];
      final executor = CiE2ePlanExecutor(
        appVersion: 'test',
        stepFunctions: {
          CiE2eOperation.importUrl: (step) async {
            calls.add(step.opName);
            return CiE2eStepOutcome.fail(
              failedCheck: 'journal-order',
              checks: {'journalOrder': false},
              detail: 'required import markers were not ordered',
            );
          },
          for (final operation in CiE2eOperation.values.skip(1))
            operation: (step) async {
              calls.add(step.opName);
              return CiE2eStepOutcome.pass();
            },
        },
      );

      final result = await executor.execute(CiE2ePlan.parse(_validPlanJson()));

      expect(calls, ['importUrl']);
      expect(result.result, CiE2eResultStatus.fail);
      expect(result.firstFailure, 'importUrl:journal-order');
      expect(result.steps, hasLength(1));
      expect(result.steps.single.status, CiE2eStepStatus.fail);
    });

    test('records a per-step timeout instead of hanging', () async {
      final raw = jsonDecode(_validPlanJson()) as Map<String, dynamic>
        ..['stepTimeoutSeconds'] = 1
        ..['steps'] = [
          {'op': 'disconnect'},
        ];
      final executor = CiE2ePlanExecutor(
        appVersion: 'test',
        stepFunctions: {
          CiE2eOperation.disconnect: (_) =>
              Completer<CiE2eStepOutcome>().future,
        },
      );

      final stopwatch = Stopwatch()..start();
      final result = await executor.execute(CiE2ePlan.parse(jsonEncode(raw)));
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(result.result, CiE2eResultStatus.fail);
      expect(result.firstFailure, 'disconnect:timeout');
      expect(result.steps.single.status, CiE2eStepStatus.fail);
      expect(result.steps.single.checks, {'completedBeforeTimeout': false});
    });

    test('never serializes a URL from a thrown step failure', () async {
      const secretUrl =
          'https://user:password@example.test/subscription?token=secret';
      final raw = jsonDecode(_validPlanJson()) as Map<String, dynamic>
        ..['steps'] = [
          {
            'op': 'importUrl',
            'urlFile': r'C:\ci\sub_url.txt',
            'expectHost': 'example.test'
          },
        ];
      final executor = CiE2ePlanExecutor(
        appVersion: 'test',
        stepFunctions: {
          CiE2eOperation.importUrl: (_) async => throw StateError(secretUrl),
        },
      );

      final result = await executor.execute(CiE2ePlan.parse(jsonEncode(raw)));
      final serialized = jsonEncode(result.toJson());

      expect(serialized, isNot(contains(secretUrl)));
      expect(serialized, isNot(contains('password')));
      expect(serialized, isNot(contains('token=secret')));
      expect(result.firstFailure, 'importUrl:exception');
    });
  });

  group('evaluateCiE2eImportJournal', () {
    test('requires one ordered transaction and no failure after the marker',
        () {
      const marker = '[ci-e2e] import-start attempt-1';
      final checks = evaluateCiE2eImportJournal('''
[import] validate from an older attempt
$marker
[import] validate
[import] profile-commit [profile] addProfile profile-id
[import] profile-apply
''', marker);

      expect(checks, {
        'journalMarkerFound': true,
        'validateOnce': true,
        'profileCommitOnce': true,
        'profileApplyOnce': true,
        'journalOrder': true,
        'noAddProfileFailed': true,
      });
    });

    test('rejects duplicate markers and a terminal import failure', () {
      const marker = '[ci-e2e] import-start attempt-2';
      final checks = evaluateCiE2eImportJournal('''
$marker
[import] validate
[import] validate
[import] profile-commit [profile] addProfile profile-id
Add Profile Failed: hidden detail
[import] profile-apply
''', marker);

      expect(checks['validateOnce'], isFalse);
      expect(checks['noAddProfileFailed'], isFalse);
      expect(checks['journalOrder'], isFalse);
    });

    test('ignores unrelated journal entries after the attempt end marker', () {
      const start = '[ci-e2e] import-start attempt-3';
      const end = '[ci-e2e] import-end attempt-3';
      final checks = evaluateCiE2eImportJournal(
        '''
$start
[import] validate
[import] profile-commit [profile] addProfile profile-id
[import] profile-apply
$end
Add Profile Failed: unrelated later attempt
''',
        start,
        endMarker: end,
      );

      expect(checks['journalOrder'], isTrue);
      expect(checks['noAddProfileFailed'], isTrue);
      expect(checks['journalEndMarkerFound'], isTrue);
    });
  });

  test('atomic result writer leaves one complete JSON document', () async {
    final directory = Directory.systemTemp.createTempSync('dropweb_ci_e2e');
    addTearDown(() => directory.deleteSync(recursive: true));
    final resultPath = p.join(directory.path, 'result.json');
    await File(resultPath).writeAsString('{"result":"STALE"}');
    const result = CiE2ePlanResult(
      result: CiE2eResultStatus.pass,
      firstFailure: null,
      steps: [],
      appVersion: '0.8.6+2050000005',
      ports: {'mixed': 7890},
    );

    await writeCiE2eResultAtomically(resultPath, result);

    final files = directory.listSync().whereType<File>().toList();
    expect(files.map((file) => p.basename(file.path)), ['result.json']);
    expect(
      jsonDecode(await File(resultPath).readAsString()),
      result.toJson(),
    );
  });
}

String _validPlanJson({
  Map<String, Object?> extraTopLevel = const {},
  Map<String, Object?> importExtra = const {},
}) =>
    jsonEncode({
      'schema': 1,
      'resultPath': r'C:\ci\result.json',
      'exitAfter': true,
      'stepTimeoutSeconds': 120,
      'steps': [
        {
          'op': 'importUrl',
          'urlFile': r'C:\ci\sub_url.txt',
          'expectHost': 'sub.dropweb.org',
          ...importExtra,
        },
        {'op': 'connect', 'expectTun': true},
        {
          'op': 'buildSupportBundle',
          'outPath': r'C:\ci\support-bundle.txt',
        },
        {'op': 'disconnect'},
      ],
      ...extraTopLevel,
    });
