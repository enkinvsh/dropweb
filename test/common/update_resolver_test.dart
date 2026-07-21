import 'package:dropweb/common/update_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> manifest(
  String v, {
  String? sha,
  Object? build,
}) =>
    {
      'version': v,
      if (build != null) 'build': build,
      'notes': ['fix A', 'fix B'],
      'platforms': {
        'android-arm64': {
          'url':
              'https://storage.yandexcloud.net/dropweb-downloads/latest/dropweb-arm64-v8a.apk',
          if (sha != null) 'sha256': sha,
        },
        'android-universal': {
          'url':
              'https://storage.yandexcloud.net/dropweb-downloads/latest/dropweb-universal.apk',
          if (sha != null) 'sha256': sha,
        },
      },
    };

void main() {
  group('resolveAndroidUpdate — platform key + fallback URL', () {
    test('default platform key resolves android-universal (primary + fallback)',
        () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.2', sha: 'deadbeef'),
        localVersion: '0.8.1',
      );
      expect(info, isNotNull);
      expect(info!.version, '0.8.2');
      expect(info.tag, 'v0.8.2');
      expect(info.primaryUrl, contains('dropweb-universal.apk'));
      expect(
        info.fallbackUrl,
        'https://github.com/enkinvsh/dropweb/releases/download/v0.8.2/dropweb-0.8.2-android-universal.apk',
      );
      expect(info.sha256, 'deadbeef');
      expect(info.notes, ['fix A', 'fix B']);
    });

    test('explicit android-arm64 platform key still valid (arm64 fallback URL)',
        () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.2', sha: 'deadbeef'),
        localVersion: '0.8.1',
        platformKey: 'android-arm64',
      );
      expect(info, isNotNull);
      expect(info!.primaryUrl, contains('dropweb-arm64-v8a.apk'));
      expect(
        info.fallbackUrl,
        'https://github.com/enkinvsh/dropweb/releases/download/v0.8.2/dropweb-0.8.2-android-arm64-v8a.apk',
      );
    });

    test('versioned GitHub fallback URL for android-universal (explicit)', () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.5'),
        localVersion: '0.8.1',
        platformKey: 'android-universal',
      );
      expect(info, isNotNull);
      expect(
        info!.fallbackUrl,
        'https://github.com/enkinvsh/dropweb/releases/download/v0.8.5/dropweb-0.8.5-android-universal.apk',
      );
    });

    test('missing requested platform => null', () {
      expect(
        resolveAndroidUpdate(
          manifest: {'version': '9.9.9', 'platforms': {}},
          localVersion: '0.8.1',
        ),
        isNull,
      );
    });

    test('sha256 lowercased; mandatory + minSupported parsed', () {
      final m = manifest('0.8.2', sha: 'DEADBEEF')
        ..addAll({'mandatory': true, 'minSupported': '0.8.0'});
      final info = resolveAndroidUpdate(manifest: m, localVersion: '0.8.1');
      expect(info!.sha256, 'deadbeef');
      expect(info.mandatory, isTrue);
      expect(info.minSupported, '0.8.0');
    });
  });

  group('resolveAndroidUpdate — build (versionCode) governs eligibility', () {
    // When BOTH manifest.build and installed buildNumber are valid positive
    // ints, the Android versionCode governs. Marketing semver is display/tag
    // data only and must NOT influence install ordering.

    test('same version + higher remote build => available', () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.5', build: 2050000001),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(info, isNotNull);
      expect(info!.version, '0.8.5');
      expect(info.build, 2050000001);
    });

    test('higher version + LOWER remote build => null (build governs)', () {
      expect(
        resolveAndroidUpdate(
          manifest: manifest('9.9.9', build: 100),
          localVersion: '0.8.5',
          localBuild: '2050000000',
        ),
        isNull,
      );
    });

    test('higher version + EQUAL remote build => null (build governs)', () {
      expect(
        resolveAndroidUpdate(
          manifest: manifest('9.9.9', build: 2050000000),
          localVersion: '0.8.5',
          localBuild: '2050000000',
        ),
        isNull,
      );
    });

    test('lower version + higher remote build => available (build governs)',
        () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.1', build: 2050000001),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(info, isNotNull);
      expect(info!.build, 2050000001);
      // version is display-only, reflects the (lower) marketing version.
      expect(info.version, '0.8.1');
    });
  });

  group('resolveAndroidUpdate — semver fallback when build unusable', () {
    test('missing build => semver fallback (newer semver offered)', () {
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.6'),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(info, isNotNull);
      expect(info!.build, isNull);
    });

    test('missing build + older semver => null', () {
      expect(
        resolveAndroidUpdate(
          manifest: manifest('0.8.4'),
          localVersion: '0.8.5',
          localBuild: '2050000000',
        ),
        isNull,
      );
    });

    test('malformed remote build (string) => semver fallback', () {
      final newer = resolveAndroidUpdate(
        manifest: manifest('0.8.6', build: 'abc'),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(newer, isNotNull);
      final older = resolveAndroidUpdate(
        manifest: manifest('0.8.4', build: 'abc'),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(older, isNull);
    });

    test('zero remote build => treated as missing (semver fallback)', () {
      final older = resolveAndroidUpdate(
        manifest: manifest('0.8.4', build: 0),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(older, isNull);
    });

    test('negative remote build => treated as missing (semver fallback)', () {
      final older = resolveAndroidUpdate(
        manifest: manifest('0.8.4', build: -5),
        localVersion: '0.8.5',
        localBuild: '2050000000',
      );
      expect(older, isNull);
    });

    test(
        'invalid local build => conservative semver fallback despite valid remote build',
        () {
      // Remote build is higher, but local build is unparseable, so we CANNOT
      // trust versionCode ordering => fall back to semver. semver 0.8.4 <= 0.8.5
      // => not offered.
      expect(
        resolveAndroidUpdate(
          manifest: manifest('0.8.4', build: 2050000001),
          localVersion: '0.8.5',
          localBuild: 'not-a-number',
        ),
        isNull,
      );
      // …and a newer semver IS offered through the same fallback path.
      final info = resolveAndroidUpdate(
        manifest: manifest('0.8.6', build: 2050000001),
        localVersion: '0.8.5',
        localBuild: 'not-a-number',
      );
      expect(info, isNotNull);
    });

    test('null local build => semver fallback', () {
      expect(
        resolveAndroidUpdate(
          manifest: manifest('0.8.4', build: 2050000001),
          localVersion: '0.8.5',
        ),
        isNull,
      );
    });
  });

  group('resolveAndroidUpdate — misc guards', () {
    test('empty/absent remote version => null', () {
      expect(
        resolveAndroidUpdate(
          manifest: {'platforms': {}},
          localVersion: '0.8.1',
        ),
        isNull,
      );
    });
  });
}
