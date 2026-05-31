// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/selector.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class FontFamilyItem {
  const FontFamilyItem({
    required this.fontFamily,
    required this.label,
  });
  final FontFamily fontFamily;
  final String label;
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  // Dropweb is shipped as a dark-only product. The legacy theme-mode
  // picker (System / Light / Dark) used to live here but has been
  // removed so users can no longer switch the app out of dark mode.
  // Theme color / pureBlack / text-scale still work as before.
  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        child: Column(
          spacing: 24,
          children: [
            _ThemePresetItem(),
            _PrimaryColorItem(),
            _OrbColorItem(),
            _SubscriptionLogoItem(),
            _SubscriptionThemeItem(),
            _PrueBlackItem(),
            _TextScaleFactorItem(),
            SizedBox(
              height: 64,
            ),
          ],
        ),
      );
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });
  final Widget child;
  final Info info;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
        runSpacing: 16,
        children: [
          InfoHeader(
            info: info,
            actions: actions,
          ),
          child,
        ],
      );
}

class _ThemePresetItem extends ConsumerWidget {
  const _ThemePresetItem();

  String _presetName(ThemePreset preset) {
    switch (preset.nameKey) {
      case 'presetEmerald':
        return appLocalizations.presetEmerald;
      case 'presetFrost':
        return appLocalizations.presetFrost;
      case 'presetAmethyst':
        return appLocalizations.presetAmethyst;
      case 'presetMagma':
        return appLocalizations.presetMagma;
      case 'presetAmber':
        return appLocalizations.presetAmber;
      case 'presetCrimson':
        return appLocalizations.presetCrimson;
      case 'presetStealth':
        return appLocalizations.presetStealth;
      default:
        return preset.nameKey;
    }
  }

