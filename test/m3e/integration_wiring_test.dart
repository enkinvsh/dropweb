// Проводка фазы B: кнопки M3E-главной и пустого экрана открывают именно M3E-экраны, а не
// старые листы. Действия главной НЕ подменяются (`m3eHomeActionsProvider` по умолчанию
// `M3eHomeActions.app`), чтобы проверить саму проводку; VPN здесь не включается.
// Прогон: `fvm flutter test test/m3e/integration_wiring_test.dart`.

import 'dart:async';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_settings.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:dropweb/ui/m3e/theme/m3e_own_color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'gate_support.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _sheetKey = ValueKey<String>('m3e.sheet');
const _scrimKey = ValueKey<String>('m3e.scrim');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _hostKey = ValueKey<String>('wiring.host');

/// Настройки приложения без записи в конфиг (`onUpdate` лезет в `globalState`).
class _FakeAppSetting extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps();

  @override
  void onUpdate(AppSettingProps value) {}
}

M3eRouteData _routeData() => const M3eRouteData(
      rows: [
        M3eRouteRow(
          id: 'auto',
          label: 'Авто',
          isAggregate: true,
          pingMs: 43,
          selected: true,
        ),
      ],
      routerName: 'VPN',
      fullTunnelAvailable: false,
      fullTunnel: false,
      groupsCount: 1,
    );

M3eSubModel _subModel() => M3eSubModel(
      profiles: const [
        M3eSubProfile(id: 'p0', name: 'Подписка', host: 'example.org'),
      ],
      currentId: 'p0',
      updatedAt: kHomeNow.subtract(const Duration(minutes: 4)),
    );

final _theme = parseDropwebTheme(kBoardProviders[0].theme);

/// Стенд доски без главной: нужен там, где проверяется только лист или кнопка.
Widget _board(Widget child, {List<Override> overrides = const []}) =>
    m3eBoardApp(
      seed: _theme.accent,
      filter: _theme.filter,
      brightness: Brightness.light,
      overrides: overrides,
      child: child,
    );

Widget _home() => gateHomeApp(
      'home-off',
      extra: [
        m3eRouteDataProvider.overrideWithValue(_routeData()),
        m3eSubModelProvider.overrideWithValue(_subModel()),
        m3eSubClockProvider.overrideWithValue(() => kHomeNow),
        appSettingProvider.overrideWith(_FakeAppSetting.new),
        m3eOwnColorEnabledProvider.overrideWithValue(false),
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: _theme.accent, filter: _theme.filter),
        ),
      ],
    );

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

void main() {
  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.10.3',
      buildNumber: '1',
    );
  });

  tearDown(() => debugDisableShadows = true);

  group('главная', () {
    testWidgets('«Настройки» открывают M3E-страницу настроек', (tester) async {
      await pumpM3eBoard(tester, _home());
      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, kM3eNavBtnKey);
      expect(find.byType(M3eSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Подписка» открывает M3E-лист подписок', (tester) async {
      await pumpM3eBoard(tester, _home());
      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, kM3eSubsBtnKey);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Подписка');
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Маршрут» открывает M3E-лист маршрута', (tester) async {
      await pumpM3eBoard(tester, _home());
      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, kM3eRouteBtnKey);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Маршрут');
      expect(tester.takeException(), isNull);
    });
  });

  group('пустой экран', () {
    testWidgets('«Вставить ссылку» без ссылки в буфере открывает лист добавления',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'просто текст'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpM3eBoard(
        tester,
        _board(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: M3eEmptyHome(onSettings: () {}),
            ),
          ),
          overrides: [
            m3eAddImportProvider.overrideWithValue((url) async {}),
            m3eAddScanProvider.overrideWithValue((context) async {}),
            accountLoginAvailableProvider.overrideWithValue(false),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(kM3eEmptyPasteKey));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byKey(kM3eAddFieldKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data,
          'Добавить подписку');
      expect(tester.takeException(), isNull);
    });
  });

  group('showM3eSheet(dismissible)', () {
    Future<void> open(WidgetTester tester, {required bool dismissible}) async {
      await pumpM3eBoard(
        tester,
        _board(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const SizedBox.expand(key: _hostKey),
            ),
          ),
        ),
      );
      unawaited(
        showM3eSheet<void>(
          tester.element(find.byKey(_hostKey)),
          dismissible: dismissible,
          builder: (_) => const M3eSheetScaffold(
            title: 'Обновление',
            body: SizedBox(height: 120),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
    }

    testWidgets('обязательный лист не закрывается тапом по затемнению',
        (tester) async {
      await open(tester, dismissible: false);
      await tester.tapAt(const Offset(200, 100));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets('обязательный лист не закрывается свайпом вниз', (tester) async {
      await open(tester, dismissible: false);
      await tester.drag(find.byKey(_titleKey), const Offset(0, 300));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byKey(_scrimKey), findsOneWidget);
    });

    testWidgets('обычный лист закрывается тапом по затемнению', (tester) async {
      await open(tester, dismissible: true);
      await tester.tapAt(const Offset(200, 100));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsNothing);
    });
  });
}
