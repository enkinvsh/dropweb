// Модель главной экрана: входы приложения → всё, что нужно нарисовать. Правила один в один
// с доской (canon/dropweb/android.js: status() 319-325, heroKey() 387-390, homeHtml() 403-451).
// Файл чистый: ни провайдеров, ни Flutter-виджетов, ни `Platform`. Так golden на macOS и
// устройство считают кадр одним кодом, а три сцены без источника данных (offline, error,
// switching) проверяются фикстурами без правок приложения.

import 'package:intl/intl.dart';

import '../../../common/country_name.dart';
import '../../../l10n/l10n.dart';
import '../m3e_format.dart';
import '../widgets/m3e_hero_button.dart';
import '../widgets/m3e_meter.dart';
import '../widgets/m3e_sub_card.dart';

/// Сцены главной (`SCENES` в app.js): метка состояния, на которую опираются тесты.
enum M3eHomeScene {
  homeOff,
  connecting,
  switching,
  homeOn,
  error,
  offline,
  expiring,
  trafficLow,
  trafficOut,
  expired,
}

/// Гигабайт для трафика: 1024³, как в `TrafficValue` приложения.
const int kM3eGigabyte = 1073741824;

/// За сколько дней до конца срока подписка считается «скоро истекает»
/// (`metainfo_widget.dart` приложения: 0 ≤ дней ≤ 3).
const int kM3eExpiringDays = 3;

/// Данные подписки из заголовка `subscription-userinfo`.
class M3eHomeSubscription {
  const M3eHomeSubscription({
    this.usedBytes = 0,
    this.totalBytes = 0,
    this.expire,
  });

  /// upload + download.
  final int usedBytes;

  /// 0 — безлимит.
  final int totalBytes;

  /// Конец срока; `null` — бессрочно.
  final DateTime? expire;
}

/// Всё, что приложение знает о главной в данный момент.
class M3eHomeInput {
  const M3eHomeInput({
    this.vpnOn = false,
    this.connecting = false,
    this.runTime,
    this.switching = false,
    this.error = false,
    this.online = true,
    this.ipAddress,
    this.ipCountryCode,
    this.subscription,
    this.providerName = '',
    this.announce,
    this.linksTappable = true,
  });

  /// VPN поднят (`runTime != null`).
  final bool vpnOn;

  /// Идёт подключение (`globalState.isConnecting`).
  final bool connecting;

  /// Время сеанса; нужно, пока VPN включён.
  final Duration? runTime;

  /// VPN включён, меняется маршрут или страна.
  final bool switching;

  /// Подключение не удалось.
  final bool error;

  /// Есть сеть.
  final bool online;

  /// Внешний адрес (`null` — ещё не определён).
  final String? ipAddress;

  /// Код страны адреса, `RU`; из него строится флаг.
  final String? ipCountryCode;

  /// `null` — заголовка нет: безлимит и бессрочно, а трафик на карточке — прочерк.
  final M3eHomeSubscription? subscription;

  final String providerName;

  /// Сайт или объявление провайдера под чертой карточки.
  final String? announce;

  /// Ссылки в объявлении открываются по нажатию (в магазинных сборках — нет).
  final bool linksTappable;
}

/// Готовый к отрисовке вид главной.
class M3eHomeView {
  const M3eHomeView({
    required this.scene,
    required this.heroState,
    required this.heroDisabled,
    required this.heroPressable,
    required this.heroLabel,
    required this.blocked,
    required this.card,
  });

  final M3eHomeScene scene;

  /// Форма кнопки; при закрытой подписке без активного VPN это `off`.
  final M3eHeroState heroState;

  /// Кнопка серая и не нажимается: подписка закончилась или трафик исчерпан.
  final bool heroDisabled;

  /// Нажатие по кнопке что-то делает. Пока идёт подключение — нет: отменить его
  /// в приложении нечем, подпись «Отменить подключение» остаётся для диктора.
  final bool heroPressable;

  /// Подпись кнопки для диктора.
  final String heroLabel;

  /// Подписка закончилась или трафик исчерпан: маршрут приглушён, ряд кнопок серый.
  final bool blocked;
  final M3eCardData card;
}

