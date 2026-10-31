// Общая обвязка тестов экранов «Настройки» и «Язык» iOS-редизайна (не тестовый файл).

import 'package:dropweb/models/config.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_page.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';

/// Настройки приложения без записи в конфиг: `onUpdate` настоящего провайдера лезет в
/// `globalState.configRepository`, которого в тесте нет.
class FakeAppSetting extends AppSetting {
  FakeAppSetting(this.props);

  final AppSettingProps props;

  @override
  AppSettingProps build() => props;

  @override
  void onUpdate(AppSettingProps value) {}
}

/// Тема без обращения к `globalState` (приём `layer_harness.dart`), но со своим цветом.
class FakeThemeSetting extends ThemeSetting {
  FakeThemeSetting(this.props);

  final ThemeProps props;

  @override
  ThemeProps build() => props;

  @override
  void onUpdate(ThemeProps value) {}
}

/// Переопределения для экранов настроек: язык, режим разработчика, свой цвет.
List<Override> settingsOverrides({
  String? locale,
  bool developerMode = false,
  bool ownColor = false,
}) =>
    [
      appSettingProvider.overrideWith(
        () => FakeAppSetting(
          AppSettingProps(locale: locale, developerMode: developerMode),
        ),
      ),
      themeSettingProvider.overrideWith(
        () => FakeThemeSetting(
          ThemeProps(
            m3eOwnColorEnabled: ownColor,
            m3eOwnColor: ownColor ? 0xFFFF2D55 : null,
          ),
        ),
      ),
    ];

/// Версия сборки на доске (`app.js:604`).
const String kBoardVersion = '0.10.3';

/// Цвета i-го провайдера доски.
Ios27ProviderTheme providerTheme(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

/// Элементы страницы, у которых есть рамки в `layout.json` (имена ключей `page.*`).
Map<String, Finder> pageElements() => {
      'page': find.byKey(const ValueKey('page')),
      'page.nav': find.byKey(const ValueKey('page.nav')),
      'page.back': find.byKey(const ValueKey('page.back')),
      'page.small': find.byKey(const ValueKey('page.small')),
      'page.title': find.byKey(const ValueKey('page.title')),
      'page.group': find.byKey(const ValueKey('page.group')),
      'page.row': find.byKey(const ValueKey('page.row')),
      'page.rowTitle': find.byKey(const ValueKey('page.rowTitle')),
      'page.rowDetail': find.byKey(const ValueKey('page.rowDetail')),
      'page.rowIcon': find.byKey(const ValueKey('page.rowIcon')),
      'page.rowCheck': find.byKey(const ValueKey('page.rowCheck')),
    };

/// Результаты и счётчики стенда с настоящей страницей «Настройки».
class SettingsHarness {
  /// Тексты, которые показал бы тост «Режим разработчика активирован».
  final List<String> tips = [];

  Ios27DevUnlock? unlock;
}
