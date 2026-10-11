import 'dart:io';

import 'package:dio/dio.dart';

/// Категории ошибок аккаунта, на которые UI реагирует по-разному.
/// Сопоставление сделано по ответам API кабинета (коды ошибок и строковые
/// `detail` FastAPI), а не по тексту сообщения для пользователя.
enum AccountApiErrorKind {
  /// Сеть: нет соединения, таймаут, TLS. Сессию в этом случае не трогаем.
  network,

  /// Неверный или просроченный код (бэкенд их не различает).
  invalidCode,

  /// Слишком много неверных попыток — код заблокирован на час.
  codeExpiredOrLocked,

  /// Лимит запросов или кулдаун повторной отправки; см. [AccountApiException.retryAfter].
  rateLimited,

  /// Одноразовая или невалидная почта.
  emailRejected,

  /// Proof-of-work отклонён (протух или уже использован) — нужен новый challenge.
  captchaFailed,

  /// Функция выключена на бэкенде (вход по почте).
  disabled,

  /// Сессия недействительна; после неудачного refresh хранилище уже очищено.
  unauthorized,

  /// Аккаунт заблокирован/удалён или действие запрещено для этого аккаунта.
  forbidden,

  /// 404: эндпоинта ещё нет на этом бэкенде (не задеплоен).
  notAvailable,

  /// 503: отправка почты недоступна или техработы.
  unavailable,

  /// Действие требует разблокировки биометрией (состояние locked)
  /// или ошибка самой биометрии; код плагина лежит в [AccountApiException.code].
  biometric,

  /// Не удалось сохранить сессию в защищённое хранилище.
  storage,

  /// Импорт/удаление VPN-профиля не прошли.
  profile,

  /// Прочие ответы сервера (5xx, неожиданный формат).
  server,
}

class AccountApiException implements Exception {
  const AccountApiException(
    this.kind, {
    this.statusCode,
    this.code,
    this.message,
    this.retryAfter,
  });

  /// Разбор ответа с ошибкой. [data] — тело ответа: либо
  /// `{"detail": {"code","message"}}` (api_error), либо `{"detail": "..."}`,
  /// либо 422 `{"detail": [{"loc": [...]}]}`.
  factory AccountApiException.fromResponse(
    int statusCode,
    Object? data, {
    String? retryAfterHeader,
  }) {
    final retryAfter = int.tryParse(retryAfterHeader?.trim() ?? '');
    final detail = data is Map ? data['detail'] : null;

    if (detail is Map) {
      final code = detail['code']?.toString();
      final message = detail['message']?.toString();
      final kind = _kindForCode(code) ?? _kindForStatus(statusCode, message);
      return AccountApiException(
        kind,
        statusCode: statusCode,
        code: code,
        message: message,
        retryAfter: retryAfter,
      );
    }

    if (detail is List) {
      return AccountApiException(
        _kindForValidation(detail),
        statusCode: statusCode,
        code: 'validation_error',
        message: detail.toString(),
      );
    }

    final message = detail?.toString();
    return AccountApiException(
      _kindForStatus(statusCode, message),
      statusCode: statusCode,
      message: message,
      retryAfter: retryAfter,
    );
  }

  /// Сбой транспорта Dio (ответа сервера нет).
  factory AccountApiException.fromTransport(DioException error) =>
      AccountApiException(
        AccountApiErrorKind.network,
        code: error.type.name,
        message: error.message ?? error.error?.toString(),
      );

  final AccountApiErrorKind kind;
  final int? statusCode;

  /// Машинный код ошибки сервера (`invalid_code`, `rate_limited`, …) если есть.
  final String? code;
  final String? message;

  /// Секунды из заголовка Retry-After (для [AccountApiErrorKind.rateLimited]).
  final int? retryAfter;

  static AccountApiErrorKind? _kindForCode(String? code) => switch (code) {
        'invalid_code' => AccountApiErrorKind.invalidCode,
        'email_code_locked' => AccountApiErrorKind.codeExpiredOrLocked,
        'rate_limited' ||
        'email_code_cooldown' =>
          AccountApiErrorKind.rateLimited,
        'email_disposable' => AccountApiErrorKind.emailRejected,
        'captcha_failed' => AccountApiErrorKind.captchaFailed,
        'email_code_unavailable' ||
        'maintenance' ||
        'telegram_unavailable' =>
          AccountApiErrorKind.unavailable,
        'blacklisted' ||
        'account_deleted' ||
        'channel_subscription_required' =>
          AccountApiErrorKind.forbidden,
        _ => null,
      };

  static AccountApiErrorKind _kindForStatus(int status, String? message) {
    switch (status) {
      case 401:
        return AccountApiErrorKind.unauthorized;
      case 403:
        // 'Email authentication is disabled'
        final lower = message?.toLowerCase() ?? '';
        return lower.contains('disabled')
            ? AccountApiErrorKind.disabled
            : AccountApiErrorKind.forbidden;
      case 404:
        // get_current_cabinet_user отвечает 404 'User not found' на токен
        // удалённого пользователя — это потеря сессии, а не отсутствие эндпоинта.
        return message == 'User not found'
            ? AccountApiErrorKind.unauthorized
            : AccountApiErrorKind.notAvailable;
      case 429:
        return AccountApiErrorKind.rateLimited;
      case 503:
        return AccountApiErrorKind.unavailable;
      default:
        return AccountApiErrorKind.server;
    }
  }

  static AccountApiErrorKind _kindForValidation(List<dynamic> errors) {
    for (final error in errors) {
      final loc = error is Map ? error['loc'] : null;
      if (loc is List && loc.contains('email')) {
        return AccountApiErrorKind.emailRejected;
      }
      if (loc is List && loc.contains('code')) {
        return AccountApiErrorKind.invalidCode;
      }
    }
    return AccountApiErrorKind.server;
  }

  /// Сбои, при которых имеет смысл пробовать следующий адрес API: запрос
  /// не дошёл до сервера. Таймауты отправки/чтения сюда не входят — сервер мог
  /// уже выполнить запрос (отправить письмо, повернуть refresh-токен), и повтор
  /// на другой адрес сделал бы это дважды.
  static bool isFailoverTransport(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.unknown:
        final cause = error.error;
        return cause is SocketException ||
            cause is HandshakeException ||
            cause is TlsException;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  @override
  String toString() =>
      'AccountApiException(${kind.name}, status: $statusCode, code: $code, '
      'retryAfter: $retryAfter, message: $message)';
}
