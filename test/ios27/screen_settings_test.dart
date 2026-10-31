// Экран «Настройки» iOS-редизайна: сверка с доской (рамки ±4 dp, golden), тексты и подписи строк,
// пять нажатий по заголовку (режим разработчика, НЕ ПОТЕРЯТЬ из Android), отсутствие строк
// «Обновление» и «Поддержать проект» (R10), семантика, масштаб шрифта, переход и Reduce Motion.

import 'dart:ui' show Tristate;

import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_page.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/config/config.dart';
import 'package:dropweb/views/developer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'screen_settings_support.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Страница «Настройки» как её собирает [openIos27Settings], но без маршрута: счётчик и тосты
/// подменены, чтобы считать нажатия и не трогать `globalState`.
Widget _page(
  SettingsHarness h, {
  DevUnlockCounter? counter,
  Ios27LegacyOpener? openLegacy,
  VoidCallback? onLanguage,
  VoidCallback? onAppearance,
  VoidCallback? onAbout,
  String version = kBoardVersion,
}) =>
    Builder(
      builder: (context) => Ios27Page(
        title: AppLocalizations.of(context).settings,
        titleSemanticsIdentifier: kIos27SettingsTitleIdentifier,
        onTitleTap: () {
          h.unlock ??= Ios27DevUnlock(
            ProviderScope.containerOf(context, listen: false),
            counter: counter,
            notify: h.tips.add,
          );
          h.unlock!.onTitleTap();
        },
        child: Ios27SettingsBody(
          version: version,
          onLanguage: onLanguage,
          onAppearance: onAppearance,
          onAbout: onAbout,
          openLegacy: openLegacy ?? (_, __, ___) {},
        ),
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

/// Пять нажатий подряд по крупному заголовку.
Future<void> _tapTitle(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(const ValueKey('page.title')));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(Ios27SettingsBody)),
    );

