// Подпись «Оформления» в настройках: «Провайдер» или «Свои» (доска, app.js:581 `accentName`).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/theme/m3e_own_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Включены ли «Свои» цвета (`st.useOwn` доски). Тот же флаг, что у Android, чтобы настройка
/// «провайдер или свои» не расходилась между оболочками.
final ios27UseOwnColorsProvider = Provider<bool>(
  (ref) => ref.watch(m3eOwnColorEnabledProvider),
);

/// Правая подпись строки «Оформление» на странице настроек.
///
/// Берите флаг из [ios27UseOwnColorsProvider]: `ios27AccentName(l10n, useOwn: ref.watch(ios27UseOwnColorsProvider))`.
String ios27AccentName(AppLocalizations l10n, {required bool useOwn}) =>
    useOwn ? l10n.ios27AppearanceOwn : l10n.ios27AppearanceProvider;
