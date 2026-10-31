// Адаптер главной iOS на данных доски и на входах реального конфига владельца:
// карточка, кнопка питания, фон, подписи VoiceOver и якорь таймера.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_view.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../m3e/home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/home_harness.dart' show kIos27HomeScenes;

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
    Intl.defaultLocale = 'ru';
  });

  Ios27HomeData dataOf(
    String scene, {
    bool worst = false,
    bool ipPending = false,
    bool ipSettling = false,
    DateTime? since,
    String? routeName,
  }) =>
      buildIos27HomeData(
        l,
        homeInputFor(scene, worst: worst),
        now: kHomeNow,
        locale: 'ru',
        ipPending: ipPending,
        ipSettling: ipSettling,
        since: since,
        routeName: routeName,
      );

  group('карточка на NORMAL: тексты доски', () {
    test('home-off', () {
      final c = dataOf('home-off').card;
      expect(c.title, 'DROPWEB');
      expect(c.dot, Ios27DotKind.off);
      expect(c.since, isNull);
      expect(c.planText, ios27BoardPlanLine(kIos27BoardNormal));
      expect(c.planTone, Ios27CardTone.normal);
      // Решение владельца 30.10: вместо IP — страна, колонки «Трафик» нет.
      expect(c.countryLabel, 'Страна');
      expect(c.countryText, 'Россия');
      expect(c.countryFlag, kIos27BoardFlagOff);
      expect(c.countryPending, isFalse);
      expect(c.countryPlaceholder, '—');
      expect(c.countryLoadingLabel, 'Подключение…');
      expect(c.announce, kIos27BoardNormal.announce);
      expect(c.refreshLabel, isNull);
      expect(c.semanticsLabel,
          'DROPWEB. Безлимит · бессрочно. Страна: Россия. Не подключено.');
    });

    test('connecting: busy, адреса нет, вместо прочерка индикатор (D9)', () {
      final c = dataOf('connecting').card;
      expect(c.dot, Ios27DotKind.busy);
      expect(c.statusText, kIos27BoardStatusConnecting);
      expect(c.countryText, isNull);
      expect(c.countryFlag, isEmpty);
      expect(c.countryPending, isTrue);
      expect(c.offline, isFalse);
    });

    test('home-on: таймер от since, страна и флаг', () {
      final since = kHomeNow.subtract(kHomeRunTime);
      final c = dataOf('home-on', since: since).card;
      expect(c.dot, Ios27DotKind.on);
      expect(c.since, since);
      expect(c.live, isTrue);
      expect(c.statusText, kIos27BoardStatusOn);
      expect(c.countryText, 'Нидерланды');
      expect(c.countryFlag, '🇳🇱');
    });

    test('home-on без переданного since берёт now - runTime', () {
      expect(dataOf('home-on').card.since, kHomeNow.subtract(kHomeRunTime));
    });

    test('error: красная точка, слово статуса', () {
      final c = dataOf('error').card;
      expect(c.dot, Ios27DotKind.bad);
      expect(c.statusText, kIos27BoardStatusError);
      expect(c.countryText, 'Россия');
    });

    test('offline: прочерк только здесь, индикатора нет (D9)', () {
      final c = dataOf('offline', ipPending: true).card;
      expect(c.dot, Ios27DotKind.bad);
      expect(c.statusText, kIos27BoardStatusNoNetwork);
      expect(c.countryText, isNull);
      expect(c.countryPending, isFalse);
      expect(c.offline, isTrue);
      expect(c.countryPlaceholder, '—');
    });

    test('expiring: предупреждение и «Осталось 2 дня»', () {
      final c = dataOf('expiring').card;
      expect(c.planText, 'Осталось 2 дня');
      expect(c.planTone, Ios27CardTone.warn);
      expect(c.refreshLabel, isNull);
    });

    test('traffic-low: оранжевое предупреждение и шкала', () {
      final c = dataOf('traffic-low').card;
      expect(
        c.planText,
        ios27BoardPlanLine(kIos27BoardNormal, traffic: kIos27BoardTrafficLow),
      );
      expect(c.planTone, Ios27CardTone.warn);
      expect(c.meterPercent, closeTo(98.4, 0.05));
      expect(c.refreshLabel, isNull);
    });

    test('traffic-out: красная строка, шкала полная, кнопка «Обновить»', () {
      final c = dataOf('traffic-out').card;
      expect(c.planText, 'Трафик закончился');
      expect(c.planTone, Ios27CardTone.bad);
      expect(c.meterPercent, 100);
      expect(c.refreshLabel, 'Обновить');
    });

    test('expired: красная строка и «Обновить»', () {
      final c = dataOf('expired').card;
      expect(c.planText, 'Подписка закончилась');
      expect(c.planTone, Ios27CardTone.bad);
      expect(c.refreshLabel, 'Обновить');
    });
  });

  group('индикатор вместо прочерка (D9)', () {
    M3eHomeInput input({
      bool online = true,
      String? ip,
      bool connecting = false,
    }) =>
        M3eHomeInput(
          online: online,
          connecting: connecting,
          ipAddress: ip,
          ipCountryCode: ip == null ? null : 'NL',
          providerName: 'DROPWEB',
        );

    Ios27CardData card(
      M3eHomeInput i, {
      bool pending = false,
      bool settling = false,
    }) =>
        buildIos27HomeData(
          l,
          i,
          now: kHomeNow,
          locale: 'ru',
          ipPending: pending,
          ipSettling: settling,
        ).card;

    test('адреса нет, ожидание идёт: индикатор', () {
      expect(card(input(), pending: true).countryPending, isTrue);
    });

    test('адреса нет, ожидание кончилось: честный прочерк без индикатора', () {
      final c = card(input());
      expect(c.countryPending, isFalse);
      expect(c.countryText, isNull);
      expect(c.offline, isTrue, reason: 'виджет рисует countryPlaceholder');
    });

    test('сессия проверки идёт: индикатор держится при известном адресе', () {
      final c = card(input(ip: '1.2.3.4'), settling: true);
      expect(c.countryPending, isTrue);
      expect(c.countryText, 'Нидерланды');
    });

    test('адрес известен, проверок нет: адрес с флагом', () {
      final c = card(input(ip: '1.2.3.4'));
      expect(c.countryPending, isFalse);
      expect(c.countryText, 'Нидерланды');
      expect(c.countryFlag, '🇳🇱');
    });

    test('нет сети: индикатора нет, даже если ожидание идёт', () {
      expect(card(input(online: false), pending: true).countryPending, isFalse);
    });
  });

  group('страна вместо IP (решение владельца 30.10)', () {
    M3eHomeInput withIp(String? ip, String? code) =>
        M3eHomeInput(providerName: 'X', ipAddress: ip, ipCountryCode: code);

    Ios27CardData cardOf(M3eHomeInput i, {String locale = 'ru'}) =>
        buildIos27HomeData(l, i, now: kHomeNow, locale: locale).card;

    test('название на языке приложения, код в регистре не важен', () {
      expect(cardOf(withIp('1.2.3.4', 'nl')).countryText, 'Нидерланды');
      expect(cardOf(withIp('1.2.3.4', 'NL'), locale: 'en').countryText,
          'Netherlands');
      expect(cardOf(withIp('1.2.3.4', 'NL'), locale: 'ja').countryText, 'オランダ');
      expect(
          cardOf(withIp('1.2.3.4', 'NL'), locale: 'zh_CN').countryText, '荷兰');
    });

    test('неизвестная локаль — английский, неизвестный код — сам код', () {
      expect(cardOf(withIp('1.2.3.4', 'NL'), locale: 'de').countryText,
          'Netherlands');
      expect(cardOf(withIp('1.2.3.4', 'ZZ')).countryText, 'ZZ');
    });

    test('кода нет, адрес есть: адрес маскируется, полный не попадает', () {
      final c = cardOf(withIp('94.183.12.34', null));
      expect(c.countryText, '94.183.•••.•••');
      expect(c.countryText, isNot(contains('12.34')));
      expect(cardOf(withIp('94.183.12.34', '')).countryText, '94.183.•••.•••');
      expect(cardOf(withIp('2a0e:97c0:3e3:4f1::1c', null)).countryText,
          '2a0e:97c0:•••');
    });

    test('адреса нет: страны нет, даже если код пришёл', () {
      expect(cardOf(withIp(null, 'NL')).countryText, isNull);
    });

    test('полный адрес нигде в данных карточки не встречается', () {
      for (final scene in kIos27HomeScenes) {
        final c = dataOf(scene).card;
        final all = [
          c.title, c.statusText, c.planText, c.countryLabel, c.countryText,
          c.countryFlag, c.countryPlaceholder, c.countryLoadingLabel,
          c.announce, c.semanticsLabel, c.refreshLabel, //
        ].whereType<String>().join('|');
        expect(all, isNot(contains(kIos27BoardNormal.ipOn)), reason: scene);
        expect(all, isNot(contains(kIos27BoardIpOff)), reason: scene);
      }
    });
  });

  group('кнопка питания, фон, подписи', () {
    const power = {
      'home-off': Ios27PowerState.off,
      'connecting': Ios27PowerState.connecting,
      'home-on': Ios27PowerState.on,
      'error': Ios27PowerState.error,
      'offline': Ios27PowerState.offline,
      'expiring': Ios27PowerState.off,
      'traffic-low': Ios27PowerState.off,
      'traffic-out': Ios27PowerState.disabled,
      'expired': Ios27PowerState.disabled,
    };
    for (final e in power.entries) {
      test('${e.key}: кнопка ${e.value.name}', () {
        expect(dataOf(e.key).power, e.value);
      });
    }

    test('подключение: кнопка не нажимается, подпись «Отменить»', () {
      final d = dataOf('connecting');
      expect(d.powerPressable, isFalse);
      expect(d.powerLabel, 'Отменить подключение');
    });

    test('подписи кнопки питания по состояниям', () {
      expect(dataOf('home-off').powerLabel, 'Подключить VPN');
      expect(dataOf('home-on').powerLabel, 'Отключить VPN');
      expect(dataOf('error').powerLabel, 'Повторить подключение');
      expect(dataOf('home-off').powerPressable, isTrue);
    });

    test('фон: включено 1, подключение 0.5, остальное 0', () {
      expect(dataOf('home-on').backdrop, Ios27BackdropState.on);
      expect(dataOf('connecting').backdrop, Ios27BackdropState.connecting);
      for (final s in ['home-off', 'error', 'offline', 'expired']) {
        expect(dataOf(s).backdrop, Ios27BackdropState.off, reason: s);
      }
    });

    test('blocked только при закончившейся подписке или трафике', () {
      expect(dataOf('expired').blocked, isTrue);
      expect(dataOf('traffic-out').blocked, isTrue);
      expect(dataOf('traffic-low').blocked, isFalse);
      expect(dataOf('home-on').blocked, isFalse);
    });

    test('подписи группы, подписки, шестерёнки и маршрута', () {
      final d = dataOf('home-off');
      expect(d.joyLabel, 'Подключение и страна');
      expect(d.subscriptionsLabel, 'Подписка');
      expect(d.settingsLabel, 'Настройки');
      expect(d.routeLabel, 'Маршрут: Авто. Открыть список');
      expect(
        dataOf('home-off', routeName: ' Нидерланды ').routeLabel,
        'Маршрут: Нидерланды. Открыть список',
      );
      expect(
        dataOf('home-off', routeName: '').routeLabel,
        'Маршрут: Авто. Открыть список',
      );
    });
  });

  group('WORST: данные не обрезаются адаптером', () {
    test('длинное имя и объявление проходят как есть, IPv6 не показывается',
        () {
      final c = dataOf('home-on', worst: true).card;
      expect(c.title, kIos27BoardWorst.profiles.first);
      expect(c.countryText, isNot(contains(':')));
      expect(c.announce, kIos27BoardWorst.announce);
    });
  });

  group('якорь таймера', () {
    final t0 = DateTime(2026, 10, 30, 12);

    test('VPN выключен: якоря нет', () {
      expect(Ios27SinceAnchor().update(null, t0), isNull);
    });

    test('первое значение ставит якорь = now - runTime', () {
      final a = Ios27SinceAnchor();
      expect(
        a.update(const Duration(seconds: 10), t0),
        t0.subtract(const Duration(seconds: 10)),
      );
    });

    test('дрожание в пределах полутора секунд якорь не двигает', () {
      final a = Ios27SinceAnchor();
      final first = a.update(const Duration(seconds: 10), t0)!;
      // Через 2 с приложение прислало 11,2 с вместо 12: секунды не должны прыгать.
      final next = a.update(
        const Duration(milliseconds: 11200),
        t0.add(const Duration(seconds: 2)),
      );
      expect(next, first);
    });

    test('расхождение больше полутора секунд переставляет якорь', () {
      final a = Ios27SinceAnchor()..update(const Duration(seconds: 10), t0);
      final later = t0.add(const Duration(seconds: 2));
      final next = a.update(const Duration(seconds: 3), later);
      expect(next, later.subtract(const Duration(seconds: 3)));
    });

    test('выключение сбрасывает якорь, новое включение ставит заново', () {
      final a = Ios27SinceAnchor()..update(const Duration(seconds: 10), t0);
      expect(a.update(null, t0), isNull);
      expect(a.since, isNull);
      expect(
        a.update(const Duration(seconds: 1), t0),
        t0.subtract(const Duration(seconds: 1)),
      );
    });
  });
}
