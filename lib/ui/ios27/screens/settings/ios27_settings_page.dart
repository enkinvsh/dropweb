// Страница «Настройки» iOS-редизайна (доска app.js:600-604).
//
// Группа из двух строк («Язык», «Оформление»), зазор и «О программе». Больше на доске ничего
// нет, и в магазинной iOS-сборке добавлять нечего: «Проверить обновления» и «Поддержать
// проект» здесь не рисуются вовсе (R10, правила App Store), а не прячутся.
//
// НЕ ПОТЕРЯТЬ из Android (`m3e_settings.dart`): пять быстрых нажатий по заголовку включают
// режим разработчика, и под основной группой появляются входы в старые экраны. Идентификатор
// заголовка `dw_settings_title` нужен UI-автотестам.

import 'dart:async';

import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_toast.dart' show M3eToastKind;
import 'package:dropweb/ui/ios27/screens/about/ios27_about_page.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_accent_name.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_appearance_page.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_language_page.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_route.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/screens/m3e_language.dart'
    show m3eLanguageNativeName, m3eLocaleFromSetting;
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/config/config.dart';
import 'package:dropweb/views/developer.dart';
import 'package:dropweb/widgets/scaffold.dart' show CommonScaffold;
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Идентификатор крупного заголовка для UI-автотестов: тот же, что на Android
/// (`kM3eSettingsTitleIdentifier`) и на заголовке старого листа настроек.
const String kIos27SettingsTitleIdentifier = 'dw_settings_title';

/// Ключ строки «Язык» (имена остальных строк берутся из `page.row`, как на доске).
const Key kIos27SettingsLanguageKey =
    ValueKey<String>('ios27.settings.language');

/// Ключи строк режима разработчика: на доске их нет, поэтому имена не из `layout.json`.
const Key kIos27SettingsConfigKey = ValueKey<String>('ios27.settings.config');
const Key kIos27SettingsApplicationKey =
    ValueKey<String>('ios27.settings.application');
const Key kIos27SettingsDeveloperKey =
    ValueKey<String>('ios27.settings.developer');

/// Пять быстрых нажатий по заголовку (3 с окна, `DevUnlockCounter`) включают режим разработчика.
///
/// Живёт столько же, сколько открытая страница: счётчик заводит [openIos27Settings]. Состояние
/// читается через [ProviderContainer], потому что нажатие приходит из заголовка страницы,
/// который сам не знает про Riverpod.
class Ios27DevUnlock {
  Ios27DevUnlock(
    this._container, {
    DevUnlockCounter? counter,
    void Function(String text)? notify,
  })  : _counter = counter ?? DevUnlockCounter(),
        _notify = notify ?? _showTip;

  final ProviderContainer _container;
  final DevUnlockCounter _counter;
  final void Function(String text) _notify;

  static void _showTip(String text) =>
      globalState.showNotifier(text, kind: M3eToastKind.check);

  /// Нажатие по заголовку.
  void onTitleTap() {
    if (!_counter.registerTap()) {
      return;
    }
    if (_container.read(appSettingProvider).developerMode) {
      return;
    }
    _container
        .read(appSettingProvider.notifier)
        .updateState((s) => s.copyWith(developerMode: true));
    // `current`, а не контекст открытия: язык мог смениться, пока страница лежала в стопке.
    _notify(AppLocalizations.current.developerModeEnableTip);
  }
}

/// Открывает страницу настроек.
///
/// Заголовок перечитывает язык: пока поверх лежит «Язык», выбор новой локали должен
/// переименовать и эту страницу.
Future<void> openIos27Settings(BuildContext context) {
  final unlock = Ios27DevUnlock(
    ProviderScope.containerOf(context, listen: false),
  );
  return pushIos27LocalizedPage<void>(
    context,
    title: (l) => l.settings,
    titleSemanticsIdentifier: kIos27SettingsTitleIdentifier,
    onTitleTap: unlock.onTitleTap,
    builder: (_) => const Ios27SettingsBody(),
  );
}

/// Открывает старый экран отдельным маршрутом поверх, как делал `OpenDelegate`: он рисует
/// свой фон и заголовок, поэтому в страницу iOS не встраивается.
typedef Ios27LegacyOpener = void Function(
  BuildContext context,
  String title,
  Widget screen,
);

