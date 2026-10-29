import 'package:dropweb/common/constant.dart' show maxTextScale, minTextScale;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct;

import '../color/color.dart';
import '../symbols.g.dart';
import '../theme/m3e_own_color.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/m3e_theme_source.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_list.dart';
import '../widgets/m3e_page.dart';
import '../widgets/m3e_symbol.dart';
import 'm3e_color_sheet.dart';

/// Ключи элементов: совпадают с именами в `test/m3e/ref/layout.json` (сцены
/// `appearance-<тема>-p<N>`).
const Key kM3eAppearanceListKey = ValueKey<String>('m3e.list');

/// Ключ пункта группы «Цвет провайдера / Свой цвет» (0 и 1).
Key m3eAppearanceItemKey(int index) => ValueKey<String>('m3e.list.item.$index');

/// Ключи сетки основных цветов страницы и её образцов (10-й — «Другой цвет»).
const Key kM3ePaletteKey = ValueKey<String>('m3e.page.swatches');
Key m3ePaletteSwatchKey(int index) =>
    ValueKey<String>('m3e.page.swatch.$index');

/// Девять основных цветов: те же формулы, что `SEEDS` в android.js (оттенок, C 48, T 60).
final List<int> m3eSeedColors = [
  for (final h in const [25, 55, 90, 140, 175, 215, 260, 295, 330])
    Hct.from(h.toDouble(), 48, 60).toInt() & 0xFFFFFF,
];

/// Три цвета образца из схемы [seed]/[filter]: primary-container, secondary-container,
/// tertiary-container текущей яркости (`swatchVars` доски).
({Color a, Color b, Color c, Color on}) _swatchColors(
  String seed,
  String filter,
  bool dark,
) {
  final s = scheme(seed, filter, dark: dark);
  return (
    a: s.primaryContainer,
    b: s.secondaryContainer,
    c: s.tertiaryContainer,
    on: s.onPrimaryContainer,
  );
}

String _hex(int rgb) => m3eHexOf(rgb);

/// Экран «Оформление» (`PAGES.appearance` доски): выбор между цветом провайдера и
/// своим, при своём цвете ещё и сетка основных цветов.
///
/// Чистая отрисовка без провайдеров. [M3eThemeScope] должен стоять выше по дереву.
/// Пункт «Масштаб текста» на доске отсутствует: он остался со старого экрана и лежит
/// отдельной группой ниже ([showExtras]).
class M3eAppearanceView extends StatelessWidget {
  const M3eAppearanceView({
    super.key,
    required this.providerSeed,
    required this.providerFilter,
    required this.ownEnabled,
    this.ownColor,
    this.showExtras = true,
    this.textScaleEnabled = true,
    this.textScale = 1,
    required this.onBack,
    this.onUseProvider,
    this.onUseOwn,
    this.onPick,
    this.onOtherColor,
    this.onTextScaleEnabled,
    this.onTextScale,
  });

  /// Акцент и фильтр схемы подписки: образец первого пункта.
  final String providerSeed;
  final String providerFilter;
  final bool ownEnabled;

  /// ARGB своего цвета; без него второй пункт не показывает образец.
  final int? ownColor;
  final bool showExtras;
  final bool textScaleEnabled;
  final double textScale;
  final VoidCallback onBack;
  final VoidCallback? onUseProvider;
  final VoidCallback? onUseOwn;
  final ValueChanged<int>? onPick;
  final VoidCallback? onOtherColor;
  final ValueChanged<bool>? onTextScaleEnabled;
  final ValueChanged<double>? onTextScale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = M3eColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    final own = ownEnabled && ownColor != null;
    final ownRgb = ownColor == null ? null : ownColor! & 0xFFFFFF;
    final provider = _swatchColors(providerSeed, providerFilter, dark);
    final ownSwatch = ownRgb == null
        ? null
        : _swatchColors(_hex(ownRgb), m3eOwnColorFilter, dark);