/// Остаток подписки на момент [now]: состояние тарифа и число дней до конца.
({M3eSubState state, int daysLeft}) m3eSubStateOf(
  M3eHomeSubscription? sub,
  DateTime now,
) {
  if (sub == null) return (state: M3eSubState.ok, daysLeft: 0);
  final expire = sub.expire;
  if (expire != null && !expire.isAfter(now)) {
    return (state: M3eSubState.expired, daysLeft: 0);
  }
  if (sub.totalBytes > 0 && sub.usedBytes >= sub.totalBytes) {
    return (state: M3eSubState.trafficOut, daysLeft: 0);
  }
  if (expire != null) {
    final left = expire.difference(now);
    // Меньше суток тоже «1 день»: доска знает только дни.
    final days = (left.inMinutes / Duration.minutesPerDay).ceil();
    if (days <= kM3eExpiringDays) {
      return (state: M3eSubState.expiring, daysLeft: days < 1 ? 1 : days);
    }
  }
  return (state: M3eSubState.ok, daysLeft: 0);
}

/// Эмодзи-флаг по коду страны: две региональные буквы; пусто для чужого формата.
String? m3eFlagFromCode(String? code) {
  if (code == null || code.length != 2) return null;
  final up = code.toUpperCase();
  final a = up.codeUnitAt(0), b = up.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return null;
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCodes([base + a, base + b]);
}

/// Число гигабайт без хвоста `,0`: `49,2`, `50`, `0,8` (так подписаны данные доски).
String _plainGb(double gb, String? locale) {
  final text = gb.toStringAsFixed(1);
  final trimmed =
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return decimalWithLocale(trimmed, locale);
}

String _dateText(DateTime date, String? localeName) {
  final locale = localeName ?? Intl.getCurrentLocale();
  try {
    // Русский формат доски — «13 января 2027», без «г.» из `yMMMMd`.
    final format = locale.startsWith('ru')
        ? DateFormat('d MMMM y', locale)
        : DateFormat.yMMMMd(locale);
    return format.format(date);
  } on Object {
    // Данные локали даты не загружены (тест без делегатов): запасной ISO.
    return DateFormat('yyyy-MM-dd', 'en_US').format(date);
  }
}

