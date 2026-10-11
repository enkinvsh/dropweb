import 'dart:convert';

import 'package:dropweb/common/log_redaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Behavioural contract for the encrypted subscription-URL store. Extracted so
/// `Preferences` can depend on it and unit tests can substitute an in-memory
/// fake with no real KeyStore. Production is [SecureProfileUrlStore].
abstract class SecureProfileUrlStoreInterface {
  Future<String?> getUrl(String profileId);
  Future<String?> getFallbackUrl(String profileId);
  Future<bool> setUrl(String profileId, String? url);
  Future<bool> setFallbackUrl(String profileId, String? url);

  /// Зеркала подписки (`dropweb-sub-mirrors`), JSON-список строк.
  Future<List<String>?> getMirrors(String profileId);
  Future<bool> setMirrors(String profileId, List<String>? mirrors);

  /// Стабильный id подписки (`dropweb-sub-id`) — обычно токен из пути.
  Future<String?> getSubId(String profileId);
  Future<bool> setSubId(String profileId, String? subId);

  /// Последний сработавший НЕ основной адрес: с него начинается следующее
  /// обновление, чтобы не ждать таймаутов мёртвого основного фронта.
  Future<String?> getPreferredUrl(String profileId);
  Future<bool> setPreferredUrl(String profileId, String? url);

  /// Маяк зеркал (`dropweb-sub-beacon` / `-key`). Токена в них нет, но
  /// подмена ключа в plaintext позволила бы подсунуть чужой список фронтов.
  Future<List<String>?> getBeaconUrls(String profileId);
  Future<bool> setBeaconUrls(String profileId, List<String>? urls);
  Future<List<String>?> getBeaconKeys(String profileId);
  Future<bool> setBeaconKeys(String profileId, List<String>? keys);

  /// Закодированный `BeaconState`: максимальный принятый seq и последний
  /// проверенный документ.
  Future<String?> getBeaconState(String profileId);
  Future<bool> setBeaconState(String profileId, String? state);

  Future<void> removeProfile(String profileId);
  Future<bool> isMigrated();

  /// Persists the "migration complete" marker and confirms it read back.
  /// Returns true only when the marker is durably set — a silent KeyStore
  /// failure must leave the migration retryable, not falsely complete.
  Future<bool> markMigrated();
}

/// Encrypted store for subscription URLs (tokens embedded) — SharedPreferences
/// is readable via ADB backup and by rooted companions. Only URLs live here;
/// the rest of Profile stays in the plaintext Config blob for fast access.
class SecureProfileUrlStore implements SecureProfileUrlStoreInterface {
  SecureProfileUrlStore._();

  static final SecureProfileUrlStore instance = SecureProfileUrlStore._();

  static const _urlKeyPrefix = 'profile_url:';
  static const _fallbackKeyPrefix = 'profile_fallback_url:';
  static const _mirrorsKeyPrefix = 'profile_mirrors:';
  static const _subIdKeyPrefix = 'profile_sub_id:';
  static const _preferredKeyPrefix = 'profile_preferred_url:';
  static const _beaconUrlsKeyPrefix = 'profile_beacon_urls:';
  static const _beaconKeysKeyPrefix = 'profile_beacon_keys:';
  static const _beaconStateKeyPrefix = 'profile_beacon_state:';
  static const _migrationKey = 'profile_url_migrated_v1';

  // first_unlock — readable once the device is unlocked, stays readable after
  // (VPN may need to reconnect in background).
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  @override
  Future<String?> getUrl(String profileId) async {
    try {
      return await _storage.read(key: '$_urlKeyPrefix$profileId');
    } catch (e) {
      if (kDebugMode) {
        // SECURITY: redact in case the platform exception ever echoes the
        // stored URL value back into the message.
        debugPrint(redactUrls('[SecureProfileStore] getUrl failed: $e'));
      }
      return null;
    }
  }

