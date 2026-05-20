import 'package:dropweb/controller.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the auto-update eligibility decision.
///
/// Bug: migrated URL profiles store an empty plaintext `Profile.url` (the
/// real subscription URL lives in `SecureProfileUrlStore`). The previous
/// `autoUpdateProfiles()` skip used `profile.type == ProfileType.file`,
/// which is derived from `url.isEmpty`, so migrated URL profiles were
/// misclassified as file profiles and never auto-updated.
///
/// The helper takes the already-resolved URL (from
/// `preferences.getProfileUrl(profile)`) so the distinction is based on
/// what we can actually fetch, not the in-memory plaintext field.
void main() {
  group('controller.shouldAutoUpdateProfile', () {
    final now = DateTime(2026, 5, 20, 12);
    final dueLastUpdate = now.subtract(const Duration(hours: 2));
    final freshLastUpdate = now.subtract(const Duration(minutes: 5));

    Profile makeProfile({
      String url = '',
      bool autoUpdate = true,
      DateTime? lastUpdateDate,
      Duration autoUpdateDuration = const Duration(hours: 1),
    }) =>
        Profile(
          id: 'p1',
          url: url,
          autoUpdate: autoUpdate,
          lastUpdateDate: lastUpdateDate,
          autoUpdateDuration: autoUpdateDuration,
        );

    test(
        'migrated URL profile (plaintext url empty, resolved URL from secure '
        'store) is eligible when due', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(lastUpdateDate: dueLastUpdate),
          now: now,
          resolvedUrl: 'https://example.com/sub',
        ),
        isTrue,
      );
    });

    test('real file profile (no resolved URL) is skipped', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(lastUpdateDate: dueLastUpdate),
          now: now,
          resolvedUrl: null,
        ),
        isFalse,
      );
    });

    test('empty resolved URL is treated as file profile and skipped', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(lastUpdateDate: dueLastUpdate),
          now: now,
          resolvedUrl: '',
        ),
        isFalse,
      );
    });

    test('autoUpdate disabled is skipped even when due', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(
            autoUpdate: false,
            lastUpdateDate: dueLastUpdate,
          ),
          now: now,
          resolvedUrl: 'https://example.com/sub',
        ),
        isFalse,
      );
    });

    test('profile not yet due is skipped', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(lastUpdateDate: freshLastUpdate),
          now: now,
          resolvedUrl: 'https://example.com/sub',
        ),
        isFalse,
      );
    });

    test('profile never updated yet is eligible', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(lastUpdateDate: null),
          now: now,
          resolvedUrl: 'https://example.com/sub',
        ),
        isTrue,
      );
    });

    test(
        'legacy URL profile (plaintext url still present, resolved URL '
        'matches) is eligible when due', () {
      expect(
        shouldAutoUpdateProfile(
          profile: makeProfile(
            url: 'https://example.com/sub',
            lastUpdateDate: dueLastUpdate,
          ),
          now: now,
          resolvedUrl: 'https://example.com/sub',
        ),
        isTrue,
      );
    });
  });
}
