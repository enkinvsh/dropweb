import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState, Tristate;

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_language.dart';
import 'package:dropweb/ui/m3e/screens/m3e_settings.dart';
import 'package:dropweb/ui/m3e/theme/m3e_own_color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Версия доски (`VERSION` в android.js).
const _version = '0.10.3';

/// Настройки приложения без записи в конфиг: `onUpdate` настоящего провайдера лезет в
/// `globalState.configRepository`.
class _FakeAppSetting extends AppSetting {
  _FakeAppSetting(this.props);

  final AppSettingProps props;

  @override
  AppSettingProps build() => props;

  @override
  void onUpdate(AppSettingProps value) {}
}

/// Проверка обновления в процессе: пункт «Проверить обновления» должен быть неактивен.
class _CheckingUpdate extends AppUpdate {
  @override
  AppUpdateState build() =>
      const AppUpdateState(status: AppUpdateStatus.checking);
}

Widget _motionless(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

Widget _settings({
  VoidCallback? onAppearance,
  VoidCallback? onAbout,
  VoidCallback? onCheckUpdate,
  bool showCheckUpdate = false,
  bool showSupport = false,
  double textScale = 1,
}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: M3eSettingsPage(
          version: _version,
          showCheckUpdate: showCheckUpdate,
          showSupport: showSupport,
          onAppearance: onAppearance ?? () {},
          onAbout: onAbout ?? () {},
          onCheckUpdate: onCheckUpdate ?? () {},
        ),
      ),
    );

Widget _language({double textScale = 1}) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        // Система в доске русская: подпись первого пункта «Русский».
        child: const M3eLanguagePage(systemLocale: Locale('ru')),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  AppSettingProps props = const AppSettingProps(),
  List<Override> overrides = const [],
}) async {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      overrides: [
        appSettingProvider.overrideWith(() => _FakeAppSetting(props)),
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: h.accent, filter: h.filter),
        ),
        // Настоящий провайдер читает themeSettingProvider и через него globalState.
        m3eOwnColorEnabledProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: child,
    ),
  );
}

Map<String, dynamic> _elements(String scene) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  return (all[scene] as Map<String, dynamic>)['elements']
      as Map<String, dynamic>;
}

Rect _ref(String scene, String key, [int index = 0]) {
  var e = _elements(scene)[key];
  if (e is List) e = e[index];
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<String>(key)));

void _near(Rect actual, Rect expected, String what) {
  const tolerance = 4.0;
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$what: x');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$what: y');
  expect(actual.width, closeTo(expected.width, tolerance), reason: '$what: w');
  expect(actual.height, closeTo(expected.height, tolerance),
      reason: '$what: h');
}

Brightness _b(String theme) =>
    theme == 'dark' ? Brightness.dark : Brightness.light;

