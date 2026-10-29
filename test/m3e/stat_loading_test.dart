// Индикатор загрузки на месте адреса карточки (решение владельца 2026-10-29):
// канон M3E, переход к значению, статика под «меньше движения» и закрытым маршрутом.

import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Карточка с готовыми строками; загрузка подменяет адрес прочерком, как модель.
/// Точка «выключено»: у подключённой бежит бесконечный пульс, и счётчик тикеров не
/// отличил бы его от незаконченной смены значения.
M3eCardData _card({
  bool ipLoading = false,
  M3eDotState dot = M3eDotState.on,
}) =>
    M3eCardData(
      providerName: 'dropweb',
      dot: dot,
      statusText: 'Подключено',
      statusVisible: false,
      timer: '12:49',
      planText: 'Безлимит · до 13 января 2027',
      ipFlag: ipLoading ? null : '🇳🇱',
      ipAddress: ipLoading ? '—' : '185.107.56.12',
      trafficText: '0,8 ГБ',
      ipLoading: ipLoading,
      announce: 'dropweb.org',
    );

Widget _host(
  ValueNotifier<M3eCardData> data, {
  Brightness brightness = Brightness.light,
  int provider = 0,
  bool reduced = true,
  bool tickers = true,
  double scale = 1,
}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: TickerMode(
          enabled: tickers,
          child: ColoredBox(
            color: M3eColors.of(context).home.bg,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 108,
                    width: 379,
                    child: ValueListenableBuilder<M3eCardData>(
                      valueListenable: data,
                      builder: (_, d, __) =>
                          M3eSubCard(data: d, onRefresh: () {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _inValue(int i, Finder what) =>
    find.descendant(of: find.byKey(M3eCardKeys.statValue(i)), matching: what);

Future<void> _pump(WidgetTester tester, Widget app) async {
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('golden: карточка в ожидании (адрес грузится)', () {
    for (final (brightness, p) in [
      (Brightness.light, 0),
      (Brightness.dark, 5),
    ]) {
      final name = 'card_loading_${brightness.name}_p$p';
      testWidgets(name, (tester) async {
        final data = ValueNotifier(_card(ipLoading: true));
        addTearDown(data.dispose);
        // Эталоны доски сняты при «меньше движения»: статичная форма без вращения.
        await pumpM3eBoard(
          tester,
          _host(data, brightness: brightness, provider: p),
        );
        expect(tester.takeException(), isNull);
        await expectM3eGolden(tester, name);
      });
    }
  });

  group('индикатор вместо значения', () {
    testWidgets('при загрузке на месте адреса живой индикатор M3E',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false));
      expect(
          _inValue(0, find.byType(ExpressiveLoadingIndicator)), findsOneWidget);
      // Трафик не ждёт ничего: обычный текст.
      expect(
          _inValue(1, find.byType(ExpressiveLoadingIndicator)), findsNothing);
      expect(_inValue(1, find.text('0,8 ГБ')), findsOneWidget);
    });

    testWidgets('значение приходит fade-ом, после него ни одного тикера',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false));

      data.value = _card(dot: M3eDotState.off);
      await tester.pump();
      // Уход старого 100 мс, приход нового 350 мс: через 20 мс значение уже в дереве.
      await tester.pump(const Duration(milliseconds: 20));
      expect(_inValue(0, find.text('185.107.56.12')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(
          _inValue(0, find.byType(ExpressiveLoadingIndicator)), findsNothing);
      expect(_inValue(0, find.text('185.107.56.12')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'после загрузки живых тикеров нет');
      expect(tester.takeException(), isNull);
    });

    testWidgets('смена одного значения другим тоже плавная', (tester) async {
      final data = ValueNotifier(_card(dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false));
      expect(_inValue(1, find.text('0,8 ГБ')), findsOneWidget);

      data.value = const M3eCardData(
        providerName: 'dropweb',
        dot: M3eDotState.off,
        statusText: 'Подключено',
        statusVisible: false,
        timer: '12:49',
        planText: 'Безлимит · до 13 января 2027',
        ipFlag: '🇩🇪',
        ipAddress: '91.12.4.9',
        trafficText: '1,2 ГБ',
        announce: 'dropweb.org',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // Старое значение ещё уходит, новое уже приходит.
      expect(_inValue(1, find.text('1,2 ГБ')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_inValue(1, find.text('0,8 ГБ')), findsNothing);
      expect(_inValue(0, find.text('185.107.56.12')), findsNothing);
      expect(_inValue(0, find.text('91.12.4.9')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('высота строк и карточки не прыгает при смене на значение',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false));
      final card = tester.getSize(find.byKey(M3eCardKeys.card));
      final ip = tester.getSize(find.byKey(M3eCardKeys.statValue(0)));
      final traffic = tester.getSize(find.byKey(M3eCardKeys.statValue(1)));

      data.value = _card(dot: M3eDotState.off);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(find.byKey(M3eCardKeys.card)).height, card.height);
      expect(tester.getSize(find.byKey(M3eCardKeys.statValue(0))).height,
          ip.height);
      expect(tester.getSize(find.byKey(M3eCardKeys.statValue(1))).height,
          traffic.height);
    });
  });

  group('движение', () {
    testWidgets('«меньше движения»: статичная форма, кадров никто не просит',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Индикатор виден: на месте текста форма.
      expect(_inValue(0, find.byType(CustomPaint)), findsWidgets);
    });

    testWidgets('TickerMode выключен: статичная форма, ни тикеров, ни таймеров',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false, tickers: false));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
        'TickerMode: значение подставляется сразу, без зависшего старого',
        (tester) async {
      final data = ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
      addTearDown(data.dispose);
      await _pump(tester, _host(data, reduced: false, tickers: false));
      data.value = _card(dot: M3eDotState.off);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(_inValue(0, find.byType(CustomPaint)), findsNothing);
      expect(_inValue(0, find.text('185.107.56.12')), findsOneWidget);
    });
  });

  group('масштаб текста приложения', () {
    for (final scale in [1.4, 2.0]) {
      testWidgets('x$scale: индикатор в строке значения, без переполнений',
          (tester) async {
        final data =
            ValueNotifier(_card(ipLoading: true, dot: M3eDotState.off));
        addTearDown(data.dispose);
        await _pump(tester, _host(data, scale: scale));
        expect(tester.takeException(), isNull);
        for (final i in [0]) {
          final row = tester.getRect(find.byKey(M3eCardKeys.statValue(i)));
          final shapes = _inValue(i, find.byType(CustomPaint));
          expect(shapes, findsWidgets, reason: 'значение $i: нет индикатора');
          final r = tester.getRect(shapes.first);
          expect(r.top, greaterThanOrEqualTo(row.top - 0.5), reason: 'верх $i');
          expect(r.bottom, lessThanOrEqualTo(row.bottom + 0.5),
              reason: 'низ $i');
          expect(r.right, lessThanOrEqualTo(row.right + 0.5),
              reason: 'право $i');
        }
        // Индикатор растёт с текстом, а не остаётся точкой.
        final shape =
            tester.getRect(_inValue(0, find.byType(CustomPaint)).first);
        expect(shape.height, greaterThan(20 * scale - 1));
      });
    }
  });

  group('экран: ожидание адреса', () {
    const idle = M3eHomeInput(providerName: 'dropweb', announce: 'dropweb.org');

    testWidgets('адреса нет: индикатор до потолка ожидания, потом прочерк',
        (tester) async {
      await _pump(
        tester,
        gateHomeApp(
          'home-off',
          reduced: false,
          extra: [
            m3eHomeInputProvider.overrideWithValue(idle),
            m3eIpWaitProvider.overrideWithValue(const Duration(seconds: 3)),
          ],
        ),
      );
      expect(
          _inValue(0, find.byType(ExpressiveLoadingIndicator)), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          _inValue(0, find.byType(ExpressiveLoadingIndicator)), findsNothing);
      expect(_inValue(0, find.text('—')), findsOneWidget);
    });
  });
}
