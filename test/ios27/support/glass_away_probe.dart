// Зонд ухода нижнего ряда главной под лист: читает прозрачность Flutter-содержимого стекла.
//
// `away` уходит в `Ios27Glass`: материал гасит сам нативный вид (или заглушка), а значки —
// `Ios27GlassAwayFade` рядом с ним. Слой прозрачности над кнопкой ставить нельзя (над нативным
// видом он рисуется неверно), поэтому тесты читают именно эти узлы, а не предка ряда.

import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Прозрачности всех `Ios27GlassAwayFade` внутри нижнего ряда (ключ `dock`): у каждой кнопки
/// два узла — подложка заглушки и содержимое (в нативной ветке только содержимое).
List<double> dockGlassFades(WidgetTester tester) => tester
    .widgetList<Ios27GlassAwayFade>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dock')),
        matching: find.byType(Ios27GlassAwayFade),
      ),
    )
    .map((w) => w.value)
    .toList();

/// Общая прозрачность ряда: три кнопки идут на одних таймингах, поэтому значения равны;
/// расхождение само по себе ошибка (кнопки ушли бы вразнобой).
double dockGlassFade(WidgetTester tester) {
  final fades = dockGlassFades(tester);
  expect(
    fades,
    isNotEmpty,
    reason: 'в нижнем ряду нет Ios27GlassAwayFade: стекло потеряло away',
  );
  for (final v in fades) {
    expect(v, closeTo(fades.first, 1e-9), reason: 'кнопки ряда идут вразнобой');
  }
  return fades.first;
}
