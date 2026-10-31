import 'package:intl/intl.dart';

/// Превращает сырые строки ошибок ядра mihomo и сети в короткие тексты для тоста.
///
/// Ядро шлёт технические строки вроде «dial tcp 1.2.3.4:443: i/o timeout»,
/// которые обычному пользователю ничего не говорят. Тост вмещает две строки,
/// поэтому текст здесь — одна короткая фраза с сутью ошибки, без советов и
/// второго предложения; подробности остаются в логе.
///
/// Язык берётся по префиксу [Intl.defaultLocale]: `ru`, `ja` и `zh` имеют свой
/// текст, остальные локали получают английский.
class ErrorMapper {
  ErrorMapper._();

  static final _patterns = <_ErrorPattern>[
    _ErrorPattern(
      RegExp(r'activeInAnotherSession', caseSensitive: false),
      ru: 'Dropweb уже запущен в другой сессии Windows',
      en: 'Dropweb is running in another Windows session',
      ja: 'Dropwebは別のWindowsセッションで実行中です',
      zh: 'Dropweb 已在另一个 Windows 会话中运行',
    ),
    // `tun start timeout` — наш таймаут ожидания подтверждения TUN на Android.
    _ErrorPattern(
      RegExp(r'TUN listener start timed out|tun start timeout',
          caseSensitive: false),
      ru: 'VPN запускается дольше обычного',
      en: 'VPN is taking longer than usual to start',
      ja: 'VPNの起動に時間がかかっています',
      zh: 'VPN 启动时间比平时长',
    ),
    // Наши таймауты ядра на десктопе (fail-closed).
    _ErrorPattern(
      RegExp(r'core did not answer|core call timed out', caseSensitive: false),
      ru: 'VPN-ядро не отвечает',
      en: 'VPN core is not responding',
      ja: 'VPNコアが応答しません',
      zh: 'VPN 核心无响应',
    ),
    // Сеть недоступна / нет интернета.
    _ErrorPattern(
      RegExp(r'network is unreachable|no route to host', caseSensitive: false),
      ru: 'Нет подключения к интернету',
      en: 'No internet connection',
      ja: 'インターネットに接続されていません',
      zh: '无网络连接',
    ),
    // Сбой DNS.
    _ErrorPattern(
      RegExp(r'all DNS request failed|no such host|dns.*fail',
          caseSensitive: false),
      ru: 'Не удаётся найти сервер',
      en: 'Cannot find the server',
      ja: 'サーバーが見つかりません',
      zh: '找不到服务器',
    ),
    // Таймаут соединения.
    _ErrorPattern(
      RegExp(r'i/o timeout|context deadline exceeded|connection timed out',
          caseSensitive: false),
      ru: 'Сервер не отвечает',
      en: 'Server is not responding',
      ja: 'サーバーが応答しません',
      zh: '服务器无响应',
    ),
    // Таймауты Dio (connection / receive / send) и Dart TimeoutException.
    _ErrorPattern(
      RegExp(
          r'connection timeout|receive timeout|send timeout|connectionTimeout|receiveTimeout|sendTimeout|TimeoutException',
          caseSensitive: false),
      ru: 'Сервер не отвечает',
      en: 'Server is not responding',
      ja: 'サーバーが応答しません',
      zh: '服务器无响应',
    ),
    // Отказ в соединении.
    _ErrorPattern(
      RegExp(r'connection refused', caseSensitive: false),
      ru: 'Сервер отклонил соединение',
      en: 'Server refused the connection',
      ja: 'サーバーが接続を拒否しました',
      zh: '服务器拒绝了连接',
    ),
    // Сброс соединения.
    _ErrorPattern(
      RegExp(r'connection reset by peer|broken pipe', caseSensitive: false),
      ru: 'Соединение прервано',
      en: 'Connection interrupted',
      ja: '接続が中断されました',
      zh: '连接已中断',
    ),
    // EOF — общий обрыв соединения.
    _ErrorPattern(
      RegExp(r'EOF|unexpected EOF', caseSensitive: false),
      ru: 'Соединение с сервером потеряно',
      en: 'Lost connection to the server',
      ja: 'サーバーとの接続が切れました',
      zh: '与服务器的连接已断开',
    ),
    // Плохой TLS-сертификат (Dio bad certificate и ошибки проверки).
    _ErrorPattern(
      RegExp(
          r'bad certificate|certificate verify failed|CERTIFICATE_VERIFY_FAILED|HandshakeException',
          caseSensitive: false),
      ru: 'Сертификат сервера не прошёл проверку',
      en: 'Server certificate check failed',
      ja: 'サーバー証明書を検証できません',
      zh: '服务器证书验证失败',
    ),
    // Ошибки рукопожатия TLS / Reality.
    _ErrorPattern(
      RegExp(r'tls.*handshake|reality.*verif|certificate',
          caseSensitive: false),
      ru: 'Ошибка защищённого соединения',
      en: 'Secure connection failed',
      ja: '安全な接続に失敗しました',
      zh: '安全连接失败',
    ),
    // Узел не найден в конфигурации.
    _ErrorPattern(
      RegExp(r'proxy.*not found|proxy adapter not found', caseSensitive: false),
      ru: 'Сервер не найден в подписке',
      en: 'Server not found in the subscription',
      ja: 'サブスクリプションにサーバーが見つかりません',
      zh: '订阅中找不到该服务器',
    ),
    // Порт занят.
    _ErrorPattern(
      RegExp(r'address already in use', caseSensitive: false),
      ru: 'Порт занят другим приложением',
      en: 'Port is used by another app',
      ja: 'ポートは他のアプリで使用中です',
      zh: '端口被其他应用占用',
    ),
    // Кончились дескрипторы.
    _ErrorPattern(
      RegExp(r'too many open files', caseSensitive: false),
      ru: 'Слишком много подключений',
      en: 'Too many connections',
      ja: '接続数が多すぎます',
      zh: '连接数过多',
    ),
    // Ошибки авторизации.
    _ErrorPattern(
      RegExp(r'auth.*fail|authentication.*fail|unauthorized',
          caseSensitive: false),
      ru: 'Ошибка авторизации',
      en: 'Authentication failed',
      ja: '認証に失敗しました',
      zh: '认证失败',
    ),
    // HTTP 404.
    _ErrorPattern(
      RegExp(r'status code of 404|404 Not Found', caseSensitive: false),
      ru: 'Подписка не найдена',
      en: 'Subscription not found',
      ja: 'サブスクリプションが見つかりません',
      zh: '找不到订阅',
    ),
    // HTTP 403.
    _ErrorPattern(
      RegExp(r'status code of 403|403 Forbidden', caseSensitive: false),
      ru: 'Доступ запрещён',
      en: 'Access denied',
      ja: 'アクセスが拒否されました',
      zh: '访问被拒绝',
    ),
    // HTTP 5xx.
    _ErrorPattern(
      RegExp(
          r'status code of 50[0-9]|502 Bad Gateway|503 Service Unavailable|500 Internal',
          caseSensitive: false),
      ru: 'Сервер подписки недоступен',
      en: 'Subscription server unavailable',
      ja: 'サブスクリプションサーバーに接続できません',
      zh: '订阅服务器不可用',
    ),
    // Ошибка разбора YAML: провайдер отдал не тот формат (например, сырой
    // VLESS вместо Mihomo YAML).
    _ErrorPattern(
      RegExp(r'yaml:\s*unmarshal errors|cannot unmarshal !!str',
          caseSensitive: false),
      ru: 'Формат подписки не поддерживается',
      en: 'Subscription format is not supported',
      ja: 'サブスクリプションの形式に対応していません',
      zh: '不支持该订阅格式',
    ),
    // Ошибка токена YAML — та же причина: неверный формат подписки.
    _ErrorPattern(
      RegExp(r'yaml:\s*found character that cannot start any token',
          caseSensitive: false),
      ru: 'Формат подписки не поддерживается',
      en: 'Subscription format is not supported',
      ja: 'サブスクリプションの形式に対応していません',
      zh: '不支持该订阅格式',
    ),
    // Тело подписки больше нашего лимита (наш собственный throw).
    _ErrorPattern(
      RegExp(r'Subscription too large', caseSensitive: false),
      ru: 'Подписка слишком большая',
      en: 'Subscription is too large',
      ja: 'サブスクリプションが大きすぎます',
      zh: '订阅文件过大',
    ),
    // Редирект без заголовка Location (наш собственный throw).
    _ErrorPattern(
      RegExp(r'Redirect detected, but no location', caseSensitive: false),
      ru: 'Сервер подписки ответил некорректно',
      en: 'Subscription server replied incorrectly',
      ja: 'サブスクリプションサーバーの応答が不正です',
      zh: '订阅服务器响应无效',
    ),
    // Нет интернета / хост недоступен / DioException connection error /
    // SocketException.
    _ErrorPattern(
      RegExp(
          r'DioException.*connection error|SocketException|Failed host lookup|connectionError',
          caseSensitive: false),
      ru: 'Нет подключения к интернету',
      en: 'No internet connection',
      ja: 'インターネットに接続されていません',
      zh: '无网络连接',
    ),
    // Функция недоступна на платформе (нет нативной реализации).
    _ErrorPattern(
      RegExp(r'MissingPluginException', caseSensitive: false),
      ru: 'Недоступно на этой платформе',
      en: 'Not available on this platform',
      ja: 'このプラットフォームでは利用できません',
      zh: '此平台不支持',
    ),
    // Некорректный ответ / конфиг (ошибка разбора).
    _ErrorPattern(
      RegExp(r'FormatException', caseSensitive: false),
      ru: 'Некорректный ответ сервера',
      en: 'Invalid server response',
      ja: 'サーバーの応答が不正です',
      zh: '服务器响应无效',
    ),
  ];

