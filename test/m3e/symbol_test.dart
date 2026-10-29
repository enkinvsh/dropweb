import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('таблица: 57 значков, у каждого непустые o и f', () {
    expect(kM3eSymbolPaths.length, 57);
    expect(M3eSymbol.values.length, 57);
    // У части значков (например power_settings_new) контур и заливка в шрифте
    // совпадают: у глифа нет внутренней полости, поэтому o != f не требуем.
    for (final e in kM3eSymbolPaths.entries) {
      expect(e.value.o, isNotEmpty, reason: e.key.id);
      expect(e.value.f, isNotEmpty, reason: e.key.id);
      expect(e.value.o.startsWith('M'), isTrue, reason: e.key.id);
    }
  });

  testWidgets('виджет рисуется в обоих вариантах и красится цветом', (t) async {
    for (final fill in [false, true]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: M3eSymbolIcon(
              M3eSymbol.powerSettingsNew,
              fill: fill,
              color: Colors.red,
              semanticLabel: 'Питание',
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      final svg = t.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 24);
      expect(svg.height, 24);
      expect(find.bySemanticsLabel('Питание'), findsOneWidget);
    }
  });

  testWidgets('без цвета берётся IconTheme, без подписи значок скрыт',
      (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Colors.green),
          child: M3eSymbolIcon(M3eSymbol.bolt, size: 32),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    final svg = t.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 32);
    expect(
      svg.colorFilter,
      const ColorFilter.mode(Colors.green, BlendMode.srcIn),
    );
  });
}
