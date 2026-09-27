import 'package:dropweb/services/hwid_recovery.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Short, test-friendly cadence; production defaults (30s / 10min) are just
  // parameters over the same machinery.
  const interval = Duration(seconds: 5);
  const cap = Duration(seconds: 18); // fits 3 polls, expires before the 4th

  HwidRecoveryService build({
    required List<String> calls,
    bool Function()? isForeground,
    bool Function(String)? isCurrentProfile,
    Future<void> Function(String)? retry,
  }) =>
      HwidRecoveryService(
        retryProfileUpdate: retry ??
            (id) async {
              calls.add(id);
            },
        isForeground: isForeground ?? () => true,
        isCurrentProfile: isCurrentProfile,
        pollInterval: interval,
        episodeCap: cap,
      );

  test('onHwidLimit opens an episode once; repeats stay silent', () {
    final svc = build(calls: []);
    expect(svc.onHwidLimit('p1'), isTrue);
    expect(svc.onHwidLimit('p1'), isFalse); // same episode → no dialog again
    expect(svc.isActive, isTrue);
  });

  test('foreground poll retries on the injected cadence and honors the cap',
      () {
    fakeAsync((async) {
      final calls = <String>[];
      final svc = build(calls: calls);
      svc.onHwidLimit('p1');

      async.elapse(const Duration(seconds: 16)); // 3 ticks at 5/10/15s
      expect(calls, ['p1', 'p1', 'p1']);

      // Cap (18s) expires before the 20s tick fires → episode ends itself.
      async.elapse(const Duration(seconds: 10));
      expect(calls.length, 3);
      expect(svc.isActive, isFalse);
    });
  });

  test('background ticks are skipped, resume triggers an immediate retry', () {
    fakeAsync((async) {
      final calls = <String>[];
      var foreground = false;
      final svc = build(calls: calls, isForeground: () => foreground);
      svc.onHwidLimit('p1');

      async.elapse(const Duration(seconds: 11)); // 2 ticks, both backgrounded
      expect(calls, isEmpty);

      foreground = true;
      svc.onAppResumed();
      async.flushMicrotasks();
      expect(calls, ['p1']);
    });
  });

  test('onRecovered closes only the matching episode and stops the poll', () {
    fakeAsync((async) {
      final calls = <String>[];
      final svc = build(calls: calls);
      svc.onHwidLimit('p1');

      expect(svc.onRecovered('other'), isFalse);
      expect(svc.isActive, isTrue);

      expect(svc.onRecovered('p1'), isTrue);
      expect(svc.isActive, isFalse);
      expect(svc.onRecovered('p1'), isFalse); // already closed → no re-toast

      async.elapse(const Duration(seconds: 30));
      expect(calls, isEmpty); // poll actually cancelled
    });
  });

  test('a new profile signal replaces the previous episode', () {
    fakeAsync((async) {
      final calls = <String>[];
      final svc = build(calls: calls);
      svc.onHwidLimit('p1');
      expect(svc.onHwidLimit('p2'), isTrue); // different profile → new episode

      async.elapse(const Duration(seconds: 6));
      expect(calls, ['p2']); // old p1 poll is gone

      expect(svc.onRecovered('p1'), isFalse);
      expect(svc.onRecovered('p2'), isTrue);
    });
  });

  test('overlapping retries are collapsed (in-flight guard)', () {
    fakeAsync((async) {
      var inFlight = 0;
      var maxInFlight = 0;
      var total = 0;
      final svc = build(
        calls: [],
        retry: (id) async {
          inFlight++;
          total++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          // Slower than the poll interval → next ticks must be dropped,
          // not queued.
          await Future<void>.delayed(const Duration(seconds: 12));
          inFlight--;
        },
      );
      svc.onHwidLimit('p1');

      async.elapse(const Duration(seconds: 16)); // ticks at 5/10/15
      expect(maxInFlight, 1);
      expect(total, lessThanOrEqualTo(2));
    });
  });

  test('a background (non-active) profile never opens an episode or dialog',
      () {
    fakeAsync((async) {
      final calls = <String>[];
      final svc = build(calls: calls, isCurrentProfile: (id) => id == 'active');

      // Auto-update of another subscription hit ITS device limit — must not
      // pop a dialog over the active profile nor poll the background one.
      expect(svc.onHwidLimit('background'), isFalse);
      expect(svc.isActive, isFalse);

      // …and must not hijack an episode already running for the active one.
      expect(svc.onHwidLimit('active'), isTrue);
      expect(svc.onHwidLimit('background'), isFalse);
      async.elapse(const Duration(seconds: 6));
      expect(calls, ['active']);
    });
  });

  test('switching away from the flagged profile ends the episode silently', () {
    fakeAsync((async) {
      final calls = <String>[];
      var current = 'p1';
      final svc = build(calls: calls, isCurrentProfile: (id) => id == current)
        ..onHwidLimit('p1');

      current = 'p2';
      async.elapse(const Duration(seconds: 6)); // next tick sees the switch
      expect(calls, isEmpty);
      expect(svc.isActive, isFalse);

      svc.onAppResumed();
      async.flushMicrotasks();
      expect(calls, isEmpty);
    });
  });
}
