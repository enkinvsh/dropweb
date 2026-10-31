// Поток сообщений `updateParams` в нативное стекло (G9, MAJOR-1).
//
// Радиус стекла слоя зума меняется каждый кадр. Пока стекло «ушло», форму никто не видит, поэтому
// после `away == true` Dart не шлёт сообщения, отличающиеся только формой; Swift и сам не трогает
// переход при смене одной формы (`surfaceDiffers`), так что запрет — вторая линия защиты. В
// `flutter test` без шва `debugAllowNativeInTests`
// вместо `UiKitView` рисуется заглушка, и поток сообщений не виден: здесь шов включён, а каналы
// `flutter/platform_views` и `dropweb/glass_<id>` подменены.
import 'dart:async';

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Один нативный вид, как его видит Dart: параметры создания и все `updateParams`.
class _View {
  _View(this.id, this.created);

  final int id;
  final Map<Object?, Object?> created;
  final List<Map<Object?, Object?>> updates = <Map<Object?, Object?>>[];

  double radius(Map<Object?, Object?> m) => (m['radius']! as num).toDouble();
}

/// Перехват каналов нативного стекла. Дерево снимается до сброса моков: `dispose` вида тоже
/// ходит в канал `flutter/platform_views`.
class _Native {
  final Map<int, _View> views = <int, _View>{};

