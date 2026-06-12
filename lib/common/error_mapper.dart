import 'package:intl/intl.dart';

/// Maps raw mihomo core error strings to human-readable messages.
///
/// The core sends technical error logs like "dial tcp 1.2.3.4:443: i/o timeout"
/// which mean nothing to regular users. This mapper translates them to clear
/// messages with actionable suggestions.
class ErrorMapper {
  ErrorMapper._();

  static final _patterns = <_ErrorPattern>[
    // Network unreachable / no internet
    _ErrorPattern(
      RegExp(r'network is unreachable|no route to host', caseSensitive: false),
      ru: 'Нет подключения к интернету. Проверьте Wi-Fi или мобильную сеть.',
      en: 'No internet connection. Check your Wi-Fi or mobile network.',
    ),
    // DNS failure
    _ErrorPattern(
      RegExp(r'all DNS request failed|no such host|dns.*fail',
          caseSensitive: false),
      ru: 'Не удаётся найти сервер. Проверьте подключение к интернету.',
      en: 'Cannot find server. Check your internet connection.',
    ),
    // Connection timeout
    _ErrorPattern(
      RegExp(r'i/o timeout|context deadline exceeded|connection timed out',
          caseSensitive: false),
      ru: 'Сервер не отвечает. Попробуйте другой сервер или подождите.',
      en: 'Server is not responding. Try a different server or wait.',
    ),
    // Dio HTTP timeouts (connection / receive / send) + Dart TimeoutException
    _ErrorPattern(
      RegExp(
          r'connection timeout|receive timeout|send timeout|connectionTimeout|receiveTimeout|sendTimeout|TimeoutException',
          caseSensitive: false),
      ru: 'Сервер не отвечает. Проверьте подключение к интернету и попробуйте ещё раз.',
      en: 'Server is not responding. Check your internet connection and try again.',
    ),
    // Connection refused
    _ErrorPattern(
      RegExp(r'connection refused', caseSensitive: false),
      ru: 'Сервер отклонил подключение. Попробуйте другой сервер.',
      en: 'Server refused the connection. Try a different server.',
    ),
    // Connection reset
    _ErrorPattern(
      RegExp(r'connection reset by peer|broken pipe', caseSensitive: false),
      ru: 'Соединение прервано. Попробуйте подключиться ещё раз.',
      en: 'Connection was interrupted. Try reconnecting.',
    ),
    // EOF (generic connection drop)
    _ErrorPattern(
      RegExp(r'EOF|unexpected EOF', caseSensitive: false),
      ru: 'Соединение с сервером потеряно. Попробуйте ещё раз.',
      en: 'Lost connection to server. Try again.',
    ),
    // Bad TLS certificate (Dio bad certificate / verify failures)
    _ErrorPattern(
      RegExp(
          r'bad certificate|certificate verify failed|CERTIFICATE_VERIFY_FAILED|HandshakeException',
          caseSensitive: false),
      ru: 'Не удалось проверить сертификат сервера. Проверьте дату и время на устройстве или попробуйте другой сервер.',
      en: 'Could not verify the server certificate. Check your device date and time or try a different server.',
    ),
    // TLS / Reality handshake errors
    _ErrorPattern(
      RegExp(r'tls.*handshake|reality.*verif|certificate',
          caseSensitive: false),
      ru: 'Ошибка безопасного соединения. Обновите подписку или попробуйте другой сервер.',
      en: 'Secure connection failed. Update your subscription or try a different server.',
    ),
    // Proxy not found
    _ErrorPattern(
      RegExp(r'proxy.*not found|proxy adapter not found', caseSensitive: false),
      ru: 'Сервер не найден в конфигурации. Обновите подписку.',
      en: 'Server not found in configuration. Update your subscription.',
    ),
    // Address in use (port conflict)
    _ErrorPattern(
      RegExp(r'address already in use', caseSensitive: false),
      ru: 'Порт уже занят другим приложением. Перезапустите VPN.',
      en: 'Port is already in use by another app. Restart VPN.',
    ),
    // Too many open files
    _ErrorPattern(
      RegExp(r'too many open files', caseSensitive: false),
      ru: 'Слишком много подключений. Перезапустите VPN.',
      en: 'Too many connections. Restart VPN.',
    ),
    // Authentication errors
    _ErrorPattern(
      RegExp(r'auth.*fail|authentication.*fail|unauthorized',
          caseSensitive: false),
      ru: 'Ошибка авторизации. Обновите подписку.',
      en: 'Authentication failed. Update your subscription.',
    ),
    // HTTP 404
    _ErrorPattern(
      RegExp(r'status code of 404|404 Not Found', caseSensitive: false),
      ru: 'Подписка не найдена. Проверьте ссылку.',
      en: 'Subscription not found. Check the link.',
    ),
    // HTTP 403
    _ErrorPattern(
      RegExp(r'status code of 403|403 Forbidden', caseSensitive: false),
      ru: 'Доступ запрещён. Обратитесь к провайдеру.',
      en: 'Access denied. Contact your provider.',
    ),
    // HTTP 5xx server errors
    _ErrorPattern(
      RegExp(
          r'status code of 50[0-9]|502 Bad Gateway|503 Service Unavailable|500 Internal',
          caseSensitive: false),
      ru: 'Сервер подписки временно недоступен. Попробуйте позже.',
      en: 'Subscription server is temporarily unavailable. Try later.',
    ),
    // YAML unmarshal errors — provider returned wrong format (e.g. raw VLESS instead of Mihomo YAML)
    _ErrorPattern(
      RegExp(r'yaml:\s*unmarshal errors|cannot unmarshal !!str',
          caseSensitive: false),
      ru: 'Ваш провайдер не поддерживает это приложение. Обратитесь к провайдеру или используйте другую ссылку на подписку.',
      en: 'Your provider does not support this app. Contact your provider or use a different subscription link.',
    ),
    // YAML token parse error — same cause: wrong subscription format
    _ErrorPattern(
      RegExp(r'yaml:\s*found character that cannot start any token',
          caseSensitive: false),
      ru: 'Ваш провайдер не поддерживает это приложение. Обратитесь к провайдеру или используйте другую ссылку на подписку.',
      en: 'Your provider does not support this app. Contact your provider or use a different subscription link.',
    ),
    // No internet / host unreachable / Dio connection error / SocketException
    _ErrorPattern(
      RegExp(
          r'DioException.*connection error|SocketException|Failed host lookup|connectionError',
          caseSensitive: false),
      ru: 'Нет подключения к интернету. Проверьте соединение и попробуйте ещё раз.',
      en: 'No internet connection. Check your connection and try again.',
    ),
    // Feature not available on this platform (missing native implementation)
    _ErrorPattern(
      RegExp(r'MissingPluginException', caseSensitive: false),
      ru: 'Эта функция недоступна на вашей платформе.',
      en: 'This feature is not available on your platform.',
    ),
    // Malformed response / config (parsing failure)
    _ErrorPattern(
      RegExp(r'FormatException', caseSensitive: false),
      ru: 'Получен некорректный ответ. Проверьте ссылку или конфигурацию.',
      en: 'Received an invalid response. Check the link or configuration.',
    ),
  ];

