import 'dart:convert';

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Minimal JSON for a Profile. `id` and `autoUpdateDuration` are the only
  // required fields; everything else defaults.
  Map<String, Object?> baseJson() => {
        'id': 'profile-a',
        'autoUpdateDuration': const Duration(hours: 12).inMicroseconds,
      };

  group('Profile WorkMode fields', () {
    test('old profile JSON (no mode keys) migrates to standard with null '
        'static fields', () {
      final profile = Profile.fromJson(baseJson());

      expect(profile.workMode, WorkMode.standard);
      expect(profile.staticCountry, isNull);
    });

    test('toJson/fromJson roundtrip preserves workMode + static fields', () {
      final original = Profile.fromJson(baseJson()).copyWith(
        workMode: WorkMode.country,
        staticCountry: 'NL',
      );

      // Roundtrip through the real persistence path: profiles are stored as
      // JSON strings, so nested freezed objects are resolved by jsonEncode's
      // recursive toEncodable rather than by a bare fromJson(toJson()).
      final restored = Profile.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );

      expect(restored.workMode, WorkMode.country);
      expect(restored.staticCountry, 'NL');
      expect(restored, original);
    });

    test('unknown workMode string degrades to standard', () {
      final json = baseJson()..['workMode'] = 'teleport';

      final profile = Profile.fromJson(json);

      expect(profile.workMode, WorkMode.standard);
    });
  });
}
