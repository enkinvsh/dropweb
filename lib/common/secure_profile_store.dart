import 'package:dropweb/common/log_redaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted store for subscription URLs (tokens embedded) — SharedPreferences
/// is readable via ADB backup and by rooted companions. Only URLs live here;
/// the rest of Profile stays in the plaintext Config blob for fast access.
class SecureProfileUrlStore {
  SecureProfileUrlStore._();

  static final SecureProfileUrlStore instance = SecureProfileUrlStore._();

  static const _urlKeyPrefix = 'profile_url:';
  static const _fallbackKeyPrefix = 'profile_fallback_url:';
  static const _migrationKey = 'profile_url_migrated_v1';

  // first_unlock — readable once the device is unlocked, stays readable after
  // (VPN may need to reconnect in background).
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

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

  Future<void> removeProfile(String profileId) async {
    await setUrl(profileId, null);
    await setFallbackUrl(profileId, null);
  }

  Future<bool> isMigrated() async {
    try {
      return await _storage.read(key: _migrationKey) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> markMigrated() async {
    try {
      await _storage.write(key: _migrationKey, value: '1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            redactUrls('[SecureProfileStore] markMigrated failed: $e'));
      }
    }
  }
}

final secureProfileUrlStore = SecureProfileUrlStore.instance;
