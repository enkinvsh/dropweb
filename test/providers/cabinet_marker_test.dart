import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profileHasCabinetMarker', () {
    test('enables cabinet for dropweb-cabinet: cabinet', () {
      const profile = Profile(
        id: 'profile-ascii-cabinet',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-cabinet': 'cabinet',
        },
      );

      expect(profileHasCabinetMarker(profile), isTrue);
    });

    test('enables cabinet for dropweb-cabinet: true', () {
      const profile = Profile(
        id: 'profile-ascii-true',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-cabinet': 'true',
        },
      );

      expect(profileHasCabinetMarker(profile), isTrue);
    });

    test('accepts other truthy ASCII values', () {
      for (final value in const ['1', 'yes', 'enabled', 'TRUE', ' Cabinet ']) {
        final profile = Profile(
          id: 'profile-truthy-$value',
          autoUpdateDuration: Duration.zero,
          providerHeaders: {'dropweb-cabinet': value},
        );
        expect(
          profileHasCabinetMarker(profile),
          isTrue,
          reason: 'value "$value" should enable cabinet',
        );
      }
    });

    test('does not enable cabinet for dropweb-cabinet: false', () {
      const profile = Profile(
        id: 'profile-false',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-cabinet': 'false',
        },
      );

      expect(profileHasCabinetMarker(profile), isFalse);
    });

    test('detects legacy Cyrillic cabinet marker in dropweb-cabinet header', () {
      const profile = Profile(
        id: 'profile-legacy-cyrillic',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-cabinet': 'кабинет',
        },
      );

      expect(profileHasCabinetMarker(profile), isTrue);
    });

    test('detects legacy Cyrillic cabinet marker in any provider header', () {
      const profile = Profile(
        id: 'profile-legacy-any-header',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-mode': 'FOCUS Кабинет',
        },
      );

      expect(profileHasCabinetMarker(profile), isTrue);
    });

    test('ignores profiles without cabinet marker', () {
      const profile = Profile(
        id: 'profile-clean',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-mode': 'ordinary vpn',
          'announce': 'service status',
          'dropweb-servicename': 'svc',
          'dropweb-background': 'https://example.com/bg.png',
        },
      );

      expect(profileHasCabinetMarker(profile), isFalse);
      expect(profileHasCabinetMarker(null), isFalse);
    });

    test('non-cabinet dropweb-* headers must not enable cabinet', () {
      const profile = Profile(
        id: 'profile-other-dropweb-headers',
        autoUpdateDuration: Duration.zero,
        providerHeaders: {
          'dropweb-globalmode': 'true',
          'dropweb-servicename': 'cabinet-service',
          'dropweb-background': 'cabinet.png',
        },
      );

      expect(profileHasCabinetMarker(profile), isFalse);
    });
  });
}
