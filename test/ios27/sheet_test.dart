// Лист iOS-редизайна: геометрия доски, dismissible, смахивание, клавиатура, страницы, golden.

import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';

const _fieldKey = ValueKey<String>('field');
const _titleKey = ValueKey<String>('ios27.sheet.title');
const _closeKey = ValueKey<String>('ios27.sheet.close');
const _backKey = ValueKey<String>('ios27.sheet.back');
const _grabberKey = ValueKey<String>('ios27.sheet.grabber');

/// 300 dp клавиатуры при dpr 2.
const _keyboardPx = 600.0;
const _keyboardTop = 914 - 300.0;

Widget _app({
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
}) =>
    ios27BoardApp(
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
      overrides: layerOverrides(),
      child: Builder(
        builder: (context) =>
            ColoredBox(color: ios27ColorsFor(context).palette.bg),
      ),
    );

/// Контекст корневого навигатора: выше любой области темы.
BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<Future<T?>> _open<T>(
  WidgetTester tester, {
  Widget body = const SizedBox.expand(),
  bool dismissible = true,
  Ios27SheetDetent detent = Ios27SheetDetent.medium,
  String title = 'Маршрут',
}) async {
  final future = showIos27Sheet<T>(
    _root(tester),
    title: title,
    detent: detent,
    dismissible: dismissible,
    builder: (_) => body,
  );
  await _settle(tester);
  return future;
}