    final radio = M3eList(
      semanticLabel: l10n.m3eAppearanceGroupLabel,
      children: [
        M3eListItem(
          key: m3eAppearanceItemKey(0),
          label: l10n.m3eAppearanceProvider,
          sup: l10n.m3eAppearanceProviderSub,
          lead: M3eListLead.radio(!own),
          radioChecked: !own,
          trail: M3eListTrail.swatch(
            primary: provider.a,
            secondary: provider.b,
            tertiary: provider.c,
          ),
          onTap: onUseProvider,
        ),
        M3eListItem(
          key: m3eAppearanceItemKey(1),
          label: l10n.m3eAppearanceOwn,
          sup: own ? _hex(ownRgb!) : l10n.m3eAppearanceOwnSub,
          lead: M3eListLead.radio(own),
          radioChecked: own,
          trail: own && ownSwatch != null
              ? M3eListTrail.swatch(
                  primary: ownSwatch.a,
                  secondary: ownSwatch.b,
                  tertiary: ownSwatch.c,
                )
              : null,
          onTap: onUseOwn,
        ),
      ],
    );

    return M3ePage(
      title: l10n.m3eAppearanceTitle,
      onBack: onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(key: kM3eAppearanceListKey, child: radio),
          if (own) ...[
            M3eListHeader(l10n.m3eAppearanceBasicColors),
            _Palette(
              key: kM3ePaletteKey,
              dark: dark,
              ownRgb: ownRgb,
              onPick: onPick,
              onOther: onOtherColor,
            ),
          ],
          if (showExtras) ...[
            const SizedBox(height: 16),
            _Extras(
              textScaleEnabled: textScaleEnabled,
              textScale: textScale,
              onTextScaleEnabled: onTextScaleEnabled,
              onTextScale: onTextScale,
            ),
          ],
        ],
      ),
    );
  }
}

/// Сетка 5 колонок (`.dr-swatches`): зазор 12, поля по бокам 4.
class _Palette extends StatelessWidget {
  const _Palette({
    super.key,
    required this.dark,
    required this.ownRgb,
    required this.onPick,
    required this.onOther,
  });