void main() {
  group('golden', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        testWidgets('settings_${theme}_p$p', (tester) async {
          await _pump(tester, _settings(), provider: p, brightness: _b(theme));
          await expectM3eGolden(tester, 'settings_${theme}_p$p');
        });
        testWidgets('language_${theme}_p$p', (tester) async {
          await _pump(tester, _language(), provider: p, brightness: _b(theme));
          await expectM3eGolden(tester, 'language_${theme}_p$p');
        });
      }
    }
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        final settings = 'settings-$theme-p$p';
        testWidgets(settings, (tester) async {
          await _pump(tester, _settings(), provider: p, brightness: _b(theme));
          _near(_rect(tester, 'm3e.bar'), _ref(settings, 'bar'), 'bar');
          _near(_rect(tester, 'm3e.bar.back'), _ref(settings, 'bar.back'),
              'bar.back');
          _near(_rect(tester, 'm3e.page.title'), _ref(settings, 'page.title'),
              'page.title');
          _near(_rect(tester, 'm3e.list'), _ref(settings, 'list'), 'list');
          for (var i = 0; i < 3; i++) {
            _near(_rect(tester, 'm3e.list.item.$i'),
                _ref(settings, 'list.item', i), 'list.item.$i');
          }
        });

        final language = 'language-$theme-p$p';
        testWidgets(language, (tester) async {
          await _pump(tester, _language(), provider: p, brightness: _b(theme));
          _near(_rect(tester, 'm3e.bar'), _ref(language, 'bar'), 'bar');
          _near(_rect(tester, 'm3e.bar.back'), _ref(language, 'bar.back'),
              'bar.back');
          _near(_rect(tester, 'm3e.page.title'), _ref(language, 'page.title'),
              'page.title');
          // В layout.json под страницей «Язык» лежат настройки: второй `list` и пункты 3..7.
          _near(_rect(tester, 'm3e.list'), _ref(language, 'list', 1), 'list');
          for (var i = 0; i < 5; i++) {
            _near(_rect(tester, 'm3e.list.item.$i'),
                _ref(language, 'list.item', 3 + i), 'list.item.$i');
          }
        });
      }
    }
  });

  group('настройки: поведение', () {
    testWidgets('тексты доски и колбэки', (tester) async {
      var appearance = 0, about = 0;
      await _pump(
        tester,
        _settings(onAppearance: () => appearance++, onAbout: () => about++),
      );
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Язык'), findsOneWidget);
      expect(find.text('Как в системе'), findsOneWidget);
      expect(find.text('Оформление'), findsOneWidget);
      expect(find.text('Цвет провайдера'), findsOneWidget);
      expect(find.text('О программе'), findsOneWidget);
      expect(find.text('Версия 0.10.3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.1')));
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.2')));
      expect((appearance, about), (1, 1));
    });

    testWidgets('«Свой цвет» по провайдеру m3eOwnColorEnabledProvider',
        (tester) async {
      await _pump(
        tester,
        _settings(),
        overrides: [m3eOwnColorEnabledProvider.overrideWithValue(true)],
      );
      expect(find.text('Свой цвет'), findsOneWidget);
      expect(find.text('Цвет провайдера'), findsNothing);
    });

    testWidgets('подпись языка: родное имя выбранного', (tester) async {
      await _pump(
        tester,
        _settings(),
        props: const AppSettingProps(locale: 'ja'),
      );
      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('Как в системе'), findsNothing);
    });

    testWidgets('пункт «Язык» открывает страницу «Язык»', (tester) async {
      await _pump(tester, _settings());
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      // «English» встречается дважды: язык платформы в тестах английский, и он же
      // подпись пункта «Как в системе».
      expect(find.byKey(m3eLanguageItemKey(4)), findsOneWidget);
      expect(find.text('简体中文'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Назад» закрывает страницу', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => pushM3ePage<void>(
              context,
              (_) => const M3eSettingsPage(
                version: _version,
                showCheckUpdate: false,
                showSupport: false,
                onAppearance: _noop,
                onAbout: _noop,
                onCheckUpdate: _noop,
              ),
            ),
            child: const Text('Открыть'),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Настройки'), findsOneWidget);
      await tester.tap(find.byKey(kM3ePageBackKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Настройки'), findsNothing);
    });

    testWidgets(
        '«Проверить обновления» и «Поддержать проект» появляются по флагам',
        (tester) async {
      var check = 0;
      await _pump(
        tester,
        _settings(
          showCheckUpdate: true,
          showSupport: true,
          onCheckUpdate: () => check++,
        ),
      );
      expect(find.text('Проверить обновления'), findsOneWidget);
      expect(find.text('Поддержать проект'), findsOneWidget);
      await tester.tap(find.byKey(kM3eSettingsCheckUpdateKey));
      expect(check, 1);
      // Основная группа остаётся ровно на доске.
      _near(
          _rect(tester, 'm3e.list'), _ref('settings-light-p0', 'list'), 'list');
    });

    testWidgets('пока идёт проверка обновления пункт неактивен',
        (tester) async {
      var check = 0;
      await _pump(
        tester,
        _settings(showCheckUpdate: true, onCheckUpdate: () => check++),
        overrides: [appUpdateProvider.overrideWith(_CheckingUpdate.new)],
      );
      expect(find.text('Проверка...'), findsOneWidget);
      await tester.tap(find.byKey(kM3eSettingsCheckUpdateKey));
      expect(check, 0);
    });

    testWidgets('без флагов второй группы нет', (tester) async {
      await _pump(tester, _settings());
      expect(find.byKey(kM3eSettingsMoreListKey), findsNothing);
      expect(find.text('Проверить обновления'), findsNothing);
      expect(find.text('Поддержать проект'), findsNothing);
    });

    testWidgets('режим разработчика открывает входы в старые экраны',
        (tester) async {
      await _pump(
        tester,
        _settings(),
        props: const AppSettingProps(developerMode: true),
      );
      for (final key in [
        kM3eSettingsAlwaysOnKey,
        kM3eSettingsAccessKey,
        kM3eSettingsConfigKey,
        kM3eSettingsApplicationKey,
        kM3eSettingsDeveloperKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });
  });

  group('5 нажатий по заголовку', () {
    Future<void> tapTitle(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tapAt(
          tester.getCenter(find.byKey(kM3ePageTitleKey)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('пятое включает developerMode, четыре — нет', (tester) async {
      await _pump(tester, _settings());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(M3eSettingsPage)),
      );
      await tapTitle(tester, 4);
      expect(container.read(appSettingProvider).developerMode, isFalse);
      expect(find.byKey(kM3eSettingsAlwaysOnKey), findsNothing);
      await tapTitle(tester, 1);
      expect(container.read(appSettingProvider).developerMode, isTrue);
      await tester.pump();
      expect(find.byKey(kM3eSettingsAlwaysOnKey), findsOneWidget);
    });

    testWidgets('нажатия мимо заголовка не считаются', (tester) async {
      await _pump(tester, _settings());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(M3eSettingsPage)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.tapAt(const Offset(200, 700));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(container.read(appSettingProvider).developerMode, isFalse);
    });

    testWidgets('идентификатор dw_settings_title виден в семантике',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _settings());
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == kM3eSettingsTitleIdentifier,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('язык: поведение', () {
    testWidgets('тексты доски', (tester) async {
      await _pump(tester, _language());
      expect(find.text('Язык'), findsOneWidget);
      expect(find.text('Как в системе'), findsOneWidget);
      expect(
          find.text('Русский'), findsNWidgets(2)); // подпись системы и сам язык
      for (final name in ['English', '日本語', '简体中文']) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('смена языка пишет locale; «Как в системе» сбрасывает',
        (tester) async {
      await _pump(tester, _language());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(M3eLanguagePage)),
      );
      expect(container.read(appSettingProvider).locale, isNull);
      await tester.tap(find.byKey(m3eLanguageItemKey(4)));
      await tester.pump();
      expect(container.read(appSettingProvider).locale, 'zh_CN');
      await tester.tap(find.byKey(m3eLanguageItemKey(2)));
      await tester.pump();
      expect(container.read(appSettingProvider).locale, 'en');
      await tester.tap(find.byKey(m3eLanguageItemKey(0)));
      await tester.pump();
      expect(container.read(appSettingProvider).locale, isNull);
    });

    testWidgets('семантика радио: выбран один пункт', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _language(),
        props: const AppSettingProps(locale: 'ja'),
      );
      for (var i = 0; i < 5; i++) {
        final data = tester
            .getSemantics(find.byKey(m3eLanguageItemKey(i)))
            .getSemanticsData();
        expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue,
            reason: 'item $i');
        expect(
          data.flagsCollection.isChecked,
          i == 3 ? CheckedState.isTrue : CheckedState.isFalse,
          reason: 'item $i',
        );
      }
      expect(Tristate.isTrue, isNot(Tristate.isFalse));
      handle.dispose();
    });

    testWidgets('языки приложения совпадают со списком страницы',
        (tester) async {
      final supported = {
        'ru',
        'en',
        'ja',
        'zh_CN',
      };
      expect(
        kM3eLanguages.map((l) => l.toString()).toSet(),
        supported,
      );
    });
  });

  group('WORST', () {
    testWidgets('шрифт 2.0: настройки без overflow', (tester) async {
      await _pump(
        tester,
        _settings(
          textScale: 2,
          showCheckUpdate: true,
          showSupport: true,
        ),
        props: const AppSettingProps(locale: 'zh_CN', developerMode: true),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('шрифт 2.0: язык без overflow', (tester) async {
      await _pump(tester, _language(textScale: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('длинная версия в подписи не ломает раскладку', (tester) async {
      await _pump(
        tester,
        _motionless(
          M3eSettingsPage(
            version: '10.222.3333-beta.4444+2050000023-extra-long-build-tag',
            showCheckUpdate: false,
            showSupport: false,
            onAppearance: () {},
            onAbout: () {},
            onCheckUpdate: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'm3e.list.item.2').height, 72);
    });
  });
}

void _noop() {}
