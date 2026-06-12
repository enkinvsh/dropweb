import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Config legacy persisted keys', () {
    // Users upgrading from builds that persisted the removed WebDAV `dav`
    // block (Config) and `recoveryStrategy` (AppSettingProps) must keep
    // deserializing without an exception: json_serializable ignores unknown
    // keys (no disallowUnrecognizedKeys), and compatibleFromJson only remaps
    // accessControl/proxiesStyle. This test locks that property.
    test('fromJson tolerates removed dav + recoveryStrategy keys', () {
      final legacyAppSetting = const AppSettingProps().toJson()
        ..['recoveryStrategy'] = 'compatible';
      final legacy = <String, Object?>{
        'appSetting': legacyAppSetting,
        'profiles': const <Object?>[],
        'currentProfileId': 'p1',
        'overrideDns': false,
        'dav': {
          'uri': 'https://dav.example/old',
          'user': 'u',
          'password': 'p',
          'fileName': 'backup.zip',
        },
      };

      final config = Config.compatibleFromJson(legacy);
      expect(config.currentProfileId, 'p1');
      // Round-trip of the parsed object must not resurrect removed keys.
      final reserialized = config.toJson();
      expect(reserialized.containsKey('dav'), isFalse);
      // Config.toJson is not explicit_to_json — serialize the nested props
      // directly to assert the removed key cannot be re-emitted.
      expect(
        config.appSetting.toJson().containsKey('recoveryStrategy'),
        isFalse,
      );
    });
  });
}
