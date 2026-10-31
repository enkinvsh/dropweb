// Движение карточки главной (№4): таймер обычным текстом раз в секунду, точка статична,
// «Уменьшить движение», TickerMode, фон приложения, смена страны и снятие таймеров.
// Образец: test/m3e/live_timer_test.dart.
//
// Решение владельца 30.10: у карточки нет бесконечного движения (ни кольца, ни переката цифр, ни
// пульса точки) — каждый кадр на устройстве перекомпозирует нативные стёкла (батарея).

import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';

Ios27CardData _data({
  DateTime? since,
  Ios27DotKind dot = Ios27DotKind.on,
  String? country = 'Нидерланды',
  bool pending = false,
}) =>
    Ios27CardData(
      title: 'DROPWEB',
      dot: dot,
      statusText: 'Подключено',
      since: since,
      planText: 'Безлимит · бессрочно',
      countryLabel: 'Страна',
      countryText: country,
      countryFlag: country == null ? '' : '🇳🇱',
      countryPending: pending,
      countryLoadingLabel: 'Подключение…',
      announce: 'dropweb.org',
      semanticsLabel: 'Подключение и подписка',
    );

Widget _app(
  WidgetTester tester,
  Ios27CardData data, {
  bool reduce = false,
  bool tickers = true,
}) =>
    ios27BoardApp(
      brightness: Brightness.light,
      disableAnimations: reduce,
      child: TickerMode(
        enabled: tickers,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Ios27Card(data: data, now: tester.binding.clock.now),
          ),
        ),
      ),
    );

