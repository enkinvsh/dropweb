import 'package:dropweb/models/app_update.dart';
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
    test('scheduled skips within 1h', () {
      expect(
        shouldRunScheduledCheck(
          manual: false,
          lastCheck: now,
          now: now.add(const Duration(minutes: 59)),
        ),
        isFalse,
      );
    });
    test('scheduled runs once 1h has passed', () {
      expect(
        shouldRunScheduledCheck(
          manual: false,
          lastCheck: now,
          now: now.add(const Duration(hours: 1)),
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

  group('shouldAutoOfferUpdate', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1000000000000);
    const info = AppUpdateInfo(
      version: '0.9.0',
      tag: 'v0.9.0',
      primaryUrl: 'https://yc/apk',
    );
    bool offer({
      AppUpdateInfo? info = info,
      AppUpdateStatus status = AppUpdateStatus.available,
      String snoozedVersion = '',
      int snoozedUntilMs = 0,
    }) =>
        shouldAutoOfferUpdate(
          info: info,
          status: status,
          snoozedVersion: snoozedVersion,
          snoozedUntilMs: snoozedUntilMs,
          now: now,
        );
    final within = now.add(const Duration(hours: 23)).millisecondsSinceEpoch;

    test('available without snooze => offer', () {
      expect(offer(), isTrue);
    });
    test('readyToInstall => offer', () {
      expect(offer(status: AppUpdateStatus.readyToInstall), isTrue);
    });
    test('same version snoozed within 24h => no offer', () {
      expect(offer(snoozedVersion: '0.9.0', snoozedUntilMs: within), isFalse);
    });
    test('same version after snooze expired => offer', () {
      expect(
        offer(
          snoozedVersion: '0.9.0',
          snoozedUntilMs:
              now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
        ),
        isTrue,
      );
    });
    test('newer version than the snoozed one => offer', () {
      expect(offer(snoozedVersion: '0.8.9', snoozedUntilMs: within), isTrue);
    });
    test('mandatory ignores the snooze', () {
      expect(
        offer(
          info: info.copyWith(mandatory: true),
          snoozedVersion: '0.9.0',
          snoozedUntilMs: within,
        ),
        isTrue,
      );
    });
    test('no info => no offer', () {
      expect(offer(info: null), isFalse);
    });
    for (final status in [
      AppUpdateStatus.idle,
      AppUpdateStatus.checking,
      AppUpdateStatus.upToDate,
      AppUpdateStatus.checkFailed,
      AppUpdateStatus.downloading,
      AppUpdateStatus.verifying,
      AppUpdateStatus.error,
    ]) {
      test('status ${status.name} => no offer', () {
        expect(offer(status: status), isFalse);
      });
    }
  });

  group('applyCheckResult', () {
    const info = AppUpdateInfo(
      version: '0.9.0',
      tag: 'v0.9.0',
      primaryUrl: 'https://yc/apk',
    );
    test('no update => upToDate without info', () {
      final s = applyCheckResult(
        const AppUpdateState(status: AppUpdateStatus.checking, info: info),
        null,
      );
      expect(s.status, AppUpdateStatus.upToDate);
      expect(s.info, isNull);
    });
    test('update => available, dismissed reset', () {
      final s = applyCheckResult(
        const AppUpdateState(status: AppUpdateStatus.checking, dismissed: true),
        info,
      );
      expect(s.status, AppUpdateStatus.available);
      expect(s.info, info);
      expect(s.dismissed, isFalse);
    });
    test('same version already readyToInstall stays readyToInstall', () {
      final s = applyCheckResult(
        const AppUpdateState(
          status: AppUpdateStatus.readyToInstall,
          info: info,
          progress: 1,
        ),
        info,
      );
      expect(s.status, AppUpdateStatus.readyToInstall);
    });
    test('newer version than the staged one => available', () {
      final s = applyCheckResult(
        const AppUpdateState(
            status: AppUpdateStatus.readyToInstall, info: info),
        info.copyWith(version: '0.9.1'),
      );
      expect(s.status, AppUpdateStatus.available);
      expect(s.info?.version, '0.9.1');
    });
  });
}
