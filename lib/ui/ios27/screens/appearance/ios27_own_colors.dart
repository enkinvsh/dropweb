// Свои цвета iOS-оформления: чтение (три слота) и запись (включить, выбрать, вернуть провайдера).
//
// Три слота доски (`SLOTS`, app.js:128): акцент (общий с Android, `m3eOwnColor`), фон сверху и
// фон снизу (`ios27OwnOrb1/2`, решение владельца В1). Итоговую тему приложения собирает
// `ios27ThemeProvider` (ios27_theme_source.dart): здесь только то, что нужно странице «Оформление».

import 'package:dropweb/models/config.dart' show ThemeProps;
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/m3e/theme/m3e_own_color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart' show m3eHexOf;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Три своих цвета для образца «Свои» и колодцев: сохранённый слот или цвет провайдера.
///
/// Не зависит от того, включены ли «Свои»: на доске `own = st.own || {…провайдер}`
/// (app.js:613), и образец «Свои» всегда показывает три цвета, которые получатся при включении.
/// Незаданный слот остаётся цветом провайдера (как `ensureOwn`, app.js:415, только живой: смена
/// цвета провайдера доезжает до слота, который пользователь не трогал). Значения сырые
/// (`#RRGGBB`), без подгонки контраста: так их показывают образцы и колодцы на доске.
final ios27OwnThemeProvider = Provider<Ios27ProviderTheme>((ref) {
  final provider = ref.watch(ios27ProviderThemeProvider);
  final (accent, orb1, orb2) = ref.watch(
    themeSettingProvider.select(
      (t) => (t.m3eOwnColor, t.ios27OwnOrb1, t.ios27OwnOrb2),
    ),
  );
  return provider.withOwn(
    accent: accent == null ? null : m3eHexOf(accent),
    orb1: orb1 == null ? null : m3eHexOf(orb1),
    orb2: orb2 == null ? null : m3eHexOf(orb2),
  );
});

/// ARGB непрозрачного цвета из `#RRGGBB`.
int ios27ArgbOfHex(String hex) {
  final rgb = Ios27Rgb.fromHex(hex);
  return 0xFF000000 | (rgb.r << 16) | (rgb.g << 8) | rgb.b;
}

/// Запись своих цветов. Зеркалит `M3eOwnColorActions` Android: возврат к провайдеру не стирает
/// выбранные цвета, выбор цвета включает «Свои» сразу.
class Ios27OwnColorActions {
  const Ios27OwnColorActions(this._ref);

  final Ref _ref;

  /// Включает «Свои». Слоты не трогает: пока ничего не выбрано, цвета остаются цветами
  /// провайдера, и включение ничего не перекрашивает (как `ensureOwn`, app.js:415).
  ///
  /// `M3eOwnColorActions.enable` здесь нельзя: он записывает в акцент семя Android, а оно у
  /// DROPWEB подменено на `#38BDF8` (`m3eSeedFor`), и включение «Своих» перекрасило бы iOS.
  void enable() {
    _ref.read(themeSettingProvider.notifier).updateState(
          (t) => t.copyWith(m3eOwnColorEnabled: true),
        );
  }

  /// Возвращает цвета провайдера; выбранные свои остаются сохранёнными.
  void useProvider() => _ref.read(m3eOwnColorActionsProvider).useProvider();

  /// Выбирает [hex] (`#RRGGBB`) для [slot] и включает «Свои».
  void pick(Ios27ColorSlot slot, String hex) {
    final argb = ios27ArgbOfHex(hex);
    switch (slot) {
      case Ios27ColorSlot.accent:
        // Общее с Android поле: запись и включение делает его же действие.
        _ref.read(m3eOwnColorActionsProvider).pick(argb);
      case Ios27ColorSlot.orb1:
        _write((t) => t.copyWith(m3eOwnColorEnabled: true, ios27OwnOrb1: argb));
      case Ios27ColorSlot.orb2:
        _write((t) => t.copyWith(m3eOwnColorEnabled: true, ios27OwnOrb2: argb));
    }
  }

  /// Применяет готовую тему целиком: все три слота разом и «Свои» включены.
  ///
  /// Одна запись вместо трёх `pick`: интерфейс перекрашивается за один кадр, а не тремя ступенями
  /// (акцент, потом фон сверху, потом фон снизу). Значения кладутся в том же виде, что и у колодцев
  /// (`0xFF000000 | RGB`), поэтому «активна ли тема» сводится к сравнению трёх чисел. Включение идёт
  /// мимо `M3eOwnColorActions.enable` по той же причине, что в [enable].
  void applyTheme({required int accent, required int orb1, required int orb2}) {
    _write(
      (t) => t.copyWith(
        m3eOwnColorEnabled: true,
        m3eOwnColor: _opaque(accent),
        ios27OwnOrb1: _opaque(orb1),
        ios27OwnOrb2: _opaque(orb2),
      ),
    );
  }

  static int _opaque(int argb) => 0xFF000000 | (argb & 0xFFFFFF);

  void _write(ThemeProps Function(ThemeProps) change) =>
      _ref.read(themeSettingProvider.notifier).updateState(change);
}

final ios27OwnColorActionsProvider =
    Provider<Ios27OwnColorActions>(Ios27OwnColorActions.new);