  @override
  Future<String?> getFallbackUrl(String profileId) async {
    try {
      return await _storage.read(key: '$_fallbackKeyPrefix$profileId');
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            redactUrls('[SecureProfileStore] getFallbackUrl failed: $e'));
      }
      return null;
    }
  }

  @override
  Future<bool> setUrl(String profileId, String? url) async {
    try {
      final key = '$_urlKeyPrefix$profileId';
      if (url == null || url.isEmpty) {
        await _storage.delete(key: key);
        return true;
      }
      await _storage.write(key: key, value: url);
      // Verify the write persisted — the keystore can fail silently, and the
      // caller strips the plaintext copy only after a confirmed write.
      final readBack = await _storage.read(key: key);
      return readBack == url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[SecureProfileStore] setUrl failed: $e'));
      }
      return false;
    }
  }

  @override
  Future<bool> setFallbackUrl(String profileId, String? url) async {
    try {
      final key = '$_fallbackKeyPrefix$profileId';
      if (url == null || url.isEmpty) {
        await _storage.delete(key: key);
        return true;
      }
      await _storage.write(key: key, value: url);
      final readBack = await _storage.read(key: key);
      return readBack == url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            redactUrls('[SecureProfileStore] setFallbackUrl failed: $e'));
      }
      return false;
    }
  }

  Future<String?> _readValue(String key, String op) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[SecureProfileStore] $op failed: $e'));
      }
      return null;
    }
  }

  /// Запись с проверкой чтением: KeyStore умеет молча не сохранить значение.
  Future<bool> _writeValue(String key, String? value, String op) async {
    try {
      if (value == null || value.isEmpty) {
        await _storage.delete(key: key);
        return true;
      }
      await _storage.write(key: key, value: value);
      return await _storage.read(key: key) == value;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[SecureProfileStore] $op failed: $e'));
      }
      return false;
    }
  }

  Future<List<String>?> _readList(String key, String op) async {
    final raw = await _readValue(key, op);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeList(String key, List<String>? values, String op) =>
      _writeValue(
        key,
        values == null || values.isEmpty ? null : json.encode(values),
        op,
      );

  @override
  Future<List<String>?> getMirrors(String profileId) =>
      _readList('$_mirrorsKeyPrefix$profileId', 'getMirrors');

  @override
  Future<bool> setMirrors(String profileId, List<String>? mirrors) =>
      _writeList('$_mirrorsKeyPrefix$profileId', mirrors, 'setMirrors');

  @override
  Future<List<String>?> getBeaconUrls(String profileId) =>
      _readList('$_beaconUrlsKeyPrefix$profileId', 'getBeaconUrls');

  @override
  Future<bool> setBeaconUrls(String profileId, List<String>? urls) =>
      _writeList('$_beaconUrlsKeyPrefix$profileId', urls, 'setBeaconUrls');

  @override
  Future<List<String>?> getBeaconKeys(String profileId) =>
      _readList('$_beaconKeysKeyPrefix$profileId', 'getBeaconKeys');

  @override
  Future<bool> setBeaconKeys(String profileId, List<String>? keys) =>
      _writeList('$_beaconKeysKeyPrefix$profileId', keys, 'setBeaconKeys');

  @override
  Future<String?> getBeaconState(String profileId) =>
      _readValue('$_beaconStateKeyPrefix$profileId', 'getBeaconState');

  @override
  Future<bool> setBeaconState(String profileId, String? state) =>
      _writeValue('$_beaconStateKeyPrefix$profileId', state, 'setBeaconState');

  @override
  Future<String?> getSubId(String profileId) =>
      _readValue('$_subIdKeyPrefix$profileId', 'getSubId');

  @override
  Future<bool> setSubId(String profileId, String? subId) =>
      _writeValue('$_subIdKeyPrefix$profileId', subId, 'setSubId');

  @override
  Future<String?> getPreferredUrl(String profileId) =>
      _readValue('$_preferredKeyPrefix$profileId', 'getPreferredUrl');

  @override
  Future<bool> setPreferredUrl(String profileId, String? url) =>
      _writeValue('$_preferredKeyPrefix$profileId', url, 'setPreferredUrl');

  @override
  Future<void> removeProfile(String profileId) async {
    await setUrl(profileId, null);
    await setFallbackUrl(profileId, null);
    await setMirrors(profileId, null);
    await setSubId(profileId, null);
    await setPreferredUrl(profileId, null);
    await setBeaconUrls(profileId, null);
    await setBeaconKeys(profileId, null);
    await setBeaconState(profileId, null);
  }

  @override
  Future<bool> isMigrated() async {
    try {
      return await _storage.read(key: _migrationKey) == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markMigrated() async {
    try {
      await _storage.write(key: _migrationKey, value: '1');
      // Confirm the marker persisted. The KeyStore can fail silently; the
      // caller must not treat the one-time migration as complete unless the
      // marker is durably readable, or plaintext URLs could be stripped while
      // the migration is (falsely) considered done.
      final readBack = await _storage.read(key: _migrationKey);
      return readBack == '1';
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[SecureProfileStore] markMigrated failed: $e'));
      }
      return false;
    }
  }
}

final secureProfileUrlStore = SecureProfileUrlStore.instance;