/// Сеанс, начатый `12:49.3` назад: следующая граница секунды через 700 мс (+5 мс запаса).
DateTime _since(WidgetTester tester) => tester.binding.clock
    .now()
    .subtract(const Duration(minutes: 12, seconds: 49, milliseconds: 300));

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  group('таймер', () {
    testWidgets('цифры сменяются раз в секунду по границе секунды',
        (tester) async {
      try {
        await pumpIos27Board(
          tester,
          _app(tester, _data(since: _since(tester))),
        );
        expect(find.text('12:49'), findsOneWidget);

        // До границы остаётся 700 мс: за 600 мс цифры стоят.
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('12:49'), findsOneWidget);

        // Граница пройдена: ровно одна секунда добавлена.
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('12:50'), findsOneWidget);

        for (var expected = 51; expected <= 53; expected++) {
          await tester.pump(const Duration(milliseconds: 1000));
          expect(find.text('12:$expected'), findsOneWidget);
        }
      } finally {
        await _close(tester);
      }
    });

    testWidgets('переход через час: m:ss → h:mm:ss', (tester) async {
      try {
        final since = tester.binding.clock.now().subtract(
              const Duration(minutes: 59, seconds: 59, milliseconds: 300),
            );
        await pumpIos27Board(tester, _app(tester, _data(since: since)));
        expect(find.text('59:59'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 710));
        expect(find.text('1:00:00'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('цифры не перекатываются: одна строка, без размытия и копий',
        (tester) async {
      try {
        await pumpIos27Board(
            tester, _app(tester, _data(since: _since(tester))));
        await tester.pump(const Duration(milliseconds: 710));
        // Сразу после смены секунды: новая строка целиком и никаких уходящих копий.
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.text('12:49'), findsNothing);
        expect(find.text('12:50'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('«Уменьшить движение»: те же секунды, без Ticker',
        (tester) async {
      try {
        await pumpIos27Board(
          tester,
          _app(tester, _data(since: _since(tester)), reduce: true),
        );
        await tester.pump(const Duration(milliseconds: 710));
        expect(find.text('12:50'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('без сеанса таймера нет', (tester) async {
      try {
        await pumpIos27Board(tester, _app(tester, _data()));
        expect(find.byKey(Ios27CardKeys.timer), findsNothing);
      } finally {
        await _close(tester);
      }
    });
  });

  group('точка статуса', () {
    testWidgets('статична: ни кольца, ни пульса, кадров не просит',
        (tester) async {
      try {
        for (final dot in Ios27DotKind.values) {
          await pumpIos27Board(
            tester,
            _app(tester, _data(dot: dot)),
          );
          final box = find.byKey(Ios27CardKeys.dot);
          expect(box, findsOneWidget, reason: '$dot');
          expect(
            find.descendant(of: box, matching: find.byType(CustomPaint)),
            findsNothing,
            reason: '$dot: точка не рисуется кистью, кольца нет',
          );
          final size = tester.getSize(box);
          await tester.pump(const Duration(seconds: 3));
          expect(tester.getSize(box), size);
          expect(tester.binding.transientCallbackCount, 0, reason: '$dot');
          expect(tester.binding.hasScheduledFrame, isFalse, reason: '$dot');
        }
      } finally {
        await _close(tester);
      }
    });
  });

  group('остановка', () {
    testWidgets('TickerMode(false): таймер стоит, кадров нет; вернулись: идёт',
        (tester) async {
      try {
        await pumpIos27Board(
          tester,
          _app(tester, _data(since: _since(tester)), tickers: false),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('12:49'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);

        // Вернулись: строка догоняет время сразу.
        await tester.pumpWidget(_app(tester, _data(since: _since(tester))));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('12:'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text('12:50'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('приложение в фоне: таймер стоит, при возврате догоняет часы',
        (tester) async {
      try {
        await pumpIos27Board(
            tester, _app(tester, _data(since: _since(tester))));
        await tester.pump(const Duration(milliseconds: 100));

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.transientCallbackCount, 0);
        // Строка не уходит вперёд, пока приложение свёрнуто.
        expect(find.text('12:49'), findsOneWidget);
        expect(await _framesOver(tester, 3000), 0);

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 100));
        // Время пересчитано по часам: прошло ≥ 3 с, а не продолжено с замороженной секунды.
        expect(find.text('12:49'), findsNothing);
        expect(find.textContaining('12:5'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('снятие карточки гасит таймер', (tester) async {
      await pumpIos27Board(tester, _app(tester, _data(since: _since(tester))));
      await tester.pump(const Duration(milliseconds: 300));
      await _close(tester);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      // Висящий Timer после снятия уронил бы тест на проверке отложенных таймеров.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('смена страны', () {
    testWidgets('первая отрисовка без анимации, смена: старый гаснет за 100 мс',
        (tester) async {
      try {
        await pumpIos27Board(
            tester, _app(tester, _data(since: _since(tester))));
        expect(find.text('Нидерланды'), findsOneWidget);

        await tester.pumpWidget(
          _app(tester, _data(since: _since(tester), country: 'Россия')),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Нидерланды'), findsOneWidget);
        expect(find.text('Россия'), findsOneWidget);

        await tester.pump(Ios27Motion.springSmooth.settle +
            const Duration(milliseconds: 150));
        expect(find.text('Нидерланды'), findsNothing);
        expect(find.text('Россия'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('«Уменьшить движение»: смена за 100 мс без сдвига',
        (tester) async {
      try {
        await pumpIos27Board(
          tester,
          _app(tester, _data(since: _since(tester)), reduce: true),
        );
        final y0 =
            tester.getTopLeft(find.byKey(Ios27CardKeys.country).first).dy;
        await tester.pumpWidget(
          _app(tester, _data(since: _since(tester), country: 'Россия'),
              reduce: true),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
            tester.getTopLeft(find.byKey(Ios27CardKeys.country).first).dy, y0);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Нидерланды'), findsNothing);
      } finally {
        await _close(tester);
      }
    });
  });

  group('индикатор определения страны', () {
    testWidgets('крутится и при «Уменьшить движение», в фоне стоит',
        (tester) async {
      try {
        await pumpIos27Board(
          tester,
          _app(tester,
              _data(dot: Ios27DotKind.busy, country: null, pending: true),
              reduce: true),
        );
        expect(find.byKey(Ios27CardKeys.spinner), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        expect(await _framesOver(tester, 1000), greaterThan(0));

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(await _framesOver(tester, 1000), 0);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });
  });
}

/// Счётчик кадров, которые просит приложение. Спиннер и пульс `busy` теперь шагают `Timer`-ом
/// (`Ios27SteppedClock`), поэтому `transientCallbackCount` у них всегда 0 и «живость» видна только
/// по запрошенным кадрам. Persistent-колбэк снять нельзя: он один на процесс и включается флагом.
class _FrameMeter {
  bool on = false;
  int frames = 0;
}

final _FrameMeter _meter = _FrameMeter();
bool _meterHooked = false;

/// Сколько кадров просили за [ms] модельных миллисекунд (шаг 16 мс).
Future<int> _framesOver(WidgetTester tester, int ms) async {
  if (!_meterHooked) {
    _meterHooked = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (_meter.on) {
        _meter.frames++;
      }
    });
  }
  _meter
    ..frames = 0
    ..on = true;
  try {
    for (var i = 0; i < ms ~/ 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    _meter.on = false;
  }
  return _meter.frames;
}
