// Общая обвязка тестов слоёв iOS (тост, алерт, лист): источник темы без globalState.

import 'package:dropweb/models/config.dart';
import 'package:dropweb/providers/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ThemeSetting без обращения к globalState: слои, открытые маршрутом, ставят
/// `Ios27ThemeScope` (из провайдера), а настоящий провайдер читает `globalState.config`, которого
/// в тесте нет (приём из `theme_scope_test.dart`).
class _FakeThemeSetting extends ThemeSetting {
  @override
  ThemeProps build() => const ThemeProps();

  // Смена состояния иначе пишет срез в globalState.configRepository.
  @override
  void onUpdate(ThemeProps value) {}
}

/// Переопределения провайдеров для `ios27BoardApp(overrides: …)`.
List<Override> layerOverrides() => [
      themeSettingProvider.overrideWith(_FakeThemeSetting.new),
    ];
