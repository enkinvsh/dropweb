import 'dart:async';

import 'package:dropweb/common/lumina.dart';
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _contentKey = Key('content');
const _ghostKey = Key('ghost');
const _backGhostKey = Key('back-ghost');
const _probeKey = Key('probe');

const _source = Rect.fromLTWH(40, 80, 300, 120);
const _pill = Rect.fromLTWH(140, 700, 100, 36);

Rect _target(Size size) =>
    Rect.fromLTRB(8, size.height - 300, size.width - 8, size.height - 8);

GlassMorphSpec _spec({
  GlassMorphHide? hide,
  GlassMorphOrigin? closeOrigin,
  bool drag = false,
}) =>
    GlassMorphSpec(
      source: () => _source,
      target: _target,
      ghost: const SizedBox.expand(key: _ghostKey),
      hideSource: hide,
      closeOrigin: closeOrigin,
      dragToDismiss: drag,
      showHandle: drag,
      fromRadius: Lumina.radiusLg,
      toRadius: Lumina.radiusXxl,
      fromSettings: Lumina.liquidCard,
      toSettings: Lumina.liquidMenu,
      content: (_) => const SizedBox.expand(key: _contentKey),
    );

Future<NavigatorState> _pumpHost(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
  return navigatorKey.currentState!;
}

Future<void> _open(
  WidgetTester tester,
  NavigatorState navigator,
  GlassMorphSpec spec,
) async {
  unawaited(showGlassMorph<void>(navigator.context, spec));
  await tester.pumpAndSettle();
}

// Пружина останавливается с допуском, поэтому равенство точное нельзя:
// сравниваем с точностью до десятой доли пикселя.
void _expectOffsetNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.1));
  expect(actual.dy, closeTo(expected.dy, 0.1));
}

