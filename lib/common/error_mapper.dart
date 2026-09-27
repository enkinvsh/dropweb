import 'package:intl/intl.dart';

/// Maps raw mihomo core error strings to human-readable messages.
///
/// The core sends technical error logs like "dial tcp 1.2.3.4:443: i/o timeout"
/// which mean nothing to regular users. This mapper translates them to clear
/// messages with actionable suggestions.
///
/// Messages are localized by the [Intl.defaultLocale] prefix: `ru`, `ja` and
/// `zh` get their own text; every other locale falls back to English.
class ErrorMapper {
  ErrorMapper._();

  static final _patterns = <_ErrorPattern>[
    _ErrorPattern(
      RegExp(r'activeInAnotherSession', caseSensitive: false),
      ru: 'Dropweb уже активен в другой сессии Windows.',
      en: 'Dropweb is already active in another Windows session.',
      ja: 'Dropwebは別のWindowsセッションで既に実行中です。',
      zh: 'Dropweb 已在另一个 Windows 会话中运行。',
    ),
    _ErrorPattern(
      RegExp(r'TUN listener start timed out', caseSensitive: false),
      ru: 'VPN-интерфейс поднимается дольше обычного. Подождите и попробуйте ещё раз.',
      en: 'The VPN interface is taking longer than usual. Wait a moment and try again.',
      ja: 'VPNインターフェースの起動に時間がかかっています。しばらく待ってから再試行してください。',
      zh: 'VPN 接口启动时间比平时长。请稍候再试。',
    ),
    // Our fail-closed desktop core timeout errors
    _ErrorPattern(
      RegExp(r'core did not answer|core call timed out', caseSensitive: false),
      ru: 'VPN-ядро не отвечает. Перезапустите приложение.',
      en: 'VPN core is not responding. Restart the app.',
      ja: 'VPNコアが応答しません。アプリを再起動してください。',
      zh: 'VPN 核心无响应。请重启应用。',
    ),
    // Network unreachable / no internet
    _ErrorPattern(
      RegExp(r'network is unreachable|no route to host', caseSensitive: false),
      ru: 'Нет подключения к интернету. Проверьте Wi-Fi или мобильную сеть.',
      en: 'No internet connection. Check your Wi-Fi or mobile network.',
      ja: 'インターネットに接続されていません。Wi-Fiまたはモバイルネットワークを確認してください。',
      zh: '无网络连接。请检查 Wi-Fi 或移动网络。',
    ),
    // DNS failure
    _ErrorPattern(
      RegExp(r'all DNS request failed|no such host|dns.*fail',
          caseSensitive: false),
      ru: 'Не удаётся найти сервер. Проверьте подключение к интернету.',
      en: 'Cannot find server. Check your internet connection.',
      ja: 'サーバーが見つかりません。インターネット接続を確認してください。',
      zh: '找不到服务器。请检查网络连接。',
    ),
    // Connection timeout
    _ErrorPattern(
      RegExp(r'i/o timeout|context deadline exceeded|connection timed out',
          caseSensitive: false),
      ru: 'Сервер не отвечает. Попробуйте другой сервер или подождите.',
      en: 'Server is not responding. Try a different server or wait.',
      ja: 'サーバーが応答しません。別のサーバーを試すか、しばらくお待ちください。',
      zh: '服务器无响应。请尝试其他服务器或稍候。',
    ),
    // Dio HTTP timeouts (connection / receive / send) + Dart TimeoutException
    _ErrorPattern(
      RegExp(
          r'connection timeout|receive timeout|send timeout|connectionTimeout|receiveTimeout|sendTimeout|TimeoutException',
          caseSensitive: false),
      ru: 'Сервер не отвечает. Проверьте подключение к интернету и попробуйте ещё раз.',
      en: 'Server is not responding. Check your internet connection and try again.',
      ja: 'サーバーが応答しません。インターネット接続を確認して再試行してください。',
      zh: '服务器无响应。请检查网络连接后重试。',
    ),
    // Connection refused
    _ErrorPattern(
      RegExp(r'connection refused', caseSensitive: false),
      ru: 'Сервер отклонил подключение. Попробуйте другой сервер.',
      en: 'Server refused the connection. Try a different server.',
      ja: 'サーバーが接続を拒否しました。別のサーバーを試してください。',
      zh: '服务器拒绝了连接。请尝试其他服务器。',
    ),
    // Connection reset
    _ErrorPattern(
      RegExp(r'connection reset by peer|broken pipe', caseSensitive: false),
      ru: 'Соединение прервано. Попробуйте подключиться ещё раз.',
      en: 'Connection was interrupted. Try reconnecting.',
      ja: '接続が中断されました。再接続してください。',
      zh: '连接已中断。请重新连接。',
    ),
    // EOF (generic connection drop)
    _ErrorPattern(
      RegExp(r'EOF|unexpected EOF', caseSensitive: false),
      ru: 'Соединение с сервером потеряно. Попробуйте ещё раз.',
      en: 'Lost connection to server. Try again.',
      ja: 'サーバーとの接続が切れました。再試行してください。',
      zh: '与服务器的连接已断开。请重试。',
    ),
    // Bad TLS certificate (Dio bad certificate / verify failures)
    _ErrorPattern(
      RegExp(
          r'bad certificate|certificate verify failed|CERTIFICATE_VERIFY_FAILED|HandshakeException',
          caseSensitive: false),
      ru: 'Не удалось проверить сертификат сервера. Проверьте дату и время на устройстве или попробуйте другой сервер.',
      en: 'Could not verify the server certificate. Check your device date and time or try a different server.',
      ja: 'サーバー証明書を検証できません。端末の日付と時刻を確認するか、別のサーバーを試してください。',
      zh: '无法验证服务器证书。请检查设备的日期和时间，或尝试其他服务器。',
    ),
    // TLS / Reality handshake errors
    _ErrorPattern(
      RegExp(r'tls.*handshake|reality.*verif|certificate',
          caseSensitive: false),
      ru: 'Ошибка безопасного соединения. Обновите подписку или попробуйте другой сервер.',
      en: 'Secure connection failed. Update your subscription or try a different server.',
      ja: '安全な接続に失敗しました。サブスクリプションを更新するか、別のサーバーを試してください。',
      zh: '安全连接失败。请更新订阅或尝试其他服务器。',
    ),
    // Proxy not found
    _ErrorPattern(
      RegExp(r'proxy.*not found|proxy adapter not found', caseSensitive: false),
      ru: 'Сервер не найден в конфигурации. Обновите подписку.',
      en: 'Server not found in configuration. Update your subscription.',
      ja: '設定にサーバーが見つかりません。サブスクリプションを更新してください。',
      zh: '配置中找不到该服务器。请更新订阅。',
    ),
    // Address in use (port conflict)
    _ErrorPattern(
      RegExp(r'address already in use', caseSensitive: false),
      ru: 'Порт уже занят другим приложением. Перезапустите VPN.',
      en: 'Port is already in use by another app. Restart VPN.',
      ja: 'ポートは他のアプリで使用中です。VPNを再起動してください。',
      zh: '端口已被其他应用占用。请重启 VPN。',
    ),
    // Too many open files
    _ErrorPattern(
      RegExp(r'too many open files', caseSensitive: false),
      ru: 'Слишком много подключений. Перезапустите VPN.',
      en: 'Too many connections. Restart VPN.',
      ja: '接続数が多すぎます。VPNを再起動してください。',
      zh: '连接数过多。请重启 VPN。',
    ),
    // Authentication errors
    _ErrorPattern(
      RegExp(r'auth.*fail|authentication.*fail|unauthorized',
          caseSensitive: false),
      ru: 'Ошибка авторизации. Обновите подписку.',
      en: 'Authentication failed. Update your subscription.',
      ja: '認証に失敗しました。サブスクリプションを更新してください。',
      zh: '认证失败。请更新订阅。',
    ),
    // HTTP 404
    _ErrorPattern(
      RegExp(r'status code of 404|404 Not Found', caseSensitive: false),
      ru: 'Подписка не найдена. Проверьте ссылку.',
      en: 'Subscription not found. Check the link.',
      ja: 'サブスクリプションが見つかりません。リンクを確認してください。',
      zh: '找不到订阅。请检查链接。',
    ),
    // HTTP 403
    _ErrorPattern(
      RegExp(r'status code of 403|403 Forbidden', caseSensitive: false),
      ru: 'Доступ запрещён. Обратитесь к провайдеру.',
      en: 'Access denied. Contact your provider.',
      ja: 'アクセスが拒否されました。プロバイダーにお問い合わせください。',
      zh: '访问被拒绝。请联系服务商。',
    ),
    // HTTP 5xx server errors
    _ErrorPattern(
      RegExp(
          r'status code of 50[0-9]|502 Bad Gateway|503 Service Unavailable|500 Internal',
          caseSensitive: false),
      ru: 'Сервер подписки временно недоступен. Попробуйте позже.',
      en: 'Subscription server is temporarily unavailable. Try later.',
      ja: 'サブスクリプションサーバーは一時的に利用できません。後でもう一度お試しください。',
      zh: '订阅服务器暂时不可用。请稍后再试。',
    ),
    // YAML unmarshal errors — provider returned wrong format (e.g. raw VLESS instead of Mihomo YAML)
    _ErrorPattern(
      RegExp(r'yaml:\s*unmarshal errors|cannot unmarshal !!str',
          caseSensitive: false),
      ru: 'Ваш провайдер не поддерживает это приложение. Обратитесь к провайдеру или используйте другую ссылку на подписку.',
      en: 'Your provider does not support this app. Contact your provider or use a different subscription link.',
      ja: 'ご利用のプロバイダーはこのアプリに対応していません。プロバイダーに問い合わせるか、別のサブスクリプションリンクを使用してください。',
      zh: '您的服务商不支持此应用。请联系服务商或使用其他订阅链接。',
    ),
    // YAML token parse error — same cause: wrong subscription format
    _ErrorPattern(
      RegExp(r'yaml:\s*found character that cannot start any token',
          caseSensitive: false),
      ru: 'Ваш провайдер не поддерживает это приложение. Обратитесь к провайдеру или используйте другую ссылку на подписку.',
      en: 'Your provider does not support this app. Contact your provider or use a different subscription link.',
      ja: 'ご利用のプロバイダーはこのアプリに対応していません。プロバイダーに問い合わせるか、別のサブスクリプションリンクを使用してください。',
      zh: '您的服务商不支持此应用。请联系服务商或使用其他订阅链接。',
    ),
    // Subscription body exceeded our size ceiling (our own raw throw)
    _ErrorPattern(
      RegExp(r'Subscription too large', caseSensitive: false),
      ru: 'Подписка слишком большая — обратитесь к провайдеру.',
      en: 'Subscription file is too large — contact your provider.',
      ja: 'サブスクリプションが大きすぎます。プロバイダーにお問い合わせください。',
      zh: '订阅文件过大，请联系服务商。',
    ),
    // Redirect without a Location header (our own raw throw)
    _ErrorPattern(
      RegExp(r'Redirect detected, but no location', caseSensitive: false),
      ru: 'Сервер подписки вернул некорректный ответ. Попробуйте позже.',
      en: 'Subscription server returned an invalid response. Try later.',
      ja: 'サブスクリプションサーバーが不正な応答を返しました。後でもう一度お試しください。',
      zh: '订阅服务器返回了无效响应。请稍后再试。',
    ),
    // No internet / host unreachable / Dio connection error / SocketException
    _ErrorPattern(
      RegExp(
          r'DioException.*connection error|SocketException|Failed host lookup|connectionError',
          caseSensitive: false),
      ru: 'Нет подключения к интернету. Проверьте соединение и попробуйте ещё раз.',
      en: 'No internet connection. Check your connection and try again.',
      ja: 'インターネットに接続されていません。接続を確認して再試行してください。',
      zh: '无网络连接。请检查网络后重试。',
    ),
    // Feature not available on this platform (missing native implementation)
    _ErrorPattern(
      RegExp(r'MissingPluginException', caseSensitive: false),
      ru: 'Эта функция недоступна на вашей платформе.',
      en: 'This feature is not available on your platform.',
      ja: 'この機能はお使いのプラットフォームでは利用できません。',
      zh: '此功能在您的平台上不可用。',
    ),
    // Malformed response / config (parsing failure)
    _ErrorPattern(
      RegExp(r'FormatException', caseSensitive: false),
      ru: 'Получен некорректный ответ. Проверьте ссылку или конфигурацию.',
      en: 'Received an invalid response. Check the link or configuration.',
      ja: '不正な応答を受信しました。リンクまたは設定を確認してください。',
      zh: '收到无效响应。请检查链接或配置。',
    ),
  ];

