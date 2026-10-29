import 'dart:ui' show PlatformDispatcher;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/m3e_list.dart';
import '../widgets/m3e_page.dart';

/// Ключ списка и пунктов страницы «Язык»: имена из `test/m3e/ref/layout.json`
/// (сцены `language-<тема>-p<N>`).
const Key kM3eLanguageListKey = ValueKey<String>('m3e.list');

/// Ключ пункта страницы «Язык»; нулевой — «Как в системе».
Key m3eLanguageItemKey(int index) => ValueKey<String>('m3e.list.item.$index');

/// Языки, которые умеет приложение, в порядке доски: ru, en, ja, zh. Код записывается в
/// `AppSettingProps.locale` строкой `Locale.toString()`, как делает старый список.
const List<Locale> kM3eLanguages = [
  Locale('ru'),
  Locale('en'),
  Locale('ja'),
  Locale('zh', 'CN'),
];

/// Название языка на нём самом. Таблица своя, не `Intl.message`: язык в списке должен
/// читаться, даже если интерфейс сейчас на другом (человек ищет «свой» язык глазами).
String m3eLanguageNativeName(Locale locale) {
  switch (locale.languageCode) {
    case 'ru':
      return 'Русский';
    case 'en':
      return 'English';
    case 'ja':
      return '日本語';
    case 'zh':
      return '简体中文';
  }
  return locale.toString();
}

/// Строка из `AppSettingProps.locale` в `Locale` (`zh_CN` → zh, CN). `null` — «как в
/// системе».
Locale? m3eLocaleFromSetting(String? value) {
  if (value == null) return null;
  final parts = value.split('_');
  if (parts.length == 1) return Locale(parts[0]);
  if (parts.length == 2) return Locale(parts[0], parts[1]);
  return null;
}

/// Страница «Язык»: `PAGES.language` доски (android.js 484–488). Первый пункт —
/// «Как в системе» (подпись — родное имя языка системы), дальше четыре языка. Все с
/// радиокнопкой; выбор сразу пишется в настройки, как в старом списке.
///
/// [systemLocale] нужен тестам: по умолчанию берётся язык платформы.
class M3eLanguagePage extends ConsumerWidget {
  const M3eLanguagePage({super.key, this.systemLocale});

  final Locale? systemLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = m3eLocaleFromSetting(
      ref.watch(appSettingProvider.select((s) => s.locale)),
    );
    final system = systemLocale ?? PlatformDispatcher.instance.locale;

    void choose(Locale? locale) {
      ref.read(appSettingProvider.notifier).updateState(
            (s) => s.copyWith(locale: locale?.toString()),
          );
    }

    return M3ePage(
      title: l10n.language,
      body: KeyedSubtree(
        key: kM3eLanguageListKey,
        child: M3eList(
          semanticLabel: l10n.language,
          children: [
            M3eListItem(
              key: m3eLanguageItemKey(0),
              label: l10n.m3eLangSystem,
              sup: m3eLanguageNativeName(system),
              lead: M3eListLead.radio(current == null),
              radioChecked: current == null,
              onTap: () => choose(null),
            ),
            for (var i = 0; i < kM3eLanguages.length; i++)
              M3eListItem(
                key: m3eLanguageItemKey(i + 1),
                label: m3eLanguageNativeName(kM3eLanguages[i]),
                lead: M3eListLead.radio(current == kM3eLanguages[i]),
                radioChecked: current == kM3eLanguages[i],
                onTap: () => choose(kM3eLanguages[i]),
              ),
          ],
        ),
      ),
    );
  }
}
