// Экран «Язык» iOS-редизайна: сверка с доской (рамки ±4 dp, golden), галочка за текущим языком,
// запись выбора в настройки, подпись «Как в системе», смена языка при открытых страницах стека,
// масштаб шрифта и движение.
//
// Иероглифы («日本語», «简体中文»): шрифт теста их не содержит, ширина заглушки другая. Рамки
// этих двух подписей из сверки исключены, координаты и высота строк проверяет `page.row`.

import 'dart:ui' show Tristate;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_language_page.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_page.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'screen_settings_support.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Страница «Язык» как её собирает [openIos27Language], но без маршрута.
Widget _page({Locale systemLocale = const Locale('ru')}) => Builder(
      builder: (context) => Ios27Page(
        title: AppLocalizations.of(context).language,
        child: Ios27LanguageBody(systemLocale: systemLocale),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Brightness brightness = Brightness.light,
  int provider = 0,
  List<Override>? overrides,
  double textScale = 1,
  Ios27Device device = kIos27BoardDevice,
  Locale locale = const Locale('ru'),
}) =>
    pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: brightness,
        theme: providerTheme(provider),
        overrides: overrides ?? settingsOverrides(),
        textScale: textScale,
        device: device,
        locale: locale,
        child: page,
      ),
      device: device,
      locale: locale,
    );

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(Ios27LanguageBody)),
    );

/// Заголовок строки списка. Простой `find.text` неоднозначен: название языка системы стоит ещё
/// и подписью под «Как в системе» («Русский», «English»).
Finder _rowTitle(String text) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.key == const ValueKey('page.rowTitle') &&
          w.data == text,
    );

