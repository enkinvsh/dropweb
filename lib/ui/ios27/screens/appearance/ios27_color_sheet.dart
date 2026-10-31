// Лист выбора цвета iOS-редизайна (доска: `sheet kind:'color'`, app.js:735-751, стили app.css:577-590).
//
// Палитра как у UIColorPickerViewController: сетка 12 × 10, ниже текущий цвет и восемь
// сохранённых системных цветов. Выбор применяется сразу, лист остаётся открытым: цвет за ним
// перекрашивается вживую (его читают все `Ios27ThemeScope`).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart' show Ios27GlassVariant;
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Поля тела листа слева и справа (`.sheet__body.cp{padding:68px 16px 24px}`, app.css:581).
const double kIos27ColorSheetInset = 16;

/// Радиус скругления сетки (`.cp__grid`, app.css:582).
const double kIos27ColorGridRadius = 8;

/// Клетка сетки чуть выше ширины (`aspect-ratio: 1 / 1.003`, app.css:583).
const double kIos27ColorCellAspect = 1.003;

/// Отступ от сетки до нижнего ряда (`.cp__bottom{margin-top:45px}`, app.css:585).
const double kIos27ColorBottomGap = 45;

/// Сторона образца текущего цвета и его радиус (`.cp__current`, app.css:587).
const double kIos27ColorCurrentSize = 75;
const double kIos27ColorCurrentRadius = 10;

/// Зазор между образцом и кружками (`.cp__bottom{gap:30px}`).
const double kIos27ColorBottomSpacing = 30;

/// Кружок сохранённого цвета и зазор между его рядами (`.cp__dot`, `.cp__dots`, app.css:588-589).
const double kIos27ColorDot = 30;
const double kIos27ColorDotRowGap = 15;

/// Кружков в ряду.
const int kIos27ColorDotColumns = 5;

/// Нижнее поле тела (`padding-bottom: 24px`).
const double kIos27ColorSheetBottom = 24;

/// Подпись слота: «Кнопки», «Фон сверху», «Фон снизу».
String ios27SlotLabel(AppLocalizations l10n, Ios27ColorSlot slot) =>
    switch (slot) {
      Ios27ColorSlot.accent => l10n.ios27ColorSlotAccent,
      Ios27ColorSlot.orb1 => l10n.ios27ColorSlotOrb1,
      Ios27ColorSlot.orb2 => l10n.ios27ColorSlotOrb2,
    };

/// Название сохранённого цвета для озвучки. Неизвестный id (новый пресет без перевода) читается
/// доской-названием из таблицы, а не пустой строкой.
String ios27PresetName(AppLocalizations l10n, Ios27AccentPreset preset) =>
    switch (preset.id) {
      'blue' => l10n.ios27PresetBlue,
      'purple' => l10n.ios27PresetPurple,
      'pink' => l10n.ios27PresetPink,
      'red' => l10n.ios27PresetRed,
      'orange' => l10n.ios27PresetOrange,
      'yellow' => l10n.ios27PresetYellow,
      'green' => l10n.ios27PresetGreen,
      'graphite' => l10n.ios27PresetGraphite,
      _ => preset.name,
    };

/// Открывает лист цвета для [slot]. Вызов берёт любой контекст, в том числе выше области темы.
Future<void> showIos27ColorSheet(BuildContext context, Ios27ColorSlot slot) {
  final l10n = AppLocalizations.of(context);
  return showIos27Sheet<void>(
    context,
    title: ios27SlotLabel(l10n, slot),
    // По содержимому: на доске у листа цвета `sheet--fit` (app.css:574), высота 515.28.
    detent: Ios27SheetDetent.fit,
    // Стекло `glass--lg`, как у листа цвета на доске (`sheet sheet--medium sheet--fit glass
    // glass--lg`, app.js:744): плотнее обычного листа `md`. При Reduce Transparency заливка
    // та же (#F2F2F2/#2A2A2A), поэтому кадры RT от класса не зависят.
    variant: Ios27GlassVariant.lg,
    builder: (_) => Ios27ColorPicker(slot: slot),
  );
}

/// Тело листа цвета: сетка, текущий цвет, сохранённые цвета. Живёт под `Ios27SheetScaffold`.
class Ios27ColorPicker extends ConsumerWidget {
  const Ios27ColorPicker({super.key, required this.slot});

  final Ios27ColorSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Ios27Colors.of(context);
    final current = ref.watch(ios27OwnThemeProvider).slot(slot).toUpperCase();
    final actions = ref.read(ios27OwnColorActionsProvider);
    void pick(String hex) => actions.pick(slot, hex);