void main() {
  group('GlassMorphHide', () {
    test('источник скрыт, пока держит хотя бы один маршрут', () {
      final hide = GlassMorphHide();
      var notifications = 0;
      hide.addListener(() => notifications++);

      expect(hide.value, isFalse);
      hide.hold();
      hide.hold();
      expect(hide.value, isTrue);
      // Второй hold не меняет значение, слушатели не дёргаются.
      expect(notifications, 1);

      hide.release();
      expect(hide.value, isTrue);
      hide.release();
      expect(hide.value, isFalse);
      expect(notifications, 2);
    });

    test('лишний release не уводит счётчик в минус', () {
      final hide = GlassMorphHide();
      hide.release();
      hide.hold();
      expect(hide.value, isTrue);
      hide.release();
      expect(hide.value, isFalse);
    });

    test('после dispose release не уведомляет слушателей', () {
      final hide = GlassMorphHide();
      hide.hold();
      hide.dispose();
      expect(hide.release, returnsNormally);
    });
  });

  group('showGlassMorph', () {
    testWidgets('панель встаёт ровно в target и прячет источник',
        (tester) async {
      final navigator = await _pumpHost(tester);
      final hide = GlassMorphHide();
      await _open(tester, navigator, _spec(hide: hide));

      final target = _target(const Size(400, 800));
      _expectOffsetNear(
          tester.getTopLeft(find.byKey(_contentKey)), target.topLeft);
      expect(tester.getSize(find.byKey(_contentKey)), target.size);
      expect(hide.value, isTrue);
      // Призрак источника к концу открытия растворился.
      expect(find.byKey(_ghostKey), findsNothing);
    });

    testWidgets('старт открытия сидит на источнике', (tester) async {
      final navigator = await _pumpHost(tester);
      unawaited(showGlassMorph<void>(navigator.context, _spec()));
      // Первый кадр маршрута строит страницу, второй уже с пружиной.
      await tester.pump();
      await tester.pump();

      final ghost = tester.getRect(find.byKey(_ghostKey));
      expect(ghost.topLeft.dx, closeTo(_source.left, 2));
      expect(ghost.topLeft.dy, closeTo(_source.top, 2));
      expect(ghost.size.width, closeTo(_source.width, 2));
      await tester.pumpAndSettle();
    });

    testWidgets('закрытие убирает маршрут и возвращает источник',
        (tester) async {
      final navigator = await _pumpHost(tester);
      final hide = GlassMorphHide();
      await _open(tester, navigator, _spec(hide: hide));

      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsNothing);
      expect(hide.value, isFalse);
    });

    testWidgets('тап по скриму закрывает шит', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, _spec());

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsNothing);
    });

    testWidgets('закрытие в returnTo: летит в пилюлю, а не в источник',
        (tester) async {
      final navigator = await _pumpHost(tester);
      final hide = GlassMorphHide();
      await _open(
        tester,
        navigator,
        _spec(
          hide: hide,
          closeOrigin: GlassMorphOrigin(
            rect: () => _pill,
            ghost: const SizedBox.expand(key: _backGhostKey),
            radius: 18,
            settings: Lumina.liquidButton,
            ghostAlignment: Alignment.bottomCenter,
          ),
        ),
      );

      navigator.pop();
      // Ждём почти до конца пути: призрак пилюли уже проявился, призрака
      // исходной карточки при закрытии нет вовсе.
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (find.byKey(_backGhostKey).evaluate().isNotEmpty) break;
      }

      expect(find.byKey(_backGhostKey), findsOneWidget);
      expect(find.byKey(_ghostKey), findsNothing);
      await tester.pumpAndSettle();
      expect(hide.value, isFalse);
    });

    testWidgets('жест вниз за порогом закрывает шит', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, _spec(drag: true));

      final target = _target(const Size(400, 800));
      // Зона ручки: верхние 32 px стекла.
      await tester.dragFrom(
        target.topCenter + const Offset(0, 16),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsNothing);
    });

    testWidgets('короткий жест возвращает шит на место', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, _spec(drag: true));

      final target = _target(const Size(400, 800));
      final gesture = await tester.startGesture(
        target.topCenter + const Offset(0, 16),
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsOneWidget);
      _expectOffsetNear(
          tester.getTopLeft(find.byKey(_contentKey)), target.topLeft);
    });

    testWidgets(
        'список с запасом в пару пикселей не забирает жест: тянем за тело '
        'шита и он закрывается', (tester) async {
      final navigator = await _pumpHost(tester);
      final spec = GlassMorphSpec(
        source: () => _source,
        target: _target,
        dragToDismiss: true,
        fromRadius: Lumina.radiusLg,
        toRadius: Lumina.radiusXxl,
        fromSettings: Lumina.liquidCard,
        toSettings: Lumina.liquidMenu,
        // Контент выше панели на 10 px: оценка высоты шита промахнулась.
        content: (_) => ListView(
          physics: const SheetFitPhysics(),
          children: const [SizedBox(key: _contentKey, height: 310)],
        ),
      );
      await _open(tester, navigator, spec);

      final target = _target(const Size(400, 800));
      await tester.dragFrom(target.center, const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsNothing);
    });

    testWidgets('по-настоящему длинный список прокручивается, а не закрывает',
        (tester) async {
      final navigator = await _pumpHost(tester);
      final spec = GlassMorphSpec(
        source: () => _source,
        target: _target,
        dragToDismiss: true,
        fromRadius: Lumina.radiusLg,
        toRadius: Lumina.radiusXxl,
        fromSettings: Lumina.liquidCard,
        toSettings: Lumina.liquidMenu,
        content: (_) => ListView(
          physics: const SheetFitPhysics(),
          children: const [SizedBox(key: _contentKey, height: 900)],
        ),
      );
      await _open(tester, navigator, spec);

      final target = _target(const Size(400, 800));
      final before = tester.getTopLeft(find.byKey(_contentKey)).dy;
      // Вверх: прокрутка списка.
      await tester.dragFrom(target.center, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(find.byKey(_contentKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(_contentKey)).dy, lessThan(before));
    });

    testWidgets('обводка рисуется поверх стекла по размеру панели',
        (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, _spec());

      final painters = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_RimPainter',
      );
      expect(painters, findsOneWidget);
      final target = _target(const Size(400, 800));
      expect(tester.getSize(painters).width, closeTo(target.width, 0.1));
      expect(tester.getSize(painters).height, closeTo(target.height, 0.1));
    });
  });

  group('fitContent', () {
    // Контент высотой 100 при стартовой оценке шита 300.
    GlassMorphSpec fit({double contentHeight = 100}) => GlassMorphSpec(
          source: () => _source,
          target: _target,
          fitContent: true,
          fromRadius: Lumina.radiusLg,
          toRadius: Lumina.radiusXxl,
          fromSettings: Lumina.liquidCard,
          toSettings: Lumina.liquidMenu,
          content: (_) => Builder(
            builder: (context) {
              final report = GlassMorphScope.maybeOf(context)!;
              return _HeightProbe(height: contentHeight, onHeight: report);
            },
          ),
        );

    testWidgets('стекло подгоняется под высоту содержимого', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, fit());

      // Высота содержимого + зазор под панелью (8), нижний край на месте.
      final panel = tester.getRect(find.byKey(_probeKey));
      expect(panel.height, closeTo(100, 0.5));
      expect(panel.bottom, closeTo(800 - 8, 0.5));
    });

    testWidgets('растёт, когда содержимое выросло', (tester) async {
      final navigator = await _pumpHost(tester);
      var height = 100.0;
      late StateSetter set;
      final spec = GlassMorphSpec(
        source: () => _source,
        target: _target,
        fitContent: true,
        fromRadius: Lumina.radiusLg,
        toRadius: Lumina.radiusXxl,
        fromSettings: Lumina.liquidCard,
        toSettings: Lumina.liquidMenu,
        content: (_) => StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return _HeightProbe(
              height: height,
              onHeight: GlassMorphScope.maybeOf(context)!,
            );
          },
        ),
      );
      await _open(tester, navigator, spec);
      expect(tester.getRect(find.byKey(_probeKey)).height, closeTo(100, 0.5));

      set(() => height = 220);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_probeKey)).height, closeTo(220, 0.5));
    });

    testWidgets('потолок высоты — доля экрана', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, fit(contentHeight: 2000));

      final panel = tester.getRect(find.byKey(_probeKey));
      // 800 * 0.85 минус зазор 8.
      expect(panel.height, closeTo(800 * 0.85 - 8, 1));
    });

    testWidgets('поднимается над клавиатурой', (tester) async {
      final navigator = await _pumpHost(tester);
      await _open(tester, navigator, fit());
      expect(tester.getRect(find.byKey(_probeKey)).bottom, closeTo(792, 0.5));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(_probeKey)).bottom,
          closeTo(792 - 300, 0.5));
    });

    testWidgets('содержимое не видит клавиатуру: подъём уже сделан стеклом',
        (tester) async {
      final navigator = await _pumpHost(tester);
      double? seen;
      final spec = GlassMorphSpec(
        source: () => _source,
        target: _target,
        fitContent: true,
        fromRadius: Lumina.radiusLg,
        toRadius: Lumina.radiusXxl,
        fromSettings: Lumina.liquidCard,
        toSettings: Lumina.liquidMenu,
        content: (context) {
          seen = MediaQuery.viewInsetsOf(context).bottom;
          return const SizedBox.expand();
        },
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await _open(tester, navigator, spec);

      expect(seen, 0);
    });
  });

  group('showGlassMorph (reduce-motion)', () {
    testWidgets('reduce-motion: панель сразу в target, без полёта',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final navigator = await _pumpHost(tester);
      unawaited(showGlassMorph<void>(navigator.context, _spec()));
      await tester.pump();
      await tester.pump();

      // Стекло уже на месте: двигается только непрозрачность содержимого.
      final finder = find.byKey(_contentKey);
      final target = _target(const Size(400, 800));
      // До проявления содержимого его может ещё не быть в дереве; ждём кадр.
      await tester.pump(const Duration(milliseconds: 60));
      expect(finder, findsOneWidget);
      _expectOffsetNear(tester.getTopLeft(finder), target.topLeft);
      await tester.pumpAndSettle();
    });
  });
}

/// Содержимое с известной высотой: сообщает её хосту после кадра, как это
/// делает LiquidSheetBody. Само заполняет панель, поэтому по его размеру
/// видно высоту стекла.
class _HeightProbe extends StatefulWidget {
  const _HeightProbe({required this.height, required this.onHeight});

  final double height;
  final ValueChanged<double> onHeight;

  @override
  State<_HeightProbe> createState() => _HeightProbeState();
}

class _HeightProbeState extends State<_HeightProbe> {
  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHeight(widget.height);
    });
  }

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(_HeightProbe old) {
    super.didUpdateWidget(old);
    if (old.height != widget.height) _report();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: _probeKey);
}
