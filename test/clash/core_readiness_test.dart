import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/core_readiness.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const _connectTimeout = Duration(seconds: 2);
const _retryBackoffs = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

void main() {
  test('never-connected core retries with 1/2/4s backoff then fails typed', () {
    fakeAsync((async) {
      final spawnTimes = <Duration>[];
      final teardowns = <CoreBootAttempt>[];
      CoreBootException? failure;

      final machine = CoreReadinessMachine(
        bind: (_) async {},
        spawn: (attempt) async => spawnTimes.add(async.elapsed),
        initialize: (_) async {},
        teardown: (attempt) async => teardowns.add(attempt),
        connectBackTimeout: _connectTimeout,
        retryBackoffs: _retryBackoffs,
      );

      machine.restart().catchError((Object error) {
        failure = error as CoreBootException;
      });
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();

      expect(spawnTimes, const [
        Duration.zero,
        Duration(seconds: 3),
        Duration(seconds: 7),
        Duration(seconds: 13),
      ]);
      final observedBackoffs = <Duration>[
        for (var index = 1; index < spawnTimes.length; index++)
          spawnTimes[index] - spawnTimes[index - 1] - _connectTimeout,
      ];
      expect(observedBackoffs, _retryBackoffs);
      expect(teardowns, hasLength(4));
      expect(failure?.phase, CoreBootPhase.waitingForConnect);
      expect(failure?.attempt, 4);
      expect(machine.phase, CoreBootPhase.failed);
    });
  });

  test('generation N-1 callbacks cannot affect generation N', () {
    fakeAsync((async) {
      final initialized = <CoreBootAttempt>[];
      late CoreReadinessMachine machine;
      machine = CoreReadinessMachine(
        bind: (_) async {},
        spawn: (_) async {},
        initialize: (attempt) async => initialized.add(attempt),
        teardown: (_) async {},
        connectBackTimeout: _connectTimeout,
        retryBackoffs: _retryBackoffs,
      );

      machine.restart();
      async.flushMicrotasks();
      final generationOne = machine.currentAttempt!;
      expect(machine.acceptConnection(generationOne), isTrue);
      async.flushMicrotasks();
      expect(machine.phase, CoreBootPhase.ready);

      machine.restart();
      async.flushMicrotasks();
      final generationTwo = machine.currentAttempt!;
      expect(generationTwo.generation, generationOne.generation + 1);
      expect(machine.phase, CoreBootPhase.waitingForConnect);

      expect(machine.acceptConnection(generationOne), isFalse);
      expect(
        machine.reportAttemptFailure(
          generationOne,
          StateError('late process exit'),
        ),
        isFalse,
      );
      async.flushMicrotasks();
      expect(machine.phase, CoreBootPhase.waitingForConnect);
      expect(initialized, [generationOne]);

      expect(machine.acceptConnection(generationTwo), isTrue);
      async.flushMicrotasks();
      expect(machine.phase, CoreBootPhase.ready);
      expect(initialized, [generationOne, generationTwo]);
    });
  });

  test('Process.start throw becomes typed spawn failure with no zone error',
      () {
    final uncaught = <Object>[];
    CoreBootException? failure;

    runZonedGuarded(
      () => fakeAsync((async) {
        final machine = CoreReadinessMachine(
          bind: (_) async {},
          spawn: (_) async {
            throw const ProcessException(
              r'C:\Program Files\dropweb\DropwebCore.exe',
              <String>['47891'],
              'Access is denied',
              5,
            );
          },
          initialize: (_) async {},
          teardown: (_) async {},
          connectBackTimeout: _connectTimeout,
          retryBackoffs: _retryBackoffs,
        );

        machine.restart().catchError((Object error) {
          failure = error as CoreBootException;
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 7));
        async.flushMicrotasks();
      }),
      (error, _) => uncaught.add(error),
    );

    expect(uncaught, isEmpty);
    expect(failure?.phase, CoreBootPhase.spawning);
    expect(failure?.cause, isA<ProcessException>());
    expect(
      failure?.executablePath,
      r'C:\Program Files\dropweb\DropwebCore.exe',
    );
    expect(failure?.osErrorCode, 5);
  });

  test('strict init failure retries and never reports ready', () {
    fakeAsync((async) {
      final observedPhases = <CoreBootPhase>[];
      final teardowns = <CoreBootAttempt>[];
      CoreBootException? failure;
      late CoreReadinessMachine machine;
      machine = CoreReadinessMachine(
        bind: (_) async {},
        spawn: (attempt) async {
          Timer.run(() => machine.acceptConnection(attempt));
        },
        initialize: (_) async => throw StateError('strict init failed'),
        teardown: (attempt) async => teardowns.add(attempt),
        connectBackTimeout: _connectTimeout,
        retryBackoffs: _retryBackoffs,
        onPhaseChanged: (phase, _) => observedPhases.add(phase),
      );

      machine.restart().catchError((Object error) {
        failure = error as CoreBootException;
      });
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 7));
      async.flushMicrotasks();

      expect(teardowns, hasLength(4));
      expect(observedPhases, isNot(contains(CoreBootPhase.ready)));
      expect(failure?.phase, CoreBootPhase.initializing);
      expect(machine.phase, CoreBootPhase.failed);
    });
  });

  test('terminal failure is emitted exactly once', () {
    fakeAsync((async) {
      var failureEvents = 0;
      var spawnAttempts = 0;
      late CoreReadinessMachine machine;
      machine = CoreReadinessMachine(
        bind: (_) async {},
        spawn: (_) async => spawnAttempts++,
        initialize: (_) async {},
        teardown: (_) async {},
        connectBackTimeout: _connectTimeout,
        retryBackoffs: _retryBackoffs,
        onFailed: (_) => failureEvents++,
      );

      machine.restart().catchError((_) {});
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();
      final failedAttempt = machine.currentAttempt!;

      expect(failureEvents, 1);
      expect(spawnAttempts, 4);
      expect(machine.phase, CoreBootPhase.failed);

      expect(machine.acceptConnection(failedAttempt), isFalse);
      expect(
        machine.reportAttemptFailure(
          failedAttempt,
          StateError('duplicate late exit'),
        ),
        isFalse,
      );
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();

      expect(failureEvents, 1);
      expect(spawnAttempts, 4);
      expect(machine.phase, CoreBootPhase.failed);
    });
  });

  test('reentrant restart during binding shares the current generation', () {
    fakeAsync((async) {
      var bindCalls = 0;
      var bindingTransitions = 0;
      late CoreReadinessMachine machine;
      machine = CoreReadinessMachine(
        bind: (_) async => bindCalls++,
        spawn: (_) async {},
        initialize: (_) async {},
        teardown: (_) async {},
        connectBackTimeout: _connectTimeout,
        retryBackoffs: _retryBackoffs,
        onPhaseChanged: (phase, _) {
          if (phase == CoreBootPhase.binding && bindingTransitions++ == 0) {
            machine.restart();
          }
        },
      );

      machine.restart();
      async.flushMicrotasks();
      final attempt = machine.currentAttempt!;

      expect(machine.generation, 1);
      expect(bindCalls, 1);
      expect(machine.acceptConnection(attempt), isTrue);
      async.flushMicrotasks();
      expect(machine.phase, CoreBootPhase.ready);
    });
  });
}
