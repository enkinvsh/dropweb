// ПРОБА ПРОЛАГОВ (отчёт .omo/ios/g6/lag/report.md): что работает на каждом кадре, пока лист
// «Подписка» или «Маршрут» вырастает из кнопки дока.
//
// Метод. Главная с настоящей навигацией дока (`openIos27HomeSubscriptions` / `openIos27HomeRoute`),
// нативное стекло включено (`debugAllowNativeInTests` + подменённые каналы `flutter/platform_views`
// и `dropweb/glass_<id>`, как в `zoom_glass_params_test.dart`). Кадры шагом 16 мс: на каждом считаем
//   - перестроенные элементы по типам (`debugOnRebuildDirtyWidget`),
//   - вызовы `paintChild` по типам (`debugOnProfilePaint`),
//   - живые нативные виды и сообщения `updateParams`.
// FakeAsync не меряет стоимость кадра, только объём работы; фон идёт CPU-путём, поэтому его кадры
// от нажатия по кнопке считаются по модели `Ios27BackdropMotion` отдельным тестом.
//
// Как гейт закреплено то, что исправлено в этой волне (см. отчёт):
//  - содержимое листа не перерисовывается целиком на каждом кадре зума (граница перерисовки в
//    `Ios27ZoomGlass`): до правки 1665/1602 вызовов `paintChild` за 0–600 мс, после ~1060/~995;
//  - радиус стекла слоя уходит в нативный вид с шагом полпикселя: `updateParams` 25 → 16 за
//    открытие, а в покое радиус ровно конечный;
//  - после оседания листа кадров нет.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_nav.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Tokens;
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';
import 'support/screen_route_fixtures.dart';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Перехват нативных видов стекла: сколько живо и сколько `updateParams` пришло.
class _Native {
  final Set<int> live = <int>{};
  int created = 0;
  int updates = 0;
  final Map<int, double> lastRadius = <int, double>{};

  void install() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    Ios27Glass.debugAllowNativeInTests = true;
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      final args = call.arguments;
      if (call.method == 'create' && args is Map) {
        final id = args['id']! as int;
        live.add(id);
        created++;
        _messenger.setMockMethodCallHandler(MethodChannel('dropweb/glass_$id'),
            (c) async {
          if (c.method == 'updateParams') {
            updates++;
            final m = c.arguments;
            if (m is Map && m['radius'] is num) {
              lastRadius[id] = (m['radius'] as num).toDouble();
            }
          }
          return null;
        });
      } else if (call.method == 'dispose' && args is Map) {
        live.remove(args['id']);
      } else if (call.method == 'dispose' && args is int) {
        live.remove(args);
      }
      return null;
    });
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    Ios27Glass.debugAllowNativeInTests = false;
    debugDefaultTargetPlatformOverride = null;
    Ios27A11y.debugReset();
  }
}

/// Итог одного кадра зума.
class _Frame {
  _Frame(this.t, this.rebuilds, this.paints, this.views, this.updates);

  final int t;
  final Map<String, int> rebuilds;
  final Map<String, int> paints;
  final int views;
  final int updates;

  int get rebuildTotal => rebuilds.values.fold(0, (a, b) => a + b);
  int get paintTotal => paints.values.fold(0, (a, b) => a + b);
}

final Map<String, int> _cur = <String, int>{};
final Map<String, int> _paintCur = <String, int>{};

/// Шагает кадрами по 16 мс до [untilMs] и записывает работу каждого.
Future<List<_Frame>> _record(
  WidgetTester tester,
  _Native native, {
  required int untilMs,
}) async {
  final out = <_Frame>[];
  debugOnRebuildDirtyWidget = (e, _) {
    final k = e.widget.runtimeType.toString();
    _cur[k] = (_cur[k] ?? 0) + 1;
  };
  debugOnProfilePaint = (r) {
    final k = r.runtimeType.toString();
    _paintCur[k] = (_paintCur[k] ?? 0) + 1;
  };
  try {
    for (var t = 16; t <= untilMs; t += 16) {
      _cur.clear();
      _paintCur.clear();
      final before = native.updates;
      await tester.pump(const Duration(milliseconds: 16));
      out.add(_Frame(
        t,
        Map<String, int>.of(_cur),
        Map<String, int>.of(_paintCur),
        native.live.length,
        native.updates - before,
      ));
    }
  } finally {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
  }
  return out;
}

