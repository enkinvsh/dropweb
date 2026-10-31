// Страница «Оформление» iOS-редизайна (доска app.js:608-629, сцены appearance / colors / color-sheet).
//
// Группы. «Стекло»: превью из трёх стеклянных кнопок поверх цветной подложки, строка «Как в
// системе» и ползунок прозрачности. «Цвета»: «Провайдер» / «Свои» (список с галочкой, HIG), при
// «Своих» ниже три колодца цвета: «Кнопки», «Фон сверху», «Фон снизу»; нажатие на колодец
// открывает лист цвета. Светлая и тёмная тема идут за системой, своего переключателя нет.
//
// Ползунок стекла вернулся по решению владельца 30.10 (отменяет Q1): по умолчанию стекло
// системное, а если человек двигает ползунок, действует своё значение. Строки «Как в системе» на
// доске нет, это добавка приложения: её высоту сверяющие тесты вычитают из сдвига групп ниже.
//
// Третья группа, «Темы» (шесть готовых троек из `themePresets`), тоже добавка приложения по просьбе
// владельца 30.10 («нет пресетов тем»). Она стоит последней, поэтому рамки доски выше не сдвигает.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_accent_name.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_color_sheet.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_level.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_preview.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_slider.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_theme_presets.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Открывает страницу оформления.
Future<void> openIos27Appearance(BuildContext context) => pushIos27Page<void>(
      context,
      titleBuilder: (c) => AppLocalizations.of(c).m3eAppearanceTitle,
      builder: (_) => const Ios27AppearanceBody(),
    );

/// Тело страницы «Оформление»: колонка групп под заголовком `Ios27Page`.
class Ios27AppearanceBody extends ConsumerWidget {
  const Ios27AppearanceBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final useOwn = ref.watch(ios27UseOwnColorsProvider);
    final provider = ref.watch(ios27ProviderThemeProvider);
    final own = ref.watch(ios27OwnThemeProvider);
    final actions = ref.read(ios27OwnColorActionsProvider);
    final glassSystem = ref.watch(ios27GlassSystemProvider);
    final glassActions = ref.read(ios27GlassLevelActionsProvider);
    final glassToggle =
        glassSystem ? glassActions.useOwn : glassActions.useSystem;

    // Образец режима: три цвета секторами по 120° (`trio`, app.js:585). Цвета сырые, без подгонки
    // контраста: на образце видно то, что прислал провайдер или выбрал человек.
    Widget swatch(Ios27ProviderTheme theme) => Ios27RowSwatch.trio(
          key: const ValueKey<String>('page.rowSwatch'),
          accent: Ios27Rgb.fromHex(theme.accent).color,
          orb1: Ios27Rgb.fromHex(theme.orb1).color,
          orb2: Ios27Rgb.fromHex(theme.orb2).color,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27GroupHead(l10n.ios27GlassTitle),
        Ios27List(
          children: [
            // Превью и строка «Как в системе» одним ребёнком: между ними разделителя нет, как и
            // между превью и ползунком на доске.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Ios27GlassPreview(),
                Ios27ListRow(
                  semanticIdentifier: 'dw_appearance_glass_system',
                  title: l10n.m3eLangSystem,
                  trailing: Ios27Toggle(
                    key: const ValueKey<String>('page.glassSystemSwitch'),
                    value: glassSystem,
                    onChanged: (_) => glassToggle(),
                  ),
                  onTap: glassToggle,
                ),
              ],
            ),
            const Ios27GlassSliderRow(),
          ],
        ),
        const Ios27Gap(),
        Ios27GroupHead(l10n.ios27AppearanceColors),
        Ios27List(
          children: [
            Ios27ListRow(
              leading: swatch(provider),
              separatorInset: kIos27RowSeparatorInsetSwatch,
              title: l10n.ios27AppearanceProvider,
              accessory:
                  useOwn ? Ios27RowAccessory.none : Ios27RowAccessory.check,
              onTap: actions.useProvider,
              semanticIdentifier: 'dw_appearance_provider',
            ),
            Ios27ListRow(
              leading: swatch(own),
              separatorInset: kIos27RowSeparatorInsetSwatch,
              title: l10n.ios27AppearanceOwn,
              accessory:
                  useOwn ? Ios27RowAccessory.check : Ios27RowAccessory.none,
              onTap: actions.enable,
              semanticIdentifier: 'dw_appearance_own',
            ),
          ],
        ),
        if (useOwn) ...[
          const Ios27Gap(),
          Ios27List(
            children: [
              for (final slot in Ios27ColorSlot.values)
                Ios27ListRow(
                  title: ios27SlotLabel(l10n, slot),
                  trailing: Ios27RowWell(
                    key: const ValueKey<String>('page.well'),
                    color: Ios27Rgb.fromHex(own.slot(slot)).color,
                  ),
                  onTap: () => showIos27ColorSheet(context, slot),
                  semanticIdentifier: 'dw_appearance_well_${slot.name}',
                ),
            ],
          ),
        ],
        // Готовые темы: на доске группы нет, она добавлена по просьбе владельца (30.10).
        const Ios27Gap(),
        const Ios27ThemePresetsSection(),
      ],
    );
  }
}
