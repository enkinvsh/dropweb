import 'package:dropweb/services/android_app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('downloadSourcesInOrder', () {
    test('YC primary first, GitHub fallback second', () {
      final s = downloadSourcesInOrder(
        primaryUrl: 'https://yc/apk',
        fallbackUrl: 'https://gh/apk',
      );
      expect(s, ['https://yc/apk', 'https://gh/apk']);
    });

    test('no fallback => single source', () {
      expect(
        downloadSourcesInOrder(primaryUrl: 'https://yc/apk', fallbackUrl: null),
        ['https://yc/apk'],
      );
      expect(
        downloadSourcesInOrder(primaryUrl: 'https://yc/apk', fallbackUrl: ''),
        ['https://yc/apk'],
      );
    });
  });

  group('shouldRunScheduledCheck', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1000000000000);
    test('manual always runs', () {
      expect(shouldRunScheduledCheck(manual: true, lastCheck: now, now: now),
          isTrue);
    });
    test('scheduled skips within 24h', () {
      expect(
        shouldRunScheduledCheck(
          manual: false,
          lastCheck: now,
          now: now.add(const Duration(hours: 5)),
        ),
        isFalse,
      );
    });
    test('scheduled runs after 24h', () {
      expect(
        shouldRunScheduledCheck(
          manual: false,
          lastCheck: now,
          now: now.add(const Duration(hours: 25)),
        ),
        isTrue,
      );
    });
  });

  group('sha256Matches', () {
    test('null expected => pass (graceful, integrity unverified)', () {
      expect(sha256Matches(expected: null, actual: 'abc'), isTrue);
    });
    test('case-insensitive equal => pass; mismatch => fail', () {
      expect(sha256Matches(expected: 'ABC', actual: 'abc'), isTrue);
      expect(sha256Matches(expected: 'abc', actual: 'def'), isFalse);
    });
  });
}