Map<String, int> _sum(Iterable<Map<String, int>> maps) {
  final r = <String, int>{};
  for (final m in maps) {
    m.forEach((k, v) => r[k] = (r[k] ?? 0) + v);
  }
  return r;
}

String _top(Map<String, int> m, [int n = 8]) {
  final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return e.take(n).map((x) => '${x.key}=${x.value}').join(', ');
}

void _print(String name, List<_Frame> frames) {
  final open = frames.where((f) => f.t <= 600).toList();
  final settle = frames.where((f) => f.t > 1000).toList();
  final openRebuild = _sum(open.map((f) => f.rebuilds));
  final openPaint = _sum(open.map((f) => f.paints));
  // ignore: avoid_print
  print('LAG | $name | кадров 0–600 мс: ${open.length}, '
      'перестроек всего ${open.fold(0, (a, f) => a + f.rebuildTotal)} '
      '(на кадр ${(open.fold(0, (a, f) => a + f.rebuildTotal) / open.length).toStringAsFixed(1)}), '
      'paintChild всего ${open.fold(0, (a, f) => a + f.paintTotal)} '
      '(на кадр ${(open.fold(0, (a, f) => a + f.paintTotal) / open.length).toStringAsFixed(1)}), '
      'updateParams ${open.fold(0, (a, f) => a + f.updates)}, '
      'живых видов min/max ${open.map((f) => f.views).reduce((a, b) => a < b ? a : b)}/'
      '${open.map((f) => f.views).reduce((a, b) => a > b ? a : b)}');
  // ignore: avoid_print
  print('LAG | $name | топ перестроек 0–600: ${_top(openRebuild)}');
  // ignore: avoid_print
  print('LAG | $name | топ paintChild 0–600: ${_top(openPaint)}');
  // ignore: avoid_print
  print('LAG | $name | покой 1000+ мс: кадров с работой '
      '${settle.where((f) => f.rebuildTotal + f.paintTotal > 0).length} из ${settle.length}');
  for (final t in const [16, 32, 80, 208]) {
    final f = frames.firstWhere((f) => f.t == t, orElse: () => frames.first);
    // ignore: avoid_print
    print('LAG | $name | кадр $t мс: перестройки {${_top(f.rebuilds, 14)}}');
    // ignore: avoid_print
    print('LAG | $name | кадр $t мс: paintChild {${_top(f.paints, 14)}}');
  }
  // ignore: avoid_print
  print('LAG | $name | по кадрам (t: перестроек/paint/updateParams): '
      '${open.take(24).map((f) => '${f.t}:${f.rebuildTotal}/${f.paintTotal}/${f.updates}').join(' ')}');
}

/// Логотип декодируется один раз на файл: декодер живёт только в реальном `runAsync`.
class _Logo {
  ui.Image? image;
  MemoryImage? provider;
}

final _Logo _logo = _Logo();

Future<void> _prepareLogo(WidgetTester tester) async {
  if (_logo.image == null) {
    final bytes =
        File('test/ios27/fixtures/screen_sub_logo.png').readAsBytesSync();
    _logo.provider = MemoryImage(bytes);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      _logo.image = (await codec.getNextFrame()).image;
    });
  }
  PaintingBinding.instance.imageCache.putIfAbsent(
    _logo.provider!,
    () => OneFrameImageStreamCompleter(
      Future.value(ImageInfo(image: _logo.image!.clone())),
    ),
  );
}

