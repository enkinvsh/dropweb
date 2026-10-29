import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../color/color.dart';
import 'm3e_theme_scope.dart';
import 'm3e_theme_source.dart';

/// Цвета M3E для контекста, который может стоять выше `M3eThemeScope`.
///
/// Корневой навигатор (`navigatorKey.currentContext`, из него открываются диалоги и
/// листы автопредложений) лежит выше тела экрана, где живёт `M3eThemeScope`. Поэтому
/// без темы выше цвета строятся из провайдера [m3eThemeSourceProvider] так же, как это
/// делает сам `M3eThemeScope`, а яркость берётся от системы. Требует `ProviderScope`
/// выше контекста.
M3eColors m3eColorsFor(BuildContext context) {
  final inherited = context.dependOnInheritedWidgetOfExactType<M3eColors>();
  if (inherited != null) return inherited;
  final source =
      ProviderScope.containerOf(context).read(m3eThemeSourceProvider);
  final brightness = MediaQuery.platformBrightnessOf(context);
  final dark = brightness == Brightness.dark;
  return M3eColors(
    scheme: scheme(source.seed, source.filter, dark: dark),
    home: homeVars(source.seed, source.filter, dark: dark),
    brightness: brightness,
    child: const SizedBox.shrink(),
  );
}
