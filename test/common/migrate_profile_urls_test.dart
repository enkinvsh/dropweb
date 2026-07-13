// Regression lock for W3.4-A: the one-time plaintext→encrypted subscription-URL
// migration must be TRANSACTIONAL. Before this guard,
// `Preferences.migrateProfileUrlsIfNeeded` called `markMigrated()`
// UNCONDITIONALLY (preferences.dart:247), before and independent of the
// stripped-config save and regardless of whether the per-profile secure writes
// succeeded — so a transient KeyStore failure could flip the "migrated" marker
// while a profile's URL was neither in the secure store nor in the stripped
// Config: permanent subscription-URL loss. It also did a bare `json.decode`
// (preferences.dart:230) that could crash the deferred post-frame task.
//
// These tests inject a fake secure store (no real KeyStore) and a raw-config
// writer seam, and assert the invariant: the marker is set ONLY after every
// required per-profile write succeeds AND the stripped Config is durably
// persisted AND the marker itself reads back; any partial failure keeps the
// failed profile's plaintext in Config with the marker false, so the next run
// safely retries.

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/preferences.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SecureProfileUrlStoreInterface] with fault injection — stands in
/// for the real KeyStore-backed store in unit tests.
class FakeSecureStore implements SecureProfileUrlStoreInterface {
  final Map<String, String> urls = {};
  final Map<String, String> fallbacks = {};
  bool migrated = false;

  /// Profile ids whose [setUrl] must fail (simulated KeyStore write failure).
  final Set<String> failUrlFor = {};

  /// Profile ids whose [setFallbackUrl] must fail.
  final Set<String> failFallbackFor = {};

  /// When true, [markMigrated] fails its write/readback and returns false.
  bool failMarkMigrated = false;

  int markMigratedCalls = 0;

  @override
  Future<String?> getUrl(String profileId) async => urls[profileId];

  @override
  Future<String?> getFallbackUrl(String profileId) async =>
      fallbacks[profileId];

  @override
  Future<bool> setUrl(String profileId, String? url) async {
    if (failUrlFor.contains(profileId)) return false;
    if (url == null || url.isEmpty) {
      urls.remove(profileId);
      return true;
    }
    urls[profileId] = url;
    return true;
  }

  @override
  Future<bool> setFallbackUrl(String profileId, String? url) async {
    if (failFallbackFor.contains(profileId)) return false;
    if (url == null || url.isEmpty) {
      fallbacks.remove(profileId);
      return true;
    }
    fallbacks[profileId] = url;
    return true;
  }

  @override
  Future<void> removeProfile(String profileId) async {
    urls.remove(profileId);
    fallbacks.remove(profileId);
  }

  @override
  Future<bool> isMigrated() async => migrated;

  @override
  Future<bool> markMigrated() async {
    markMigratedCalls++;
    if (failMarkMigrated) return false;
    migrated = true;
    return true;
  }
}