/// Считает вид главной по правилам доски.
///
/// [now] передаётся снаружи, чтобы срок подписки считался на одно и то же время
/// в тестах и на устройстве. [locale] — имя локали экрана для чисел и дат (без него
/// берётся глобальная локаль intl). Требует `AppLocalizations.load(locale)` до вызова.
///
/// [ipPending] — «проверка адреса идёт или ждётся»: её знает экран (таймеры проверок
/// живут в его состоянии), а не вход приложения. [ipSettling] — идёт сессия проверки после
/// смены туннеля: пока она не кончилась, индикатор держится даже при известном адресе,
/// иначе промежуточный ответ показался бы раньше финального.
M3eHomeView buildM3eHomeView(
  AppLocalizations l,
  M3eHomeInput input, {
  required DateTime now,
  String? locale,
  bool ipPending = false,
  bool ipSettling = false,
}) {
  // `home` доски: connecting | on | error | off. Переключение маршрута при включённом
  // VPN тоже connecting, как `SCENES.switching`.
  final conn = input.connecting || input.switching;
  final on = !conn && input.vpnOn;
  final errorHome = !conn && !on && input.error;
  final sub = m3eSubStateOf(input.subscription, now);
  final blocked =
      sub.state == M3eSubState.expired || sub.state == M3eSubState.trafficOut;
  // Закрытая подписка отключает кнопку, только если VPN не работает: иначе человек
  // не смог бы его выключить. На доске такого сочетания нет (там blocked ⇒ home off).
  final heroBlocked = blocked && !on && !conn;

  // status() доски: тон «ошибка» только вне подключения.
  final String status;
  var bad = false;
  if (conn) {
    status = input.switching ? l.m3eStatusSwitching : l.m3eStatusConnecting;
  } else if (!input.online) {
    status = l.m3eStatusOffline;
    bad = true;
  } else if (on) {
    status = l.m3eStatusConnected;
  } else if (errorHome) {
    status = l.m3eStatusError;
    bad = true;
  } else {
    status = l.m3eStatusDisconnected;
  }

  final subscription = input.subscription;
  M3eTrafficInfo? traffic;
  if (subscription != null && subscription.totalBytes > 0) {
    final used = subscription.usedBytes / kM3eGigabyte;
    final total = subscription.totalBytes / kM3eGigabyte;
    final left = (total - used) < 0 ? 0.0 : total - used;
    traffic = M3eTrafficInfo(
      used: _plainGb(used, locale),
      total: _plainGb(total, locale),
      left: _plainGb(left, locale),
      pct: subscription.usedBytes * 100 / subscription.totalBytes,
    );
  }
  final expire = subscription?.expire;
  final plan = planLine(
    l,
    traffic: traffic,
    until: expire == null ? null : _dateText(expire, locale),
    state: sub.state,
    daysLeft: sub.daysLeft,
  );

  // Без адреса показываем прочерк, как при подключении и без сети.
  final none = conn || !input.online || input.ipAddress == null;
  final address = none ? l.m3eStatNone : input.ipAddress!;
  // Решение владельца 2026-10-29: пока значение определяется, вместо «—» индикатор
  // загрузки M3E. Подключение и переключение тоже считаются ожиданием: адрес появится
  // только после него, и «—» между подключением и значением мигал бы.
  // Без сети проверять нечего — прочерк без анимации, как на доске.
  final ipLoading = input.online &&
      (conn || ipSettling || (input.ipAddress == null && ipPending));
  // Решение владельца 2026-10-30: на главной не светим IP целиком (он попадает на
  // скриншоты и в запись экрана), вместо него страна выхода. Код страны валиден, когда из
  // него строится флаг; без кода показываем только маску адреса, чтобы было видно, что
  // проверка прошла. Колонка «Трафик» убрана: расход остаётся в полосе под тарифом.
  final String countryText;
  if (none) {
    countryText = l.m3eStatNone;
  } else if (m3eFlagFromCode(input.ipCountryCode) != null) {
    countryText = countryDisplayName(
      input.ipCountryCode!,
      locale ?? Intl.getCurrentLocale(),
    );
  } else {
    countryText = maskIpAddress(address);
  }

  final card = M3eCardData(
    providerName: input.providerName,
    dot: conn
        ? M3eDotState.busy
        : bad
            ? M3eDotState.bad
            : on
                ? M3eDotState.on
                : M3eDotState.off,
    statusText: status,
    statusVisible: bad,
    timer: on ? elapsedText(input.runTime ?? Duration.zero) : null,
    planText: plan.text,
    planTone: plan.tone,
    meterPercent: traffic?.pct,
    meterTone:
        traffic == null ? M3eMeterTone.normal : meterToneFor(traffic.pct),
    ipFlag: none ? null : m3eFlagFromCode(input.ipCountryCode),
    ipAddress: address,
    countryText: countryText,
    ipLoading: ipLoading,
    announce: input.announce ?? '',
    showRefresh: plan.needsRefresh,
  );

  final M3eHeroState heroState;
  if (heroBlocked) {
    heroState = M3eHeroState.off;
  } else if (conn) {
    heroState = M3eHeroState.connecting;
  } else if (on) {
    heroState = M3eHeroState.on;
  } else if (errorHome) {
    heroState = M3eHeroState.error;
  } else {
    heroState = M3eHeroState.off;
  }

  final scene = conn
      ? (input.switching ? M3eHomeScene.switching : M3eHomeScene.connecting)
      : !input.online
          ? M3eHomeScene.offline
          : on
              ? M3eHomeScene.homeOn
              : errorHome
                  ? M3eHomeScene.error
                  : switch (sub.state) {
                      M3eSubState.expired => M3eHomeScene.expired,
                      M3eSubState.trafficOut => M3eHomeScene.trafficOut,
                      M3eSubState.expiring => M3eHomeScene.expiring,
                      M3eSubState.ok => (traffic != null && traffic.pct > 90)
                          ? M3eHomeScene.trafficLow
                          : M3eHomeScene.homeOff,
                    };

  return M3eHomeView(
    scene: scene,
    heroState: heroState,
    heroDisabled: heroBlocked,
    heroPressable: !conn,
    heroLabel: on
        ? l.m3eA11yDisconnect
        : conn
            ? l.m3eA11yCancel
            : errorHome
                ? l.m3eA11yRetry
                : l.m3eA11yConnect,
    blocked: blocked,
    card: card,
  );
}
