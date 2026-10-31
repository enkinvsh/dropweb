// Группа «Темы» на странице «Оформление»: готовые темы из `themePresets` одним нажатием.
//
// На доске такой группы нет: владелец после TestFlight 2050000029 написал «нет пресетов тем»
// (30.10). В Lumina они были на странице тем, у Android M3E лежат прямо на «Оформлении» плитками
// основных цветов. Здесь это обычный список с кружком-образцом и галочкой, как «Провайдер» / «Свои»
// выше: тот же компонент и тот же отступ разделителя.

import 'package:dropweb/common/constant.dart' show ThemePreset, themePresets;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ обёртки группы. Группа не входит в раскладку доски, и сверка с её рамками (`page.group`,
/// `page.row`, …) отбрасывает всё, что лежит под этим ключом.
const ValueKey<String> kIos27ThemesKey = ValueKey<String>('page.themes');

/// Название готовой темы. Ключи те же, что у старого экрана тем (`lib/views/theme.dart`).
String ios27ThemeName(AppLocalizations l10n, ThemePreset preset) {
  switch (preset.nameKey) {
    case 'presetEmerald':
      return l10n.presetEmerald;
    case 'presetFrost':
      return l10n.presetFrost;
    case 'presetAmethyst':
      return l10n.presetAmethyst;
    case 'presetCrimson':
      return l10n.presetCrimson;
    case 'presetAmber':
      return l10n.presetAmber;
    case 'presetStealth':
      return l10n.presetStealth;
    default:
      // Ключ без перевода показываем как есть: пустая строка спрятала бы строку из списка.
      return preset.nameKey;
  }
}

/// Номер активной темы в [themePresets] или `null`.
///
/// Активна та, у которой «Свои» включены и все три сохранённых слота совпали с темой. Сравнение
/// идёт по RGB без альфы: слоты лежат как `0xFF000000 | RGB`, в `themePresets` тоже непрозрачные
/// цвета, но совпадение не должно зависеть от того, кто из них что дописал в старший байт.
/// Возврат к провайдеру галочку снимает, а сохранённые значения не стирает (правило «Своих»).
final ios27ActiveThemeProvider = Provider<int?>((ref) {
  final (enabled, accent, orb1, orb2) = ref.watch(
    themeSettingProvider.select(
      (t) =>
          (t.m3eOwnColorEnabled, t.m3eOwnColor, t.ios27OwnOrb1, t.ios27OwnOrb2),
    ),
  );
  if (!enabled || accent == null || orb1 == null || orb2 == null) {
    return null;
  }
  bool same(int a, int b) => (a & 0xFFFFFF) == (b & 0xFFFFFF);
  for (var i = 0; i < themePresets.length; i++) {
    final p = themePresets[i];
    if (same(accent, p.accent) &&
        same(orb1, p.orbPrimary) &&
        same(orb2, p.orbSecondary)) {
      return i;
    }
  }
  return null;
});

/// Заголовок «Темы» и список готовых тем.
class Ios27ThemePresetsSection extends ConsumerWidget {
  const Ios27ThemePresetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(ios27ActiveThemeProvider);
    final actions = ref.read(ios27OwnColorActionsProvider);

    // Один ключ на заголовок и список: так сверка с доской отбрасывает группу целиком.
    return KeyedSubtree(
      key: kIos27ThemesKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Ios27GroupHead(l10n.ios27AppearanceThemes),
          Ios27List(
            children: [
              for (var i = 0; i < themePresets.length; i++)
                _row(l10n, themePresets[i], i, i == active, actions),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    AppLocalizations l10n,
    ThemePreset preset,
    int index,
    bool active,
    Ios27OwnColorActions actions,
  ) =>
      Ios27ListRow(
        // Образец показывает три цвета темы сырыми, без подгонки контраста: так же, как образцы
        // «Провайдер» и «Свои» выше. Свой ключ, чтобы не путаться с их `page.rowSwatch`.
        leading: Ios27RowSwatch.trio(
          key: const ValueKey<String>('page.themeSwatch'),
          accent: Color(preset.accent),
          orb1: Color(preset.orbPrimary),
          orb2: Color(preset.orbSecondary),
        ),
        separatorInset: kIos27RowSeparatorInsetSwatch,
        title: ios27ThemeName(l10n, preset),
        accessory: active ? Ios27RowAccessory.check : Ios27RowAccessory.none,
        onTap: () => actions.applyTheme(
          accent: preset.accent,
          orb1: preset.orbPrimary,
          orb2: preset.orbSecondary,
        ),
        semanticIdentifier: 'dw_appearance_theme_$index',
      );
}