  /// Находит фрагмент «status code of NNN» в ошибке Dio о плохом ответе.
  static final _httpStatusRegex = RegExp(r'status code of (\d{3})');

  /// Переводит сырую строку ошибки в короткий понятный текст.
  /// Возвращает null, если ни один известный шаблон не подошёл: сырой текст
  /// в тост показывать нельзя, вызывающий берёт [generic] или свою фразу.
  static String? mapError(String rawError) {
    for (final pattern in _patterns) {
      if (pattern.regex.hasMatch(rawError)) {
        return pattern.text;
      }
    }
    // Плохой ответ Dio с HTTP-статусом, не покрытым отдельным шаблоном.
    final statusMatch = _httpStatusRegex.firstMatch(rawError);
    if (statusMatch != null) {
      final code = statusMatch.group(1);
      return _pick(
        ru: 'Сервер вернул ошибку $code',
        en: 'Server returned error $code',
        ja: 'サーバーがエラー$codeを返しました',
        zh: '服务器返回错误 $code',
      );
    }
    return null;
  }

  /// Общий запасной текст, когда [mapError] вернул null. Вызывающие, которым
  /// доступен контекст, предпочитают ARB-текст `genericErrorMessage`; этот
  /// геттер — запасной вариант ru/en/ja/zh для кода без виджетов.
  static String get generic => _pick(
        ru: 'Что-то пошло не так',
        en: 'Something went wrong',
        ja: '問題が発生しました',
        zh: '出了点问题',
      );

  /// Не удалось запустить VPN-сервис.
  static String get vpnStartFailed => _pick(
        ru: 'Не удалось запустить VPN',
        en: 'Could not start VPN',
        ja: 'VPNを起動できませんでした',
        zh: '无法启动 VPN',
      );

  /// Пользователь отказал в разрешении на VPN.
  static String get vpnPermissionDenied => _pick(
        ru: 'Нет разрешения на VPN',
        en: 'VPN permission denied',
        ja: 'VPNの権限がありません',
        zh: '没有 VPN 权限',
      );

  /// Выбирает вариант по текущему [Intl.defaultLocale]:
  /// `ru*` → [ru], `ja*` → [ja], `zh*` → [zh], иначе → [en].
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

  /// Текст для текущей локали (см. [ErrorMapper._pick]).
  String get text => ErrorMapper._pick(ru: ru, en: en, ja: ja, zh: zh);
}