  void install() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    Ios27Glass.debugAllowNativeInTests = true;
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map<Object?, Object?>;
        final id = args['id']! as int;
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(args['params']! as Uint8List),
        ) as Map<Object?, Object?>;
        final view = _View(id, params);
        views[id] = view;
        _messenger.setMockMethodCallHandler(MethodChannel('dropweb/glass_$id'),
            (c) async {
          if (c.method == 'updateParams') {
            view.updates.add(c.arguments as Map<Object?, Object?>);
          }
          return null;
        });
      }
      return null;
    });
  }

  void uninstall() {
    for (final id in views.keys) {
      _messenger.setMockMethodCallHandler(
          MethodChannel('dropweb/glass_$id'), null);
    }
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    Ios27Glass.debugAllowNativeInTests = false;
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _withNative(
  WidgetTester tester,
  Future<void> Function(_Native native) body,
) async {
  final native = _Native()..install();
  try {
    await body(native);
    await tester.pumpWidget(const SizedBox());
  } finally {
    native.uninstall();
  }
}

void main() {
  tearDown(() {
    Ios27A11y.debugReset();
    Ios27Glass.debugForceStub = false;
    Ios27Glass.debugAllowNativeInTests = false;
    debugDefaultTargetPlatformOverride = null;
  });

  group('Ios27GlassParams.sameExceptShape', () {
    const base = Ios27GlassParams(
      shape: Ios27GlassShape.rounded(24),
      dark: false,
      variant: Ios27GlassVariant.md,
    );

    test('форма не считается отличием, всё остальное считается', () {
      expect(
        base.sameExceptShape(
          const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(34),
            dark: false,
            variant: Ios27GlassVariant.md,
          ),
        ),
        isTrue,
      );
      expect(base == base, isTrue);

      final others = <Ios27GlassParams>[
        const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(24),
            dark: true,
            variant: Ios27GlassVariant.md),
        const Ios27GlassParams(shape: Ios27GlassShape.rounded(24), dark: false),
        const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(24),
            dark: false,
            variant: Ios27GlassVariant.md,
            away: true),
        const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(24),
            dark: false,
            variant: Ios27GlassVariant.md,
            level: 40),
        const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(24),
            dark: false,
            variant: Ios27GlassVariant.md,
            tint: Color(0xFF29FF76)),
        const Ios27GlassParams(
            shape: Ios27GlassShape.rounded(24),
            dark: false,
            variant: Ios27GlassVariant.md,
            reduceMotion: true),
      ];
      for (final other in others) {
        expect(base.sameExceptShape(other), isFalse, reason: '$other');
      }
    });

    test('== сравнивает и форму, и остальное', () {
      const shapeOnly = Ios27GlassParams(
        shape: Ios27GlassShape.rounded(34),
        dark: false,
        variant: Ios27GlassVariant.md,
      );
      expect(base == shapeOnly, isFalse);
      expect(
        base ==
            const Ios27GlassParams(
              shape: Ios27GlassShape.rounded(24),
              dark: false,
              variant: Ios27GlassVariant.md,
            ),
        isTrue,
      );
    });
  });

  group('смена формы нативного стекла', () {
    Widget app(ValueNotifier<({bool away, double radius})> state) =>
        ios27BoardApp(
          brightness: Brightness.light,
          reduceTransparency: false,
          child: Center(
            child: SizedBox(
              width: 120,
              height: 80,
              child: ValueListenableBuilder<({bool away, double radius})>(
                valueListenable: state,
                builder: (_, v, __) => Ios27Glass(
                  variant: Ios27GlassVariant.md,
                  shape: Ios27GlassShape.rounded(v.radius),
                  away: v.away,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );

    testWidgets('видимое стекло получает форму каждый кадр', (tester) async {
      await _withNative(tester, (native) async {
        final state = ValueNotifier((away: false, radius: 20.0));
        addTearDown(state.dispose);
        await pumpIos27Board(tester, app(state));
        final view = native.views.values.single;
        for (var i = 1; i <= 10; i++) {
          state.value = (away: false, radius: 20.0 + i);
          await tester.pump();
        }
        expect(view.updates, hasLength(10));
        expect(view.updates.map(view.radius), <double>[
          for (var i = 1; i <= 10; i++) 20.0 + i,
        ]);
        expect(view.updates.every((m) => m['away'] == false), isTrue);
      });
    });

    testWidgets('ушедшее стекло форму не шлёт, возврат уходит с актуальной',
        (tester) async {
      await _withNative(tester, (native) async {
        final state = ValueNotifier((away: false, radius: 20.0));
        addTearDown(state.dispose);
        await pumpIos27Board(tester, app(state));
        final view = native.views.values.single;

        state.value = (away: true, radius: 22.0);
        await tester.pump();
        expect(view.updates, hasLength(1));
        expect(view.updates.single['away'], true);
        expect(view.radius(view.updates.single), 22.0);

        // Пока стекло ушло, радиус может меняться сколько угодно: сообщений нет.
        for (var i = 1; i <= 8; i++) {
          state.value = (away: true, radius: 22.0 + i);
          await tester.pump();
        }
        expect(view.updates, hasLength(1));

        // Возврат несёт актуальную форму: нативный вид не остаётся со старым радиусом.
        state.value = (away: false, radius: 40.0);
        await tester.pump();
        expect(view.updates, hasLength(2));
        expect(view.updates.last['away'], false);
        expect(view.radius(view.updates.last), 40.0);

        // И снова ушёл: первое сообщение «ушло» идёт всегда.
        state.value = (away: true, radius: 41.0);
        await tester.pump();
        expect(view.updates, hasLength(3));
        expect(view.updates.last['away'], true);
      });
    });
  });

  group('зум из глобуса: стекло слоя', () {
    // Главная с живым флагом ухода, как в приложении: любой маршрут над ней уводит ряд.
    Widget zoomHome(ValueNotifier<bool> away) => ios27BoardApp(
          brightness: Brightness.light,
          reduceTransparency: false,
          overrides: layerOverrides(),
          child: ValueListenableBuilder<bool>(
            valueListenable: away,
            builder: (_, v, __) => ios27HomeFrame(
              input: homeInputFor('home-off'),
              glassAway: v,
            ),
          ),
        );

    testWidgets(
        'открытие и закрытие: после первого away=true updateParams не идут',
        (tester) async {
      await _withNative(tester, (native) async {
        final away = ValueNotifier<bool>(false);
        addTearDown(away.dispose);
        await pumpIos27Board(tester, zoomHome(away));

        final root = tester.element(find.byType(Navigator).first);
        final opened = showIos27Sheet<void>(
          root,
          title: 'Маршрут',
          origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
          builder: (_) => const SizedBox.expand(),
        );
        unawaited(opened);
        away.value = true;
        await tester.pump();
        for (var t = 0; t <= 800; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 1000));

        // Стекло слоя — единственный нативный вид класса md без вложенности: кнопки дока
        // малые, кнопки внутри листа вложенные.
        final layer = native.views.values
            .where((v) =>
                v.created['variant'] == 'md' && v.created['nested'] == false)
            .toList();
        expect(layer, hasLength(1), reason: 'стекло слоя создано один раз');
        final view = layer.single;
        final openingUpdates = view.updates.length;

        away.value = false;
        Navigator.of(tester.element(find.byType(Navigator).first)).pop();
        await tester.pump();
        for (var t = 0; t <= 640; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await opened;

        // Открытие: форма морфится каждый кадр, сообщения идут.
        expect(openingUpdates, greaterThan(10));
        final openRadii =
            view.updates.take(openingUpdates).map(view.radius).toSet();
        expect(openRadii.length, greaterThan(5),
            reason: 'радиус видимого стекла доходит до нативного вида');

        // Закрытие: до ухода радиус идёт, потом первый away=true и тишина.
        final closing = view.updates.sublist(openingUpdates);
        final firstAway = closing.indexWhere((m) => m['away'] == true);
        expect(firstAway, isNonNegative,
            reason: 'в конце втягивания материал убран (away=true)');
        expect(firstAway, greaterThan(0),
            reason: 'до ухода форма морфится: сообщения идут');
        final after = closing.sublist(firstAway + 1);
        expect(
          after,
          isEmpty,
          reason: 'после away=true ушло ещё ${after.length} updateParams '
              '(радиусы ${after.map(view.radius).map((r) => r.toStringAsFixed(2)).join(', ')}): '
              'нативный вид обрывал бы уход на каждом',
        );
      });
    });
  });
}