void _openLegacy(BuildContext context, String title, Widget screen) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => CommonScaffold.open(
        key: Key(title),
        onBack: () => Navigator.of(routeContext).pop(),
        title: title,
        body: SafeArea(child: screen),
        disableBackground: true,
        actions: const [],
      ),
    ),
  );
}

/// Тело страницы «Настройки».
///
/// [version] нужен тестам; по умолчанию берётся версия сборки. [onLanguage], [onAppearance],
/// [onAbout] и [openLegacy] подменяют переходы.
class Ios27SettingsBody extends ConsumerWidget {
  const Ios27SettingsBody({
    super.key,
    this.version,
    this.onLanguage,
    this.onAppearance,
    this.onAbout,
    this.openLegacy = _openLegacy,
  });

  final String? version;
  final VoidCallback? onLanguage;
  final VoidCallback? onAppearance;
  final VoidCallback? onAbout;
  final Ios27LegacyOpener openLegacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = m3eLocaleFromSetting(
      ref.watch(appSettingProvider.select((s) => s.locale)),
    );
    final developer =
        ref.watch(appSettingProvider.select((s) => s.developerMode));
    final ownColor = ref.watch(ios27UseOwnColorsProvider);

    // `langName()` доски (app.js:586): «Как в системе», пока язык не выбран, иначе его имя.
    final languageDetail =
        locale == null ? l.m3eLangSystem : m3eLanguageNativeName(locale);
    // `accentName()` доски (app.js:581): общий помощник страницы «Оформление».
    final appearanceDetail = ios27AccentName(l, useOwn: ownColor);
    // На доске «0.10.3» без слова «Версия» (app.js:604), как у Android берётся из сборки.
    final aboutDetail = version ?? globalState.packageInfo.version;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(
          children: [
            Ios27ListRow(
              key: kIos27SettingsLanguageKey,
              leading: const Ios27Avatar.icon(Ios27IconName.globe),
              title: l.language,
              detail: languageDetail,
              accessory: Ios27RowAccessory.chevron,
              onTap: onLanguage ?? () => unawaited(openIos27Language(context)),
            ),
            Ios27ListRow(
              leading: const Ios27Avatar.icon(Ios27IconName.droplet),
              title: l.m3eAppearanceTitle,
              detail: appearanceDetail,
              accessory: Ios27RowAccessory.chevron,
              onTap:
                  onAppearance ?? () => unawaited(openIos27Appearance(context)),
            ),
          ],
        ),
        const Ios27Gap(),
        Ios27List(
          children: [
            Ios27ListRow(
              leading: const Ios27Avatar.icon(Ios27IconName.info),
              title: l.m3eAboutTitle,
              detail: aboutDetail,
              accessory: Ios27RowAccessory.chevron,
              onTap: onAbout ?? () => unawaited(openIos27About(context)),
            ),
          ],
        ),
        // Режим разработчика: то, что было в старом листе настроек. «Всегда включённый VPN» и
        // «Контроль доступа» — понятия Android, на iOS их нет (как и в `shouldShowAccessControl`).
        if (developer) ...[
          const Ios27Gap(),
          Ios27List(
            children: [
              Ios27ListRow(
                key: kIos27SettingsConfigKey,
                leading: const Ios27Avatar.icon(Ios27IconName.layers),
                title: l.basicConfig,
                accessory: Ios27RowAccessory.chevron,
                onTap: () =>
                    openLegacy(context, l.override, const ConfigView()),
              ),
              Ios27ListRow(
                key: kIos27SettingsApplicationKey,
                leading: const Ios27Avatar.icon(Ios27IconName.settings),
                title: l.application,
                accessory: Ios27RowAccessory.chevron,
                onTap: () => openLegacy(
                  context,
                  l.application,
                  const ApplicationSettingView(),
                ),
              ),
              Ios27ListRow(
                key: kIos27SettingsDeveloperKey,
                leading: const Ios27Avatar.icon(Ios27IconName.zap),
                title: l.developerMode,
                accessory: Ios27RowAccessory.chevron,
                onTap: () => openLegacy(
                  context,
                  l.developerMode,
                  const DeveloperView(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
