import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct;

import '../../../l10n/l10n.dart';
import '../symbols.g.dart';
import '../theme/m3e_own_color.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_sheet.dart';
import '../widgets/m3e_symbol.dart';

/// Ключ блока образцов листа (`.dr-swatches--grid` доски).
const ValueKey<String> kM3eColorGridKey = ValueKey('m3e.swatches');

/// Ключ образца листа по порядку (0..29).
ValueKey<String> m3eColorSwatchKey(int i) => ValueKey('m3e.swatch.$i');

/// 30 оттенков палитры «Другой цвет»: те же формулы HCT, что `GRID` в android.js.
///
/// Первые 12 — насыщенные (C 64, T 62), следующие 12 — приглушённые (C 28, T 45),
/// последние 6 — серые с лёгким оттенком (C 6, тон 30 + 9 на шаг).
final List<int> m3eColorGrid = _buildGrid();

List<int> _buildGrid() {
  int argb(num h, num c, num t) =>
      Hct.from(h.toDouble(), c.toDouble(), t.toDouble()).toInt() & 0xFFFFFF;
  return [
    for (var h = 0; h < 360; h += 30) argb(h, 64, 62),
    for (var h = 0; h < 360; h += 30) argb(h, 28, 45),
    for (final (i, h) in const [0, 40, 80, 220, 260, 300].indexed)
      argb(h, 6, 30 + i * 9),
  ];
}

/// Содержимое листа: сетка 6 × 5 сплошных кругов. [selected] — RGB выбранного
/// цвета или `null`, если ни один не отмечен.
class M3eColorSheetView extends StatelessWidget {
  const M3eColorSheetView({super.key, required this.selected, this.onPick});

  final int? selected;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return M3eSheetScaffold(
      title: l10n.m3eColorTitle,
      body: Padding(
        key: kM3eColorGridKey,
        // Поля 4/0/8 как у `.dr-swatches--grid`.
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final size = (box.maxWidth - gap * 5) / 6;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, rgb) in m3eColorGrid.indexed)
                  SizedBox(
                    width: size,
                    height: size,
                    child: _SolidSwatch(
                      key: m3eColorSwatchKey(i),
                      rgb: rgb,
                      label: l10n.m3eColorShade(i + 1),
                      checked:
                          selected != null && (selected! & 0xFFFFFF) == rgb,
                      reduced: reduced,
                      onTap: onPick == null ? null : () => onPick!(rgb),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Сплошной образец (`.dr-swatch--solid`). Выбранный из круга превращается в скруглённый
/// квадрат (радиус 30 %) и несёт белую галочку на затемнённом круге 32.
class _SolidSwatch extends StatelessWidget {
  const _SolidSwatch({
    super.key,
    required this.rgb,
    required this.label,
    required this.checked,
    required this.reduced,
    required this.onTap,
  });

  final int rgb;
  final String label;
  final bool checked;
  final bool reduced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF000000 | rgb);
    return LayoutBuilder(
      builder: (context, box) {
        final r = BorderRadius.circular(box.maxWidth * (checked ? 0.3 : 0.5));
        return Semantics(
          label: label,
          button: true,
          selected: checked,
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: reduced ? Duration.zero : M3eDuration.short4,
                    curve: M3eEasing.emphasized,
                    decoration: BoxDecoration(color: color, borderRadius: r),
                    alignment: Alignment.center,
                    child: checked
                        ? Container(
                            width: 32,
                            height: 32,
                            // Затемнение 32 % из роли scrim: белая галочка читается на любом
                            // из 30 оттенков, включая светлые серые.
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: M3eColors.of(context)
                                  .scheme
                                  .scrim
                                  .withValues(alpha: 0.32),
                            ),
                            alignment: Alignment.center,
                            child: const M3eSymbolIcon(
                              M3eSymbol.check,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(borderRadius: r, onTap: onTap),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Открывает лист «Другой цвет». Выбор записывается сразу и включает свой цвет;
/// лист остаётся открытым, как на доске: отметка переезжает на выбранный образец.
///
/// Содержимое обёрнуто в [M3eThemeScope], чтобы цвет в листе обновлялся вместе со схемой.
/// Рамка и ручка листа берут схему в момент открытия.
Future<void> showM3eColorSheet(BuildContext context) =>
    showM3eSheet<void>(context, builder: (_) => const _M3eColorSheet());

class _M3eColorSheet extends ConsumerWidget {
  const _M3eColorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(m3eOwnColorEnabledProvider);
    final own = ref.watch(m3eOwnColorProvider);
    return M3eThemeScope(
      child: M3eColorSheetView(
        selected: enabled ? own : null,
        onPick: ref.read(m3eOwnColorActionsProvider).pick,
      ),
    );
  }
}
