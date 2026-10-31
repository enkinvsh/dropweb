// Прозрачность стекла: чтение (уровень, «как в системе») и запись для страницы «Оформление».
//
// Доска: ползунок «Стекло» 0..100, стандарт 25 (app.js:213 `GLASS_STD`), слово под ним
// (`glassName`, app.js:425). Решение владельца 30.10: по умолчанию стекло системное, свой
// уровень включается, только если сдвинуть ползунок (поэтому здесь есть «Как в системе», которого
// на доске нет). Итог попадает в стекло через `ios27GlassLevelProvider` (ios27_theme_source.dart).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/config.dart' show ThemeProps;
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Стандартный уровень доски (`GLASS_STD`, app.js:213): четверть шкалы, вид кита iOS по умолчанию.
/// Ползунок показывает его, пока включено «Как в системе», и им же начинается свой уровень.
const int kIos27GlassStandard = 25;

/// Границы ползунка (`min=0 max=100`).
const int kIos27GlassMin = 0;
const int kIos27GlassMax = 100;

/// Шаг для жестов доступности (увеличить/уменьшить): 5, потому что сто шагов по единице
/// VoiceOver-пользователю пролистывать нечем. Палец и клавиатура двигают по единице (`step=1`).
const int kIos27GlassAccessibilityStep = 5;

/// Слово под ползунком и значение для VoiceOver (`glassName`, app.js:425):
/// ниже 17 «Прозрачнее», до 33 «Стандартное», до 85 «Плотнее», выше «Тонированное».
String ios27GlassName(AppLocalizations l10n, int level) {
  if (level < kIos27GlassStandard - 8) {
    return l10n.ios27GlassClearer;
  }
  if (level > kIos27GlassStandard + 8) {
    return level > 85 ? l10n.ios27GlassTinted : l10n.ios27GlassDenser;
  }
  return l10n.ios27GlassStandard;
}

/// Включено ли «Как в системе»: своего уровня нет.
final ios27GlassSystemProvider =
    Provider<bool>((ref) => ref.watch(ios27GlassLevelProvider) == null);

/// Уровень, который показывает ползунок: свой или стандартный, пока стекло системное.
final ios27GlassSliderValueProvider = Provider<int>(
  (ref) => ref.watch(ios27GlassLevelProvider) ?? kIos27GlassStandard,
);

/// Запись уровня. Одно поле `ios27GlassLevel`: `null` значит «Как в системе».
class Ios27GlassLevelActions {
  const Ios27GlassLevelActions(this._ref);

  final Ref _ref;

  /// Свой уровень [level] (0..100); выключает «Как в системе».
  void setLevel(int level) {
    final value = level.clamp(kIos27GlassMin, kIos27GlassMax);
    _write((t) => t.copyWith(ios27GlassLevel: value));
  }

  /// «Как в системе» включено: свой уровень снимается.
  void useSystem() => _write((t) => t.copyWith(ios27GlassLevel: null));

  /// «Как в системе» выключено: стекло остаётся прежним на вид, потому что свой уровень начинается
  /// со стандартного (на уровне 25 нативное стекло и таблица материалов дают то же, что системное).
  void useOwn() => setLevel(kIos27GlassStandard);

  void _write(ThemeProps Function(ThemeProps) change) =>
      _ref.read(themeSettingProvider.notifier).updateState(change);
}

final ios27GlassLevelActionsProvider =
    Provider<Ios27GlassLevelActions>(Ios27GlassLevelActions.new);
