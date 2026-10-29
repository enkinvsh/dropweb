import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/config.dart';
import '../color/color.dart' show argbFromHexOrNull;
import 'm3e_theme_source.dart';

/// Включён ли свой цвет приложения («Оформление» → «Свой цвет»).
final m3eOwnColorEnabledProvider = Provider<bool>(
  (ref) => ref.watch(themeSettingProvider.select((t) => t.m3eOwnColorEnabled)),
);

/// Сохранённый свой цвет (ARGB) или `null`, если его ещё не выбирали.
final m3eOwnColorProvider = Provider<int?>(
  (ref) => ref.watch(themeSettingProvider.select((t) => t.m3eOwnColor)),
);

/// Операции над своим цветом. Поля живут в `ThemeProps` отдельно от `primaryColor`:
/// обновление профиля с другим `dropweb-theme` их не трогает.
class M3eOwnColorActions {
  const M3eOwnColorActions(this._ref);

  final Ref _ref;

  /// Включает свой цвет. Первое включение берёт акцент текущей подписки (как `ensureOwn`
  /// на доске), чтобы схема не прыгала, пока человек ещё ничего не выбрал.
  void enable() {
    final saved = _ref.read(m3eOwnColorProvider);
    final fallback = argbFromHexOrNull(
      _ref.read(m3eProviderSourceProvider).seed,
    )!;
    _ref.read(themeSettingProvider.notifier).updateState(
          (t) => t.copyWith(
            m3eOwnColorEnabled: true,
            m3eOwnColor: saved ?? fallback,
          ),
        );
  }

  /// Выбирает цвет и включает свой цвет сразу, без отдельного шага.
  void pick(int argb) {
    _ref.read(themeSettingProvider.notifier).updateState(
          (t) => t.copyWith(
            m3eOwnColorEnabled: true,
            m3eOwnColor: 0xFF000000 | (argb & 0xFFFFFF),
          ),
        );
  }

  /// Возвращает цвет провайдера; выбранный свой цвет остаётся сохранённым.
  void useProvider() {
    _ref.read(themeSettingProvider.notifier).updateState(
          (t) => t.copyWith(m3eOwnColorEnabled: false),
        );
  }
}

final m3eOwnColorActionsProvider =
    Provider<M3eOwnColorActions>(M3eOwnColorActions.new);