Profile _profile(String id, {String url = '', String? fallbackUrl}) => Profile(
      id: id,
      url: url,
      fallbackUrl: fallbackUrl,
      autoUpdateDuration: defaultUpdateDuration,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider is touched by the quarantine/log breadcrumb path.
  final ppTemp = Directory.systemTemp.createTempSync('dropweb_pp_mig');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => ppTemp.path,
  );

  SharedPreferences.setMockInitialValues({});

  late SharedPreferences sp;
  late FakeSecureStore fake;

  setUp(() async {
    sp = (await preferences.sharedPreferencesCompleter.future)!;
    await sp.clear();
    fake = FakeSecureStore();
    preferences.secureStore = fake;
    preferences.rawStringWriter =
        (prefs, key, value) => prefs.setString(key, value);
  });

  tearDown(() {
    preferences.secureStore = secureProfileUrlStore;
    preferences.rawStringWriter = Preferences.defaultRawStringWriter;
  });

  Future<void> seedConfig(List<Profile> profiles) async {
    final config = Config(
      themeProps: defaultThemeProps,
      profiles: profiles,
    );
    await sp.setString(configKey, json.encode(config));
  }

  Config readConfig() =>
      Config.compatibleFromJson(json.decode(sp.getString(configKey)!));

  String? urlOf(String id) =>
      readConfig().profiles.firstWhere((p) => p.id == id).url;
  String? fbOf(String id) =>
      readConfig().profiles.firstWhere((p) => p.id == id).fallbackUrl;

  test('all writes succeed: marks migrated, strips every URL', () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub'),
      _profile('b', url: 'https://b.example/sub', fallbackUrl: 'https://b.fb'),
    ]);

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isTrue, reason: 'complete success marks migrated');
    expect(fake.urls['a'], 'https://a.example/sub');
    expect(fake.urls['b'], 'https://b.example/sub');
    expect(fake.fallbacks['b'], 'https://b.fb');
    expect(urlOf('a'), '', reason: 'plaintext stripped after secure write');
    expect(urlOf('b'), '');
    expect(fbOf('b'), isNull);
  });

  test('one profile URL write fails: marker stays false, its plaintext kept',
      () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub'),
      _profile('b', url: 'https://b.example/sub'),
    ]);
    fake.failUrlFor.add('b');

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isFalse, reason: 'partial failure ≠ migrated');
    // 'a' migrated and may be stripped; 'b' plaintext MUST remain.
    expect(fake.urls['a'], 'https://a.example/sub');
    expect(fake.urls.containsKey('b'), isFalse);
    expect(urlOf('b'), 'https://b.example/sub',
        reason: 'failed profile keeps plaintext for the next retry');
  });

  test('fallback write fails: profile not stripped, marker false', () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub', fallbackUrl: 'https://a.fb'),
    ]);
    fake.failFallbackFor.add('a');

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isFalse);
    expect(urlOf('a'), 'https://a.example/sub',
        reason: 'a partial (url ok, fallback failed) write must not strip');
    expect(fbOf('a'), 'https://a.fb');
  });

  test('config persistence failure: marker stays false, no data loss',
      () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub'),
    ]);
    // The stripped-config write fails durably.
    preferences.rawStringWriter = (prefs, key, value) async => false;

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isFalse,
        reason:
            'cannot mark migrated when the stripped config did not persist');
    // Config on disk is unchanged (write returned false) → plaintext intact.
    expect(urlOf('a'), 'https://a.example/sub');
  });

  test('marker write/readback fails: stays unmigrated for next run', () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub'),
    ]);
    fake.failMarkMigrated = true;

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isFalse, reason: 'marker readback failed');
    expect(fake.markMigratedCalls, greaterThan(0));
    // URL is safely in the secure store; the stripped config persisted; only
    // the marker did not stick, so the next run re-runs harmlessly.
    expect(fake.urls['a'], 'https://a.example/sub');
  });

  test('retry after partial success completes the migration', () async {
    await seedConfig([
      _profile('a', url: 'https://a.example/sub'),
      _profile('b', url: 'https://b.example/sub'),
    ]);
    // First run: 'b' fails.
    fake.failUrlFor.add('b');
    await preferences.migrateProfileUrlsIfNeeded();
    expect(fake.migrated, isFalse);
    expect(urlOf('b'), 'https://b.example/sub');

    // Second run: KeyStore recovered.
    fake.failUrlFor.clear();
    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isTrue, reason: 'retry finishes the migration');
    expect(fake.urls['b'], 'https://b.example/sub');
    expect(urlOf('a'), '');
    expect(urlOf('b'), '');
  });

  test('empty/no config: marks migrated only via marker readback', () async {
    // No config key set at all.
    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isTrue);
    expect(fake.markMigratedCalls, 1);
  });

  test('already migrated: no-op, no marker rewrite', () async {
    fake.migrated = true;
    await seedConfig([_profile('a', url: 'https://a.example/sub')]);

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.markMigratedCalls, 0, reason: 'short-circuits on isMigrated');
    expect(urlOf('a'), 'https://a.example/sub', reason: 'no restrip');
  });

  test('corrupt config decodes via safe path (no bare json.decode crash)',
      () async {
    await sp.setString(configKey, '{ broken json ,,');

    // Must NOT throw — the deferred post-frame task cannot be allowed to crash.
    await preferences.migrateProfileUrlsIfNeeded();

    // The corrupt active config was quarantined into configBackupKey. A future
    // recovery may reinject plaintext URLs that still need migrating, so the
    // one-time marker MUST stay false — completing here would strand those URLs.
    expect(fake.migrated, isFalse,
        reason: 'quarantined config ⇒ migration not complete');
    expect(fake.markMigratedCalls, 0,
        reason: 'must not even attempt to complete on a quarantined config');
    expect(sp.getString(configBackupKey), '{ broken json ,,',
        reason: 'used the existing quarantine path (backup preserved)');
  });

  test('truly-absent config (no active, no backup) marks migrated', () async {
    // Neither an active config nor a quarantine backup exists → nothing to
    // migrate now or later → safe to complete the one-time migration.
    expect(sp.getString(configKey), isNull);
    expect(sp.getString(configBackupKey), isNull);

    await preferences.migrateProfileUrlsIfNeeded();

    expect(fake.migrated, isTrue);
    expect(fake.markMigratedCalls, 1);
  });
}
