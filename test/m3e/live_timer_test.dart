// Живой таймер сеанса, пульс точки подключения и плавная смена IP на главной
// (владелец 2026-10-29: «секунды идут по 2», «нет пульсации», «нет плавности IP»).

import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _sec = Duration(seconds: 1);

final _header = parseDropwebTheme(kBoardProviders[0].theme);

Finder _inTimer(Finder what) =>
    find.descendant(of: find.byKey(M3eCardKeys.timer), matching: what);

Finder _inCountry(Finder what) =>
    find.descendant(of: find.byKey(M3eCardKeys.country), matching: what);

/// Прозрачность ближайшего `FadeTransition` над [of].
double _opacityOf(WidgetTester tester, Finder of) {
  final fade =
      find.ancestor(of: of, matching: find.byType(FadeTransition)).first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

M3eHomeInput _on(String ip, String country) => M3eHomeInput(
      vpnOn: true,
      runTime: kHomeRunTime,
      ipAddress: ip,
      ipCountryCode: country,
      subscription: const M3eHomeSubscription(),
      providerName: 'dropweb',
      announce: 'dropweb.org',
    );

/// Источник входа главной, который тест меняет во время работы.
final _source = StateProvider<M3eHomeInput>((ref) => _on('91.12.4.9', 'DE'));

Widget _homeWithSource(
  WidgetTester tester, {
  bool reduced = false,
  bool tickers = true,
}) =>
    gateHomeApp(
      'home-on',
      reduced: reduced,
      tickers: tickers,
      tickClock: tester.binding.clock.now,
      extra: [
        m3eHomeInputProvider.overrideWith((ref) => ref.watch(_source)),
      ],
    );

void _setInput(WidgetTester tester, M3eHomeInput input) {
  ProviderScope.containerOf(tester.element(find.byType(M3eHome)))
      .read(_source.notifier)
      .state = input;
}

/// Карточка отдельно, с нужным режимом движения: ни экрана, ни фона, ни кнопки, чтобы
/// счётчик тикеров относился только к ней.
Widget _cardApp(
  M3eDotState dot, {
  bool reduced = false,
  bool tickers = true,
  ValueListenable<String?>? liveTimer,
  bool pending = false,
}) =>
    m3eBoardApp(
      seed: _header.accent,
      filter: _header.filter,
      brightness: Brightness.light,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: TickerMode(
            enabled: tickers,
            child: ColoredBox(
              color: M3eColors.of(context).home.bg,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 108),
                  child: SizedBox(
                    width: 379,
                    child: M3eSubCard(
                      liveTimer: liveTimer,
                      data: M3eCardData(
                        providerName: 'dropweb',
                        dot: dot,
                        statusText: 'Подключено',
                        statusVisible: false,
                        timer: '12:49',
                        planText: 'Безлимит',
                        ipFlag: '🇳🇱',
                        ipAddress: '185.107.56.12',
                        countryText: 'Нидерланды',
                        ipLoading: pending,
                        announce: 'dropweb.org',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

int _frames = 0;
bool _metered = false;
bool _meterOn = false;

/// Сколько кадров реально отрисовано за [ms] модельных миллисекунд (шаг 16 мс): `pump`
/// рисует кадр только если его кто-то запросил, так что число — это нагрузка дерева.
Future<int> _framesOver(WidgetTester tester, int ms) async {
  if (!_metered) {
    _metered = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (_meterOn) _frames++;
    });
  }
  _frames = 0;
  _meterOn = true;
  try {
    for (var i = 0; i < ms ~/ 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    _meterOn = false;
  }
  return _frames;
}

void main() {
  group('часы сеанса: M3eElapsedClock', () {
    testWidgets('идут раз в секунду, ровно +1 с за секунду', (tester) async {
      final clock = M3eElapsedClock(tester.binding.clock.now)
        ..update(const Duration(seconds: 5, milliseconds: 400))
        ..setTick(tick: true);
      expect(clock.value, '0:05');
      expect(clock.ticking, isTrue);

      // Граница следующей секунды через 600 мс.
      await tester.pump(const Duration(milliseconds: 599));
      expect(clock.value, '0:05');
      await tester.pump(const Duration(milliseconds: 2));
      expect(clock.value, '0:06');
      await tester.pump(_sec);
      expect(clock.value, '0:07');
      await tester.pump(_sec);
      expect(clock.value, '0:08');
      clock.dispose();
    });

    testWidgets('без VPN или без разрешения на бег таймера нет',
        (tester) async {
      final clock = M3eElapsedClock(tester.binding.clock.now)
        ..setTick(tick: true)
        ..update(null);
      expect(clock.ticking, isFalse, reason: 'VPN выключен: нечего считать');
      expect(clock.value, isNull);

      clock
        ..update(const Duration(seconds: 5))
        ..setTick(tick: false);
      expect(clock.ticking, isFalse,
          reason: 'экран закрыт или приложение в фоне');
      await tester.pump(const Duration(seconds: 5));
      expect(clock.value, '0:05', reason: 'без бега значение стоит');

      clock.update(null);
      expect(clock.ticking, isFalse);
      clock.dispose();
    });

    testWidgets('якорь сдвигается только при расхождении больше 1,5 с',
        (tester) async {
      final clock = M3eElapsedClock(tester.binding.clock.now)
        ..update(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 2));
      // Источник пришёл на 100 мс «раньше»: секунда не должна откатиться назад.
      clock.update(const Duration(seconds: 11, milliseconds: 900));
      expect(clock.value, '0:12');
      // Новый сеанс (переподключение): якорь берётся заново.
      clock.update(const Duration(seconds: 3));
      expect(clock.value, '0:03');
      clock.dispose();
    });

    testWidgets('возврат из фона не откатывает секунды', (tester) async {
      final clock = M3eElapsedClock(tester.binding.clock.now)
        ..update(const Duration(seconds: 10))
        ..setTick(tick: true);
      await tester.pump(const Duration(seconds: 5));
      clock.setTick(tick: false);
      await tester.pump(const Duration(seconds: 20));
      // Источник в фоне не обновлялся; при возврате берём якорь, а не устаревшее число.
      clock.setTick(tick: true);
      expect(clock.value, '0:35');
      clock.dispose();
    });
  });

  group('таймер на главной', () {
    testWidgets('с анимациями секунды идут простым текстом, без перекатов',
        (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester));
      expect(find.text('12:49'), findsOneWidget);

      await tester.pump(_sec);
      // Текст меняется целиком и сразу: никаких пар старой и новой цифры в дереве.
      expect(find.text('12:50'), findsOneWidget);
      expect(find.text('12:49'), findsNothing);
      expect(_inTimer(find.byType(AnimatedSwitcher)), findsNothing);
      expect(_inTimer(find.byType(FadeTransition)), findsNothing);

      await tester.pump(_sec);
      expect(find.text('12:51'), findsOneWidget);
    });

    testWidgets('«меньше движения»: секунды идут, но без анимации',
        (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester, reduced: true));
      expect(find.text('12:49'), findsOneWidget);
      await tester.pump(_sec);
      await tester.pump();
      expect(find.text('12:50'), findsOneWidget);
      await tester.pump(_sec);
      await tester.pump();
      expect(find.text('12:51'), findsOneWidget);
      expect(_inTimer(find.byType(AnimatedSwitcher)), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('под закрытым маршрутом (TickerMode выключен) таймер молчит',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _homeWithSource(tester, reduced: true, tickers: false),
      );
      expect(find.text('12:49'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('12:49'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('точка состояния', () {
    // Бесконечное движение на карточке убрано решением владельца 2026-10-30 (карточка №4):
    // точка стоит при любом состоянии и любом режиме движения.
    for (final dot in M3eDotState.values) {
      for (final (name, reduced, tickers) in const [
        ('с анимациями', false, true),
        ('«меньше движения»', true, true),
        ('TickerMode выключен', false, false),
      ]) {
        testWidgets('$dot, $name: точка стоит, кадров нет', (tester) async {
          await pumpM3eBoard(
            tester,
            _cardApp(dot, reduced: reduced, tickers: tickers),
          );
          await tester.pump(const Duration(seconds: 3));
          expect(
            find.descendant(
              of: find.byKey(M3eCardKeys.dot),
              matching: find.byType(Transform),
            ),
            findsNothing,
            reason: 'кольца и масштаба нет',
          );
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.binding.hasScheduledFrame, isFalse);
        });
      }
    }
  });

  group('батарея: карточка не оживает сама', () {
    // Решение владельца 2026-10-30 (карточка №4): ни кольца, ни переката цифр. Дерево
    // карточки живёт только секундным таймером, остальное время кадров не просит.
    testWidgets('home-on: секундный таймер, ≈ 1 кадр/с и ни одного тикера',
        (tester) async {
      final clock = M3eElapsedClock(tester.binding.clock.now)
        ..update(kHomeRunTime)
        ..setTick(tick: true);
      try {
        await pumpM3eBoard(
          tester,
          _cardApp(M3eDotState.on, liveTimer: clock),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.transientCallbackCount, 0);
        final frames = await _framesOver(tester, 5000);
        expect(frames, inInclusiveRange(4, 6),
            reason: 'за 5 с — по кадру на секунду таймера');
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        clock.dispose();
      }
    });

    testWidgets('home-on без таймера (экран закрыт): 0 кадров', (tester) async {
      await pumpM3eBoard(
        tester,
        _cardApp(M3eDotState.on, tickers: false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(await _framesOver(tester, 5000), 0);
    });

    testWidgets('«меньше движения»: connecting 0 кадров, спиннера нет',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _cardApp(M3eDotState.busy, reduced: true, pending: true),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(await _framesOver(tester, 3000), 0);
    });
  });

  group('смена страны', () {
    testWidgets(
        'старое гаснет, новое проявляется, ширина плывёт, потом оседает',
        (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_inCountry(find.text('Германия')), findsOneWidget);
      final start =
          tester.getSize(_inCountry(find.byType(AnimatedSize)).first).width;

      _setInput(tester, _on('185.107.56.12', 'NL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(_inCountry(find.text('Германия')), findsOneWidget,
          reason: 'уходящее ещё в дереве');
      expect(_inCountry(find.text('Нидерланды')), findsOneWidget,
          reason: 'входящее уже в дереве');
      expect(_opacityOf(tester, _inCountry(find.text('Германия'))),
          inExclusiveRange(0, 1));
      expect(_opacityOf(tester, _inCountry(find.text('Нидерланды'))),
          inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 60));
      final slide = _inCountry(find.byType(SlideTransition));
      expect(slide, findsWidgets,
          reason: 'входящее въезжает короткой пружиной');
      expect(_opacityOf(tester, _inCountry(find.text('Нидерланды'))),
          inExclusiveRange(0, 1));
      final mid =
          tester.getSize(_inCountry(find.byType(AnimatedSize)).first).width;

      await tester.pump(const Duration(milliseconds: 1000));
      final end =
          tester.getSize(_inCountry(find.byType(AnimatedSize)).first).width;
      expect(_inCountry(find.text('Германия')), findsNothing);
      expect(_opacityOf(tester, _inCountry(find.text('Нидерланды'))), 1.0);
      expect(end, greaterThan(start), reason: 'новая страна шире');
      expect(mid, inExclusiveRange(start, end),
          reason: 'на середине перехода ширина между старой и новой');

      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(_inCountry(find.byType(AnimatedSize)).first).width,
          end,
          reason: 'после пружины ширина не плывёт');
    });

    testWidgets('«меньше движения»: размер сразу, без сдвига', (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester, reduced: true));
      await tester.pump(const Duration(milliseconds: 500));
      _setInput(tester, _on('185.107.56.12', 'NL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(_inCountry(find.byType(AnimatedSize)), findsNothing);
      expect(_inCountry(find.byType(SlideTransition)), findsNothing);
      // Перекрёстное проявление не длиннее 150 мс.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_inCountry(find.text('Германия')), findsNothing);
      expect(_opacityOf(tester, _inCountry(find.text('Нидерланды'))), 1.0);
    });

    testWidgets('TickerMode выключен: значение подставляется сразу',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _homeWithSource(tester, reduced: true, tickers: false),
      );
      _setInput(tester, _on('185.107.56.12', 'NL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(_inCountry(find.text('Германия')), findsNothing);
      expect(_inCountry(find.text('Нидерланды')), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
