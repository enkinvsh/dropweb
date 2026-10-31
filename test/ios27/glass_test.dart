import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show PlatformViewHitTestBehavior, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Экран доски (`.droid`): 411x914 dp при dpr 2.
const _screen = Size(411, 914);

const _glassKey = ValueKey<String>('glass');

void _setSurface(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = _screen * 2;
  addTearDown(tester.view.reset);
}

/// Корень как в приложении: настоящий `CommonScaffold(fullBleed)`. Урок чёрного
/// экрана: тело fullBleed без непозиционированных детей схлопывалось в 0x0, и
/// проверка заглушки вне scaffold этого не поймала бы.
Widget _app(Widget body, {bool disableAnimations = false}) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Reduce Motion системы: переходы стекла сжимаются до 100 мс либо отключаются.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: CommonScaffold(
          // assert в build() требует заголовок даже у fullBleed.
          title: '',
          fullBleed: true,
          body: body,
        ),
      ),
    );

/// Кадр + доигрывание перехода заливки заглушки: при смене тона/темы она плавно
/// перетекает пружиной `smooth` (735 мс), поэтому проверки значений идут после неё.
/// Первое построение не анимируется, а `pump(1 с)` тикер доводит до конца
/// (тикер стартует на первом кадре, один длинный `pump` без предшествующего не хватит).
Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  bool disableAnimations = false,
}) async {
  _setSurface(tester);
  await tester.pumpWidget(_app(body, disableAnimations: disableAnimations));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void _setBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void _setHighContrast(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(highContrast: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Заливка заглушки: у непрозрачной это `ShapeDecoration`, у полупрозрачной (недоступная кнопка
/// из цветного стекла) `CustomPaint`, который не пускает тени под заливку.
Color _stubFill(WidgetTester tester) {
  final decorated = find
      .descendant(
        of: find.byType(Ios27Glass),
        matching: find.byType(DecoratedBox),
      )
      .evaluate();
  if (decorated.isNotEmpty) {
    return _stub(tester).color!;
  }
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(Ios27Glass),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter! as dynamic).fill as Color;
}

ShapeDecoration _stub(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(Ios27Glass),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as ShapeDecoration;
}

ShapeBorderClipper _clipper(WidgetTester tester) => tester
    .widget<ClipPath>(
      find.descendant(
        of: find.byType(Ios27Glass),
        matching: find.byType(ClipPath),
      ),
    )
    .clipper! as ShapeBorderClipper;

Widget _glass({
  Ios27GlassShape shape = const Ios27GlassShape.capsule(),
  Ios27GlassVariant variant = Ios27GlassVariant.small,
  Color? tint,
  bool enabled = true,
  bool away = false,
  Clip clipBehavior = Clip.antiAlias,
}) =>
    Center(
      child: Ios27Glass(
        key: _glassKey,
        shape: shape,
        variant: variant,
        tint: tint,
        enabled: enabled,
        away: away,
        clipBehavior: clipBehavior,
        child: const SizedBox(width: 120, height: 60),
      ),
    );

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Включает нативную ветку: платформа iOS, разрешение внутри `flutter test`,
/// мок канала платформенных видов. Дерево снимается до сброса мока: `dispose`
/// вида тоже ходит в этот канал.
Future<void> _withNative(
  WidgetTester tester,
  Future<void> Function(List<int> created) body,
) async {
  final created = <int>[];
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  Ios27Glass.debugAllowNativeInTests = true;
  _messenger.setMockMethodCallHandler(SystemChannels.platform_views,
      (call) async {
    if (call.method == 'create') {
      created.add((call.arguments as Map<Object?, Object?>)['id']! as int);
    }
    return null;
  });
  try {
    await body(created);
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDefaultTargetPlatformOverride = null;
    Ios27Glass.debugAllowNativeInTests = false;
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  }
}

void main() {
  tearDown(() {
    Ios27A11y.debugReset();
    Ios27Glass.debugForceStub = false;
    Ios27Glass.debugAllowNativeInTests = false;
  });

  group('заглушка', () {
    testWidgets('ненулевой размер внутри CommonScaffold(fullBleed)',
        (tester) async {
      await _pump(
        tester,
        const Center(
          child: SizedBox(width: 120, height: 60, child: Ios27Glass()),
        ),
      );
      // Без ребёнка виджет занимает все ограничения: 120x60 от SizedBox.
      expect(tester.getSize(find.byType(Ios27Glass)), const Size(120, 60));

      await _pump(tester, _glass());
      // С ребёнком размер задаёт он.
      expect(tester.getSize(find.byKey(_glassKey)), const Size(120, 60));
      expect(tester.takeException(), isNull);
    });

    testWidgets('без ребёнка и без ограничителей: весь экран, не 0x0',
        (tester) async {
      await _pump(tester, const Ios27Glass(key: _glassKey));
      expect(tester.getSize(find.byKey(_glassKey)), _screen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('нет ни одного UiKitView', (tester) async {
      await _pump(tester, _glass());
      expect(find.byType(UiKitView), findsNothing);
    });

    testWidgets('платформа iOS внутри flutter test всё равно даёт заглушку',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pump(tester, _glass());
        expect(find.byType(UiKitView), findsNothing);
        expect(_stub(tester).color, const Color(0xFFF2F2F2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('цвета: светлая и тёмная заливка доски при Reduce Transparency',
        (tester) async {
      await _pump(tester, _glass());
      expect(_stub(tester).color, const Color(0xFFF2F2F2));

      _setBrightness(tester, Brightness.dark);
      await _pump(tester, _glass());
      expect(_stub(tester).color, const Color(0xFF2A2A2A));
    });

    testWidgets('тон: заливка = акцент; disabled: полупрозрачная подложка',
        (tester) async {
      const accent = Color(0xFF29FF76);
      await _pump(tester, _glass(tint: accent));
      expect(_stub(tester).color, accent);

      await _pump(tester, _glass(tint: accent, enabled: false));
      expect(_stubFill(tester), const Color(0x33F8F8F8));

      _setBrightness(tester, Brightness.dark);
      await _pump(tester, _glass(tint: accent, enabled: false));
      expect(_stubFill(tester), const Color(0x2B999999));
    });

    // Тени кольца и подложки рисуются только снаружи формы, как CSS `box-shadow`: сквозь
    // полупрозрачную заливку они не просвечивают (glass.css:261, на доске кнопка почти прозрачна).
    testWidgets('disabled: под полупрозрачной заливкой нет теней',
        (tester) async {
      const key = ValueKey<String>('shot');
      await _pump(
        tester,
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: _glass(tint: const Color(0xFF29FF76), enabled: false),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image =
          await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
      final bytes = await tester.runAsync(image!.toByteData);
      int px(int x, int y) {
        final i = (y * image.width + x) * 4;
        return bytes!.getUint8(i); // красный канал
      }

      // Центр кнопки: белый фон + F8F8F8 с альфой 0.2 ≈ почти белый. С тенями под заливкой
      // было бы ~0xB5.
      expect(px(image.width ~/ 2, image.height ~/ 2), greaterThan(0xF4));
      // Снаружи формы кольцо на месте: пиксель чуть левее капсулы темнее фона.
      final centerY = image.height ~/ 2;
      var darkest = 255;
      for (var x = 0; x < image.width ~/ 2 - 120; x++) {
        darkest = darkest < px(x, centerY) ? darkest : px(x, centerY);
      }
      expect(darkest, lessThan(0xFF), reason: 'кольцо снаружи рисуется');
    });

    // `content` — матовый материал контента, не стекло: у него своя заливка (группа ниже).
    testWidgets('все классы стекла без тона получают одну плотную заливку',
        (tester) async {
      for (final variant in Ios27GlassVariant.values
          .where((v) => v != Ios27GlassVariant.content)) {
        await _pump(tester, _glass(variant: variant));
        expect(
          _stub(tester).color,
          const Color(0xFFF2F2F2),
          reason: '$variant',
        );
      }
    });

    testWidgets('Ios27GlassColors подменяет палитру и яркость', (tester) async {
      await _pump(
        tester,
        const Ios27GlassColors(
          brightness: Brightness.dark,
          dark: Ios27GlassPalette(
            fill: Color(0xFF112233),
            disabledTintFill: Color(0x33445566),
            contrastRing: Color(0x80FFFFFF),
          ),
          child: Center(child: Ios27Glass(key: _glassKey)),
        ),
      );
      expect(_stub(tester).color, const Color(0xFF112233));
    });

    testWidgets('явная яркость сильнее системной и Ios27GlassColors',
        (tester) async {
      _setBrightness(tester, Brightness.light);
      await _pump(
        tester,
        const Ios27GlassColors(
          brightness: Brightness.light,
          child: Center(
            child: Ios27Glass(key: _glassKey, brightness: Brightness.dark),
          ),
        ),
      );
      expect(_stub(tester).color, const Color(0xFF2A2A2A));
    });

    testWidgets('капсула и скруглённый прямоугольник: форма и клип ребёнка',
        (tester) async {
      await _pump(tester, _glass());
      expect(_stub(tester).shape, const StadiumBorder());
      expect(_clipper(tester).shape, const StadiumBorder());

      await _pump(tester, _glass(shape: const Ios27GlassShape.rounded(26)));
      final expected = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      );
      expect(_stub(tester).shape, expected);
      expect(_clipper(tester).shape, expected);
    });

    testWidgets('Clip.none: ребёнок без обрезки', (tester) async {
      await _pump(tester, _glass(clipBehavior: Clip.none));
      expect(
        find.descendant(
          of: find.byType(Ios27Glass),
          matching: find.byType(ClipPath),
        ),
        findsNothing,
      );
    });

    testWidgets('кромка по классу: small с щелями, md/lg с тенью, inactive без',
        (tester) async {
      await _pump(tester, _glass());
      final small = _stub(tester).shadows!;
      // Кольцо, две боковые щели, внешняя тень.
      expect(small, hasLength(4));
      expect(small.first.spreadRadius, 0.5);
      expect(small.last.offset, const Offset(0, 8));
      expect(small.last.blurRadius, 15);

      await _pump(tester, _glass(variant: Ios27GlassVariant.md));
      final md = _stub(tester).shadows!;
      expect(md.last.offset, const Offset(0, 18));
      expect(md.last.blurRadius, 46);

      await _pump(tester, _glass(variant: Ios27GlassVariant.lg));
      expect(_stub(tester).shadows!.last.blurRadius, 48);

      await _pump(tester, _glass(variant: Ios27GlassVariant.widget));
      expect(_stub(tester).shadows, hasLength(1));

      await _pump(tester, _glass(variant: Ios27GlassVariant.inactive));
      expect(_stub(tester).shadows, hasLength(1));
    });

    testWidgets('Increase Contrast: одно кольцо 1px, тон не меняется',
        (tester) async {
      _setHighContrast(tester);
      await _pump(tester, _glass(variant: Ios27GlassVariant.md));
      final ring = _stub(tester).shadows!;
      expect(ring, hasLength(1));
      expect(ring.single.spreadRadius, 1);
      expect(ring.single.color, const Color(0x80000000));

      await _pump(tester, _glass(tint: const Color(0xFF29FF76)));
      expect(_stub(tester).shadows, hasLength(4));
    });
  });

  group('нативная ветка и Reduce Transparency', () {
    testWidgets('debugForceStub перекрывает iOS', (tester) async {
      await _withNative(tester, (created) async {
        Ios27Glass.debugForceStub = true;
        await _pump(tester, _glass());
        expect(find.byType(UiKitView), findsNothing);
        expect(created, isEmpty);
      });
    });

    testWidgets(
        'на iOS стекло нативное; Reduce Transparency меняет его на заглушку',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, _glass());
        expect(find.byType(UiKitView), findsOneWidget);
        expect(created, hasLength(1));
        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(view.viewType, 'dropweb/glass');
        expect(view.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
        expect(
          (view.creationParams! as Map<String, Object?>)['shape'],
          'capsule',
        );

        Ios27A11y.debugOverride = true;
        await tester.pump();
        expect(find.byType(UiKitView), findsNothing);
        expect(_stub(tester).color, const Color(0xFFF2F2F2));

        Ios27A11y.debugOverride = false;
        await tester.pump();
        expect(find.byType(UiKitView), findsOneWidget);
      });
    });

    testWidgets('смена тона уходит в updateParams без пересоздания вида',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, _glass());
        await tester.pump();
        final id = created.single;

        final calls = <MethodCall>[];
        final channel = MethodChannel('dropweb/glass_$id');
        _messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

        const accent = Color(0xFF29FF76);
        await tester.pumpWidget(_app(_glass(tint: accent)));
        await tester.pump();

        expect(created, hasLength(1), reason: 'вид не пересоздаётся');
        expect(calls, hasLength(1));
        expect(calls.single.method, 'updateParams');
        final map = calls.single.arguments as Map<Object?, Object?>;
        expect(map['tint'], accent.toARGB32());
        expect(map['variant'], 'small');

        // Тот же набор повторно не отправляется.
        await tester.pumpWidget(_app(_glass(tint: accent)));
        await tester.pump();
        expect(calls, hasLength(1));

        _messenger.setMockMethodCallHandler(channel, null);
      });
    });
  });

  group('тон и уход под лист (W2b)', () {
    /// Прозрачность Flutter-содержимого стекла (последний `Ios27GlassAwayFade`
    /// в стеке — тот, что оборачивает ребёнка).
    double contentFade(WidgetTester tester) => tester
        .widgetList<Ios27GlassAwayFade>(
          find.descendant(
            of: find.byType(Ios27Glass),
            matching: find.byType(Ios27GlassAwayFade),
          ),
        )
        .last
        .opacity
        .value;

    testWidgets('заглушка: смена тона перетекает пружиной, а не скачет',
        (tester) async {
      const accent = Color(0xFF29FF76);
      await _pump(tester, _glass());
      expect(_stub(tester).color, const Color(0xFFF2F2F2));

      await tester.pumpWidget(_app(_glass(tint: accent)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final mid = _stub(tester).color!;
      expect(mid, isNot(const Color(0xFFF2F2F2)));
      expect(mid, isNot(accent));

      await tester.pump(const Duration(seconds: 1));
      expect(_stub(tester).color, accent);

      // Обратно: цель — снова плотная подложка, без залипания на промежуточном.
      await tester.pumpWidget(_app(_glass()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_stub(tester).color, const Color(0xFFF2F2F2));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('заглушка + Reduce Motion: тон меняется сразу', (tester) async {
      const accent = Color(0xFF29FF76);
      await _pump(tester, _glass(), disableAnimations: true);
      await tester.pumpWidget(
        _app(_glass(tint: accent), disableAnimations: true),
      );
      await tester.pump();
      expect(_stub(tester).color, accent);
    });

    testWidgets('заглушка: away гасит содержимое 250 мс и возвращает 150+300',
        (tester) async {
      await _pump(tester, _glass());
      expect(contentFade(tester), 1);

      await tester.pumpWidget(_app(_glass(away: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(contentFade(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(contentFade(tester), 0);

      await tester.pumpWidget(_app(_glass()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(contentFade(tester), 0, reason: 'первые 150 мс возврат стоит');
      await tester.pump(const Duration(milliseconds: 150));
      expect(contentFade(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(contentFade(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('заглушка + Reduce Motion: away за 100 мс', (tester) async {
      await _pump(tester, _glass(), disableAnimations: true);
      await tester
          .pumpWidget(_app(_glass(away: true), disableAnimations: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(contentFade(tester), 0);
    });

    testWidgets('нативно: away и reduceMotion уходят в updateParams',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, _glass(), disableAnimations: true);
        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        final params = view.creationParams! as Map<String, Object?>;
        expect(params['away'], false);
        expect(params['reduceMotion'], true);

        final calls = <MethodCall>[];
        final channel = MethodChannel('dropweb/glass_${created.single}');
        _messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

        await tester.pumpWidget(
          _app(_glass(away: true), disableAnimations: true),
        );
        await tester.pump();
        expect(created, hasLength(1), reason: 'вид не пересоздаётся');
        expect(calls, hasLength(1));
        final map = calls.single.arguments as Map<Object?, Object?>;
        expect(map['away'], true);
        expect(map['reduceMotion'], true);

        _messenger.setMockMethodCallHandler(channel, null);
      });
    });

    // Полупрозрачный предок `UIVisualEffectView` рисуется неверно (вспышка плоских
    // кругов): прозрачность допустима только над тем, что рисует Flutter.
    testWidgets('нативно: над UiKitView нет Opacity и FadeTransition',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, _glass(tint: const Color(0xFF29FF76)));
        await tester.pumpWidget(_app(_glass(away: true)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        for (final type in <Type>[
          Opacity,
          FadeTransition,
          AnimatedOpacity,
          Ios27GlassAwayFade,
        ]) {
          expect(
            find.ancestor(
              of: find.byType(UiKitView),
              matching: find.byType(type),
            ),
            findsNothing,
            reason: '$type над нативным видом',
          );
        }
        // Значок гаснет собственной прозрачностью Flutter — рядом, а не над видом.
        expect(contentFade(tester), inExclusiveRange(0, 1));
      });
    });

    testWidgets('нативно: смена тона шлёт один updateParams, без анимации Dart',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, _glass());
        final calls = <MethodCall>[];
        final channel = MethodChannel('dropweb/glass_${created.single}');
        _messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

        await tester.pumpWidget(_app(_glass(tint: const Color(0xFF29FF76))));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, hasLength(1));
        expect(tester.hasRunningAnimations, isFalse);

        _messenger.setMockMethodCallHandler(channel, null);
      });
    });
  });

  group('content: матовая карточка (карточка №4)', () {
    Widget card({
      Color? tint,
      bool enabled = true,
      bool nested = false,
      bool away = false,
      Ios27GlassShape shape = const Ios27GlassShape.rounded(26),
    }) =>
        Center(
          child: Ios27Glass(
            key: _glassKey,
            variant: Ios27GlassVariant.content,
            shape: shape,
            tint: tint,
            enabled: enabled,
            nested: nested,
            away: away,
            child: const SizedBox(width: 120, height: 60),
          ),
        );

    /// Кромка заглушки: сторона границы `ShapeDecoration`.
    BorderSide rim(WidgetTester tester) =>
        (_stub(tester).shape as OutlinedBorder).side;

    testWidgets('заглушка: непрозрачная заливка по теме, не палитра стекла',
        (tester) async {
      await _pump(tester, card());
      expect(_stub(tester).color, const Color(0xFFFFFFFF));
      expect(_stub(tester).color!.a, 1);

      _setBrightness(tester, Brightness.dark);
      await _pump(tester, card());
      expect(_stub(tester).color, const Color(0xFF1C1C1E));
      expect(_stub(tester).color!.a, 1);

      // Палитра стекла (#F2F2F2 / #2A2A2A) на матовую карточку не действует.
      await _pump(
        tester,
        Ios27GlassColors(
          brightness: Brightness.dark,
          dark: const Ios27GlassPalette(
            fill: Color(0xFF112233),
            disabledTintFill: Color(0x33445566),
            contrastRing: Color(0x80FFFFFF),
          ),
          child: card(),
        ),
      );
      expect(_stub(tester).color, const Color(0xFF1C1C1E));
    });

    testWidgets('заглушка: тон и enabled:false не окрашивают карточку',
        (tester) async {
      const accent = Color(0xFF29FF76);
      await _pump(tester, card(tint: accent));
      expect(_stub(tester).color, const Color(0xFFFFFFFF));

      await _pump(tester, card(tint: accent, enabled: false));
      expect(_stub(tester).color, const Color(0xFFFFFFFF));

      _setBrightness(tester, Brightness.dark);
      await _pump(tester, card(tint: accent));
      expect(_stub(tester).color, const Color(0xFF1C1C1E));
      expect(tester.hasRunningAnimations, isFalse,
          reason: 'заливка не анимируется');
    });

    testWidgets('заглушка: кромка 0.5 внутри формы и тень 0 1 3 доски',
        (tester) async {
      await _pump(tester, card());
      final light = _stub(tester);
      expect(rim(tester).width, 0.5);
      expect(
          rim(tester).color, const Color(0xA6FFFFFF)); // rgba(255,255,255,.65)
      expect(rim(tester).strokeAlign, BorderSide.strokeAlignInside);
      expect(light.shadows, hasLength(1));
      expect(light.shadows!.single.color, const Color(0x0F000000)); // .06
      expect(light.shadows!.single.offset, const Offset(0, 1));
      expect(light.shadows!.single.blurRadius, 3);
      // Без блика и боковых щелей других классов.
      expect(light.shadows!.single.spreadRadius, 0);

      _setBrightness(tester, Brightness.dark);
      await _pump(tester, card());
      expect(rim(tester).color, const Color(0x17FFFFFF)); // .09
      expect(
          _stub(tester).shadows!.single.color, const Color(0x61000000)); // .38
    });

    testWidgets(
        'заглушка: форма капсулой и прямоугольником, nested не действует',
        (tester) async {
      await _pump(tester, card(shape: const Ios27GlassShape.capsule()));
      expect(_stub(tester).shape, isA<StadiumBorder>());

      await _pump(tester, card(nested: true));
      final shape = _stub(tester).shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(26));
      expect(_stub(tester).color, const Color(0xFFFFFFFF));
    });

    testWidgets('заглушка + Increase Contrast: одно кольцо 1px',
        (tester) async {
      _setHighContrast(tester);
      await _pump(tester, card());
      final ring = _stub(tester).shadows!;
      expect(ring, hasLength(1));
      expect(ring.single.spreadRadius, 1);
      expect(ring.single.color, const Color(0x80000000));
      expect(_stub(tester).color, const Color(0xFFFFFFFF));
    });

    testWidgets('заглушка: away гасит заливку вместе с содержимым',
        (tester) async {
      await _pump(tester, card());
      await tester.pumpWidget(_app(card(away: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final fades = tester
          .widgetList<Ios27GlassAwayFade>(
            find.descendant(
              of: find.byType(Ios27Glass),
              matching: find.byType(Ios27GlassAwayFade),
            ),
          )
          .map((f) => f.opacity.value)
          .toList();
      // Фон заглушки и содержимое: оба погашены.
      expect(fades, [0, 0]);
    });

    testWidgets('нативно: variant content уходит в протокол, тон и уровень нет',
        (tester) async {
      await _withNative(tester, (created) async {
        const accent = Color(0xFF29FF76);
        // Тон и вложенность карточка не читает: в протокол они не попадают.
        await tester.pumpWidget(
          _app(
            Ios27GlassColors(
              level: 70,
              child: card(tint: accent, nested: true),
            ),
          ),
        );
        await tester.pump();
        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        final params = view.creationParams! as Map<String, Object?>;
        expect(params['variant'], 'content');
        expect(params['tint'], isNull);
        expect(params['level'], -1,
            reason: 'уровень «Стекло» карточку не трогает');
        expect(params['nested'], false);
        expect(params['interactive'], false);
        expect(params['material'], isNull);
        expect(params['enabled'], true);
        expect(params['shape'], 'rect');
        expect(params['radius'], 26.0);
        expect(params['dark'], isA<bool>());
      });
    });

    testWidgets(
        'нативно: ползунок «Стекло» и смена тона не шлют updateParams, away шлёт',
        (tester) async {
      await _withNative(tester, (created) async {
        const accent = Color(0xFF29FF76);
        await tester.pumpWidget(
          _app(Ios27GlassColors(level: 10, child: card())),
        );
        await tester.pump();
        final calls = <MethodCall>[];
        final channel = MethodChannel('dropweb/glass_${created.single}');
        _messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

        // Уровень и тон меняются, карточка про них не знает: ни одного сообщения.
        await tester.pumpWidget(
          _app(Ios27GlassColors(level: 90, child: card(tint: accent))),
        );
        await tester.pump();
        await tester.pumpWidget(
          _app(
            Ios27GlassColors(
                level: 40, child: card(tint: accent, enabled: false)),
          ),
        );
        await tester.pump();
        expect(calls, isEmpty);

        // Уход под лист карточке нужен так же, как стеклу: он единственный, что уходит.
        await tester.pumpWidget(
          _app(Ios27GlassColors(level: 40, child: card(away: true))),
        );
        await tester.pump();
        expect(calls, hasLength(1));
        final map = calls.single.arguments as Map<Object?, Object?>;
        expect(map['away'], true);
        expect(map['variant'], 'content');
        expect(map['level'], -1);

        _messenger.setMockMethodCallHandler(channel, null);
      });
    });

    testWidgets('нативно: контроль — у класса small уровень «Стекло» уходит',
        (tester) async {
      await _withNative(tester, (created) async {
        await tester.pumpWidget(
          _app(Ios27GlassColors(level: 10, child: _glass())),
        );
        await tester.pump();
        final calls = <MethodCall>[];
        final channel = MethodChannel('dropweb/glass_${created.single}');
        _messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        await tester.pumpWidget(
          _app(Ios27GlassColors(level: 90, child: _glass())),
        );
        await tester.pump();
        expect(calls, hasLength(1));
        expect((calls.single.arguments as Map<Object?, Object?>)['level'], 90);
        _messenger.setMockMethodCallHandler(channel, null);
      });
    });

    testWidgets('нативно: над UiKitView карточки нет прозрачных предков',
        (tester) async {
      await _withNative(tester, (created) async {
        await _pump(tester, card());
        await tester.pumpWidget(_app(card(away: true)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        for (final type in <Type>[
          Opacity,
          FadeTransition,
          AnimatedOpacity,
          Ios27GlassAwayFade,
        ]) {
          expect(
            find.ancestor(
              of: find.byType(UiKitView),
              matching: find.byType(type),
            ),
            findsNothing,
            reason: '$type над нативным видом',
          );
        }
      });
    });
  });

  group('Ios27GlassParams', () {
    test('toMap: ключи протокола dropweb/glass', () {
      const accent = Color(0xFF29FF76);
      const params = Ios27GlassParams(
        shape: Ios27GlassShape.rounded(26),
        dark: true,
        variant: Ios27GlassVariant.md,
        tint: accent,
        interactive: true,
        nested: true,
        enabled: false,
        material: Ios27GlassMaterial.thick,
      );
      expect(params.toMap(), <String, Object?>{
        'shape': 'rect',
        'radius': 26.0,
        'variant': 'md',
        'glass': 'regular',
        'tint': accent.toARGB32(),
        'tintAlpha': 0.50,
        'interactive': true,
        'nested': true,
        'enabled': false,
        'material': 'thick',
        'dark': true,
        // Уровень стекла «Оформления»: −1 — «как в системе» (W3).
        'level': -1,
        // Нижний ряд уходит под лист (W2b) и Reduce Motion для нативных переходов.
        'away': false,
        'reduceMotion': false,
      });
    });

    test('toMap: капсула без тона, плотность светлой темы', () {
      final map = const Ios27GlassParams(
        shape: Ios27GlassShape.capsule(),
        dark: false,
      ).toMap();
      expect(map['shape'], 'capsule');
      expect(map['radius'], 0.0);
      expect(map['tint'], isNull);
      expect(map['material'], isNull);
      expect(map['tintAlpha'], 0.96);
      expect(map['level'], -1);
    });

    test('toMap: away и reduceMotion берутся из параметров', () {
      final map = const Ios27GlassParams(
        shape: Ios27GlassShape.capsule(),
        dark: false,
        away: true,
        reduceMotion: true,
      ).toMap();
      expect(map['away'], true);
      expect(map['reduceMotion'], true);
    });

    test('away и reduceMotion входят в равенство', () {
      const base = Ios27GlassParams(
        shape: Ios27GlassShape.capsule(),
        dark: false,
      );
      const away = Ios27GlassParams(
        shape: Ios27GlassShape.capsule(),
        dark: false,
        away: true,
      );
      const reduced = Ios27GlassParams(
        shape: Ios27GlassShape.capsule(),
        dark: false,
        reduceMotion: true,
      );
      expect(base, isNot(away));
      expect(base, isNot(reduced));
      expect(base.hashCode, isNot(away.hashCode));
    });

    test('toMap: класс content уходит строкой content', () {
      final map = const Ios27GlassParams(
        shape: Ios27GlassShape.rounded(26),
        dark: false,
        variant: Ios27GlassVariant.content,
      ).toMap();
      expect(map['variant'], 'content');
      expect(Ios27GlassVariant.values.map((v) => v.name), contains('content'));
    });

    test('равенство по значению: основа решения «слать updateParams»', () {
      const a = Ios27GlassParams(
        shape: Ios27GlassShape.rounded(34),
        dark: false,
      );
      const b = Ios27GlassParams(
        shape: Ios27GlassShape.rounded(34),
        dark: false,
      );
      const c = Ios27GlassParams(
        shape: Ios27GlassShape.rounded(34),
        dark: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
