import 'package:dropweb/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('controller.shouldHandleUpdateResult', () {
    // Stable channel: always handle both auto and manual results.
    test('stable build always handles auto checks', () {
      expect(
        shouldHandleUpdateResult(isPre: false, handleError: false),
        isTrue,
      );
    });

    test('stable build always handles manual checks', () {
      expect(
        shouldHandleUpdateResult(isPre: false, handleError: true),
        isTrue,
      );
    });

    // Pre channel: keep automatic prompts suppressed (handleError=false)
    // to avoid noisy prerelease dialogs on every startup.
    test('pre build suppresses automatic checks', () {
      expect(
        shouldHandleUpdateResult(isPre: true, handleError: false),
        isFalse,
      );
    });

    // Pre channel: allow explicit/manual "Проверить обновления" so the
    // user gets feedback (either the update dialog or "latest version").
    test('pre build allows manual checks', () {
      expect(
        shouldHandleUpdateResult(isPre: true, handleError: true),
        isTrue,
      );
    });
  });
}
