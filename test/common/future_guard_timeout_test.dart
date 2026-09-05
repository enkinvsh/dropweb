import 'dart:async';

import 'package:dropweb/common/future.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `guardWithTimeout` is the testable Dart-side seam used by
  // GlobalState.handleEvaluate to fail the JS config-apply loudly instead of
  // hanging: it races the eval future against a deadline, disposes the wedged
  // runtime on expiry, and throws a readable error string.
  group('guardWithTimeout — races a future against a deadline', () {
    test('returns the value when the future completes in time', () async {
      final result = await Future<int>.value(42).guardWithTimeout(
        timeout: const Duration(seconds: 10),
        message: 'should not throw',
      );
      expect(result, 42);
    });

    test('does NOT invoke onTimeout when the future completes in time',
        () async {
      var disposed = false;
      await Future<String>.value('ok').guardWithTimeout(
        timeout: const Duration(seconds: 10),
        message: 'should not throw',
        onTimeout: () => disposed = true,
      );
      expect(disposed, isFalse);
    });

    test('throws the readable message when the future never completes',
        () async {
      // A never-completing future stands in for a runaway script that wedges
      // the JS runtime — mirrors `while(true){}` on an async engine path.
      final never = Completer<int>().future;
      await expectLater(
        never.guardWithTimeout(
          timeout: const Duration(milliseconds: 20),
          message: 'script evaluation timed out (10s)',
        ),
        throwsA('script evaluation timed out (10s)'),
      );
    });

    test('runs the onTimeout cleanup exactly once on expiry', () async {
      var disposeCount = 0;
      final never = Completer<int>().future;
      try {
        await never.guardWithTimeout(
          timeout: const Duration(milliseconds: 20),
          message: 'timed out',
          onTimeout: () => disposeCount++,
        );
        fail('expected guardWithTimeout to throw on expiry');
      } catch (e) {
        expect(e, 'timed out');
      }
      expect(disposeCount, 1);
    });
  });
}
