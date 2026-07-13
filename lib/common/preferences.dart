import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';
import 'path.dart';
import 'print.dart';
import 'secure_profile_store.dart';

class Preferences {
  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, __) => sharedPreferencesCompleter.complete(null));
  }
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  /// Resolves the app-private directory used to quarantine unreadable persisted
  /// blobs. Overridable in tests; production resolves via [AppPath], bounded so
  /// a slow/blocked platform channel can never delay recovery. Returns null
  /// when the directory can't be obtained — quarantine-to-file is then skipped
  /// (best-effort), and recovery still removes the bad key and boots defaults.
  @visibleForTesting
  Future<Directory?> Function() quarantineDirResolver = defaultQuarantineDir;

  @visibleForTesting
  static Future<Directory?> defaultQuarantineDir() async {
    try {
      final dir =
          await appPath.dataDir.future.timeout(const Duration(seconds: 2));
      return Directory(p.join(dir.path, "quarantine"));
    } catch (_) {
      return null;
    }
  }

  /// Deterministic ASCII filename for the single retained quarantine copy per
  /// label. A fixed name (not a timestamp) bounds the directory to exactly one
  /// file per label — a fresh corruption overwrites the previous copy, and the
  /// file's mtime carries the "when". [label] is a fixed ASCII token
  /// ('config' / 'clash_config').
  static String _quarantineFileName(String label) =>
      'corrupt-$label-latest.txt';

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return null;
    final clashConfigString = preferences.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    try {
      final decoded = json.decode(clashConfigString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('clash config root is not a JSON object');
      }
      return ClashConfig.fromJson(decoded);
    } catch (e) {
      // NEVER let a corrupt/stale/partially-written blob throw before runApp
      // (state.dart:516 migrateOldData ← GlobalState.init). Quarantine and
      // fall back to the default ClashConfig (patchClashConfig default).
      await _quarantineCorrupt(
        preferences: preferences,
        activeKey: clashConfigKey,
        backupKey: clashConfigBackupKey,
        rawValue: clashConfigString,
        label: 'clash_config',
        error: e,
      );
      return null;
    }
  }

  /// Loads Config (without URLs — those are in [SecureProfileUrlStore],
  /// fetched lazily via [getProfileUrl] to keep startup free of Keystore IPC).
  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return null;
    final configString = preferences.getString(configKey);
    if (configString == null) return null;
    try {
      final decoded = json.decode(configString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('config root is not a JSON object');
      }
      return Config.compatibleFromJson(decoded);
    } catch (e) {
      // NEVER let a corrupt/stale/partially-written blob throw before runApp
      // (state.dart:204 GlobalState.init). Quarantine the unreadable blob and
      // return null so GlobalState boots the existing default Config. This is
      // the FlClash #2139 white-screen class; the post-frame repair dialog
      // only covers SharedPreferences==null, not a decode/schema failure.
      await _quarantineCorrupt(
        preferences: preferences,
        activeKey: configKey,
        backupKey: configBackupKey,
        rawValue: configString,
        label: 'config',
        error: e,
      );
      return null;
    }
  }

  /// Preserves an unreadable persisted blob and removes the bad active key so
  /// recovery does not repeat on every launch. Every step is individually
  /// best-effort: a failure in any one (SharedPreferences write, filesystem,
  /// logging) must still let recovery complete and the app boot defaults.
  ///
  /// SECURITY: the raw blob may contain a subscription URL/token, so it is
  /// NEVER logged. Only the byte length and the error's runtime type are
  /// logged — the decode error's message can itself echo raw source, so the
  /// message text is deliberately not emitted.
  Future<void> _quarantineCorrupt({
    required SharedPreferences preferences,
    required String activeKey,
    required String backupKey,
    required String rawValue,
    required String label,
    required Object error,
  }) async {
    // 1. Preserve the raw blob in a deterministic, bounded (latest-only)
    //    private backup key. Overwrites any prior backup — no key accumulation.
    try {
      await preferences.setString(backupKey, rawValue);
    } catch (_) {}

    // 2. Best-effort copy in the single deterministic per-label file under
    //    app-private support storage (overwrites any prior copy; mtime = when).
    await _writeQuarantineFile(label, rawValue);

    // 3. Remove the bad active key so the next launch reads null and boots
    //    defaults instead of re-entering recovery.
    try {
      await preferences.remove(activeKey);
    } catch (_) {}

    // 4. Redaction-safe breadcrumb (no raw contents, no error message text).
    try {
      commonPrint.log(
        '[preferences] quarantined corrupt $label '
        '(${rawValue.length} bytes, ${error.runtimeType}); booting defaults',
      );
    } catch (_) {}
  }

  /// Writes the raw blob to the single deterministic ASCII-named file for
  /// [label] under app-private application-support storage. Overwrites any
  /// prior copy so the directory holds AT MOST one file per label. Fully
  /// best-effort and bounded: a null directory or any filesystem error is
  /// swallowed so recovery never aborts.
  Future<void> _writeQuarantineFile(String label, String rawValue) async {
    try {
      final dir = await quarantineDirResolver();
      if (dir == null) return;
      final file = File(p.join(dir.path, _quarantineFileName(label)));
      await file.parent.create(recursive: true);
      await file.writeAsString(rawValue, flush: true);
    } catch (_) {
      // A filesystem error must still lead to booting defaults.
    }
  }

  /// Drops a quarantined blob once its owning config is successfully persisted
  /// again: removes the private backup key and deletes the label's quarantine
  /// file. This bounds secret retention — the raw blob survives only until the
  /// next good save/migration, long enough for support to recover a failed
  /// boot. Best-effort and scoped to [label] alone; unrelated backups are
  /// never touched.
  Future<void> _clearQuarantine(
    SharedPreferences preferences,
    String backupKey,
    String label,
  ) async {
    try {
      await preferences.remove(backupKey);
    } catch (_) {}
    try {
      final dir = await quarantineDirResolver();
      if (dir == null) return;
      final file = File(p.join(dir.path, _quarantineFileName(label)));
      // Synchronous existence probe: avoid_slow_async_io flags async exists().
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Pruning is best-effort; a leftover file must not fail the save.
    }
  }

  /// Profile URL from encrypted store; falls back to in-memory copy if
  /// migration hasn't run yet. Tolerate keystore being slow right after boot.
  Future<String?> getProfileUrl(Profile profile) async {
    final fromStore = await secureProfileUrlStore.getUrl(profile.id);
    if (fromStore != null && fromStore.isNotEmpty) return fromStore;
    return profile.url.isEmpty ? null : profile.url;
  }

  Future<String?> getProfileFallbackUrl(Profile profile) async {
    final fromStore = await secureProfileUrlStore.getFallbackUrl(profile.id);
    if (fromStore != null && fromStore.isNotEmpty) return fromStore;
    return profile.fallbackUrl;
  }

  /// One-time move of plaintext URLs into encrypted store. Idempotent.
  /// MUST run post-frame so a slow keystore can't keep the splash on screen.
  Future<void> migrateProfileUrlsIfNeeded() async {
    if (await secureProfileUrlStore.isMigrated()) return;

    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return;
    final configString = preferences.getString(configKey);
    if (configString == null) {
      await secureProfileUrlStore.markMigrated();
      return;
    }

    final config = Config.compatibleFromJson(json.decode(configString));
    var wrotePlaintext = false;
    final stripIds = <String>{};
    for (final profile in config.profiles) {
      var ok = true;
      if (profile.url.isNotEmpty) {
        ok = await secureProfileUrlStore.setUrl(profile.id, profile.url);
        wrotePlaintext = true;
      }
      final fb = profile.fallbackUrl;
      if (fb != null && fb.isNotEmpty) {
        final fbOk = await secureProfileUrlStore.setFallbackUrl(profile.id, fb);
        ok = ok && fbOk;
        wrotePlaintext = true;
      }
      if (ok) stripIds.add(profile.id);
    }
    await secureProfileUrlStore.markMigrated();
    if (wrotePlaintext) {
      await _writeConfigStripped(config, preferences, stripIds);
    }
  }

  /// Persist Config — URLs go to the encrypted store, JSON blob is stripped.
  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return false;

    final stripIds = <String>{};
    for (final profile in config.profiles) {
      var ok = true;
      if (profile.url.isNotEmpty) {
        ok = await secureProfileUrlStore.setUrl(profile.id, profile.url);
      }
      if (profile.fallbackUrl != null && profile.fallbackUrl!.isNotEmpty) {
        final fbOk = await secureProfileUrlStore.setFallbackUrl(
          profile.id,
          profile.fallbackUrl,
        );
        ok = ok && fbOk;
      }
      // Strip the plaintext URL only after it is safely in the encrypted store,
      // so a transient keystore failure cannot lose the subscription URL.
      if (ok) stripIds.add(profile.id);
    }

    final saved = await _writeConfigStripped(config, preferences, stripIds);
    if (saved) {
      // The Config now persists cleanly again — drop any prior corrupt-Config
      // backup so secrets are not retained past the first good save. Scoped to
      // the Config quarantine only; a stale clash backup is left intact.
      await _clearQuarantine(preferences, configBackupKey, 'config');
    }
    return saved;
  }

  /// Writes Config with empty url/fallbackUrl. Callers MUST first sync the
  /// real values to [secureProfileUrlStore] or the data is lost.
  Future<bool> _writeConfigStripped(
    Config config,
    SharedPreferences preferences,
    Set<String> stripIds,
  ) async {
    final strippedProfiles = config.profiles
        .map(
          (p) => stripIds.contains(p.id)
              ? p.copyWith(
                  url: '',
                  fallbackUrl: null,
                )
              : p,
        )
        .toList();
    final strippedConfig = config.copyWith(profiles: strippedProfiles);
    return preferences.setString(
      configKey,
      json.encode(strippedConfig),
    );
  }

  Future<void> clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return;
    await preferences.remove(clashConfigKey);
    // Legacy clash config has been finalized (migrated into the main Config or
    // deliberately dropped) — clear its quarantine so a corrupt clash backup is
    // not retained. Scoped to clash only; the Config backup is untouched.
    await _clearQuarantine(preferences, clashConfigBackupKey, 'clash_config');
  }

  /// True when a corrupt legacy clash_config was quarantined (its raw blob is
  /// held in [clashConfigBackupKey]) but not yet cleared. Lets migration tell a
  /// corrupt-and-quarantined legacy config (getClashConfig returned null AFTER
  /// removing the active key) apart from one that never existed — the former
  /// still needs its lower-sensitivity backup dropped after recovery.
  Future<bool> hasClashConfigBackup() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString(clashConfigBackupKey) != null;
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    sharedPreferencesIns?.clear();
  }

  /// Get persisted SOCKS port (null if never generated)
  Future<int?> getSocksPort() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt(socksPortKey);
  }

  /// Save SOCKS port for persistence across restarts
  Future<bool> saveSocksPort(int port) async {
    final preferences = await sharedPreferencesCompleter.future;
    return await preferences?.setInt(socksPortKey, port) ?? false;
  }
}

final preferences = Preferences();