  void _apply(WidgetRef ref, ThemePreset preset) {
    ref.read(themeSettingProvider.notifier).updateState((state) {
      final colors = [...state.primaryColors];
      if (!colors.contains(preset.accent)) {
        colors.add(preset.accent);
      }
      return state.copyWith(
        primaryColor: preset.accent,
        primaryColors: colors,
        orbColorPrimary: preset.orbPrimary,
        orbColorSecondary: preset.orbSecondary,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trio = ref.watch(
      themeSettingProvider.select(
        (state) => (
          state.primaryColor,
          state.orbColorPrimary,
          state.orbColorSecondary,
        ),
      ),
    );

    return ItemCard(
      info: Info(
        label: appLocalizations.themePresets,
        iconWidget: HugeIcon(icon: HugeIcons.strokeRoundedPaintBrush01, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (_, constraints) {
            const columns = 3;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final preset in themePresets)
                  SizedBox(
                    width: itemWidth,
                    child: _PresetCard(
                      name: _presetName(preset),
                      accent: preset.accent,
                      orbPrimary: preset.orbPrimary,
                      orbSecondary: preset.orbSecondary,
                      isSelected: trio.$1 == preset.accent &&
                          trio.$2 == preset.orbPrimary &&
                          trio.$3 == preset.orbSecondary,
                      onTap: () => _apply(ref, preset),
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.accent,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final int accent;
  final int orbPrimary;
  final int orbSecondary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return EffectGestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: AnimatedContainer(
              duration: midDuration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Color(accent)
                      : colorScheme.outlineVariant.withOpacity(0.4),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Color(accent).withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(orbPrimary),
                            Color(accent),
                            Color(orbSecondary),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(accent),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.85),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(accent),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  int _calcColumns(double maxWidth) => max((maxWidth / 96).ceil(), 3);

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.resetTip,
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColors: defaultPrimaryColors,
            primaryColor: defaultPrimaryColor,
            schemeVariant: DynamicSchemeVariant.fidelity,
            orbColorPrimary: null,
            orbColorSecondary: null,
          ),
        );
  }

  Future<void> _handleDel() async {
    if (_removablePrimaryColor == null) {
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(
          appLocalizations.colorSchemes,
        ),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
      (state) {
        final newPrimaryColors = List<int>.from(state.primaryColors)
          ..remove(_removablePrimaryColor);
        var newPrimaryColor = state.primaryColor;
        if (state.primaryColor == _removablePrimaryColor) {
          if (newPrimaryColors.contains(defaultPrimaryColor)) {
            newPrimaryColor = defaultPrimaryColor;
          } else {
            newPrimaryColor = null;
          }
        }
        return state.copyWith(
          primaryColors: newPrimaryColors,
          primaryColor: newPrimaryColor,
        );
      },
    );
    setState(() {
      _removablePrimaryColor = null;
    });
  }

  Future<void> _handleEdit(int? color) async {
    setState(() {
      _removablePrimaryColor = null;
    });
    final res = await globalState.showCommonDialog<int>(
      child: _PaletteDialog(
        initialColor: color != null ? Color(color) : null,
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColors: state.primaryColors.contains(res)
                ? state.primaryColors
                : (List.from(state.primaryColors)..add(res)),
            primaryColor: res,
          ),
        );
  }

  Future<void> _handleAdd() async {
    final res = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (res == null) {
      return;
    }
    final isExists = ref.read(
      themeSettingProvider.select((state) => state.primaryColors.contains(res)),
    );
    if (isExists && mounted) {
      context.showNotifier(
        appLocalizations.existsTip(
          appLocalizations.colorSchemes,
        ),
      );
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColors: List.from(
              state.primaryColors,
            )..add(res),
            // Auto-select the freshly added color so the user's "Apply"
            // immediately reflects on the rest of the UI without an
            // extra tap on the swatch.
            primaryColor: res,
          ),
        );
  }

  String _schemeLabel(DynamicSchemeVariant variant) {
    switch (variant) {
      case DynamicSchemeVariant.fidelity:
        return appLocalizations.schemeCalm;
      case DynamicSchemeVariant.vibrant:
        return appLocalizations.schemeBright;
      case DynamicSchemeVariant.monochrome:
        return appLocalizations.schemeMono;
      case DynamicSchemeVariant.neutral:
        return appLocalizations.schemeNeutral;
      case DynamicSchemeVariant.expressive:
        return appLocalizations.schemeExpressive;
      default:
        return appLocalizations.schemeCalm;
    }
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select(
        (state) => state.schemeVariant,
      ),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: appLocalizations.colorSchemes,
        options: const [
          DynamicSchemeVariant.fidelity,
          DynamicSchemeVariant.vibrant,
          DynamicSchemeVariant.monochrome,
          DynamicSchemeVariant.neutral,
          DynamicSchemeVariant.expressive,
        ],
        textBuilder: _schemeLabel,
        value: schemeVariant,
      ),
    );
    if (value == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            schemeVariant: value,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final vm4 = ref.watch(
      themeSettingProvider.select(
        (state) => VM4(
          a: state.primaryColor,
          b: state.primaryColors,
          c: state.schemeVariant,
          d: state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(state.primaryColors, defaultPrimaryColors),
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isEquals = vm4.d;

    return CommonPopScope(
      onPop: () {
        if (_removablePrimaryColor != null) {
          setState(() {
            _removablePrimaryColor = null;
          });
          return false;
        }
        return true;
      },
      child: ItemCard(
        info: Info(
          label: appLocalizations.themeColor,
          iconWidget: HugeIcon(icon: HugeIcons.strokeRoundedColors, size: 24),
        ),
        actions: genActions(
          [
            if (_removablePrimaryColor == null)
              FilledButton(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _handleChangeSchemeVariant,
                child: Text(_schemeLabel(schemeVariant)),
              ),
            if (_removablePrimaryColor != null)
              FilledButton(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _removablePrimaryColor = null;
                  });
                },
                child: Text(appLocalizations.cancel),
              ),
            if (_removablePrimaryColor == null && !isEquals)
              IconButton.filledTonal(
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                onPressed: _handleReset,
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                    size: 20),
              )
          ],
          space: 8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: LayoutBuilder(
            builder: (_, constraints) {
              final columns = _calcColumns(constraints.maxWidth);
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final color in primaryColors)
                    Container(
                      clipBehavior: Clip.none,
                      width: itemWidth,
                      height: itemWidth,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          EffectGestureDetector(
                            child: ColorSchemeBox(
                              isSelected: color == primaryColor,
                              primaryColor: color != null ? Color(color) : null,
                              onPressed: () => _handleEdit(color),
                            ),
                            onLongPress: () {
                              setState(() {
                                _removablePrimaryColor = color;
                              });
                            },
                          ),
                          if (_removablePrimaryColor != null &&
                              _removablePrimaryColor == color)
                            Container(
                              color: Colors.white.opacity0,
                              padding: const EdgeInsets.all(8),
                              child: IconButton.filledTonal(
                                onPressed: _handleDel,
                                padding: const EdgeInsets.all(12),
                                iconSize: 30,
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedDelete01,
                                  size: 30,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_removablePrimaryColor == null)
                    Container(
                      width: itemWidth,
                      height: itemWidth,
                      padding: const EdgeInsets.all(
                        4,
                      ),
                      child: IconButton.filledTonal(
                        onPressed: _handleAdd,
                        iconSize: 32,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 32,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrbColorItem extends ConsumerWidget {
  const _OrbColorItem();

  Future<void> _handlePick(void Function(int picked) apply) async {
    final picked = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (picked == null) {
      return;
    }
    apply(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(
      themeSettingProvider.select(
        (state) =>
            (state.orbColorPrimary, state.orbColorSecondary, state.orbBlur),
      ),
    );
    final orbColorPrimary = colors.$1;
    final orbColorSecondary = colors.$2;
    final orbBlur = colors.$3;

    return ItemCard(
      info: Info(
        label: appLocalizations.backgroundOrbs,
        iconWidget: HugeIcon(icon: HugeIcons.strokeRoundedBlur, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Expanded(
                  child: _OrbSlot(
                    label: appLocalizations.orbOne,
                    color: orbColorPrimary,
                    onTap: () => _handlePick(
                      (picked) => ref
                          .read(themeSettingProvider.notifier)
                          .updateState(
                            (state) => state.copyWith(orbColorPrimary: picked),
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: _OrbSlot(
                    label: appLocalizations.orbTwo,
                    color: orbColorSecondary,
                    onTap: () => _handlePick(
                      (picked) => ref
                          .read(themeSettingProvider.notifier)
                          .updateState(
                            (state) =>
                                state.copyWith(orbColorSecondary: picked),
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              appLocalizations.orbBlur,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              spacing: 32,
              children: [
                Expanded(
                  child: SliderTheme(
                    data: _SliderDefaultsM3(context),
                    child: Slider(
                      padding: EdgeInsets.zero,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      value: orbBlur.clamp(1.0, 5.0),
                      onChanged: (value) {
                        ref.read(themeSettingProvider.notifier).updateState(
                              (state) => state.copyWith(orbBlur: value),
                            );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 36,
                    child: Text(
                      "${orbBlur.round()}",
                      textAlign: TextAlign.right,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbSlot extends StatelessWidget {
  const _OrbSlot({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: EffectGestureDetector(
              child: ColorSchemeBox(
                isSelected: color != null,
                primaryColor: color != null ? Color(color!) : null,
                onPressed: onTap,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            color != null ? Color(color!).hex : appLocalizations.autoFollowAccent,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
}

class _SubscriptionLogoItem extends ConsumerWidget {
  const _SubscriptionLogoItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applySubscriptionLogo = ref.watch(
      appSettingProvider.select(
        (state) => state.applySubscriptionLogo,
      ),
    );
    return ListItem.switchItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 24),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.subscriptionLogo,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
      ),
      delegate: SwitchDelegate(
        value: applySubscriptionLogo,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  applySubscriptionLogo: value,
                ),
              );
        },
      ),
    );
  }
}

class _SubscriptionThemeItem extends ConsumerWidget {
  const _SubscriptionThemeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applySubscriptionTheme = ref.watch(
      appSettingProvider.select(
        (state) => state.applySubscriptionTheme,
      ),
    );
    return ListItem.switchItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedPaintBoard, size: 24),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.subscriptionTheme,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
      ),
      delegate: SwitchDelegate(
        value: applySubscriptionTheme,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  applySubscriptionTheme: value,
                ),
              );
        },
      ),
    );
  }
}

class _PrueBlackItem extends ConsumerWidget {
  const _PrueBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prueBlack = ref.watch(
      themeSettingProvider.select(
        (state) => state.pureBlack,
      ),
    );
    return ListItem.switchItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedSun02, size: 24),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.pureBlackMode,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
      ),
      delegate: SwitchDelegate(
        value: prueBlack,
        onChanged: (value) {
          ref.read(themeSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  pureBlack: value,
                ),
              );
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select(
        (state) => state.textScale,
      ),
    );
    final process = "${((textScale.scale * 100) as double).round()}%";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListItem.switchItem(
            leading: HugeIcon(icon: HugeIcons.strokeRoundedTextFont, size: 24),
            horizontalTitleGap: 12,
            title: Text(
              appLocalizations.textScale,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
            ),
            delegate: SwitchDelegate(
              value: textScale.enable,
              onChanged: (value) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith.textScale(
                        enable: value,
                      ),
                    );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref.read(themeSettingProvider.notifier).updateState(
                                (state) => state.copyWith.textScale(
                                  scale: value,
                                ),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  process,
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog({this.initialColor});

  final Color? initialColor;

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  late Color _color = widget.initialColor ?? const Color(0xFF22C55E);

  int _toArgb(Color c) =>
      0xFF000000 | (c.toARGB32() & 0x00FFFFFF);

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.palette,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_toArgb(_color)),
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
            enableAlpha: false,
            paletteType: PaletteType.hueWheel,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
      );
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor => WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
            color: _colors.onInverseSurface,
          );

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Size(4.0, 44.0);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Size(4.0, 44.0);
        }
        if (states.contains(WidgetState.focused)) {
          return const Size(2.0, 44.0);
        }
        if (states.contains(WidgetState.pressed)) {
          return const Size(2.0, 44.0);
        }
        return const Size(4.0, 44.0);
      });

  @override
  double? get trackGap => 6.0;
}
