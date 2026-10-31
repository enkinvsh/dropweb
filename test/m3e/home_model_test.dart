import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_meter.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'home_scenes.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
    Intl.defaultLocale = 'ru';
  });

  M3eHomeView viewOf(String scene, {bool worst = false}) =>
      buildM3eHomeView(l, homeInputFor(scene, worst: worst), now: kHomeNow);

  group('сцены доски на NORMAL', () {
    test('каждая сцена определяется верно', () {
      for (final id in kHomeSceneIds) {
        expect(viewOf(id).scene, kHomeSceneByName[id], reason: id);
      }
    });

    test('home-off: спокойная карточка, кнопка «Подключить»', () {
      final v = viewOf('home-off');
      expect(v.heroState, M3eHeroState.off);
      expect(v.heroDisabled, isFalse);
      expect(v.heroLabel, l.m3eA11yConnect);
      expect(v.blocked, isFalse);
      expect(v.card.dot, M3eDotState.off);
      expect(v.card.statusText, l.m3eStatusDisconnected);
      expect(v.card.statusVisible, isFalse);
      expect(v.card.timer, isNull);
      expect(v.card.ipAddress, '95.24.118.7');
      expect(v.card.ipFlag, '🇷🇺');
      expect(v.card.showRefresh, isFalse);
    });

    test('connecting: busy, адрес прочерком, нажатие ничего не делает', () {
      final v = viewOf('connecting');
      expect(v.heroState, M3eHeroState.connecting);
      expect(v.heroLabel, l.m3eA11yCancel);
      expect(v.heroPressable, isFalse);
      expect(v.card.dot, M3eDotState.busy);
      expect(v.card.statusText, l.m3eStatusConnecting);
      expect(v.card.statusVisible, isFalse);
      expect(v.card.ipAddress, l.m3eStatNone);
      expect(v.card.ipFlag, isNull);
    });

    test('switching: то же, что connecting, но подпись «Переключение»', () {
      final v = viewOf('switching');
      expect(v.heroState, M3eHeroState.connecting);
      expect(v.card.dot, M3eDotState.busy);
      expect(v.card.statusText, l.m3eStatusSwitching);
      expect(v.card.ipAddress, l.m3eStatNone);
    });

    test('home-on: таймер и адрес из данных, кнопка «Отключить»', () {
      final v = viewOf('home-on');
      expect(v.heroState, M3eHeroState.on);
      expect(v.heroLabel, l.m3eA11yDisconnect);
      expect(v.card.dot, M3eDotState.on);
      expect(v.card.statusText, l.m3eStatusConnected);
      expect(v.card.statusVisible, isFalse);
      expect(v.card.timer, '12:49');
      expect(v.card.ipAddress, '185.107.56.12');
    });

    test('error: красная точка, «Повторить подключение»', () {
      final v = viewOf('error');
      expect(v.heroState, M3eHeroState.error);
      expect(v.heroLabel, l.m3eA11yRetry);
      expect(v.card.dot, M3eDotState.bad);
      expect(v.card.statusText, l.m3eStatusError);
      expect(v.card.statusVisible, isTrue);
      expect(v.card.timer, isNull);
    });

    test('offline: «Нет сети», адрес прочерком, кнопка не блокируется', () {
      final v = viewOf('offline');
      expect(v.heroState, M3eHeroState.off);
      expect(v.heroDisabled, isFalse);
      expect(v.card.dot, M3eDotState.bad);
      expect(v.card.statusText, l.m3eStatusOffline);
      expect(v.card.statusVisible, isTrue);
      expect(v.card.ipAddress, l.m3eStatNone);
    });

    test('expiring: предупреждение в строке тарифа, «Обновить» нет', () {
      final v = viewOf('expiring');
      expect(v.card.planTone, M3ePlanTone.warn);
      expect(v.card.showRefresh, isFalse);
      expect(v.blocked, isFalse);
      expect(v.heroDisabled, isFalse);
    });

    test('traffic-low: шкала в тоне предупреждения', () {
      final v = viewOf('traffic-low');
      expect(v.card.meterPercent, closeTo(98.4, 0.01));
      expect(v.card.meterTone, isNot(M3eMeterTone.normal));
      expect(v.blocked, isFalse);
    });

    test('traffic-out: подписка закрыта, кнопка и маршрут приглушены', () {
      final v = viewOf('traffic-out');
      expect(v.blocked, isTrue);
      expect(v.heroDisabled, isTrue);
      expect(v.heroState, M3eHeroState.off);
      expect(v.card.showRefresh, isTrue);
      expect(v.card.meterPercent, closeTo(100, 0.01));
    });

    test('expired: подписка закрыта, кнопка серая', () {
      final v = viewOf('expired');
      expect(v.blocked, isTrue);
      expect(v.heroDisabled, isTrue);
      expect(v.card.showRefresh, isTrue);
      expect(v.card.planTone, M3ePlanTone.bad);
    });
  });

  group('правила, которых нет на доске', () {
    test('закрытая подписка при включённом VPN кнопку не блокирует', () {
      const input = M3eHomeInput(
        vpnOn: true,
        runTime: Duration(minutes: 1),
        subscription: M3eHomeSubscription(usedBytes: 10, totalBytes: 10),
      );
      final v = buildM3eHomeView(l, input, now: kHomeNow);
      expect(v.blocked, isTrue);
      expect(v.heroDisabled, isFalse);
      expect(v.heroState, M3eHeroState.on);
    });

    test('без адреса вместо него прочерк', () {
      final v = buildM3eHomeView(l, const M3eHomeInput(), now: kHomeNow);
      expect(v.card.ipAddress, l.m3eStatNone);
      expect(v.card.ipFlag, isNull);
    });

    test('безлимит и бессрочно: шкалы нет', () {
      final v = buildM3eHomeView(
        l,
        const M3eHomeInput(subscription: M3eHomeSubscription()),
        now: kHomeNow,
      );
      expect(v.card.meterPercent, isNull);
      expect(v.scene, M3eHomeScene.homeOff);
    });

    test('страна выхода вместо адреса: короткое название на языке экрана', () {
      M3eHomeView withCode(String? code, {String? locale}) => buildM3eHomeView(
            l,
            M3eHomeInput(ipAddress: '185.107.56.12', ipCountryCode: code),
            now: kHomeNow,
            locale: locale,
          );
      expect(withCode('NL').card.countryText, 'Нидерланды');
      expect(withCode('us').card.countryText, 'США');
      expect(withCode('US', locale: 'en').card.countryText, 'United States');
      expect(withCode('NL', locale: 'en').card.countryText, 'Netherlands');
    });

    test('нет адреса, нет сети или подключение: прочерк', () {
      expect(
        buildM3eHomeView(l, const M3eHomeInput(), now: kHomeNow)
            .card
            .countryText,
        l.m3eStatNone,
      );
      for (final scene in ['offline', 'connecting', 'switching']) {
        expect(viewOf(scene).card.countryText, l.m3eStatNone, reason: scene);
      }
    });

    test('адрес есть, кода страны нет: только маска адреса', () {
      String masked(String ip, [String? code]) => buildM3eHomeView(
            l,
            M3eHomeInput(ipAddress: ip, ipCountryCode: code),
            now: kHomeNow,
          ).card.countryText;
      expect(masked('94.183.247.4'), '94.183.•••.•••');
      expect(masked('2a0e:97c0:3e3:4f1::1c'), '2a0e:97c0:•••');
      // Код неверного формата флага не даёт: считаем, что страны нет.
      expect(masked('94.183.247.4', 'RUS'), '94.183.•••.•••');
      expect(masked('94.183.247.4', ''), '94.183.•••.•••');
    });

    test('полный адрес не попадает в текст страны ни в одной сцене', () {
      for (final worst in [false, true]) {
        for (final id in kHomeSceneIds) {
          final c = viewOf(id, worst: worst).card;
          if (c.ipAddress == l.m3eStatNone) continue;
          expect(c.countryText, isNot(contains(c.ipAddress)),
              reason: '$id worst=$worst');
        }
      }
    });

    test('флаг по коду страны', () {
      expect(m3eFlagFromCode('ru'), '🇷🇺');
      expect(m3eFlagFromCode('NL'), '🇳🇱');
      expect(m3eFlagFromCode(null), isNull);
      expect(m3eFlagFromCode('RUS'), isNull);
      expect(m3eFlagFromCode('1A'), isNull);
    });

    test('остаток подписки: граница трёх дней и истёкший срок', () {
      M3eSubState at(Duration d) => m3eSubStateOf(
            M3eHomeSubscription(expire: kHomeNow.add(d)),
            kHomeNow,
          ).state;
      expect(at(const Duration(days: 3)), M3eSubState.expiring);
      expect(at(const Duration(days: 4)), M3eSubState.ok);
      expect(at(const Duration(seconds: -1)), M3eSubState.expired);
    });
  });

  group('ожидание адреса (индикатор вместо прочерка)', () {
    M3eHomeView build(
      String scene, {
      bool ipPending = false,
      bool ipSettling = false,
      bool noAddress = false,
      bool online = true,
    }) {
      final base = homeInputFor(scene);
      return buildM3eHomeView(
        l,
        M3eHomeInput(
          vpnOn: base.vpnOn,
          connecting: base.connecting,
          runTime: base.runTime,
          switching: base.switching,
          error: base.error,
          online: online,
          ipAddress: noAddress ? null : base.ipAddress,
          ipCountryCode: base.ipCountryCode,
          subscription: base.subscription,
          providerName: base.providerName,
        ),
        now: kHomeNow,
        ipPending: ipPending,
        ipSettling: ipSettling,
      );
    }

    test('VPN выключен, адрес известен: ничего не грузится', () {
      final c = build('home-off', ipPending: true).card;
      expect(c.ipLoading, isFalse);
    });

    test('VPN выключен, адреса нет и его ждут: грузится адрес', () {
      final c = build('home-off', ipPending: true, noAddress: true).card;
      expect(c.ipLoading, isTrue);
      expect(c.ipAddress, l.m3eStatNone);
    });

    test('VPN выключен, адреса нет и ждать нечего: прочерк без анимации', () {
      final c = build('home-off', noAddress: true).card;
      expect(c.ipLoading, isFalse);
      expect(c.ipAddress, l.m3eStatNone);
    });

    test('подключение и переключение: грузится адрес', () {
      for (final scene in ['connecting', 'switching']) {
        final c = build(scene).card;
        expect(c.ipLoading, isTrue, reason: scene);
      }
    });

    test('смена узла: адрес сброшен и проверяется заново', () {
      final c = build('home-on', ipPending: true, noAddress: true).card;
      expect(c.ipLoading, isTrue);
    });

    test('сессия проверки идёт: промежуточный адрес не показывается', () {
      for (final scene in ['home-on', 'home-off']) {
        final c = build(scene, ipSettling: true).card;
        expect(c.ipLoading, isTrue, reason: scene);
      }
    });

    test('сессия кончилась: адрес на месте, индикатора нет', () {
      final c = build('home-on').card;
      expect(c.ipLoading, isFalse);
      expect(c.ipAddress, isNot(l.m3eStatNone));
    });

    test('без сети проверять нечего: прочерк без анимации', () {
      for (final scene in ['offline', 'connecting']) {
        final c = build(
          scene,
          online: false,
          ipPending: true,
          noAddress: true,
        ).card;
        expect(c.ipLoading, isFalse, reason: scene);
      }
    });
  });
}
