import 'dart:ui' show Locale;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_meter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  late AppLocalizations ru;

  setUpAll(() async {
    ru = await AppLocalizations.load(const Locale('ru'));
  });

  group('gbText', () {
    test('два знака до 10 ГБ, запятая, неразрывный пробел', () {
      expect(gbText(ru, 0.28), '0,28\u00a0ГБ');
      expect(gbText(ru, 0.23), '0,23\u00a0ГБ');
      expect(gbText(ru, 0), '0,00\u00a0ГБ');
      expect(gbText(ru, 9.99), '9,99\u00a0ГБ');
    });

    test('от 10 ГБ один знак', () {
      expect(gbText(ru, 10), '10,0\u00a0ГБ');
      expect(gbText(ru, 49.2), '49,2\u00a0ГБ');
      expect(gbText(ru, 50), '50,0\u00a0ГБ');
    });

    test('число и единица не разделяются обычным пробелом', () {
      expect(gbText(ru, 1.5).contains(' '), isFalse);
      expect(gbText(ru, 1.5).contains('\u00a0'), isTrue);
    });
  });

  group('pingText', () {
    test('значение с единицей и без значения', () {
      expect(pingText(ru, 44), '44\u00a0мс');
      expect(pingText(ru, 2024), '2024\u00a0мс');
      expect(pingText(ru, null), '—');
    });
  });

  group('elapsedText', () {
    test('минуты и секунды', () {
      expect(elapsedText(Duration.zero), '0:00');
      expect(elapsedText(const Duration(seconds: 9)), '0:09');
      expect(elapsedText(const Duration(minutes: 12, seconds: 48)), '12:48');
      expect(elapsedText(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('от часа h:mm:ss', () {
      expect(elapsedText(const Duration(hours: 1)), '1:00:00');
      expect(
        elapsedText(const Duration(hours: 2, minutes: 5, seconds: 7)),
        '2:05:07',
      );
    });

    test('отрицательное время считается нулём', () {
      expect(elapsedText(const Duration(seconds: -5)), '0:00');
    });
  });

  group('planLine', () {
    const low =
        M3eTrafficInfo(used: '49,2', total: '50', left: '0,8', pct: 98.4);
    const mid =
        M3eTrafficInfo(used: '12,5', total: '50', left: '37,5', pct: 25);

    test('безлимит без срока', () {
      final p = planLine(ru);
      expect(p.text, 'Безлимит · бессрочно');
      expect(p.tone, M3ePlanTone.normal);
      expect(p.needsRefresh, isFalse);
    });

    test('трафик из total и срок', () {
      expect(
        planLine(ru, traffic: mid, until: '13 января 2027').text,
        '12,5 из 50 ГБ · до 13 января 2027',
      );
    });

    test('трафик на исходе заменяет строку предупреждением', () {
      final p = planLine(ru, traffic: low, until: '13 января 2027');
      expect(p.text, 'Осталось 0,8 ГБ');
      expect(p.tone, M3ePlanTone.warn);
      expect(p.needsRefresh, isFalse);
    });

    test('ровно 90 % ещё не предупреждение', () {
      const edge = M3eTrafficInfo(used: '45', total: '50', left: '5', pct: 90);
      expect(planLine(ru, traffic: edge).tone, M3ePlanTone.normal);
    });

    test('срок подходит к концу', () {
      final p = planLine(ru, state: M3eSubState.expiring);
      expect(p.text, 'Осталось 2 дня');
      expect(p.tone, M3ePlanTone.warn);
      expect(p.needsRefresh, isFalse);
    });

    test('склонение дней', () {
      expect(
        planLine(ru, state: M3eSubState.expiring, daysLeft: 1).text,
        'Остался 1 день',
      );
      expect(
        planLine(ru, state: M3eSubState.expiring, daysLeft: 5).text,
        'Осталось 5 дней',
      );
    });

    test('подписка и трафик закончились: ошибка и кнопка Обновить', () {
      final expired = planLine(ru, state: M3eSubState.expired);
      expect(expired.text, 'Подписка закончилась');
      expect(expired.tone, M3ePlanTone.bad);
      expect(expired.needsRefresh, isTrue);
      final out = planLine(ru, state: M3eSubState.trafficOut);
      expect(out.text, 'Трафик закончился');
      expect(out.tone, M3ePlanTone.bad);
      expect(out.needsRefresh, isTrue);
    });

    test('состояние подписки сильнее предупреждения о трафике', () {
      expect(
        planLine(ru, traffic: low, state: M3eSubState.expired).text,
        'Подписка закончилась',
      );
    });
  });

  test('meterToneFor: границы 90 и 100', () {
    expect(meterToneFor(0), M3eMeterTone.normal);
    expect(meterToneFor(90), M3eMeterTone.normal);
    expect(meterToneFor(90.1), M3eMeterTone.low);
    expect(meterToneFor(99.9), M3eMeterTone.low);
    expect(meterToneFor(100), M3eMeterTone.out);
    expect(meterToneFor(130), M3eMeterTone.out);
  });

  test('в английской локали точка вместо запятой', () async {
    final en = await AppLocalizations.load(const Locale('en'));
    expect(gbText(en, 0.28), '0.28\u00a0GB');
    expect(pingText(en, 44), '44\u00a0ms');
    // Возвращаем ru: локаль хранится глобально, остальные тесты файла от неё зависят.
    await AppLocalizations.load(const Locale('ru'));
  });

  test('разделитель берётся из локали экрана, а не из глобальной intl', () {
    final saved = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = saved);
    // Глобальная локаль чужая (en_US), экран русский: ждём запятую.
    Intl.defaultLocale = 'en_US';
    // Единица приходит из arb по глобальной локали (GB), проверяем число.
    expect(gbText(ru, 344.4, locale: 'ru'), startsWith('344,4\u00a0'));
    expect(gbText(ru, 0.28, locale: 'ru'), startsWith('0,28\u00a0'));
    // И наоборот: экран английский при глобальной ru.
    Intl.defaultLocale = 'ru';
    expect(gbText(ru, 344.4, locale: 'en'), startsWith('344.4\u00a0'));
  });
}
