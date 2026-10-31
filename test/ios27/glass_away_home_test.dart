// Уход нижнего ряда главной под лист и зум листа из кнопки на НАТИВНОМ стекле (W2b, P4).
//
// Нативный `UIVisualEffectView` под полупрозрачным предком Flutter рисуется неправильно
// (вспышка плоских кругов), поэтому ни ряд, ни кнопка-источник зума, ни стекло самого слоя не
// имеют права гаснуть слоем над нативным видом: `away` уходит в стекло и дальше в платформенный
// вид, а значки гаснут рядом с ним.

import 'dart:async';

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/ui/ios27/layers/ios27_disclosure.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/glass_away_probe.dart';
import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';

/// Render-объект нативного вида: у `UiKitView` над ним стоят обёртки (фокус, семантика), и слой
/// композиции есть только у самого `RenderUiKitView`.
RenderUiKitView? _viewRender(Element view) {
  RenderUiKitView? found;
  void walk(Element e) {
    if (found != null) return;
    final ro = e is RenderObjectElement ? e.renderObject : null;
    if (ro is RenderUiKitView) {
      found = ro;
      return;
    }
    e.visitChildElements(walk);
  }

  walk(view);
  return found;
}

/// Что стоит над нативным видом [view] и рисует его неверно: виджеты прозрачности и слои
/// композиции. Пусто — вид лежит под чистыми предками.
///
/// Слои смотрим отдельно от виджетов: `pushOpacity` самописных render-объектов (кадр зума,
/// `Ios27GlassAwayFade`) виджетом не виден, а на устройстве портит вид так же, как `Opacity`.
List<String> _opacityAbove(Element view) {
  final found = <String>[];
  view.visitAncestorElements((a) {
    final w = a.widget;
    final name = w.runtimeType.toString();
    if (w is Opacity ||
        w is FadeTransition ||
        w is AnimatedOpacity ||
        w is Ios27GlassAwayFade ||
        name == '_SourceFade') {
      found.add(name);
    }
    return true;
  });
  Layer? layer = _viewRender(view)?.debugLayer;
  while (layer != null) {
    if (layer is OpacityLayer) found.add('OpacityLayer(${layer.alpha})');
    layer = layer.parent;
  }
  return found;
}

/// Вид стоит в дереве слоёв, а не выпал из него: иначе «чистые предки» ничего не доказывают.
bool _inLayerTree(WidgetTester tester, Element view) {
  final root = tester.binding.renderViews.first.debugLayer;
  Layer? layer = _viewRender(view)?.debugLayer;
  while (layer?.parent != null) {
    layer = layer!.parent;
  }
  return layer != null && identical(layer, root);
}

/// Стекло слоя — то `Ios27Glass`, что лежит прямо в слоте рамки зума; содержимое слоя (вложенное
/// стекло кнопок листа и алерта) лежит в другом слоте и сюда не входит.
bool _isLayerGlass(Element glass) {
  Element? parent;
  glass.visitAncestorElements((a) {
    parent = a;
    return false;
  });
  return parent?.widget is Ios27ZoomFrame;
}

/// Нативный вид принадлежит стеклу слоя, а не кнопке дока.
bool _isLayerGlassView(Element view) {
  Element? owner;
  view.visitAncestorElements((a) {
    if (a.widget is Ios27Glass) {
      owner = a;
      return false;
    }
    return true;
  });
  return owner != null && _isLayerGlass(owner!);
}

/// Нативные виды, которыми владеет зум: три кнопки дока и стекло самого слоя. Вложенное стекло
/// в содержимом слоя сюда не входит: оно живёт под прозрачностью кадра зума и описано в отчёте
/// отдельно.
List<Element> _zoomViews(WidgetTester tester) {
  final dock = find
      .descendant(
        of: find.byKey(const ValueKey<String>('dock')),
        matching: find.byType(UiKitView),
      )
      .evaluate();
  final layerGlass = find
      .descendant(
        of: find.byType(Ios27ZoomGlass),
        matching: find.byType(UiKitView),
      )
      .evaluate()
      .where(_isLayerGlassView);
  return [...dock, ...layerGlass];
}

/// Стекло самого слоя (без содержимого): его `away` убирает материал в конце втягивания.
Ios27Glass? _layerGlass(WidgetTester tester) {
  final all = find
      .descendant(
        of: find.byType(Ios27ZoomGlass),
        matching: find.byType(Ios27Glass),
      )
      .evaluate()
      .where(_isLayerGlass);
  return all.isEmpty ? null : all.first.widget as Ios27Glass;
}

