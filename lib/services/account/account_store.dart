import 'package:dropweb/common/log_redaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище сессии аккаунта. Интерфейс отделён, чтобы контроллер аккаунта
/// тестировался без KeyStore. Access-токен сюда не пишется — он живёт только в
/// памяти и восстанавливается через refresh.
abstract interface class AccountStorage {
  Future<String?> readRefreshToken();

  /// true только если значение прочиталось обратно: KeyStore умеет молча
  /// терять записи, а потеря повёрнутого refresh-токена = вылет из аккаунта.
  Future<bool> writeRefreshToken(String token);

  Future<String?> readEmail();
  Future<bool> writeEmail(String value);
  Future<bool> readBiometricEnabled();
  Future<bool> writeBiometricEnabled({required bool enabled});

  /// URL подписки, импортированный для этого аккаунта: по нему при удалении
  /// аккаунта находим и удаляем соответствующий VPN-профиль.
  Future<String?> readImportedUrl();
  Future<bool> writeImportedUrl(String url);

  /// Базы API бэкенда, на котором создана сессия. Все вызовы с токенами идут
  /// только сюда: refresh-токен одного провайдера не должен уйти другому,
  /// когда пользователь переключит профиль. Пустой список — сессия создана до
  /// привязки к бэкенду.
  Future<List<String>> readApiBases();
  Future<bool> writeApiBases(List<String> bases);

  Future<void> clear();
}

class AccountStore implements AccountStorage {
  AccountStore._();

  static final AccountStore instance = AccountStore._();

  static const _refreshKey = 'account_refresh_token';
  static const _emailKey = 'account_email';
  static const _biometricKey = 'account_biometric_enabled';
  static const _importedUrlKey = 'account_imported_url';
  static const _apiBasesKey = 'account_api_bases';
  static const _allKeys = [
    _refreshKey,
    _emailKey,
    _biometricKey,
    _importedUrlKey,
    _apiBasesKey,
  ];

  // Та же конфигурация, что у SecureProfileUrlStore: first_unlock, чтобы фоновое
  // продление сессии работало и при заблокированном после загрузки экране.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[AccountStore] read $key failed: $e'));
      }
      return null;
    }
  }

  Future<bool> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      final readBack = await _storage.read(key: key);
      return readBack == value;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(redactUrls('[AccountStore] write $key failed: $e'));
      }
      return false;
    }
  }

  @override
  Future<String?> readRefreshToken() => _read(_refreshKey);

  @override
  Future<bool> writeRefreshToken(String token) => _write(_refreshKey, token);

  @override
  Future<String?> readEmail() => _read(_emailKey);

  @override
  Future<bool> writeEmail(String value) => _write(_emailKey, value);

  @override
  Future<bool> readBiometricEnabled() async =>
      await _read(_biometricKey) == '1';

  @override
  Future<bool> writeBiometricEnabled({required bool enabled}) =>
      _write(_biometricKey, enabled ? '1' : '0');

  @override
  Future<String?> readImportedUrl() => _read(_importedUrlKey);

  @override
  Future<bool> writeImportedUrl(String url) => _write(_importedUrlKey, url);

  // Перевод строки как разделитель: в URL его не бывает.
  @override
  Future<List<String>> readApiBases() async => (await _read(_apiBasesKey) ?? '')
      .split('\n')
      .where((base) => base.isNotEmpty)
      .toList();

  @override
  Future<bool> writeApiBases(List<String> bases) =>
      _write(_apiBasesKey, bases.join('\n'));

  @override
  Future<void> clear() async {
    for (final key in _allKeys) {
      try {
        await _storage.delete(key: key);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(redactUrls('[AccountStore] delete $key failed: $e'));
        }
      }
    }
  }
}
