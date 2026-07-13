// Regression lock for W3.2-min: corrupt persisted config must NEVER abort
// bootstrap. Before this guard, `Preferences.getConfig()` / `getClashConfig()`
// did a bare `json.decode` + `fromJson` (preferences.dart:27-44) with no catch,
// so a malformed / stale / partially-written blob threw before `runApp`
// (state.dart:202 `GlobalState.init()`) and killed the first frame — the
// upstream FlClash #2139 white-screen class.
//
// This test exercises the REAL decode/recovery path (only SharedPreferences is
// mocked, per `setMockInitialValues`). It asserts that for three corruption
// shapes — malformed JSON, JSON of the wrong top-level type, and
// schema-incompatible JSON that makes the generated `fromJson` throw — the
// getters recover: return null (so GlobalState boots the default Config),
// preserve the raw blob under a deterministic private backup key, best-effort
// quarantine it to a private file, and remove the bad active key so recovery
// is not repeated every launch. Valid configs are unchanged.

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/preferences.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The recovery path logs via `commonPrint`, which flows into `fileLogger`
  // and touches `appPath` (getApplicationSupportDirectory / temp / downloads).
  // Without the plugin those method channels throw MissingPluginException as
  // an unawaited async error that flutter_test attributes to the test. Fake
  // the path_provider channel with a temp dir so the log breadcrumb's
  // best-effort file write cannot surface a spurious failure. Recovery logic
  // itself stays entirely real (unmocked).
  final ppTemp = Directory.systemTemp.createTempSync('dropweb_pp');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => ppTemp.path,
  );
  // Set the mock store ONCE, before the lazy `preferences` singleton binds to
  // a SharedPreferences instance. The singleton caches that instance for its
  // lifetime, so the test MUST write through the exact same object (fetched
  // from the singleton's completer below) — a separate `getInstance()` after a
  // later `setMockInitialValues` would be a different instance the singleton
  // never reads.
  SharedPreferences.setMockInitialValues({});

  late SharedPreferences sp;
  late Directory quarantineDir;

  setUp(() async {
    // The exact SharedPreferences instance the `preferences` singleton uses.
    sp = (await preferences.sharedPreferencesCompleter.future)!;
    await sp.clear();

    quarantineDir = await Directory.systemTemp.createTemp('dropweb_quar_test');
    preferences.quarantineDirResolver = () async => quarantineDir;
  });

  tearDown(() async {
    preferences.quarantineDirResolver = Preferences.defaultQuarantineDir;
    if (quarantineDir.existsSync()) {
      quarantineDir.deleteSync(recursive: true);
    }
  });

  List<File> quarantineFiles() =>
      quarantineDir.listSync(recursive: true).whereType<File>().toList();

  group('getConfig() corruption recovery', () {
    test('malformed JSON: returns null, backs up + removes bad key', () async {
      const corrupt = '{ "profiles": [ , broken';
      await sp.setString(configKey, corrupt);

      final result = await preferences.getConfig();

      expect(result, isNull, reason: 'boots default Config');
      expect(sp.getString(configKey), isNull, reason: 'bad key removed');
      expect(sp.getString(configBackupKey), corrupt,
          reason: 'raw blob preserved verbatim for forensics');
      final files = quarantineFiles();
      expect(files, isNotEmpty, reason: 'best-effort private quarantine file');
      expect(files.first.readAsStringSync(), corrupt);
      // ASCII-only filename.
      expect(
          p.basename(files.first.path), matches(RegExp(r'^[0-9A-Za-z._-]+$')));
    });

    test('wrong top-level JSON type (array): recovers to null', () async {
      const corrupt = '[1, 2, 3]';
      await sp.setString(configKey, corrupt);

      final result = await preferences.getConfig();

      expect(result, isNull);
      expect(sp.getString(configKey), isNull);
      expect(sp.getString(configBackupKey), corrupt);
    });

    test('schema-incompatible JSON (fromJson throws): recovers to null',
        () async {
      // Valid JSON object, but `profiles` is a String where a List is
      // required — the generated `Config.fromJson` throws a TypeError that
      // `compatibleFromJson` does not catch.
      const corrupt = '{"profiles": "not-a-list", "currentProfileId": "p1"}';
      await sp.setString(configKey, corrupt);

      final result = await preferences.getConfig();

      expect(result, isNull);
      expect(sp.getString(configKey), isNull);
      expect(sp.getString(configBackupKey), corrupt);
    });

    test('valid config is unchanged and does NOT quarantine', () async {
      const config = Config(themeProps: defaultThemeProps);
      final valid = json.encode(config.copyWith(currentProfileId: 'keep-me'));
      await sp.setString(configKey, valid);

      final result = await preferences.getConfig();

      expect(result, isNotNull);
      expect(result!.currentProfileId, 'keep-me');
      expect(sp.getString(configKey), valid, reason: 'active key untouched');
      expect(sp.getString(configBackupKey), isNull, reason: 'no backup made');
      expect(quarantineFiles(), isEmpty);
    });

    test('null (never persisted) config returns null without side effects',
        () async {
      final result = await preferences.getConfig();
      expect(result, isNull);
      expect(sp.getString(configBackupKey), isNull);
      expect(quarantineFiles(), isEmpty);
    });
  });

  group('getClashConfig() corruption recovery', () {
    test('malformed JSON: returns null, backs up + removes bad key', () async {
      const corrupt = 'not json at all }{';
      await sp.setString(clashConfigKey, corrupt);

      final result = await preferences.getClashConfig();

      expect(result, isNull);
      expect(sp.getString(clashConfigKey), isNull);
      expect(sp.getString(clashConfigBackupKey), corrupt);
      expect(quarantineFiles(), isNotEmpty);
    });

    test('wrong top-level JSON type (string): recovers to null', () async {
      const corrupt = '"i am a bare string"';
      await sp.setString(clashConfigKey, corrupt);

      final result = await preferences.getClashConfig();

      expect(result, isNull);
      expect(sp.getString(clashConfigKey), isNull);
      expect(sp.getString(clashConfigBackupKey), corrupt);
    });

    test('schema-incompatible JSON (fromJson throws): recovers to null',
        () async {
      // `mixed-port` must be an int; a string makes the generated
      // `ClashConfig.fromJson` throw.
      const corrupt = '{"mixed-port": "notanumber"}';
      await sp.setString(clashConfigKey, corrupt);

      final result = await preferences.getClashConfig();

      expect(result, isNull);
      expect(sp.getString(clashConfigKey), isNull);
      expect(sp.getString(clashConfigBackupKey), corrupt);
    });

    test('valid clash config is unchanged and does NOT quarantine', () async {
      final valid = json.encode(defaultClashConfig.copyWith(allowLan: true));
      await sp.setString(clashConfigKey, valid);

      final result = await preferences.getClashConfig();

      expect(result, isNotNull);
      expect(result!.allowLan, isTrue);
      expect(sp.getString(clashConfigKey), valid);
      expect(sp.getString(clashConfigBackupKey), isNull);
      expect(quarantineFiles(), isEmpty);
    });
  });

  test('config + clash backups use distinct keys (no clobber)', () async {
    const badConfig = '{bad-config';
    const badClash = '{bad-clash';
    await sp.setString(configKey, badConfig);
    await sp.setString(clashConfigKey, badClash);

    await preferences.getConfig();
    await preferences.getClashConfig();

    expect(sp.getString(configBackupKey), badConfig);
    expect(sp.getString(clashConfigBackupKey), badClash);
    expect(configBackupKey, isNot(clashConfigBackupKey));
  });

  List<File> filesFor(String label) => quarantineDir
      .listSync()
      .whereType<File>()
      .where((f) => p.basename(f.path).contains('corrupt-$label-'))
      .toList();

  group('quarantine cleared on next successful persist', () {
    test('successful saveConfig prunes config backup key + file', () async {
      await sp.setString(configKey, '{corrupt-config');
      await preferences.getConfig();
      expect(sp.getString(configBackupKey), isNotNull);
      expect(filesFor('config'), isNotEmpty);

      final saved = await preferences.saveConfig(
        const Config(themeProps: defaultThemeProps),
      );

      expect(saved, isTrue);
      expect(sp.getString(configBackupKey), isNull,
          reason: 'backup retained only until the next successful save');
      expect(filesFor('config'), isEmpty,
          reason: 'config quarantine file pruned on successful save');
    });

    test('saveConfig does NOT touch an unrelated clash backup', () async {
      await sp.setString(configKey, '{bad-config');
      await sp.setString(clashConfigKey, '{bad-clash');
      await preferences.getConfig();
      await preferences.getClashConfig();
      expect(sp.getString(clashConfigBackupKey), '{bad-clash');

      await preferences.saveConfig(const Config(themeProps: defaultThemeProps));

      expect(sp.getString(clashConfigBackupKey), '{bad-clash',
          reason: 'a config save must not clear the clash backup');
      expect(filesFor('clash_config'), isNotEmpty);
    });

    test('clearClashConfig prunes clash backup + file, not config backup',
        () async {
      await sp.setString(configKey, '{bad-config');
      await sp.setString(clashConfigKey, '{bad-clash');
      await preferences.getConfig();
      await preferences.getClashConfig();
      expect(sp.getString(configBackupKey), '{bad-config');
      expect(sp.getString(clashConfigBackupKey), '{bad-clash');

      await preferences.clearClashConfig();

      expect(sp.getString(clashConfigBackupKey), isNull,
          reason: 'legacy migration finalize clears its own backup');
      expect(filesFor('clash_config'), isEmpty);
      expect(sp.getString(configBackupKey), '{bad-config',
          reason: 'unrelated config backup untouched');
      expect(filesFor('config'), isNotEmpty);
    });
  });

  group('quarantine files bounded to one per label', () {
    test('two config corruptions leave exactly one config file', () async {
      await sp.setString(configKey, '{first-corrupt');
      await preferences.getConfig();
      // Distinct wall-clock ms so the pre-fix timestamped filename would
      // leave TWO files — the bound must hold regardless.
      await Future<void>.delayed(const Duration(milliseconds: 8));
      await sp.setString(configKey, '{second-corrupt-longer');
      await preferences.getConfig();

      final files = filesFor('config');
      expect(files, hasLength(1),
          reason: 'retain only the latest quarantine file per label');
      expect(files.single.readAsStringSync(), '{second-corrupt-longer',
          reason: 'latest corruption overwrites the previous file');
    });

    test('two clash corruptions leave exactly one clash file', () async {
      await sp.setString(clashConfigKey, '{first');
      await preferences.getClashConfig();
      await Future<void>.delayed(const Duration(milliseconds: 8));
      await sp.setString(clashConfigKey, '{second');
      await preferences.getClashConfig();

      final files = filesFor('clash_config');
      expect(files, hasLength(1));
      expect(files.single.readAsStringSync(), '{second');
    });
  });
}
