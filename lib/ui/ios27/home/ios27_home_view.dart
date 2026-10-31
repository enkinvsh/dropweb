// Адаптер «вход главной приложения → данные iOS-экрана». Чистый: без провайдеров и платформы.
//
// Правила сцен (какая сцена когда, какой тариф, что с адресом) уже есть в модели Android-главной
// `buildM3eHomeView`: они взяты с той же доски и заморожены тестами реального конфига владельца.
// Второй раз их писать нельзя — разъедутся. Этот файл только перекладывает готовый вид в то, что
// рисуют виджеты iOS: карточку, кнопку питания, фон и подписи для VoiceOver.

import 'package:dropweb/common/country_name.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart' show M3ePlanTone;
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart' show M3eHeroState;
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart' show M3eDotState;
import 'package:flutter/foundation.dart';

/// Всё, что нужно экрану главной, одним значением.
@immutable
class Ios27HomeData {
  const Ios27HomeData({
    required this.scene,
    required this.card,
    required this.power,
    required this.powerPressable,
    required this.powerLabel,
    required this.backdrop,
    required this.blocked,
    required this.linksTappable,
    required this.joyLabel,
    required this.subscriptionsLabel,
    required this.routeLabel,
    required this.settingsLabel,
  });

  /// Сцена доски (`home-off`, `connecting`, …); экрану нужна только тестам и отладке.
  final M3eHomeScene scene;

  /// Содержимое карточки: все строки уже отформатированы.
  final Ios27CardData card;

  /// Вид кнопки питания.
  final Ios27PowerState power;

  /// Нажатие по кнопке что-то делает. Пока идёт подключение — нет: отменить его в приложении
  /// нечем, подпись «Отменить подключение» остаётся для VoiceOver (как у Android-главной).
  final bool powerPressable;

  /// Подпись кнопки питания для VoiceOver (`Подключить VPN` / `Отключить VPN` / …).
  final String powerLabel;

  /// Яркость листов фона: включено 1, подключение 0.5, остальное 0 (bg.js:171).
  final Ios27BackdropState backdrop;

  /// Подписка закончилась или трафик исчерпан (`blocked()`, app.js:550): кнопка маршрута тускнеет.
  final bool blocked;

  /// Ссылки в объявлении открываются по нажатию.
  final bool linksTappable;

  /// Подпись группы «Подключение и страна» (`joy`, app.js:554).
  final String joyLabel;

  /// Подпись кнопки подписок («Подписка»).
  final String subscriptionsLabel;

  /// Подпись кнопки маршрута («Маршрут: Авто. Открыть список»).
  final String routeLabel;

  /// Подпись шестерёнки («Настройки»).
  final String settingsLabel;
}