/// Прозрачность источника зума у кнопки с ключом [key]: то, что гасит значок кнопки.
double _sourceFade(WidgetTester tester, String key) {
  final fades = tester
      .widgetList<Ios27GlassAwayFade>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(Ios27GlassAwayFade),
        ),
      )
      .toList();
  expect(fades, isNotEmpty, reason: 'у кнопки $key нет Ios27GlassAwayFade');
  final external = fades.first.external;
  expect(external, isNotNull, reason: 'кнопка $key не под источником зума');
  return external!.value;
}

/// Ожидаемая прозрачность источника в момент [elapsedMs] втягивания: возврат в последней
/// четверти (app.css:306-309, доли 0.747..1 по времени).
double _expectedSource(double elapsedMs) {
  final t = elapsedMs / (ios27ZoomCloseDuration.inMicroseconds / 1000);
  return ((t - 0.747) / 0.253).clamp(0.0, 1.0);
}

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  tearDown(() {
    Ios27A11y.debugReset();
    Ios27Glass.debugForceStub = false;
    Ios27Glass.debugAllowNativeInTests = false;
    debugDefaultTargetPlatformOverride = null;
  });

  Widget home({required bool away}) => ios27BoardApp(
        brightness: Brightness.light,
        // Нативная ветка живёт только без Reduce Transparency.
        reduceTransparency: false,
        child: ios27HomeFrame(
          input: homeInputFor('home-off'),
          glassAway: away,
        ),
      );

  /// Нативная ветка: платформа iOS, разрешение внутри `flutter test`, мок канала видов.
  /// Дерево снимается до сброса мока: `dispose` вида тоже ходит в этот канал.
  Future<void> withNative(
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

  Finder dockViews() => find.descendant(
        of: find.byKey(const ValueKey<String>('dock')),
        matching: find.byType(UiKitView),
      );

  void expectNoFadeAbove(WidgetTester tester, Finder views) {
    expect(views, findsWidgets);
    for (final type in <Type>[
      Opacity,
      FadeTransition,
      AnimatedOpacity,
      Ios27GlassAwayFade,
    ]) {
      expect(
        find.ancestor(of: views, matching: find.byType(type)),
        findsNothing,
        reason: '$type над нативным видом',
      );
    }
  }

  testWidgets('три кнопки ряда — нативные виды, над ними нет прозрачности',
      (tester) async {
    await withNative(tester, (created) async {
      await pumpIos27Board(tester, home(away: false));
      expect(dockViews(), findsNWidgets(3));
      expectNoFadeAbove(tester, dockViews());
    });
  });

  testWidgets('уход: away доходит до каждого вида, слоя над видами нет',
      (tester) async {
    await withNative(tester, (created) async {
      await pumpIos27Board(tester, home(away: false));
      final ids = created.toList();
      expect(ids.length, greaterThanOrEqualTo(3));

      final calls = <MethodCall>[];
      for (final id in ids) {
        _messenger.setMockMethodCallHandler(
          MethodChannel('dropweb/glass_$id'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }

      await tester.pumpWidget(home(away: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Идёт анимация ухода: значки гаснут, а над видами по-прежнему ничего нет.
      expect(dockGlassFade(tester), inExclusiveRange(0.0, 1.0));
      expectNoFadeAbove(tester, dockViews());

      final away = calls
          .where((c) => (c.arguments as Map<Object?, Object?>)['away'] == true)
          .length;
      expect(
        away,
        3,
        reason: 'ровно три кнопки ряда получили away; шестерёнка не уходит',
      );
      expect(created, hasLength(ids.length), reason: 'виды не пересоздаются');

      await tester.pump(const Duration(milliseconds: 300));
      expect(dockGlassFade(tester), 0);

      // Возврат: те же три вида получают away=false, значки возвращаются с задержкой.
      calls.clear();
      await tester.pumpWidget(home(away: false));
      await tester.pump();
      final back = calls
          .where((c) => (c.arguments as Map<Object?, Object?>)['away'] == false)
          .length;
      expect(back, 3);
      await tester.pump(const Duration(milliseconds: 100));
      expect(dockGlassFade(tester), 0, reason: 'первые 150 мс возврат стоит');
      await tester.pump(const Duration(milliseconds: 600));
      expect(dockGlassFade(tester), 1);

      for (final id in ids) {
        _messenger.setMockMethodCallHandler(
          MethodChannel('dropweb/glass_$id'),
          null,
        );
      }
    });
  });
  group('зум из кнопки: над нативными видами нет прозрачности', () {
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

    /// Прогоняет открытие и закрытие слоя кадр за кадром (шаг 16 мс) и проверяет на каждом:
    /// над нативными видами кнопок и стекла слоя нет прозрачности; значок источника скрыт всё
    /// открытие и возвращается ровно по времени доли 0.747..1 втягивания; стекло слоя убирается
    /// своим `away`, а не слоем.
    Future<void> runZoom(
      WidgetTester tester, {
      required String sourceKey,
      required Future<Object?> Function(BuildContext root) open,
      required Future<void> Function() close,
    }) async {
      await withNative(tester, (created) async {
        final away = ValueNotifier<bool>(false);
        addTearDown(away.dispose);
        await pumpIos27Board(tester, zoomHome(away));
        final problems = <String>[];
        var maxViews = 0;
        void check(String when, {bool firstFrame = false}) {
          final views = _zoomViews(tester);
          maxViews = views.length > maxViews ? views.length : maxViews;
          expect(views.length, inInclusiveRange(3, 4), reason: when);
          for (final v in views) {
            final above = _opacityAbove(v);
            if (above.isNotEmpty) {
              problems.add('$when: $above над ${v.widget.key ?? 'UiKitView'}');
            }
            // Вид слоя в самом первом кадре ещё не нарисован: слоя композиции у него нет.
            final isDock = !_isLayerGlassView(v);
            if (!_inLayerTree(tester, v) && (!firstFrame || isDock)) {
              problems.add('$when: нативный вид выпал из дерева слоёв');
            }
          }
          // Падаем на первом же кадре с прозрачностью: так в сообщении видно, где и над чем.
          expect(problems, isEmpty, reason: problems.join('\n'));
        }

        check('до открытия');
        expect(_sourceFade(tester, sourceKey), 1);

        final root = tester.element(find.byType(Navigator).first);
        final opened = open(root);
        unawaited(opened);
        away.value = true;
        await tester.pump();

        // Открытие: значок источника скрыт с первого кадра, стекло слоя на месте.
        for (var t = 0; t <= 800; t += 16) {
          check('открытие +$t мс', firstFrame: t == 0);
          expect(_sourceFade(tester, sourceKey), 0, reason: 'открытие +$t мс');
          expect(_layerGlass(tester)?.away, isFalse, reason: 'открытие +$t мс');
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 1000));
        check('покой');

        // Закрытие: главная возвращает ряд, слой втягивается.
        away.value = false;
        await close();
        await tester.pump();
        var previous = 0.0;
        final layerAway = <bool>[];
        for (var t = 0; t <= 640; t += 16) {
          check('закрытие +$t мс');
          final source = _sourceFade(tester, sourceKey);
          expect(
            source,
            closeTo(_expectedSource(t.toDouble()), 0.02),
            reason: 'закрытие +$t мс: значок следует таймлайну источника',
          );
          expect(source, greaterThanOrEqualTo(previous),
              reason: 'закрытие +$t мс');
          previous = source;
          final glass = _layerGlass(tester);
          if (glass != null) layerAway.add(glass.away);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await opened;

        expect(maxViews, 4, reason: 'проверены и три кнопки, и стекло слоя');
        // Стекло слоя уходит один раз и не возвращается; в начале втягивания оно на месте.
        expect(layerAway.first, isFalse);
        expect(layerAway.last, isTrue,
            reason: 'в конце втягивания материал убран');
        expect(layerAway.where((a) => a).length, greaterThan(3));
        final firstAway = layerAway.indexOf(true);
        expect(layerAway.sublist(firstAway).every((a) => a), isTrue);
        expect(_sourceFade(tester, sourceKey), 1);
      });
    }

    testWidgets('лист из глобуса: от первого кадра до конца втягивания',
        (tester) async {
      await runZoom(
        tester,
        sourceKey: 'dock-route',
        open: (root) => showIos27Sheet<void>(
          root,
          title: 'Маршрут',
          origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
          builder: (_) => const SizedBox.expand(),
        ),
        close: () async => Navigator.of(
          tester.element(find.byType(Navigator).first),
        ).pop(),
      );
    });

    testWidgets('алерт из кнопки питания: от первого кадра до конца втягивания',
        (tester) async {
      await runZoom(
        tester,
        sourceKey: 'power',
        open: showIos27VpnDisclosure,
        close: () => tester.tap(find.text('Отмена')),
      );
    });
  });
}