  /// Matches a "status code of NNN" fragment in a Dio bad-response error.
  static final _httpStatusRegex = RegExp(r'status code of (\d{3})');

  /// Translates a raw error string to a human-readable message.
  /// Returns null if the error doesn't match any known pattern (shown as-is).
  static String? mapError(String rawError) {
    for (final pattern in _patterns) {
      if (pattern.regex.hasMatch(rawError)) {
        return _isRussian ? pattern.ru : pattern.en;
      }
    }
    // Dio bad response with an HTTP status not covered by a specific pattern.
    final statusMatch = _httpStatusRegex.firstMatch(rawError);
    if (statusMatch != null) {
      final code = statusMatch.group(1);
      return _isRussian
          ? 'Сервер вернул ошибку $code. Попробуйте позже.'
          : 'Server returned error $code. Try again later.';
    }
    return null;
  }

  /// Generic, localized fallback used when [mapError] returns null.
  /// Callers that surface to the user should prefer the ARB-backed
  /// `appLocalizations.genericErrorMessage` for full ja/zh_CN coverage;
  /// this getter is the ru/en safety net for non-widget contexts.
  static String get generic => _isRussian
      ? 'Что-то пошло не так. Попробуйте ещё раз.'
      : 'Something went wrong. Please try again.';

  /// VPN service failed to start.
  static String get vpnStartFailed => _isRussian
      ? 'Не удалось запустить VPN. Возможно, другое VPN-приложение уже активно.'
      : 'Failed to start VPN. Another VPN app may be active.';

  /// VPN permission denied by user.
  static String get vpnPermissionDenied => _isRussian
      ? 'Нет разрешения на VPN. Разрешите подключение при следующем запросе.'
      : 'VPN permission denied. Allow the connection when prompted.';

  static bool get _isRussian {
    final locale = Intl.defaultLocale ?? 'en';
    return locale.startsWith('ru');
  }
}

class _ErrorPattern {
  const _ErrorPattern(this.regex, {required this.ru, required this.en});
  final RegExp regex;
  final String ru;
  final String en;
}
