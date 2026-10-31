// Источник цвета iOS-редизайна: три цвета провайдера из `themeSettingProvider` и свой цвет пользователя.
//
// Заголовок `dropweb-theme` пишет в `themeSettingProvider` `ProfileService._applyDropwebTheme`; сюда
// он приходит уже разобранным в `ThemeProps`. На доске тот же разбор делает `parseTheme` (app.js:77-82),
// а «Свои» цвета — `st.own` (app.js:410-415).

import 'package:dropweb/common/constant.dart' show defaultPrimaryColor;
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart' show m3eHexOf;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Размытие орбов: доска зажимает `blur` в 1..5 и при нуле или не-числе берёт 3 (`parseTheme`, app.js:81).
double _blurOf(double blur) {
  if (blur.isNaN || blur == 0) {
    return 3;
  }
  return blur.clamp(1, 5).toDouble();
}

/// Цвета провайдера подписки: акцент, верхний и нижний орб фона, размытие.
///
/// Подмены `#29FF76` на `#38BDF8` здесь НЕТ: это решение владельца только для Android
/// (`m3eSeedFor`). На iOS цвет по умолчанию — цвет по умолчанию доски: `#29FF76` из
/// `parseTheme(PROVIDERS[0].theme)`, и провайдер DROPWEB, который шлёт именно его, остаётся
/// зелёным. Пустой орб следует за акцентом, как на доске.
///
/// Свой цвет пользователя сюда не входит: он нужен образцу «Цвет провайдера» в «Оформлении»,
/// который показывает цвет подписки, а не итог. Итог — [ios27ThemeProvider].
final ios27ProviderThemeProvider = Provider<Ios27ProviderTheme>((ref) {
  final (primary, orb1, orb2, blur) = ref.watch(
    themeSettingProvider.select(
      (t) =>
          (t.primaryColor, t.orbColorPrimary, t.orbColorSecondary, t.orbBlur),
    ),
  );
  final accent = m3eHexOf(primary ?? defaultPrimaryColor);
  return Ios27ProviderTheme(
    accent: accent,
    orb1: orb1 == null ? accent : m3eHexOf(orb1),
    orb2: orb2 == null ? accent : m3eHexOf(orb2),
    blur: _blurOf(blur),
  );
});

/// Итоговая тема новых экранов: при включённых «Своих» цветах заменяются заданные слоты.
///
/// Слотов три, как на доске (`SLOTS`, app.js:128): акцент (общий с Android, `m3eOwnColor`),
/// фон сверху и фон снизу (`ios27OwnOrb1/2`, решение владельца В1). Незаданный слот (null)
/// остаётся цветом провайдера: `ensureOwn` на доске начинает свои цвета с цветов провайдера
/// (app.js:413-415), поэтому включение «Своих» без выбора ничего не перекрашивает. Размытие
/// всегда провайдерское.
final ios27ThemeProvider = Provider<Ios27ProviderTheme>((ref) {
  final provider = ref.watch(ios27ProviderThemeProvider);
  final (enabled, accent, orb1, orb2) = ref.watch(
    themeSettingProvider.select(
      (t) => (
        t.m3eOwnColorEnabled,
        t.m3eOwnColor,
        t.ios27OwnOrb1,
        t.ios27OwnOrb2,
      ),
    ),
  );
  if (!enabled) {
    return provider;
  }
  return provider.withOwn(
    accent: accent == null ? null : m3eHexOf(accent),
    orb1: orb1 == null ? null : m3eHexOf(orb1),
    orb2: orb2 == null ? null : m3eHexOf(orb2),
  );
});

/// Ползунок «Стекло» (0..100, `--lg` доски, app.js:424). `null` — «как в системе»: это значение по
/// умолчанию и то, что лежит в `ThemeProps`, пока пользователь не двигал ползунок. На iOS 26+ это
/// системное жидкое стекло как есть, на iOS 13–25 — стандарт доски (`GLASS_STD = 25`, app.js:213).
/// Отдельный провайдер, чтобы смена ползунка не перестраивала всё, что читает цвета.
final ios27GlassLevelProvider = Provider<int?>(
  (ref) => ref.watch(themeSettingProvider.select((t) => t.ios27GlassLevel)),
);