void main() {
  setUpAll(() {
    // Вид «мобильный»: `showSheet` ветвится по размеру окна.
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(411, 914),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'корневой контекст ${brightness.name}: цвета iOS, без исключений',
        (tester) async {
      await pumpIos27Board(tester, _app(brightness: brightness));
      await _open<void>(tester);
      final colors = Ios27Colors.maybeOf(tester.element(find.byKey(_titleKey)));
      expect(colors, isNotNull);
      expect(colors!.dark, brightness == Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('геометрия доски: лист, шапка, заголовок, кнопка, ручка',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await _open<void>(tester);
    final ref = Ios27RefLayout.load('route-light-rt-p0');
    final sheet =
        _rect(tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')));
    final refSheet = ref.element('sheet')!;
    expect(sheet.left, closeTo(refSheet.left, 0.5));
    expect(sheet.top, closeTo(refSheet.top, 0.5));
    expect(sheet.width, closeTo(refSheet.width, 0.5));
    expect(sheet.height, closeTo(refSheet.height, 0.5));
    final title = _rect(tester, find.byKey(_titleKey));
    final refTitle = ref.element('sheet.title')!;
    expect(title.center.dx, closeTo(refTitle.center.dx, 0.5));
    expect(title.top, closeTo(refTitle.top, 0.5));
    expect(title.width, closeTo(refTitle.width, 0.5));
    final close = _rect(tester, find.byKey(_closeKey));
    final refClose = ref.element('sheet.close')!;
    expect(close.left, closeTo(refClose.left, 0.5));
    expect(close.top, closeTo(refClose.top, 0.5));
    expect(close.size, refClose.size);
    final grabber = _rect(tester, find.byKey(_grabberKey));
    expect(grabber.size, const Size(36, 5));
    expect(grabber.top, closeTo(sheet.top + 6, 0.5));
    expect(grabber.center.dx, closeTo(sheet.center.dx, 0.5));
  });

  group('dismissible', () {
    testWidgets('false: затемнение, «назад» и смахивание не закрывают',
        (tester) async {
      await pumpIos27Board(tester, _app());
      await _open<void>(tester, dismissible: false);
      await tester.tapAt(const Offset(200, 100));
      await _settle(tester);
      expect(find.byKey(_titleKey), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_titleKey), findsOneWidget);
      await tester.fling(find.byKey(_titleKey), const Offset(0, 500), 3000);
      await _settle(tester);
      expect(find.byKey(_titleKey), findsOneWidget);
      // Лист вернулся на место.
      final sheet = _rect(
          tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')));
      expect(sheet.top, closeTo(346, 0.5));
    });

    testWidgets('true: затемнение закрывает', (tester) async {
      await pumpIos27Board(tester, _app());
      final result = await _open<int>(tester);
      await tester.tapAt(const Offset(200, 100));
      await _settle(tester);
      expect(find.byKey(_titleKey), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('true: «назад» закрывает', (tester) async {
      await pumpIos27Board(tester, _app());
      await _open<void>(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_titleKey), findsNothing);
    });

    testWidgets('true: быстрое смахивание вниз закрывает, медленное возвращает',
        (tester) async {
      await pumpIos27Board(tester, _app());
      await _open<void>(tester);
      // Слабое смещение без скорости: возврат пружиной.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_titleKey)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(
          _rect(tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')))
              .top,
          closeTo(346 + 40, 1));
      await gesture.up();
      await _settle(tester);
      expect(
          _rect(tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')))
              .top,
          closeTo(346, 0.5));
      // Быстрое смахивание закрывает.
      await tester.fling(find.byKey(_titleKey), const Offset(0, 400), 3000);
      await _settle(tester);
      expect(find.byKey(_titleKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  testWidgets('кнопка «Закрыть» возвращает результат, тикеров нет',
      (tester) async {
    await pumpIos27Board(tester, _app());
    final result = await _open<int>(tester);
    await tester.tap(find.byKey(_closeKey));
    await _settle(tester);
    expect(await result, isNull);
    expect(find.byKey(_titleKey), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('detent fit по содержимому, medium 560', (tester) async {
    await pumpIos27Board(tester, _app());
    await _open<void>(
      tester,
      detent: Ios27SheetDetent.fit,
      body: const SizedBox(height: 100),
    );
    final fit =
        _rect(tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')));
    expect(fit.height, closeTo(64 + 4 + 100, 0.5));
    expect(fit.bottom, closeTo(906, 0.5));
  });

  testWidgets('Reduce Motion: только прозрачность, лист на месте сразу',
      (tester) async {
    await pumpIos27Board(tester, _app(disableAnimations: true));
    unawaited(
      showIos27Sheet<void>(_root(tester),
          title: 'Маршрут', builder: (_) => const SizedBox.expand()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final frame =
        _rect(tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')));
    expect(frame.top, closeTo(346, 0.5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
  });

  group('клавиатура: viewInsets считаются один раз', () {
    Future<void> checkKeyboard(WidgetTester tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardPx);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byKey(_fieldKey));
      await _settle(tester, 400);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final frame = _rect(
          tester, find.byKey(const ValueKey<String>('ios27.sheet.frame')));
      // Лист стоит на 8 выше клавиатуры: ровно один раз.
      expect(frame.bottom, closeTo(_keyboardTop - 8, 0.01));
      final field = _rect(tester, find.byKey(_fieldKey));
      expect(field.height, greaterThan(0));
      expect(field.bottom, lessThanOrEqualTo(frame.bottom));
      // Потомки не получают viewInsets второй раз.
      final inner = MediaQuery.of(tester.element(find.byKey(_fieldKey)));
      expect(inner.viewInsets.bottom, 0);
      // Область под шапкой не схлопнулась.
      expect(frame.height, greaterThanOrEqualTo(160));
    }

    testWidgets('showIos27Sheet, шрифт ×2', (tester) async {
      await pumpIos27Board(tester, _app(textScale: 2.0));
      await _open<void>(
        tester,
        detent: Ios27SheetDetent.fit,
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: TextField(key: _fieldKey),
          ),
        ),
      );
      await checkKeyboard(tester);
    });

    testWidgets('showSheet (шов), шрифт ×2', (tester) async {
      // Платформа теста macOS: iOS-ветку включаем флагом, как `MessageManager.useIos27`.
      final saved = SheetSkin.defaultUseIos27;
      SheetSkin.defaultUseIos27 = true;
      addTearDown(() => SheetSkin.defaultUseIos27 = saved);
      await pumpIos27Board(tester, _app(textScale: 2.0));
      unawaited(
        showSheet<void>(
          context: _root(tester),
          useM3e: false,
          builder: (context, type) => AdaptiveSheetScaffold(
            type: type,
            title: 'Подписка',
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: TextField(key: _fieldKey),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(_titleKey), findsOneWidget);
      await checkKeyboard(tester);
    });
  });

  group('страницы второго уровня', () {
    // Страница меняет обёртки перехода (сдвиг, прозрачность) и снимает их по его концу. Без
    // GlobalKey на странице это пересоздаёт её состояние: `initState` шёл бы повторно (двойной замер
    // пинга, потеря прокрутки и ввода).
    for (final reduced in [false, true]) {
      testWidgets(
          'push + pop: initState каждой страницы ровно один раз'
          '${reduced ? ' (Reduce Motion)' : ''}', (tester) async {
        final inits = <String, int>{};
        await pumpIos27Board(tester, _app(disableAnimations: reduced));
        final future = showIos27Sheet<void>(
          _root(tester),
          builder: (_) => Ios27SheetScaffold(
            title: 'Маршрут',
            body: _InitProbe(
              name: 'root',
              inits: inits,
              child: Builder(
                builder: (c) => TextButton(
                  key: const ValueKey<String>('push'),
                  onPressed: () => Ios27SheetNavigator.push<void>(
                    c,
                    builder: (_) => Ios27SheetScaffold(
                      title: 'Серверы',
                      body: _InitProbe(
                        name: 'pushed',
                        inits: inits,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  child: const Text('Дальше'),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(inits, {'root': 1});
        await tester.tap(find.byKey(const ValueKey<String>('push')));
        await _settle(tester);
        // Страница отъехала по полному переходу и сняла обёртки: состояние то же.
        expect(inits, {'root': 1, 'pushed': 1});
        await tester.tap(find.byKey(_backKey));
        await _settle(tester);
        expect(inits, {'root': 1, 'pushed': 1});
        // Корневая страница пережила переход туда и обратно.
        expect(find.text('Дальше'), findsOneWidget);
        Navigator.of(_root(tester), rootNavigator: true).pop();
        await _settle(tester);
        await future;
      });
    }

    Widget page(String title, Widget body) =>
        Ios27SheetScaffold(title: title, body: body);

    testWidgets('push: «Назад» появляется, возвращает на первую страницу',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final future = showIos27Sheet<void>(
        _root(tester),
        builder: (_) => page(
          'Маршрут',
          Builder(
            builder: (c) => TextButton(
              key: const ValueKey<String>('push'),
              onPressed: () => Ios27SheetNavigator.push<void>(
                c,
                builder: (_) => page('Серверы', const SizedBox.expand()),
              ),
              child: const Text('Дальше'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(_backKey), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('push')));
      await _settle(tester);
      expect(find.byKey(_backKey), findsOneWidget);
      expect(find.text('Серверы'), findsOneWidget);
      // Назад кнопкой.
      await tester.tap(find.byKey(_backKey));
      await _settle(tester);
      expect(find.byKey(_backKey), findsNothing);
      expect(find.text('Серверы'), findsNothing);
      // Системное «назад» на втором уровне возвращает страницу, а не закрывает лист.
      await tester.tap(find.byKey(const ValueKey<String>('push')));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Маршрут'), findsOneWidget);
      expect(find.text('Серверы'), findsNothing);
      // Второе «назад» закрывает лист.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Маршрут'), findsNothing);
      await future;
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
        'dismissible false: на втором уровне «назад» возвращает страницу',
        (tester) async {
      await pumpIos27Board(tester, _app());
      unawaited(
        showIos27Sheet<void>(
          _root(tester),
          dismissible: false,
          builder: (_) => page(
            'Маршрут',
            Builder(
              builder: (c) => TextButton(
                key: const ValueKey<String>('push'),
                onPressed: () => Ios27SheetNavigator.push<void>(
                  c,
                  builder: (_) => page('Серверы', const SizedBox.expand()),
                ),
                child: const Text('Дальше'),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('push')));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Серверы'), findsNothing);
      expect(find.text('Маршрут'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Маршрут'), findsOneWidget);
    });
  });

  group('golden', () {
    testWidgets('оболочка листа Маршрут', (tester) async {
      await pumpIos27Board(tester, _app());
      await _open<void>(tester);
      await expectIos27Golden(tester, 'layer_sheet_route');
    });
  });
}

/// Считает вызовы `initState` страницы листа.
class _InitProbe extends StatefulWidget {
  const _InitProbe({
    required this.name,
    required this.inits,
    required this.child,
  });

  final String name;
  final Map<String, int> inits;
  final Widget child;

  @override
  State<_InitProbe> createState() => _InitProbeState();
}

class _InitProbeState extends State<_InitProbe> {
  @override
  void initState() {
    super.initState();
    widget.inits.update(widget.name, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