    const dots = kIos27AccentPresets;
    final dotRows = <List<Ios27AccentPreset?>>[
      for (var i = 0; i < dots.length; i += kIos27ColorDotColumns)
        [
          for (var j = 0; j < kIos27ColorDotColumns; j++)
            i + j < dots.length ? dots[i + j] : null,
        ],
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.ios27ColorSheetLabel(ios27SlotLabel(l10n, slot)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          kIos27ColorSheetInset,
          0,
          kIos27ColorSheetInset,
          kIos27ColorSheetBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColorGrid(selected: current, onPick: pick),
            const SizedBox(height: kIos27ColorBottomGap),
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Разделитель над нижним рядом: 1 px, сжатый по высоте вдвое (`scale: 1 .5`),
                // на 24 выше ряда: полоса 0.5 с центром на 23.5 над его верхом.
                Positioned(
                  left: 0,
                  right: 0,
                  top: -23.75,
                  height: 0.5,
                  child: ColoredBox(color: colors.palette.separator),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CurrentColor(
                      key: const ValueKey<String>('cp.current'),
                      color: Ios27Rgb.fromHex(current).color,
                    ),
                    const SizedBox(width: kIos27ColorBottomSpacing),
                    Expanded(
                      child: Column(
                        key: const ValueKey<String>('cp.dots'),
                        children: [
                          for (var r = 0; r < dotRows.length; r++) ...[
                            if (r > 0)
                              const SizedBox(height: kIos27ColorDotRowGap),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final preset in dotRows[r])
                                  preset == null
                                      // Пустое место держит колонки второго ряда под первым.
                                      ? const SizedBox.square(
                                          dimension: kIos27ColorDot,
                                        )
                                      : _PresetDot(
                                          color: Ios27Rgb.fromHex(preset.light)
                                              .color,
                                          label: ios27PresetName(l10n, preset),
                                          selected: preset.light == current,
                                          onTap: () => pick(preset.light),
                                        ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Образец текущего цвета, кромка `inset 0 0 0 .5px #00000026`.
class _CurrentColor extends StatelessWidget {
  const _CurrentColor({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: kIos27ColorCurrentSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(kIos27ColorCurrentRadius),
            border: Border.all(
              color: Colors.black.withAlpha(0x26),
              width: 0.5,
            ),
          ),
        ),
      );
}

/// Кружок сохранённого цвета. Выбранный: цветная кромка 3 и белое кольцо 2 внутри
/// (`inset 0 0 0 3px var(--c), inset 0 0 0 5px #FFFFFF`, app.css:590).
class _PresetDot extends StatelessWidget {
  const _PresetDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // Ключ стоит на круге, а не на `_PresetDot`: кружки лежат в одном `Row`, и одинаковые
          // ключи у соседей бросают «Duplicate keys». Рамка круга и есть рамка `.cp__dot` доски.
          child: SizedBox.square(
            key: const ValueKey<String>('cp.dot'),
            dimension: kIos27ColorDot,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.all(3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
}

/// Цвета клеток сетки, разобранные один раз.
final List<Color> _gridColors = List.unmodifiable(
  kIos27ColorGrid.map((h) => Ios27Rgb.fromHex(h).color),
);

/// Сетка 12 × 10 одним рисунком.
///
/// Рисуется одним `CustomPainter`, а не 120 виджетами: у соседних клеток на дробных границах
/// (ширина клетки не целая) отдельные слои дают просвет, а Chromium привязывает клетки к
/// пикселям. Клетка заходит на соседнюю на 1 dp, следующая её перекрывает. Касание считает
/// клетку по координате, каждая клетка отдаёт VoiceOver свой узел (подпись — hex, как `aria-label`).
class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.selected, required this.onPick});

  /// Текущий цвет, `#RRGGBB` верхним регистром.
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final rows = kIos27ColorGrid.length ~/ kIos27ColorGridColumns;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / kIos27ColorGridColumns;
        final height = cell * kIos27ColorCellAspect * rows;
        final selectedIndex = kIos27ColorGrid.indexOf(selected);
        return SizedBox(
          key: const ValueKey<String>('cp.grid'),
          width: box.maxWidth,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final p = details.localPosition;
              final col = (p.dx / cell).floor();
              final row = (p.dy / (height / rows)).floor();
              if (col < 0 ||
                  col >= kIos27ColorGridColumns ||
                  row < 0 ||
                  row >= rows) {
                return;
              }
              onPick(kIos27ColorGrid[row * kIos27ColorGridColumns + col]);
            },
            child: CustomPaint(
              painter: _GridPainter(
                selectedIndex: selectedIndex,
                onPick: onPick,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.selectedIndex,
    required this.onPick,
    required this.textDirection,
  });

  /// Индекс клетки текущего цвета или -1.
  final int selectedIndex;
  final ValueChanged<String> onPick;

  /// Направление текста для подписей клеток: у узла семантики с подписью оно обязательно.
  final TextDirection textDirection;

  Rect _cell(Size size, int index) {
    final cw = size.width / kIos27ColorGridColumns;
    final rows = kIos27ColorGrid.length ~/ kIos27ColorGridColumns;
    final ch = size.height / rows;
    final col = index % kIos27ColorGridColumns;
    final row = index ~/ kIos27ColorGridColumns;
    return Rect.fromLTWH(col * cw, row * ch, cw, ch);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(kIos27ColorGridRadius),
        ),
      );
    final paint = Paint();
    for (var i = 0; i < _gridColors.length; i++) {
      paint.color = _gridColors[i];
      // Заход на соседнюю клетку вправо и вниз: просвет на дробной границе закрывает следующая
      // клетка, а у края сетки лишнее срезает скругление.
      final r = _cell(size, i);
      canvas.drawRect(
        Rect.fromLTRB(r.left, r.top, r.right + 1, r.bottom + 1),
        paint,
      );
    }
    if (selectedIndex >= 0) {
      // Выбранная клетка выше соседних: белая рамка 3 внутрь и кромка 0.5 снаружи.
      final rect = _cell(size, selectedIndex);
      canvas
        ..drawRect(
          rect.inflate(0.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = Colors.black.withAlpha(0x40),
        )
        ..drawRect(
          rect.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.selectedIndex != selectedIndex;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (var i = 0; i < kIos27ColorGrid.length; i++)
          CustomPainterSemantics(
            key: ValueKey<int>(i),
            rect: _cell(size, i),
            properties: SemanticsProperties(
              label: kIos27ColorGrid[i],
              textDirection: textDirection,
              button: true,
              selected: i == selectedIndex,
              onTap: () => onPick(kIos27ColorGrid[i]),
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(_GridPainter old) =>
      old.selectedIndex != selectedIndex || old.textDirection != textDirection;
}
