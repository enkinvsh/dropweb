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

  @override
  Future<void> removeProfile(String profileId) async {
    await setUrl(profileId, null);
    await setFallbackUrl(profileId, null);
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