/// Все надписи экрана одной строкой: по ней проверяется, чего на экране быть не должно.
String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    group('сверка с доской, $mode', () {
      testWidgets('настройки: рамки ±4 dp и golden', (tester) async {
        await _pump(tester, _page(SettingsHarness()), brightness: brightness);
        expectIos27Parity(
          ios27Parity(tester, 'settings-$mode-rt-p0', pageElements()),
        );
        await expectIos27Golden(tester, 'settings_${mode}_p0');
      });
    });
  }

  // Строки не красятся акцентом, поэтому p5 нужен только для проверки, что вид не зависит
  // от цвета провайдера.
  testWidgets('провайдер p5 (серый): рамки те же, что у p0', (tester) async {
    await _pump(tester, _page(SettingsHarness()), provider: 5);
    expectIos27Parity(
      ios27Parity(tester, 'settings-light-rt-p5', pageElements()),
    );
    await expectIos27Golden(tester, 'settings_light_p5');
  });

  group('состояния данных (golden)', () {
    testWidgets('режим разработчика: три строки под «О программе»',
        (tester) async {
      await _pump(
        tester,
        _page(SettingsHarness()),
        overrides: settingsOverrides(developerMode: true),
      );
      await expectIos27Golden(tester, 'settings_dev_light');
    });

    testWidgets('English и «Свои» цвета, тёмная тема', (tester) async {
      await _pump(
        tester,
        _page(SettingsHarness()),
        brightness: Brightness.dark,
        provider: 3,
        overrides: settingsOverrides(locale: 'en', ownColor: true),
      );
      await expectIos27Golden(tester, 'settings_en_own_dark');
    });
  });

  group('тексты и подписи строк', () {
    testWidgets('по умолчанию: язык «Как в системе», оформление «Провайдер»',
        (tester) async {
      await _pump(tester, _page(SettingsHarness()));
      expect(
        _allText(tester).split('\n'),
        containsAll([
          'Настройки',
          'Язык',
          'Как в системе',
          'Оформление',
          'Провайдер',
          'О программе',
          kBoardVersion,
        ]),
      );
      // Три строки и три шеврона: ничего лишнего на странице нет.
      expect(find.byType(Ios27ListRow), findsNWidgets(3));
      expect(find.byKey(const ValueKey('page.group')), findsNWidgets(2));
    });

    testWidgets('в версии нет слова «Версия» (на доске голое «0.10.3»)',
        (tester) async {
      await _pump(tester, _page(SettingsHarness(), version: '1.2.3'));
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.textContaining('Версия'), findsNothing);
    });

    for (final c in <(String, String)>[
      ('en', 'English'),
      ('ru', 'Русский'),
      ('ja', '日本語'),
      ('zh_CN', '简体中文'),
    ]) {
      testWidgets('язык ${c.$1}: подпись «${c.$2}» вместо «Как в системе»',
          (tester) async {
        await _pump(
          tester,
          _page(SettingsHarness()),
          overrides: settingsOverrides(locale: c.$1),
        );
        expect(find.text(c.$2), findsOneWidget);
        expect(find.text('Как в системе'), findsNothing);
      });
    }

    testWidgets('свой цвет включён: оформление «Свои»', (tester) async {
      await _pump(
        tester,
        _page(SettingsHarness()),
        overrides: settingsOverrides(ownColor: true),
      );
      expect(find.text('Свои'), findsOneWidget);
      expect(find.text('Провайдер'), findsNothing);
    });

    testWidgets('подписи следуют за языком интерфейса (English)',
        (tester) async {
      await _pump(
        tester,
        _page(SettingsHarness()),
        locale: const Locale('en'),
        overrides: settingsOverrides(locale: 'en'),
      );
      final text = _allText(tester).split('\n');
      expect(
        text,
        containsAll([
          'Settings',
          'Language',
          'English',
          'Appearance',
          'Provider',
          'About',
        ]),
      );
    });

    for (final dev in [false, true]) {
      testWidgets(
          'магазинные правила (${dev ? 'режим разработчика' : 'обычный режим'}): '
          'нет обновлений, поддержки, аккаунта и слова Android',
          (tester) async {
        await _pump(
          tester,
          _page(SettingsHarness()),
          overrides: settingsOverrides(developerMode: dev),
        );
        final text = _allText(tester);
        for (final banned in [
          'Проверить обновления',
          'Обновление',
          'Поддержать',
          'Поддержка',
          'Аккаунт',
          'Кабинет',
          'Android',
          // Понятия Android, которых на iPhone нет.
          'Всегда включен',
          'Контроль доступа',
        ]) {
          expect(text.contains(banned), isFalse, reason: banned);
        }
      });
    }
  });

  group('переходы', () {
    testWidgets('строки зовут свои переходы', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        _page(
          SettingsHarness(),
          onLanguage: () => calls.add('language'),
          onAppearance: () => calls.add('appearance'),
          onAbout: () => calls.add('about'),
        ),
      );
      await tester.tap(find.byKey(kIos27SettingsLanguageKey));
      await tester.tap(find.text('Оформление'));
      await tester.tap(find.text('О программе'));
      expect(calls, ['language', 'appearance', 'about']);
    });
  });

  group('пять нажатий по заголовку (режим разработчика)', () {
    testWidgets('четыре нажатия ничего не включают, пятое включает',
        (tester) async {
      final h = SettingsHarness();
      await _pump(tester, _page(h));
      await _tapTitle(tester, 4);
      expect(
          _container(tester).read(appSettingProvider).developerMode, isFalse);
      expect(h.tips, isEmpty);
      expect(find.byKey(kIos27SettingsConfigKey), findsNothing);

      await _tapTitle(tester, 1);
      expect(_container(tester).read(appSettingProvider).developerMode, isTrue);
      // Тост «Режим разработчика активирован.» показан ровно один раз.
      expect(h.tips, ['Режим разработчика активирован.']);
    });

    testWidgets('после включения под «О программе» появляются три строки',
        (tester) async {
      final h = SettingsHarness();
      await _pump(tester, _page(h));
      await _tapTitle(tester, 5);
      await tester.pump();
      expect(find.byKey(kIos27SettingsConfigKey), findsOneWidget);
      expect(find.byKey(kIos27SettingsApplicationKey), findsOneWidget);
      expect(find.byKey(kIos27SettingsDeveloperKey), findsOneWidget);
      expect(find.byType(Ios27ListRow), findsNWidgets(6));
      expect(find.text('Конфигурация ядра'), findsOneWidget);
      expect(find.text('Настройки приложения'), findsOneWidget);
      expect(find.text('Режим разработчика'), findsOneWidget);
      // Понятия Android в iOS-списке не появляются.
      expect(find.text('Всегда включен'), findsNothing);
      expect(find.text('Контроль доступа'), findsNothing);
    });

    testWidgets('уже включённый режим: пятое нажатие тихо ничего не делает',
        (tester) async {
      final h = SettingsHarness();
      await _pump(
        tester,
        _page(h),
        overrides: settingsOverrides(developerMode: true),
      );
      await _tapTitle(tester, 5);
      expect(h.tips, isEmpty);
      expect(_container(tester).read(appSettingProvider).developerMode, isTrue);
    });

    testWidgets('второй заход серией из пяти не показывает тост повторно',
        (tester) async {
      final h = SettingsHarness();
      await _pump(tester, _page(h));
      await _tapTitle(tester, 10);
      expect(h.tips, hasLength(1));
    });

    testWidgets('нажатия вне окна 3 с не складываются', (tester) async {
      var now = DateTime(2026, 10, 30, 12);
      final h = SettingsHarness();
      await _pump(
        tester,
        _page(h, counter: DevUnlockCounter(clock: () => now)),
      );
      await _tapTitle(tester, 3);
      now = now.add(const Duration(seconds: 4));
      await _tapTitle(tester, 2);
      expect(
          _container(tester).read(appSettingProvider).developerMode, isFalse);
      // Три быстрых после паузы довершают новую серию.
      await _tapTitle(tester, 3);
      expect(_container(tester).read(appSettingProvider).developerMode, isTrue);
    });

    testWidgets('нажатия по строкам и фону серию не набирают', (tester) async {
      final h = SettingsHarness();
      // Переходы подменены: настоящая «О программе» читает сборку из globalState.
      await _pump(
        tester,
        _page(h, onAbout: () {}, onLanguage: () {}, onAppearance: () {}),
      );
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('О программе'));
        await tester.tap(find.byKey(const ValueKey('page.nav')));
      }
      await tester.pump();
      expect(
          _container(tester).read(appSettingProvider).developerMode, isFalse);
      expect(h.tips, isEmpty);
    });

    testWidgets('строки режима разработчика открывают старые экраны',
        (tester) async {
      final opened = <(String, Type)>[];
      await _pump(
        tester,
        _page(
          SettingsHarness(),
          openLegacy: (_, title, screen) =>
              opened.add((title, screen.runtimeType)),
        ),
        overrides: settingsOverrides(developerMode: true),
      );
      await tester.tap(find.byKey(kIos27SettingsConfigKey));
      await tester.tap(find.byKey(kIos27SettingsApplicationKey));
      await tester.tap(find.byKey(kIos27SettingsDeveloperKey));
      expect(opened, [
        ('Переопределение', ConfigView),
        ('Настройки приложения', ApplicationSettingView),
        ('Режим разработчика', DeveloperView),
      ]);
    });
  });

  group('семантика', () {
    testWidgets(
        'заголовок несёт идентификатор dw_settings_title и роль заголовка',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _page(SettingsHarness()));
      final finder = find.bySemanticsIdentifier('dw_settings_title');
      expect(finder, findsOneWidget);
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      expect(data.label, contains('Настройки'));
      handle.dispose();
    });

    testWidgets('строки — кнопки с подписью и значением', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _page(SettingsHarness()));
      final data = tester
          .getSemantics(find.byKey(kIos27SettingsLanguageKey))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.label, contains('Язык'));
      expect(data.label, contains('Как в системе'));
      handle.dispose();
    });

    testWidgets('идентификатор не пропадает в режиме разработчика',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _page(SettingsHarness()),
        overrides: settingsOverrides(developerMode: true),
      );
      expect(find.bySemanticsIdentifier('dw_settings_title'), findsOneWidget);
      handle.dispose();
    });
  });

  group('настоящий переход openIos27Settings', () {
    Widget host() => Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => openIos27Settings(context),
              child: const Text('Открыть'),
            ),
          ),
        );

    setUp(() {
      globalState.packageInfo = PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: '0.10.3',
        buildNumber: '2050000023',
      );
    });

    testWidgets('страница открывается, версия берётся из сборки',
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
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('page.title')), findsOneWidget);
      expect(find.text('0.10.3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('пять нажатий на открытой странице включают режим разработчика',
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
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _tapTitle(tester, 5);
      await tester.pump();
      expect(find.byKey(kIos27SettingsDeveloperKey), findsOneWidget);
    });

    testWidgets('«Назад» возвращает на главную без исключений', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: settingsOverrides(),
          disableAnimations: true,
          child: host(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('page.back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(find.byKey(const ValueKey('open')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('масштаб шрифта и самые длинные данные', () {
    // Самый тяжёлый набор: длинная версия, «Свои», режим разработчика, подпись на китайском.
    for (final dark in [false, true]) {
      for (final device in kIos27Iphones) {
        for (final scale in [0.8, 1.0, 1.4, 2.0]) {
          testWidgets(
              '${dark ? 'тёмная' : 'светлая'} ${device.name} ×$scale: '
              'нет переполнения, строки в пределах экрана', (tester) async {
            await _pump(
              tester,
              _page(
                SettingsHarness(),
                version: '0.10.3-rc.12+2050000023.build.long',
              ),
              brightness: dark ? Brightness.dark : Brightness.light,
              overrides: settingsOverrides(
                locale: 'zh_CN',
                developerMode: true,
                ownColor: true,
              ),
              textScale: scale,
              device: device,
            );
            expect(tester.takeException(), isNull);
            final screen = device.size;
            for (final row in find.byType(Ios27ListRow).evaluate()) {
              final rect = tester.getRect(find.byWidget(row.widget));
              expect(rect.left, greaterThanOrEqualTo(0), reason: 'левый край');
              expect(
                rect.right,
                lessThanOrEqualTo(screen.width + 0.01),
                reason: 'правый край',
              );
            }
            final title =
                tester.getRect(find.byKey(const ValueKey('page.title')));
            expect(title.right, lessThanOrEqualTo(screen.width + 0.01));
            // Последняя строка достижима прокруткой: страница прокручивается, а не режется.
            expect(find.byType(SingleChildScrollView), findsWidgets);
          });
        }
      }
    }
  });

  group('движение (G8)', () {
    testWidgets('покоящаяся страница не держит тикеров', (tester) async {
      await _pump(tester, _page(SettingsHarness()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: переход без тикеров после угасания',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: settingsOverrides(),
          disableAnimations: true,
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => openIos27Settings(context),
              child: const Text('Открыть'),
            ),
          ),
        ),
      );
      globalState.packageInfo = PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: kBoardVersion,
        buildNumber: '1',
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
        closeTo(0, 0.5),
        reason: 'страница стоит на месте, не едет справа',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('уход со страницы освобождает всё без исключений',
        (tester) async {
      final h = SettingsHarness();
      await _pump(tester, _page(h));
      await _tapTitle(tester, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
