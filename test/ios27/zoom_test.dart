// Движение листов и алертов доски: зум из кнопки, нижний ряд под листом, страницы внутри листа
// с обрезкой, перекрёстная смена шапки (motion.js zoomIn/zoomOut/slide/clipNav, app.js crossBar).

import 'dart:async';
import 'dart:ui' as ui;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_disclosure.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/glass_away_probe.dart';
import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';

const _srcKey = ValueKey<String>('src');
const _frameKey = ValueKey<String>('ios27.sheet.frame');
const _titleKey = ValueKey<String>('ios27.sheet.title');
const _closeKey = ValueKey<String>('ios27.sheet.close');
const _pageA = ValueKey<String>('page-a');
const _marker = ValueKey<String>('marker-b');

/// Кнопка-источник 48×48 у нижнего края, как док на доске.
const _button = Rect.fromLTWH(300, 760, 48, 48);

Widget _app({
  bool disableAnimations = false,
  Ios27ZoomId id = Ios27ZoomId.route,
}) =>
    ios27BoardApp(
      brightness: Brightness.light,
      disableAnimations: disableAnimations,
      overrides: layerOverrides(),
      child: Builder(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: ios27ColorsFor(context).palette.bg),
            ),
            Positioned.fromRect(
              rect: _button,
              child: Ios27ZoomSource(
                id: id,
                icon: (_) => const SizedBox.square(dimension: 20),
                // Источник прячет Flutter-часть стекла, поэтому кнопка собрана на `Ios27Glass`.
                child: const Ios27Glass(
                  child: SizedBox.expand(
                    key: _srcKey,
                    child: ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Прозрачность кнопки-источника: 0 — содержимое не рисуется, 1 — рисуется без слоя, между —
/// слой.
///
/// Читает итоговую прозрачность узла `Ios27GlassAwayFade`, под которым лежит содержимое
/// стекла кнопки: источник гасит именно его, а не кнопку целиком.
double _srcOpacity(WidgetTester tester) {
  final fade = find.ancestor(
    of: find.byKey(_srcKey),
    matching: find.byType(Ios27GlassAwayFade),
  );
  expect(fade, findsOneWidget,
      reason: 'содержимое источника лежит под стеклом');
  return tester.widget<Ios27GlassAwayFade>(fade).value;
}

/// Итоговая прозрачность виджета: произведение всех `Opacity`/`FadeTransition` над ним.
double _effective(Finder f, int index) {
  final target = f.at(index);
  var o = 1.0;
  for (final e
      in find.ancestor(of: target, matching: find.byType(Opacity)).evaluate()) {
    o *= (e.widget as Opacity).opacity;
  }
  for (final e in find
      .ancestor(of: target, matching: find.byType(FadeTransition))
      .evaluate()) {
    o *= (e.widget as FadeTransition).opacity.value;
  }
  return o;
}

Future<Future<void> Function()> _openFromButton(
  WidgetTester tester, {
  Ios27ZoomOrigin? origin,
}) async {
  final future = showIos27Sheet<void>(
    _root(tester),
    title: 'Маршрут',
    origin: origin,
    builder: (_) => const SizedBox.expand(),
  );
  await tester.pump();
  return () => future;
}

void main() {
  setUpAll(() {
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(411, 914),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
  });

  group('зум листа из кнопки', () {
    testWidgets(
        'первый кадр — кнопка, последний — лист; кнопка скрыта пока лист открыт',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final origin = Ios27ZoomSource.originFor(Ios27ZoomId.route);
      expect(origin, isNotNull);
      expect(origin!.rect.left, closeTo(_button.left, 1));
      expect(origin.rect.top, closeTo(_button.top, 1));
      expect(origin.rect.size, _button.size);
      expect(_srcOpacity(tester), 1);

      final done = await _openFromButton(tester, origin: origin);
      final first = _rect(tester, find.byKey(_frameKey));
      expect(first.left, closeTo(_button.left, 1));
      expect(first.top, closeTo(_button.top, 1));
      expect(first.width, closeTo(_button.width, 1));
      expect(first.height, closeTo(_button.height, 1));
      expect(_srcOpacity(tester), 0,
          reason: 'кнопка не рисуется на своём месте');

      await tester.pump(const Duration(milliseconds: 120));
      final mid = _rect(tester, find.byKey(_frameKey));
      expect(mid.width, greaterThan(first.width + 20));
      expect(mid.width, lessThan(395));

      await tester.pump(const Duration(milliseconds: 1000));
      final last = _rect(tester, find.byKey(_frameKey));
      expect(last.left, closeTo(8, 0.5));
      expect(last.top, closeTo(346, 0.5));
      expect(last.width, closeTo(395, 0.5));
      expect(last.height, closeTo(560, 0.5));
      expect(_srcOpacity(tester), 0);
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'G8: тикеров нет');

      Navigator.of(_root(tester)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_srcOpacity(tester), 0,
          reason: 'кнопка возвращается в конце втягивания');
      final shrinking = _rect(tester, find.byKey(_frameKey));
      expect(shrinking.width, lessThan(395));
      await tester.pump(const Duration(milliseconds: 600));
      await done();
      expect(find.byKey(_frameKey), findsNothing);
      expect(_srcOpacity(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('возврат кнопки идёт плавно в хвосте втягивания',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final done = await _openFromButton(
        tester,
        origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      Navigator.of(_root(tester)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_srcOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 190));
      final late = _srcOpacity(tester);
      expect(late, inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 400));
      await done();
      expect(_srcOpacity(tester), 1);
    });

    testWidgets(
        'закрытие с середины открытия: втягивание идёт от текущего места',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final done = await _openFromButton(
        tester,
        origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
      );
      await tester.pump(const Duration(milliseconds: 80));
      Navigator.of(_root(tester)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await done();
      expect(find.byKey(_frameKey), findsNothing);
      expect(_srcOpacity(tester), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('без источника лист выезжает снизу, как раньше',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final done = await _openFromButton(tester);
      final first = _rect(tester, find.byKey(_frameKey));
      expect(first.size, const Size(395, 560));
      expect(first.top, greaterThan(900));
      expect(_srcOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_rect(tester, find.byKey(_frameKey)).top, closeTo(346, 0.5));
      Navigator.of(_root(tester)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await done();
    });

    testWidgets('Reduce Motion: зума нет, только прозрачность до 100 мс',
        (tester) async {
      await pumpIos27Board(tester, _app(disableAnimations: true));
      final done = await _openFromButton(
        tester,
        origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
      );
      final first = _rect(tester, find.byKey(_frameKey));
      expect(first.size, const Size(395, 560));
      expect(first.top, closeTo(346, 0.5), reason: 'без смещения');
      expect(_srcOpacity(tester), 1, reason: 'кнопка остаётся на месте');
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.binding.transientCallbackCount, 0);
      Navigator.of(_root(tester)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      await done();
      expect(find.byKey(_frameKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('алерт раскрытия растёт из кнопки питания', () {
    testWidgets(
        'первый кадр — кнопка, последний — карточка 300 pt; кнопка возвращается',
        (tester) async {
      await pumpIos27Board(tester, _app(id: Ios27ZoomId.power));
      final glass = find
          .descendant(
            of: find.byType(Ios27ZoomGlass),
            matching: find.byType(Ios27Glass),
          )
          .first;
      final future = showIos27VpnDisclosure(_root(tester));
      await tester.pump();
      final first = _rect(tester, glass);
      expect(first.left, closeTo(_button.left, 1));
      expect(first.top, closeTo(_button.top, 1));
      expect(first.width, closeTo(_button.width, 1));
      expect(_srcOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 1000));
      final last = _rect(tester, glass);
      expect(last.width, closeTo(300, 0.5));
      expect(last.center.dx, closeTo(411 / 2, 0.5));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(find.text('Отмена'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(await future, isFalse);
      expect(_srcOpacity(tester), 1);
      expect(find.byType(Ios27Alert), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('без источника — прежний въезд масштабом', (tester) async {
      await pumpIos27Board(tester, _app());
      unawaited(
        showIos27Alert<void>(
          _root(tester),
          builder: (_) => const Center(
            child: Ios27Alert(title: 'Тест', body: Text('Текст'), actions: []),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Ios27ZoomGlass), findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(Ios27Alert), findsOneWidget);
    });
  });

  group('нижний ряд главной', () {
    Widget home({required bool away}) => ios27BoardApp(
          brightness: Brightness.light,
          child: ios27HomeFrame(
            input: homeInputFor('home-off'),
            glassAway: away,
          ),
        );
    // Ряд гасит само стекло (`Ios27Glass.away`), а не слой над кнопками: прозрачный предок
    // нативного вида рисуется неверно. Читаем прозрачность содержимого стекла.
    double dock(WidgetTester tester) => dockGlassFade(tester);

    testWidgets(
        'уходит за 250 мс, а не за кадр; возвращается с задержкой 150 мс',
        (tester) async {
      await pumpIos27Board(tester, home(away: false));
      expect(dock(tester), 1);
      await tester.pumpWidget(home(away: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(dock(tester), greaterThan(0),
          reason: 'срез в один кадр недопустим');
      await tester.pump(const Duration(milliseconds: 109));
      final mid = dock(tester);
      expect(mid, inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(dock(tester), 0);

      await tester.pumpWidget(home(away: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(dock(tester), 0, reason: 'задержка 150 мс до возврата');
      await tester.pump(const Duration(milliseconds: 150));
      expect(dock(tester), inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dock(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('Reduce Motion: прозрачность за 100 мс', (tester) async {
      Widget h({required bool away}) => ios27BoardApp(
            brightness: Brightness.light,
            disableAnimations: true,
            child: ios27HomeFrame(
              input: homeInputFor('home-off'),
              glassAway: away,
            ),
          );
      await pumpIos27Board(tester, h(away: false));
      await tester.pumpWidget(h(away: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(dock(tester), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('кнопки дока и питания — источники зума с рамкой кнопки',
        (tester) async {
      await pumpIos27Board(tester, home(away: false));
      for (final (id, key) in [
        (Ios27ZoomId.subscriptions, 'dock-sub'),
        (Ios27ZoomId.power, 'power'),
        (Ios27ZoomId.route, 'dock-route'),
      ]) {
        final origin = Ios27ZoomSource.originFor(id);
        expect(origin, isNotNull, reason: '$id');
        final box = _rect(tester, find.byKey(ValueKey<String>(key)));
        expect(origin!.rect.left, closeTo(box.left, 1));
        expect(origin.rect.top, closeTo(box.top, 1));
        expect(origin.rect.size, box.size);
      }
    });
  });

  group('страницы внутри листа', () {
    const oldRed = Color(0xFFFF0000);

    Future<void> openPages(WidgetTester tester, {bool reduced = false}) async {
      await pumpIos27Board(tester, _app(disableAnimations: reduced));
      unawaited(
        showIos27Sheet<void>(
          _root(tester),
          builder: (_) => Ios27SheetScaffold(
            title: 'Маршрут',
            body: Container(key: _pageA, color: oldRed),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
    }

    void push(WidgetTester tester, {Object? highlight}) => unawaited(
          Ios27SheetNavigator.push<void>(
            tester.element(find.byKey(_pageA)),
            highlight: highlight,
            builder: (_) => const Ios27SheetScaffold(
              title: 'Серверы и группы',
              // Прозрачное тело: без обрезки старая страница просвечивала бы сквозь него.
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: _marker,
                  width: 10,
                  height: 10,
                  child: ColoredBox(color: Color(0xFF0000FF)),
                ),
              ),
            ),
          ),
        );

    Future<List<int>> pixels(WidgetTester tester, int width) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(kIos27BoardRootKey),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    bool reddish(List<int> rgba, int width, int x, int y) {
      final i = (y * width + x) * 4;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      return r - g > 40 && r - b > 40;
    }

    testWidgets(
        'каждая страница обрезана по своей части: старая не видна правее края новой',
        (tester) async {
      await openPages(tester);
      push(tester);
      await tester.pump();
      // Ждём, пока левый край новой страницы окажется примерно в середине листа.
      Rect marker() => _rect(tester, find.byKey(_marker));
      var guard = 0;
      while (marker().left > 8 + 395 * 0.55 && guard++ < 60) {
        await tester.pump(const Duration(milliseconds: 8));
      }
      final newLeft = marker().left;
      expect(newLeft, inInclusiveRange(8 + 395 * 0.3, 8 + 395 * 0.7));

      // Под страницей виден её кусок слева (красный), правее края новой — нет.
      // `toImage()` без масштаба даёт логические пиксели: 1 px = 1 dp.
      const dpr = 1.0;
      const width = 411;
      final rgba = await pixels(tester, width);
      const y = 600;
      var leftRed = 0;
      var rightRed = 0;
      for (var x = ((8 + 20) * dpr).round(); x < width; x++) {
        if (!reddish(rgba, width, x, y)) continue;
        if (x / dpr > newLeft + 3) {
          rightRed++;
        } else {
          leftRed++;
        }
      }
      expect(leftRed, greaterThan(10),
          reason: 'старая страница видна левее края новой');
      expect(rightRed, 0,
          reason: 'правее края новой страницы старая не рисуется');
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('старая страница тускнеет до 0.6 и уезжает влево на треть',
        (tester) async {
      await openPages(tester);
      final startLeft = _rect(tester, find.byKey(_pageA)).left;
      push(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(_effective(find.byKey(_pageA), 0), greaterThan(0.95));
      await tester.pump(const Duration(milliseconds: 560));
      final nearEnd = _effective(find.byKey(_pageA), 0);
      expect(nearEnd, inInclusiveRange(0.6, 0.64));
      expect(
        _rect(tester, find.byKey(_pageA)).left,
        lessThan(startLeft - 395 * 0.25),
      );
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('заголовки старой и новой страницы не бывают видны вместе',
        (tester) async {
      await openPages(tester);
      push(tester);
      await tester.pump();
      var seenBoth = 0;
      for (var i = 0; i < 60; i++) {
        final titles = find.byKey(_titleKey);
        if (titles.evaluate().length == 2) {
          seenBoth++;
          final a = _effective(titles, 0);
          final b = _effective(titles, 1);
          expect(a > 0.5 && b > 0.5, isFalse, reason: 'кадр $i: $a и $b');
          // Правая группа (×) рисуется только новой страницей.
          final closes = find.byKey(_closeKey);
          var visible = 0;
          for (var k = 0; k < closes.evaluate().length; k++) {
            if (_effective(closes, k) > 0.01) visible++;
          }
          expect(visible, lessThanOrEqualTo(1),
              reason: 'кадр $i: два × поверх друг друга');
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(seenBoth, greaterThan(5),
          reason: 'обе шапки живут во время перехода');
    });

    testWidgets(
        'строка, из которой вошли глубже, подсвечена и гаснет при возврате',
        (tester) async {
      await pumpIos27Board(tester, _app());
      unawaited(
        showIos27Sheet<void>(
          _root(tester),
          builder: (_) => const Ios27SheetScaffold(
            title: 'Маршрут',
            body: Ios27SheetPushHighlight(
              id: 'servers',
              child: SizedBox(key: _pageA, height: 50),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      double fill() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(Ios27SheetPushHighlight, skipOffstage: false),
                matching: find.byType(DecoratedBox, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        );
        return ((box.decoration as BoxDecoration).color?.a ?? 0).toDouble();
      }

      expect(fill(), 0);
      push(tester, highlight: 'servers');
      await tester.pump();
      expect(fill(), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(fill(), greaterThan(0),
          reason: 'остаётся подсвеченной под новой страницей');

      Ios27SheetNavigator.pop(tester.element(find.byKey(_marker)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fill(), greaterThan(0),
          reason: 'гаснет не мгновенно (600 мс ease)');
      await tester.pump(const Duration(milliseconds: 1200));
      expect(fill(), 0);
    });

    testWidgets('Reduce Motion: страницы меняются прозрачностью за 100 мс',
        (tester) async {
      await openPages(tester, reduced: true);
      push(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_rect(tester, find.byKey(_marker)).left, closeTo(8, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('после перехода тикеров нет (G8)', (tester) async {
      await openPages(tester);
      push(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.binding.transientCallbackCount, 0);
      Ios27SheetNavigator.pop(tester.element(find.byKey(_marker)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