  /// Matches a "status code of NNN" fragment in a Dio bad-response error.
  static final _httpStatusRegex = RegExp(r'status code of (\d{3})');

  /// Translates a raw error string to a human-readable message.
  /// Returns null if the error doesn't match any known pattern (shown as-is).
  static String? mapError(String rawError) {
    for (final pattern in _patterns) {
      if (pattern.regex.hasMatch(rawError)) {
        return pattern.text;
      }
    }
    // Dio bad response with an HTTP status not covered by a specific pattern.
    final statusMatch = _httpStatusRegex.firstMatch(rawError);
    if (statusMatch != null) {
      final code = statusMatch.group(1);
      return _pick(
        ru: 'Сервер вернул ошибку $code. Попробуйте позже.',
        en: 'Server returned error $code. Try again later.',
        ja: 'サーバーがエラー$codeを返しました。後でもう一度お試しください。',
        zh: '服务器返回错误 $code。请稍后再试。',
      );
    }
    return null;
  }

  /// Generic, localized fallback used when [mapError] returns null.
  /// Callers that surface to the user should prefer the ARB-backed
  /// `appLocalizations.genericErrorMessage`, which follows the app's ARB
  /// locales; this getter is the ru/en/ja/zh safety net for non-widget
  /// contexts.
  static String get generic => _pick(
        ru: 'Что-то пошло не так. Попробуйте ещё раз.',
        en: 'Something went wrong. Please try again.',
        ja: '問題が発生しました。もう一度お試しください。',
        zh: '出了点问题。请重试。',
      );

