// Страница «Язык» iOS-редизайна (доска app.js:605-607, LANGS app.js:197).
//
// Список из пяти строк: «Как в системе» (подпись — язык системы) и четыре языка приложения.
// Выбранная строка помечена галочкой цвета акцента. Выбор применяется сразу, как в Android:
// пишется в `AppSettingProps.locale`, а приложение пересобирается уже на новом языке.

import 'dart:ui' show PlatformDispatcher;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_route.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/screens/m3e_language.dart'
    show kM3eLanguages, m3eLanguageNativeName, m3eLocaleFromSetting;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Открывает страницу «Язык».
Future<void> openIos27Language(BuildContext context) =>
    pushIos27LocalizedPage<void>(
      context,
      title: (l) => l.language,
      builder: (_) => const Ios27LanguageBody(),
    );

/// Тело страницы «Язык».
///
/// [systemLocale] нужен тестам: по умолчанию берётся язык платформы, он же стоит подписью
/// под «Как в системе».
class Ios27LanguageBody extends ConsumerWidget {
  const Ios27LanguageBody({super.key, this.systemLocale});

  final Locale? systemLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = m3eLocaleFromSetting(
      ref.watch(appSettingProvider.select((s) => s.locale)),
    );
    final system = systemLocale ?? PlatformDispatcher.instance.locale;

    void choose(Locale? locale) {
      ref.read(appSettingProvider.notifier).updateState(
            (s) => s.copyWith(locale: locale?.toString()),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(
          children: [
            Ios27ListRow(
              title: l.m3eLangSystem,
              subtitle: m3eLanguageNativeName(system),
              accessory: current == null
                  ? Ios27RowAccessory.check
                  : Ios27RowAccessory.none,
              onTap: () => choose(null),
            ),
            for (final locale in kM3eLanguages)
              Ios27ListRow(
                title: m3eLanguageNativeName(locale),
                accessory: current == locale
                    ? Ios27RowAccessory.check
                    : Ios27RowAccessory.none,
                onTap: () => choose(locale),
              ),
          ],
        ),
      ],
    );
  }
}
