import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/icon/app_icon.g.dart';
import 'package:dropweb/ui/m3e/icon/m3e_app_icon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

// Эталон пишет tool/canon/gen_icon.mjs: SVG, который androidIcon доски выдаёт для 6
// провайдеров в светлой и тёмной схеме. Dart-шаблон и scheme().icon должны дать те же
// строки без единого отличия.

void main() {
  final fixture =
      jsonDecode(File('test/m3e/fixtures/app_icon.json').readAsStringSync())
          as Map<String, dynamic>;
  final uid = fixture['uid'] as String;
  final cases =
      (fixture['cases'] as List<dynamic>).cast<Map<String, dynamic>>();

  test('эталон покрывает 6 провайдеров × 2 темы', () {
    expect(cases.length, 12);
  });

  test('шаблон и scheme().icon дают те же SVG-строки, что androidIcon доски',
      () {
    for (final c in cases) {
      final id = c['id'] as String;
      final icon = scheme(
        c['seed'] as String,
        c['filter'] as String,
        dark: c['dark'] as bool,
      ).icon;
      final svg = m3eAppIconSvg(
        fg: hexFromArgb(icon.fg.toARGB32()),
        bg: hexFromArgb(icon.bg.toARGB32()),
        uid: uid,
      );
      expect(svg, c['svg'], reason: id);
    }
  });

  testWidgets('M3eAppIcon рисуется без ошибок во всех эталонах',
      (tester) async {
    for (final c in cases) {
      final icon = scheme(
        c['seed'] as String,
        c['filter'] as String,
        dark: c['dark'] as bool,
      ).icon;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: M3eAppIcon(colors: icon, size: 96)),
        ),
      );
      await tester.pump();
      expect(find.byType(SvgPicture), findsOneWidget,
          reason: c['id'] as String);
      expect(tester.takeException(), isNull, reason: c['id'] as String);
    }
  });
}