/// Собирает [Ios27HomeData] из входа приложения.
///
/// [since] — начало сеанса для живого таймера карточки; его ведёт экран ([Ios27SinceAnchor]), потому
/// что виджет считает секунды сам, а не получает готовую строку. Если не передан, а VPN включён,
/// берётся `now - runTime`. [routeName] — имя страны или узла, через которые идёт трафик; пусто —
/// «Авто» (app.js:559).
Ios27HomeData buildIos27HomeData(
  AppLocalizations l,
  M3eHomeInput input, {
  required DateTime now,
  String? locale,
  bool ipPending = false,
  bool ipSettling = false,
  DateTime? since,
  String? routeName,
}) {
  final view = buildM3eHomeView(
    l,
    input,
    now: now,
    locale: locale,
    ipPending: ipPending,
    ipSettling: ipSettling,
  );
  final c = view.card;
  final live = c.timer != null;

  // Адрес в карточке M3E при «нет адреса» равен прочерку: для iOS это отдельный признак,
  // потому что вместо прочерка может крутиться индикатор (D9), а «—» рисует сам виджет.
  final noIp = c.ipAddress == l.m3eStatNone;

  // Вместо адреса карточка показывает страну выхода (решение владельца 30.10: IP на экране
  // утекает на скриншоты). Код страны приходит из той же проверки, что и адрес. Нет кода, но
  // адрес есть — показываем его замаскированным, чтобы было видно, что проверка прошла.
  final code = input.ipCountryCode?.trim() ?? '';
  final country = noIp
      ? null
      : code.isNotEmpty
          ? countryDisplayName(code, locale)
          : maskIpAddress(c.ipAddress);

  final card = Ios27CardData(
    title: c.providerName,
    dot: switch (c.dot) {
      M3eDotState.off => Ios27DotKind.off,
      M3eDotState.busy => Ios27DotKind.busy,
      M3eDotState.on => Ios27DotKind.on,
      M3eDotState.bad => Ios27DotKind.bad,
    },
    statusText: c.statusText,
    since:
        live ? (since ?? now.subtract(input.runTime ?? Duration.zero)) : null,
    planText: c.planText,
    planTone: switch (c.planTone) {
      M3ePlanTone.normal => Ios27CardTone.normal,
      M3ePlanTone.warn => Ios27CardTone.warn,
      M3ePlanTone.bad => Ios27CardTone.bad,
    },
    meterPercent: c.meterPercent,
    countryLabel: l.ios27StatCountry,
    countryText: country,
    countryFlag: c.ipFlag ?? '',
    countryPending: c.ipLoading,
    countryPlaceholder: l.m3eStatNone,
    // Рядом с индикатором на карточке №4 стоит «Подключение…», а не «Загрузка…».
    countryLoadingLabel: l.m3eStatusConnecting,
    announce: c.announce,
    refreshLabel: c.showRefresh ? l.m3eRefresh : null,
    semanticsLabel: _cardLabel(
      [
        c.providerName,
        c.planText,
        if (c.ipLoading)
          l.m3eStatusConnecting
        else if (country != null)
          '${l.ios27StatCountry}: $country',
        // Слово статуса при определении страны уже сказано выше, а «Обновить» читается
        // отдельной кнопкой.
        if (!c.ipLoading) c.statusText,
      ],
    ),
  );

  // Кнопка питания: `blocked` гасит её только без работающего VPN (иначе его не выключить).
  final power = view.heroDisabled
      ? Ios27PowerState.disabled
      : switch (view.heroState) {
          M3eHeroState.connecting => Ios27PowerState.connecting,
          M3eHeroState.on => Ios27PowerState.on,
          M3eHeroState.error => Ios27PowerState.error,
          M3eHeroState.off => view.scene == M3eHomeScene.offline
              ? Ios27PowerState.offline
              : Ios27PowerState.off,
        };

  final name = (routeName == null || routeName.trim().isEmpty)
      ? l.m3eRouteAuto
      : routeName.trim();

  return Ios27HomeData(
    scene: view.scene,
    card: card,
    power: power,
    powerPressable: view.heroPressable,
    powerLabel: view.heroLabel,
    backdrop: switch (view.heroState) {
      M3eHeroState.on => Ios27BackdropState.on,
      M3eHeroState.connecting => Ios27BackdropState.connecting,
      _ => Ios27BackdropState.off,
    },
    blocked: view.blocked,
    linksTappable: input.linksTappable,
    joyLabel: l.ios27A11yJoy,
    subscriptionsLabel: l.m3eSubTitle,
    routeLabel: l.ios27A11yRoute(name),
    settingsLabel: l.settings,
  );
}

/// Ведёт «начало сеанса» для таймера карточки.
///
/// Приложение отдаёт `runTime` раз в ~2 с и с дрожанием: если считать `now - runTime` каждый раз,
/// секунды на карточке прыгали бы. Поэтому якорь ставится один раз и переставляется, только когда
/// расхождение больше полутора секунд (перезапуск ядра, смена часов) — тот же порог, что у
/// Android-часов `M3eElapsedClock`.
class Ios27SinceAnchor {
  DateTime? _since;

  /// Допустимое расхождение нового кандидата со старым якорем.
  static const Duration tolerance = Duration(milliseconds: 1500);

  /// Текущий якорь; `null`, пока VPN выключен.
  DateTime? get since => _since;

  /// Учитывает свежий [runTime] и возвращает якорь.
  DateTime? update(Duration? runTime, DateTime now) {
    if (runTime == null) {
      return _since = null;
    }
    final candidate = now.subtract(runTime);
    final anchor = _since;
    if (anchor == null || candidate.difference(anchor).abs() > tolerance) {
      _since = candidate;
    }
    return _since;
  }
}

/// Одна читаемая фраза для VoiceOver: части через точку без пустых и без двойных точек.
String _cardLabel(List<String> parts) => parts
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .map((e) => e.endsWith('.') || e.endsWith('…') ? e : '$e.')
    .join(' ');
