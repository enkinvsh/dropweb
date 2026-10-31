// Значки доски (карта `P` в canon/dropweb/app.js:30-58, коммит df156ea1): все 26 разбираются
// flutter_svg, виджет `Ios27Icon` рисует непустую картинку нужного цвета и размера.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Рисует [icon] в [RepaintBoundary] и возвращает пиксели RGBA.
///
/// flutter_svg разбирает разметку асинхронно и вне фейковых часов теста, поэтому ждём в `runAsync`.
Future<({Uint8List rgba, int width, int height})> _render(
  WidgetTester tester,
  Widget icon, {
  double logical = 64,
  double pixelRatio = 4,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
              width: logical, height: logical, child: Center(child: icon)),
        ),
      ),
    ),
  );
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  late ui.Image image;
  late ByteData data;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    image = await boundary.toImage(pixelRatio: pixelRatio);
    data =
        (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  });
  return (
    rgba: data.buffer.asUint8List(),
    width: image.width,
    height: image.height,
  );
}

int _painted(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n;
}

void main() {
  group('карта значков', () {
    test('26 значков, у каждого есть тело', () {
      expect(Ios27IconName.values, hasLength(26));
      expect(kIos27IconBody.keys.toSet(), Ios27IconName.values.toSet());
      for (final name in Ios27IconName.values) {
        expect(kIos27IconBody[name], isNotEmpty, reason: name.name);
      }
    });

    test('имена как на доске (без wifi-off в дефисе)', () {
      expect(
        Ios27IconName.values.map((n) => n.name),
        [
          'power',
          'settings',
          'right',
          'left',
          'more',
          'check',
          'x',
          'plus',
          'refresh',
          'chat',
          'trash',
          'clipboard',
          'link',
          'qr',
          'globe',
          'layers',
          'info',
          'out',
          'clock',
          'alert',
          'zap',
          'stack',
          'wifiOff',
          'camera',
          'shield',
          'droplet',
        ],
      );
    });

    test('разметка: сетка 24, контур без заливки, закруглённые концы', () {
      final svg = ios27IconSvg(Ios27IconName.power, strokeWidth: 2.1);
      expect(svg, contains('viewBox="0 0 24 24"'));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('stroke-width="2.1"'));
      expect(svg, contains('stroke-linecap="round"'));
      expect(svg, contains('stroke-linejoin="round"'));
    });

    test('размеры и толщина по контекстам доски (app.css)', () {
      expect(
          (Ios27IconSpecs.standard.size, Ios27IconSpecs.standard.strokeWidth),
          (22.0, 2.0));
      expect((Ios27IconSpecs.power.size, Ios27IconSpecs.power.strokeWidth),
          (32.0, 2.1));
      expect((
        Ios27IconSpecs.sheetButton.size,
        Ios27IconSpecs.sheetButton.strokeWidth
      ), (
        18.0,
        2.4
      ));
      expect((Ios27IconSpecs.check.size, Ios27IconSpecs.check.strokeWidth),
          (20.0, 2.5));
      expect((Ios27IconSpecs.empty.size, Ios27IconSpecs.empty.strokeWidth),
          (56.0, 1.75));
      expect(Ios27IconSpecs.row.size, 18);
      expect(Ios27IconSpecs.button.size, 20);
      expect(Ios27IconSpecs.fieldError.size, 16);
    });
  });

  group('рисование', () {
    for (final name in Ios27IconName.values) {
      testWidgets('${name.name}: разбирается и рисует непустую картинку',
          (tester) async {
        final r = await _render(
          tester,
          Ios27Icon(name, size: 24, color: const Color(0xFFFF0000)),
        );
        final painted = _painted(r.rgba);
        expect(painted, greaterThan(40), reason: 'значок ${name.name} пуст');
        // Все закрашенные пиксели красные: цвет задаётся одним фильтром srcIn.
        for (var i = 0; i < r.rgba.length; i += 4) {
          if (r.rgba[i + 3] == 0) continue;
          expect(r.rgba[i], 255, reason: '${name.name}: красный канал');
          expect(r.rgba[i + 1], 0, reason: '${name.name}: зелёный канал');
          expect(r.rgba[i + 2], 0, reason: '${name.name}: синий канал');
        }
      });
    }

    testWidgets('размер: значок не выходит за свой квадрат', (tester) async {
      // Квадрат 64 pt, значок 22 pt по центру при pixelRatio 4: по краям 21 pt (84 px) пустоты.
      final r = await _render(tester,
          const Ios27Icon(Ios27IconName.check, color: Color(0xFF000000)));
      final w = r.width;
      for (var y = 0; y < r.height; y++) {
        for (var x = 0; x < w; x++) {
          final inside = x >= 84 && x < w - 84 && y >= 84 && y < r.height - 84;
          if (inside) continue;
          expect(r.rgba[(y * w + x) * 4 + 3], 0,
              reason: 'пиксель ($x,$y) вне квадрата значка');
        }
      }
    });

    testWidgets('толще линия — больше закрашенных пикселей', (tester) async {
      const color = Color(0xFF000000);
      final thin = await _render(
        tester,
        const Ios27Icon(Ios27IconName.power,
            size: 32, strokeWidth: 1.5, color: color),
      );
      final thick = await _render(
        tester,
        const Ios27Icon(Ios27IconName.power,
            size: 32, strokeWidth: 3, color: color),
      );
      expect(_painted(thick.rgba), greaterThan(_painted(thin.rgba)));
    });

    testWidgets('Ios27Icon.spec берёт размер и толщину из спецификации',
        (tester) async {
      final viaSpec = await _render(
        tester,
        Ios27Icon.spec(Ios27IconName.power, Ios27IconSpecs.power,
            color: const Color(0xFF000000)),
      );
      final direct = await _render(
        tester,
        const Ios27Icon(Ios27IconName.power,
            size: 32, strokeWidth: 2.1, color: Color(0xFF000000)),
      );
      expect(viaSpec.rgba, direct.rgba);
    });

    testWidgets('без цвета берёт IconTheme', (tester) async {
      final r = await _render(
        tester,
        const IconTheme(
          data: IconThemeData(color: Color(0xFF00FF00)),
          child: Ios27Icon(Ios27IconName.check),
        ),
      );
      var seen = false;
      for (var i = 0; i < r.rgba.length; i += 4) {
        if (r.rgba[i + 3] == 0) continue;
        seen = true;
        expect(r.rgba[i + 1], 255);
        expect(r.rgba[i], 0);
      }
      expect(seen, isTrue);
    });
  });

  group('запрет чужих наборов значков', () {
    test('в значках и токенах нет Icons.* и CupertinoIcons', () {
      // Чужие файлы lib/ui/ios27 (стекло, доступность) не проверяем: у них свои тесты.
      final files = <File>[
        File('lib/ui/ios27/icons.g.dart'),
        ...Directory('lib/ui/ios27/theme')
            .listSync(recursive: true)
            .whereType<File>(),
      ];
      final offenders = <String>[];
      for (final f in files) {
        if (!f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        // Игнорируем комментарии: в них имена набора могут упоминаться как запрет.
        final code = text
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (RegExp(r'\bIcons\.|CupertinoIcons\b').hasMatch(code)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
