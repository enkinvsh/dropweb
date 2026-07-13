// Transactional lock for W3.2-min N1: GlobalState.migrateOldData must fold the
// legacy `clash_config` into the LIVE `globalState.config`, successfully await
// persisting the merged Config, and ONLY THEN clear the legacy active key +
// clash quarantine. The previous implementation reassigned its local parameter
// (never updating live state) and fired save/clear UNAWAITED — a data-
// consistency bug where a write failure could silently lose the merged patch,
// and clear could race ahead of save.
//
// These tests drive the REAL Preferences recovery path (only SharedPreferences
// + path_provider are mocked) so decode/quarantine/clear logic is exercised for
// real, not mocked. GlobalState is not "too coupled" here: migrateOldData only
// touches Preferences and the flat `globalState.config` mirror, so it is called
// directly rather than mocking internals.

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/preferences.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Recovery logs flow through fileLogger → appPath (path_provider). Fake the
  // channel so a best-effort log write can't surface a MissingPluginException.
  final ppTemp = Directory.systemTemp.createTempSync('dropweb_pp_mig');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => ppTemp.path,
  );
  // Bind the singleton to the mock store once (see recovery test rationale).
  SharedPreferences.setMockInitialValues({});

  late SharedPreferences sp;
  late Directory quarantineDir;

  setUp(() async {
    sp = (await preferences.sharedPreferencesCompleter.future)!;
    await sp.clear();
    quarantineDir = await Directory.systemTemp.createTemp('dropweb_mig_quar');
    preferences.quarantineDirResolver = () async => quarantineDir;
    // Establish a known live config (the field is `late`).
    globalState.config = const Config(themeProps: defaultThemeProps);
  });

  tearDown(() async {
    preferences.quarantineDirResolver = Preferences.defaultQuarantineDir;
    if (quarantineDir.existsSync()) {
      quarantineDir.deleteSync(recursive: true);
    }
  });

  List<File> clashQuarantineFiles() => quarantineDir
      .listSync()
      .whereType<File>()
      .where((f) => p.basename(f.path).contains('clash_config'))
      .toList();

  test('valid legacy clash_config: merges into live config, persists, clears',
      () async {
    final base = const Config(themeProps: defaultThemeProps)
        .copyWith(currentProfileId: 'main');
    // A non-default clash flag proves the merge actually happened.
    await sp.setString(
      clashConfigKey,
      json.encode(defaultClashConfig.copyWith(allowLan: true)),
    );

    await globalState.migrateOldData(base);

    // 1. The LIVE mirror is updated with the merged patch (not a local copy).
    expect(globalState.config.patchClashConfig.allowLan, isTrue);
    expect(globalState.config.currentProfileId, 'main');
    // 2. The merged Config was persisted to the main key.
    final persisted = Config.compatibleFromJson(
      json.decode(sp.getString(configKey)!) as Map<String, dynamic>,
    );
    expect(persisted.patchClashConfig.allowLan, isTrue);
    expect(persisted.currentProfileId, 'main');
    // 3. The legacy active key is cleared only after the successful save,
    //    and no clash backup lingers.
    expect(sp.getString(clashConfigKey), isNull);
    expect(sp.getString(clashConfigBackupKey), isNull);
  });

  test(
      'corrupt legacy clash_config: quarantined, then cleared after checkpoint',
      () async {
    final base = const Config(themeProps: defaultThemeProps)
        .copyWith(currentProfileId: 'main');
    await sp.setString(clashConfigKey, '{corrupt-clash');

    await globalState.migrateOldData(base);

    // getClashConfig quarantined the blob and removed the active key; migration
    // then checkpoint-saved the valid main Config and dropped the legacy backup
    // + file so lower-sensitivity legacy data is not retained forever.
    expect(sp.getString(clashConfigKey), isNull);
    expect(sp.getString(clashConfigBackupKey), isNull,
        reason: 'legacy backup dropped after a successful recovery checkpoint');
    expect(clashQuarantineFiles(), isEmpty);
    // The checkpoint persisted the current valid main Config.
    expect(sp.getString(configKey), isNotNull);
  });

  test('no legacy key and no backup: no unnecessary writes', () async {
    await globalState.migrateOldData(
      const Config(themeProps: defaultThemeProps),
    );

    expect(sp.getString(configKey), isNull,
        reason: 'nothing to migrate → no save');
    expect(sp.getString(clashConfigBackupKey), isNull);
    expect(clashQuarantineFiles(), isEmpty);
  });
}