  /// VPN service failed to start.
  static String get vpnStartFailed => _pick(
        ru: 'Не удалось запустить VPN. Возможно, другое VPN-приложение уже активно.',
        en: 'Failed to start VPN. Another VPN app may be active.',
        ja: 'VPNを起動できませんでした。別のVPNアプリが有効になっている可能性があります。',
        zh: '无法启动 VPN。可能有其他 VPN 应用正在运行。',
      );

  /// VPN permission denied by user.
  static String get vpnPermissionDenied => _pick(
        ru: 'Нет разрешения на VPN. Разрешите подключение при следующем запросе.',
        en: 'VPN permission denied. Allow the connection when prompted.',
        ja: 'VPNの権限がありません。次に表示されたときに接続を許可してください。',
        zh: '没有 VPN 权限。请在下次提示时允许连接。',
      );

  /// Picks the variant for the current [Intl.defaultLocale]:
  /// `ru*` → [ru], `ja*` → [ja], `zh*` → [zh], anything else → [en].
  static String _pick({
    required String ru,
    required String en,
    required String ja,
    required String zh,
  }) {
    final locale = Intl.defaultLocale ?? 'en';
    if (locale.startsWith('ru')) return ru;
    if (locale.startsWith('ja')) return ja;
    if (locale.startsWith('zh')) return zh;
    return en;
  }
}

class _ErrorPattern {
  const _ErrorPattern(
    this.regex, {
    required this.ru,
    required this.en,
    required this.ja,
    required this.zh,
  });
  final RegExp regex;
  final String ru;
  final String en;
  final String ja;
  final String zh;

  /// Text for the current locale (see [ErrorMapper._pick]).
  String get text => ErrorMapper._pick(ru: ru, en: en, ja: ja, zh: zh);
}
