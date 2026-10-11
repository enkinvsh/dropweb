import 'package:dropweb/services/account/account_api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Замок на вход в аккаунт. Интерфейс — ради тестов контроллера без плагина.
abstract interface class AccountBiometrics {
  Future<bool> isAvailable();

  /// true — пользователь подтвердил; false — отменил или не распознан.
  /// Ошибки устройства (блокировка, нет учётных данных) — AccountApiException
  /// с kind=biometric и кодом плагина в `code`.
  Future<bool> authenticate(String reason);
}

class LocalAccountBiometrics implements AccountBiometrics {
  LocalAccountBiometrics([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on LocalAuthException catch (e) {
      // Недоступность — штатный ответ «нет», но причину оставляем в debug-логе.
      if (kDebugMode) debugPrint('[AccountBiometrics] isAvailable: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // PIN/графический ключ как запасной путь: отпечаток может не читаться
        // мокрыми пальцами, а замок не должен запирать владельца насовсем.
        biometricOnly: false,
        // Системный диалог не должен пропадать, если пользователь на секунду
        // свернул приложение (аналог stickyAuth из local_auth 2.x).
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return false;
        default:
          throw AccountApiException(
            AccountApiErrorKind.biometric,
            code: e.code.name,
            message: e.description,
          );
      }
    }
  }
}
