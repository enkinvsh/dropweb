// Живой таймер сеанса, пульс точки подключения и плавная смена IP на главной
// (владелец 2026-10-29: «секунды идут по 2», «нет пульсации», «нет плавности IP»).

import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
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

Finder _inIp(Finder what) =>
    find.descendant(of: find.byKey(M3eCardKeys.statValue(0)), matching: what);

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
                      data: M3eCardData(
                        providerName: 'dropweb',
                        dot: dot,
                        statusText: 'Подключено',
                        statusVisible: false,
                        timer: '12:49',
                        planText: 'Безлимит',
                        ipFlag: '🇳🇱',
                        ipAddress: '185.107.56.12',
                        trafficText: '0,8 ГБ',
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
    testWidgets('с анимациями цифры меняются раз в секунду, по одной',
        (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester));
      expect(find.text('12:49'), findsOneWidget);

      await tester.pump(_sec);
      await tester.pump(const Duration(milliseconds: 50));
      // Менялись «4» → «5» и «9» → «0»: пока идёт переход, обе пары в дереве.
      expect(_inTimer(find.text('4')), findsOneWidget);
      expect(_inTimer(find.text('5')), findsOneWidget);
      expect(_inTimer(find.text('9')), findsOneWidget);
      expect(_inTimer(find.text('0')), findsOneWidget);
      // Остальные символы не двигаются и не гаснут.
      for (final stay in ['1', '2', ':']) {
        expect(_inTimer(find.text(stay)), findsOneWidget);
        expect(_opacityOf(tester, _inTimer(find.text(stay))), 1.0,
            reason: '«$stay» не менялся');
      }
      final entering = _opacityOf(tester, _inTimer(find.text('5')));
      final leaving = _opacityOf(tester, _inTimer(find.text('4')));
      expect(entering, inExclusiveRange(0, 1));
      expect(leaving, inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 400));
      expect(_inTimer(find.text('4')), findsNothing);
      expect(_inTimer(find.text('9')), findsNothing);
      expect(find.text('12:50'), findsOneWidget,
          reason: 'полный текст на месте: размер и поиск по тексту');

      await tester.pump(_sec);
      await tester.pump(const Duration(milliseconds: 400));
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

  group('точка подключения', () {
    Finder ring() => find.descendant(
          of: find.byKey(M3eCardKeys.dot),
          matching: find.byType(Transform),
        );

    testWidgets('подключено: кольцо расходится от точки и гаснет',
        (tester) async {
      await pumpM3eBoard(tester, _cardApp(M3eDotState.on));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 600));
      final mid = tester.widget<Transform>(ring().first);
      expect(mid.transform.storage[0], greaterThan(1.3),
          reason: 'кольцо шире точки');

      // К концу периода (2 с) прозрачность кольца падает к нулю.
      await tester.pump(const Duration(milliseconds: 1300));
      final late = tester.widget<Transform>(ring().first);
      expect(late.transform.storage[0], greaterThan(mid.transform.storage[0]));

      // Цикл повторяется, а не останавливается.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('«меньше движения»: точка стоит, кадров нет', (tester) async {
      await pumpM3eBoard(tester, _cardApp(M3eDotState.on, reduced: true));
      await tester.pump(const Duration(seconds: 3));
      expect(ring(), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('TickerMode выключен: пульс замер', (tester) async {
      await pumpM3eBoard(tester, _cardApp(M3eDotState.on, tickers: false));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('выключено и ошибка: точка статична', (tester) async {
      for (final dot in [M3eDotState.off, M3eDotState.bad]) {
        await pumpM3eBoard(tester, _cardApp(dot));
        await tester.pump(const Duration(seconds: 2));
        expect(ring(), findsNothing, reason: '$dot');
        expect(tester.binding.transientCallbackCount, 0, reason: '$dot');
      }
    });

    testWidgets('подключение (busy) по-прежнему «дышит»', (tester) async {
      await pumpM3eBoard(tester, _cardApp(M3eDotState.busy));
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(ring(), findsWidgets);
    });
  });

  group('смена IP', () {
    testWidgets(
        'старое гаснет, новое проявляется, ширина плывёт, потом оседает',
        (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_inIp(find.text('91.12.4.9')), findsOneWidget);
      final start =
          tester.getSize(_inIp(find.byType(AnimatedSize)).first).width;

      _setInput(tester, _on('185.107.56.12', 'NL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(_inIp(find.text('91.12.4.9')), findsOneWidget,
          reason: 'уходящее ещё в дереве');
      expect(_inIp(find.text('185.107.56.12')), findsOneWidget,
          reason: 'входящее уже в дереве');
      expect(_opacityOf(tester, _inIp(find.text('91.12.4.9'))),
          inExclusiveRange(0, 1));
      expect(_opacityOf(tester, _inIp(find.text('185.107.56.12'))),
          inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 60));
      final slide = _inIp(find.byType(SlideTransition));
      expect(slide, findsWidgets,
          reason: 'входящее въезжает короткой пружиной');
      expect(_opacityOf(tester, _inIp(find.text('185.107.56.12'))),
          inExclusiveRange(0, 1));
      final mid = tester.getSize(_inIp(find.byType(AnimatedSize)).first).width;

      await tester.pump(const Duration(milliseconds: 1000));
      final end = tester.getSize(_inIp(find.byType(AnimatedSize)).first).width;
      expect(_inIp(find.text('91.12.4.9')), findsNothing);
      expect(_opacityOf(tester, _inIp(find.text('185.107.56.12'))), 1.0);
      expect(end, greaterThan(start), reason: 'новый адрес шире');
      expect(mid, inExclusiveRange(start, end),
          reason: 'на середине перехода ширина между старой и новой');

      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(_inIp(find.byType(AnimatedSize)).first).width, end,
          reason: 'после пружины ширина не плывёт');
    });

    testWidgets('«меньше движения»: размер сразу, без сдвига', (tester) async {
      await pumpM3eBoard(tester, _homeWithSource(tester, reduced: true));
      await tester.pump(const Duration(milliseconds: 500));
      _setInput(tester, _on('185.107.56.12', 'NL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(_inIp(find.byType(AnimatedSize)), findsNothing);
      expect(_inIp(find.byType(SlideTransition)), findsNothing);
      // Перекрёстное проявление не длиннее 150 мс.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_inIp(find.text('91.12.4.9')), findsNothing);
      expect(_opacityOf(tester, _inIp(find.text('185.107.56.12'))), 1.0);
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
      expect(_inIp(find.text('91.12.4.9')), findsNothing);
      expect(_inIp(find.text('185.107.56.12')), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