List<Override> _subOverrides() => [
      m3eSubModelProvider.overrideWithValue(
        const M3eSubModel(
          profiles: [
            M3eSubProfile(
              id: 'p0',
              name: 'DROPWEB',
              host: 'cfgpull.com',
              logoUrl: 'mock/logo.png',
              initials: 'db',
            ),
            M3eSubProfile(id: 'p1', name: 'Дом', host: 'panel.home-vpn.ru'),
          ],
          currentId: 'p0',
          supportUrl: 'https://cfgpull.com/help',
        ),
      ),
      m3eSubClockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 12)),
      m3eSubLogoProvider.overrideWith(
        (ref, url) async =>
            url == 'mock/logo.png' ? M3eSubLogo.raster(_logo.provider!) : null,
      ),
    ];

Widget _app(List<Override> overrides, {String scene = 'home-off'}) =>
    ios27BoardApp(
      brightness: Brightness.light,
      reduceTransparency: false,
      overrides: overrides,
      child: Builder(
        builder: (context) => ios27HomeFrame(
          input: homeInputFor(scene),
          onSubscriptions: () => openIos27HomeSubscriptions(context),
          onRoute: () => openIos27HomeRoute(context),
        ),
      ),
    );

void main() {
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
    Ios27A11y.debugReset();
    Ios27Glass.debugAllowNativeInTests = false;
    debugDefaultTargetPlatformOverride = null;
  });

  group('открытие листа из дока: работа на кадр', () {
    for (final sheet in const ['route', 'sub']) {
      testWidgets('«$sheet»: перестройки, paint, виды, updateParams',
          (tester) async {
        final native = _Native()..install();
        try {
          await _prepareLogo(tester);
          final calls = RouteCalls();
          final overrides = sheet == 'route'
              ? routeOverrides(kIos27BoardNormal, calls)
              : [...layerOverrides(), ..._subOverrides()];
          await pumpIos27Board(tester, _app(overrides));
          // Спокойное состояние главной до касания: сколько видов и кадров.
          final home = native.live.length;
          // ignore: avoid_print
          print('LAG | $sheet | живых видов на главной до открытия: $home');

          final button = find.byKey(sheet == 'route'
              ? Ios27HomeKeys.dockRoute
              : Ios27HomeKeys.dockSub);
          await tester.tap(button);
          final frames = await _record(tester, native, untilMs: 1600);
          _print(sheet, frames);
          final open = frames.where((f) => f.t <= 600).toList();
          final paints = open.fold(0, (a, f) => a + f.paintTotal);
          final updates = open.fold(0, (a, f) => a + f.updates);
          // До правки: paintChild 1665 (route) / 1602 (sub), updateParams 25.
          expect(paints, lessThan(1300),
              reason: 'содержимое листа перерисовывается на каждом кадре зума');
          expect(updates, lessThanOrEqualTo(20),
              reason: 'радиус стекла шлётся в нативный вид каждый кадр');
          expect(
            frames
                .where((f) => f.t > 1000)
                .every((f) => f.rebuildTotal + f.paintTotal == 0),
            isTrue,
            reason: 'после оседания листа кадров быть не должно',
          );
          expect(native.lastRadius.values, contains(Ios27Tokens.rAlert),
              reason: 'в покое стекло слоя несёт ровно конечный радиус');
          // ignore: avoid_print
          print(
              'LAG | $sheet | живых видов после открытия: ${native.live.length}');
          final root = tester.element(find.byType(Navigator).first);
          Navigator.of(root, rootNavigator: true).pop();
          await tester.pump(const Duration(milliseconds: 1200));
        } finally {
          await tester.pumpWidget(const SizedBox());
          native.uninstall();
        }
      });
    }
  });

  group('касание по кнопке дока и фон', () {
    test('сколько кадров фон крутит после нажатия (модель bg.js)', () {
      // Нажатие: e = max(e, 0.55) (bg.js:207); отпускание через ~100 мс; затем затухание.
      final m = Ios27BackdropMotion()
        ..pointerDown(.5, .1, 0)
        ..pointerUp();
      var frames = 0;
      while (frames < 600 && m.step(1 / 60)) {
        frames++;
      }
      frames++;
      // ignore: avoid_print
      print('LAG | фон после касания по кнопке: кадров до покоя $frames '
          '(${(frames / 60).toStringAsFixed(2)} с при 60 Гц)');
      expect(frames, lessThan(600));
    });
  });
}