/// Индексы строк с галочкой (`page.rowCheck` внутри строки).
List<int> _checkedRows(WidgetTester tester) {
  final rows = find.byType(Ios27ListRow);
  final result = <int>[];
  for (var i = 0; i < rows.evaluate().length; i++) {
    final check = find.descendant(
      of: rows.at(i),
      matching: find.byKey(const ValueKey('page.rowCheck')),
    );
    if (check.evaluate().isNotEmpty) {
      result.add(i);
    }
  }
  return result;
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    group('сверка с доской, $mode', () {
      testWidgets('язык: рамки ±4 dp и golden', (tester) async {
        await _pump(tester, _page(), brightness: brightness);
        expectIos27Parity(
          ios27Parity(tester, 'language-$mode-rt-p0', pageElements())
              .where((r) =>
                  r.name != 'page.rowTitle[3]' && r.name != 'page.rowTitle[4]')
              .toList(),
        );
        await expectIos27Golden(tester, 'language_${mode}_p0');
      });
    });
  }

  // Галочка красится акцентом, поэтому p5 (серый провайдер) — единственный кадр, где виден цвет.
  testWidgets('провайдер p5 (серый): рамки те же, галочка другого цвета',
      (tester) async {
    await _pump(tester, _page(), provider: 5);
    expectIos27Parity(
      ios27Parity(tester, 'language-light-rt-p5', pageElements())
          .where((r) =>
              r.name != 'page.rowTitle[3]' && r.name != 'page.rowTitle[4]')
          .toList(),
    );
    await expectIos27Golden(tester, 'language_light_p5');
  });

  group('галочка и запись выбора', () {
    final cases = <(String?, int, String)>[
      (null, 0, 'Как в системе'),
      ('ru', 1, 'Русский'),
      ('en', 2, 'English'),
      ('ja', 3, '日本語'),
      ('zh_CN', 4, '简体中文'),
    ];
    for (final (locale, index, name) in cases) {
      testWidgets('в настройках ${locale ?? 'нет языка'}: галочка у «$name»',
          (tester) async {
        await _pump(
          tester,
          _page(),
          overrides: settingsOverrides(locale: locale),
        );
        expect(find.byType(Ios27ListRow), findsNWidgets(5));
        expect(_checkedRows(tester), [index]);
      });
    }

    testWidgets('галочка переходит вслед за выбором', (tester) async {
      await _pump(tester, _page());
      expect(_checkedRows(tester), [0]);
      await tester.tap(_rowTitle('English'));
      await tester.pump();
      expect(_checkedRows(tester), [2]);
      await tester.tap(_rowTitle('Как в системе'));
      await tester.pump();
      expect(_checkedRows(tester), [0]);
    });

    testWidgets('нажатие пишет язык в настройки: en, zh_CN, ru, затем null',
        (tester) async {
      await _pump(tester, _page());
      String? stored() => _container(tester).read(appSettingProvider).locale;

      expect(stored(), isNull);
      await tester.tap(_rowTitle('English'));
      await tester.pump();
      expect(stored(), 'en');
      await tester.tap(_rowTitle('简体中文'));
      await tester.pump();
      expect(stored(), 'zh_CN');
      await tester.tap(_rowTitle('Русский'));
      await tester.pump();
      expect(stored(), 'ru');
      await tester.tap(_rowTitle('Как в системе'));
      await tester.pump();
      expect(stored(), isNull);
    });

    testWidgets('повторное нажатие на выбранный язык ничего не ломает',
        (tester) async {
      await _pump(tester, _page(), overrides: settingsOverrides(locale: 'en'));
      await tester.tap(_rowTitle('English'));
      await tester.tap(_rowTitle('English'));
      await tester.pump();
      expect(_container(tester).read(appSettingProvider).locale, 'en');
      expect(_checkedRows(tester), [2]);
      expect(tester.takeException(), isNull);
    });
  });

  group('подписи', () {
    testWidgets(
        'под «Как в системе» язык системы: ru, ja, en и запасной вариант',
        (tester) async {
      Future<void> check(Locale system, String expected) async {
        await _pump(tester, _page(systemLocale: system));
        final row = find.byType(Ios27ListRow).first;
        expect(
          find.descendant(of: row, matching: find.text(expected)),
          findsOneWidget,
          reason: 'система $system',
        );
      }

      await check(const Locale('ru'), 'Русский');
      await check(const Locale('ja'), '日本語');
      await check(const Locale('en', 'US'), 'English');
      await check(const Locale('de'), 'de');
    });

    testWidgets('названия языков на себе, как на доске', (tester) async {
      await _pump(tester, _page());
      for (final name in [
        'Как в системе',
        'Русский',
        'English',
        '日本語',
        '简体中文'
      ]) {
        expect(find.text(name), findsWidgets, reason: name);
      }
    });

    testWidgets('английский интерфейс: «Same as system», названия не меняются',
        (tester) async {
      await _pump(tester, _page(), locale: const Locale('en'));
      expect(find.text('Same as system'), findsOneWidget);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Русский'), findsWidgets);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('в экране нет слов «Android» и «Обновление»', (tester) async {
      await _pump(tester, _page());
      final all = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join('\n');
      expect(all, isNot(contains('Android')));
      expect(all, isNot(contains('Обновление')));
    });
  });

  group('семантика', () {
    testWidgets('строки — кнопки, выбранная помечена как выбранная',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _page(), overrides: settingsOverrides(locale: 'en'));
      final rows = find.byType(Ios27ListRow);
      for (var i = 0; i < 5; i++) {
        final data = tester.getSemantics(rows.at(i)).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue, reason: 'строка $i');
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        expect(
          data.flagsCollection.isSelected == Tristate.isTrue,
          i == 2,
          reason: 'выбрана только «English», строка $i',
        );
      }
      handle.dispose();
    });

    testWidgets('подпись первой строки читается целиком', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _page());
      final data = tester
          .getSemantics(find.byType(Ios27ListRow).first)
          .getSemanticsData();
      expect(data.label, contains('Как в системе'));
      expect(data.label, contains('Русский'));
      handle.dispose();
    });
  });

  group('настоящий переход: настройки → язык → смена языка', () {
    Widget host() => Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => openIos27Settings(context),
              child: const Text('Открыть'),
            ),
          ),
        );

    Future<void> openLanguage(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(kIos27SettingsLanguageKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    setUp(() {
      globalState.packageInfo = PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: kBoardVersion,
        buildNumber: '2050000023',
      );
    });

    testWidgets('строка «Язык» открывает страницу со списком из пяти строк',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: settingsOverrides(),
          disableAnimations: true,
          child: host(),
        ),
      );
      await openLanguage(tester);
      expect(find.byType(Ios27LanguageBody), findsOneWidget);
      expect(find.byType(Ios27ListRow), findsNWidgets(5));
      // Назад: остаётся «Настройки».
      await tester.tap(find.byKey(const ValueKey('page.back')).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Ios27LanguageBody), findsNothing);
      expect(find.byKey(kIos27SettingsLanguageKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'выбор English: подпись в «Настройках» и заголовки открытых страниц '
        'переписываются на новый язык', (tester) async {
      // Один и тот же список переопределений до и после смены языка: провайдер сохраняет состояние.
      final overrides = settingsOverrides();
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: overrides,
          disableAnimations: true,
          child: host(),
        ),
      );
      await openLanguage(tester);
      await tester.tap(_rowTitle('English'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Ios27LanguageBody)),
      );
      expect(container.read(appSettingProvider).locale, 'en');

      // Так приложение пересобирает MaterialApp на новом языке (lib/application.dart).
      await tester.runAsync(() => AppLocalizations.load(const Locale('en')));
      await tester.pumpWidget(
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: overrides,
          disableAnimations: true,
          locale: const Locale('en'),
          child: host(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Верхняя страница: «Language».
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('page.title')).last,
          matching: find.text('Language'),
        ),
        findsOneWidget,
      );
      expect(find.text('Same as system'), findsOneWidget);
      expect(_checkedRows(tester), [2]);

      // Под ней «Настройки» тоже уже английские.
      await tester.tap(find.byKey(const ValueKey('page.back')).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('page.title')),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
      final languageRow = find.byKey(kIos27SettingsLanguageKey);
      expect(
        find.descendant(of: languageRow, matching: find.text('Language')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: languageRow, matching: find.text('English')),
        findsOneWidget,
      );
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('масштаб шрифта', () {
    for (final dark in [false, true]) {
      for (final device in kIos27Iphones) {
        for (final scale in [0.8, 1.0, 1.4, 2.0]) {
          testWidgets(
              '${dark ? 'тёмная' : 'светлая'} ${device.name} ×$scale: '
              'нет переполнения, строки в пределах экрана', (tester) async {
            await _pump(
              tester,
              _page(),
              brightness: dark ? Brightness.dark : Brightness.light,
              overrides: settingsOverrides(locale: 'zh_CN'),
              textScale: scale,
              device: device,
            );
            expect(tester.takeException(), isNull);
            final screen = device.size;
            for (final row in find.byType(Ios27ListRow).evaluate()) {
              final rect = tester.getRect(find.byWidget(row.widget));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(screen.width + 0.01));
            }
            expect(find.byType(SingleChildScrollView), findsWidgets);
          });
        }
      }
    }
  });

  group('движение (G8)', () {
    testWidgets('покоящаяся страница не держит тикеров', (tester) async {
      await _pump(tester, _page());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('выбор языка не оставляет тикеров', (tester) async {
      await _pump(tester, _page());
      await tester.tap(_rowTitle('English'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('уход со страницы освобождает всё без исключений',
        (tester) async {
      await _pump(tester, _page());
      await tester.tap(_rowTitle('English'));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