  final bool dark;
  final int? ownRgb;
  final ValueChanged<int>? onPick;
  final VoidCallback? onOther;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scheme = M3eColors.of(context).scheme;
    final inSeeds = ownRgb != null && m3eSeedColors.contains(ownRgb);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 12.0;
          final size = (box.maxWidth - gap * 4) / 5;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (i, rgb) in m3eSeedColors.indexed)
                SizedBox.square(
                  dimension: size,
                  child: _Disc(
                    key: m3ePaletteSwatchKey(i),
                    colors: _swatchColors(_hex(rgb), m3eOwnColorFilter, dark),
                    label: l10n.m3eColorN(i + 1),
                    checked: ownRgb == rgb,
                    reduced: reduced,
                    onTap: onPick == null ? null : () => onPick!(rgb),
                  ),
                ),
              SizedBox.square(
                dimension: size,
                // Не из основных: образец окрашен своим цветом и отмечен.
                child: _Disc(
                  key: m3ePaletteSwatchKey(m3eSeedColors.length),
                  colors: !inSeeds && ownRgb != null
                      ? _swatchColors(_hex(ownRgb!), m3eOwnColorFilter, dark)
                      : null,
                  moreFill: scheme.surfaceContainerHighest,
                  moreInk: scheme.onSurfaceVariant,
                  label: l10n.m3eColorTitle,
                  checked: !inSeeds && ownRgb != null,
                  reduced: reduced,
                  onTap: onOther,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Круглый образец (`.dr-swatch`): три цвета схемы по углам (как образец-точка), выбранный
/// скругляется до 30 % и несёт кружок 32 с галочкой. Без [colors] рисуется кнопка
/// «Другой цвет» с палитрой на нейтральной заливке.
class _Disc extends StatelessWidget {
  const _Disc({
    super.key,
    this.colors,
    this.moreFill,
    this.moreInk,
    required this.label,
    required this.checked,
    required this.reduced,
    required this.onTap,
  });

  final ({Color a, Color b, Color c, Color on})? colors;
  final Color? moreFill;
  final Color? moreInk;
  final String label;
  final bool checked;
  final bool reduced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return LayoutBuilder(
      builder: (context, box) {
        final r = BorderRadius.circular(box.maxWidth * (checked ? 0.3 : 0.5));
        final decoration = c == null
            ? BoxDecoration(color: moreFill, borderRadius: r)
            : BoxDecoration(
                borderRadius: r,
                // Как у образца-точки: старт слева, по часовой (поворот на pi).
                gradient: SweepGradient(
                  transform: const GradientRotation(3.141592653589793),
                  colors: [c.a, c.a, c.c, c.c, c.b, c.b],
                  stops: const [0, 0.5, 0.5, 0.75, 0.75, 1],
                ),
              );
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
                    decoration: decoration,
                    alignment: Alignment.center,
                    child: checked && c != null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.a,
                            ),
                            child: SizedBox.square(
                              dimension: 32,
                              child: Center(
                                child: M3eSymbolIcon(
                                  M3eSymbol.check,
                                  size: 20,
                                  color: c.on,
                                ),
                              ),
                            ),
                          )
                        : c == null
                            ? M3eSymbolIcon(
                                M3eSymbol.palette,
                                color: moreInk,
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

/// Пункт со старого экрана: «Масштаб текста» (доступность). Строка из старого ключа
/// `textScale`.
class _Extras extends StatelessWidget {
  const _Extras({
    required this.textScaleEnabled,
    required this.textScale,
    required this.onTextScaleEnabled,
    required this.onTextScale,
  });

  final bool textScaleEnabled;
  final double textScale;
  final ValueChanged<bool>? onTextScaleEnabled;
  final ValueChanged<double>? onTextScale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = M3eColors.of(context).scheme;
    return M3eList(
      children: [
        M3eListItem(
          key: const ValueKey<String>('m3e.extras.textScale'),
          label: l10n.textScale,
          sup: textScaleEnabled ? '${(textScale * 100).round()}%' : null,
          toggled: textScaleEnabled,
          trail: M3eListTrail.toggle(textScaleEnabled),
          onTap: onTextScaleEnabled == null
              ? null
              : () => onTextScaleEnabled!(!textScaleEnabled),
        ),
        if (textScaleEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Slider(
              key: const ValueKey<String>('m3e.extras.textScale.slider'),
              min: minTextScale,
              max: maxTextScale,
              value: textScale.clamp(minTextScale, maxTextScale).toDouble(),
              label: '${(textScale * 100).round()}%',
              activeColor: scheme.primary,
              onChanged: onTextScale,
            ),
          ),
      ],
    );
  }
}

/// Экран «Оформление» на провайдерах: тема, подписка, `ThemeProps` и настройки приложения.
class M3eAppearancePage extends ConsumerWidget {
  const M3eAppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(m3eProviderSourceProvider);
    final enabled = ref.watch(m3eOwnColorEnabledProvider);
    final own = ref.watch(m3eOwnColorProvider);
    final scale = ref.watch(themeSettingProvider.select((t) => t.textScale));
    final actions = ref.read(m3eOwnColorActionsProvider);
    return M3eThemeScope(
      child: M3eAppearanceView(
        providerSeed: provider.seed,
        providerFilter: provider.filter,
        ownEnabled: enabled,
        ownColor: own,
        textScaleEnabled: scale.enable,
        textScale: scale.scale,
        onBack: () => Navigator.maybePop(context),
        onUseProvider: actions.useProvider,
        onUseOwn: actions.enable,
        onPick: actions.pick,
        onOtherColor: () => showM3eColorSheet(context),
        onTextScaleEnabled: (v) => ref
            .read(themeSettingProvider.notifier)
            .updateState((s) => s.copyWith.textScale(enable: v)),
        onTextScale: (v) => ref
            .read(themeSettingProvider.notifier)
            .updateState((s) => s.copyWith.textScale(scale: v)),
      ),
    );
  }
}
