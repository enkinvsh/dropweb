import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/surface.dart';

const _sheet = ValueKey<String>('m3e.sheet');
const _title = ValueKey<String>('m3e.sheet.title');
const _scrim = ValueKey<String>('m3e.scrim');
const _field = ValueKey<String>('field');
const _home = ValueKey<String>('home');

/// Корень как у приложения: навигатор с `navigatorKey` и ТЁМНАЯ тема Lumina снаружи.
/// `M3eThemeScope` выше корневого навигатора нет, лист обязан перекраситься сам.
Widget _app({required Brightness brightness, int provider = 0}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  const padding = EdgeInsets.only(top: kM3eStatusBar, bottom: kM3eNavBar);
  return RepaintBoundary(
    key: kM3eBoardRootKey,
    child: ProviderScope(
      overrides: [
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: header.accent, filter: header.filter),
        ),
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            platformBrightness: brightness,
            padding: padding,
            viewPadding: padding,
          ),
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: const Scaffold(
              backgroundColor: Color(0xFF444444),
              body: SizedBox.expand(key: _home),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  bool shadows = false,
}) async {
  debugDisableShadows = !shadows;
  await pumpM3eBoard(tester, _app(brightness: brightness));
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_home));

/// Вход листа: прогон анимации появления.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

/// Типичный старый лист: `AdaptiveSheetScaffold` с действием и списком `ListTile`.
Widget _oldSheet(BuildContext context, SheetType type) => AdaptiveSheetScaffold(
      type: type,
      title: 'Прокси',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
      ],
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final n in const ['Авто', 'Нидерланды', 'Финляндия', 'Германия'])
            ListTile(
              title: Text(n),
              subtitle: const Text('VLESS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(n),
            ),
        ],
      ),
    );

void main() {
  late bool savedDefault;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('ru'));
    // Вид «мобильный»: `showSheet` ветвится по ширине окна.
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(411, 914),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
  });

  // Платформа теста macOS: Android-ветку включаем флагом, как `MessageManager.useM3e`.
  setUp(() {
    savedDefault = SheetSkin.defaultUseM3e;
    SheetSkin.defaultUseM3e = true;
  });
  tearDown(() {
    SheetSkin.defaultUseM3e = savedDefault;
    debugDisableShadows = true;
  });

  group('golden', () {
    for (final brightness in Brightness.values) {
      testWidgets('sheet_skin_list_${brightness.name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        unawaited(showSheet<String>(context: _ctx(tester), builder: _oldSheet));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await _golden(tester, 'sheet_skin_list_${brightness.name}_p0');
      });
    }
  });

  group('поведение', () {
    testWidgets('рамка M3E, заголовок и действие на месте', (tester) async {
      await _pump(tester);
      unawaited(showSheet<String>(context: _ctx(tester), builder: _oldSheet));
      await _settle(tester);
      expect(find.byKey(_sheet), findsOneWidget);
      expect(find.byKey(_scrim), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_title)).data, 'Прокси');
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      // Содержимое перекрашено в тему M3E: светлая схема, а не тёмная ThemeData.dark.
      final tile = find.byType(ListTile).first;
      expect(Theme.of(tester.element(tile)).brightness, Brightness.light);
    });

    testWidgets('значение возвращается через Navigator.pop', (tester) async {
      await _pump(tester);
      final result =
          showSheet<String>(context: _ctx(tester), builder: _oldSheet);
      await _settle(tester);
      await tester.tap(find.text('Финляндия'));
      await _settle(tester);
      expect(await result, 'Финляндия');
      expect(find.byKey(_sheet), findsNothing);
    });

    testWidgets('закрывается по затемнению, результат null', (tester) async {
      await _pump(tester);
      final result =
          showSheet<String>(context: _ctx(tester), builder: _oldSheet);
      await _settle(tester);
      await tester.tapAt(const Offset(200, 120));
      await _settle(tester);
      expect(await result, isNull);
      expect(find.byKey(_sheet), findsNothing);
    });

    testWidgets('useM3e: false оставляет старый лист', (tester) async {
      await _pump(tester);
      unawaited(showSheet<String>(
        context: _ctx(tester),
        useM3e: false,
        builder: (context, type) => AdaptiveSheetScaffold(
          type: type,
          useM3e: false,
          title: 'Прокси',
          body: const SizedBox(height: 80),
        ),
      ));
      await _settle(tester);
      expect(find.byKey(_sheet), findsNothing);
      expect(find.text('Прокси'), findsOneWidget);
    });

    testWidgets('клавиатура поднимает лист и не перекрывает поле',
        (tester) async {
      await _pump(tester);
      unawaited(showSheet<void>(
        context: _ctx(tester),
        builder: (context, type) => AdaptiveSheetScaffold(
          type: type,
          title: 'Поле',
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: TextField(key: _field),
          ),
        ),
      ));
      await _settle(tester);
      final before = tester.getRect(find.byKey(_field));
      // 300 dp клавиатуры при dpr 2.
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final after = tester.getRect(find.byKey(_field));
      const keyboardTop = 914 - 300.0;
      expect(before.bottom, greaterThan(keyboardTop - 1),
          reason: 'без клавиатуры поле в нижней части экрана');
      expect(after.bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.takeException(), isNull);
    });
  });
}
