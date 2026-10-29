import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/app_update.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_update_sheet.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _sheetKey = ValueKey<String>('m3e.sheet');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _homeKey = ValueKey<String>('home');

// Данные релиза доски (UPDATE в app.js:209).
const _info = AppUpdateInfo(
  version: '0.10.4',
  tag: 'v0.10.4',
  notes: [
    'Быстрее подключается после сна телефона',
    'Исправили обрыв VPN при смене Wi-Fi на мобильную сеть',
  ],
  primaryUrl: 'https://example.test/dropweb.apk',
);

const _available = AppUpdateState(
  status: AppUpdateStatus.available,
  info: _info,
);

/// Подмена источника обновлений: считает вызовы и позволяет менять состояние из теста.
class _FakeUpdate extends AppUpdate {
  _FakeUpdate(this.initial, {this.checkResult});

  final AppUpdateState initial;
  final AppUpdateState? checkResult;
  int downloads = 0, cancels = 0, installs = 0, snoozes = 0, checks = 0;

  /// Исход `install()`: false — нет разрешения на установку, установщик не запущен.
  bool installOk = true;

  @override
  AppUpdateState build() => initial;

  // ignore: use_setters_to_change_properties
  void put(AppUpdateState next) => state = next;

  @override
  Future<void> check({bool manual = false}) async {
    checks++;
    if (checkResult != null) state = checkResult!;
  }

  @override
  Future<void> download() async => downloads++;

  @override
  void cancel() => cancels++;

  @override
  Future<bool> install() async {
    installs++;
    return installOk;
  }

  @override
  void snoozeIfPending() => snoozes++;
}

/// Фон кадра `home.bg`; ключ `home` — место, откуда берётся контекст для показа.
Widget _app({bool reduceMotion = false}) => Builder(
      builder: (context) {
        Widget child = ColoredBox(
          key: _homeKey,
          color: M3eColors.of(context).home.bg,
          child: const SizedBox.expand(),
        );
        if (reduceMotion) {
          child = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          );
        }
        return child;
      },
    );

late _FakeUpdate _fake;

Future<void> _pump(
  WidgetTester tester, {
  AppUpdateState initial = _available,
  AppUpdateState? checkResult,
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool shadows = false,
  bool reduceMotion = false,
}) async {
  // flutter_test рисует тени чёрной обводкой; для golden нужны настоящие.
  debugDisableShadows = !shadows;
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      overrides: [
        // Лист из контекста навигатора берёт цвета из провайдера темы, а настоящий
        // провайдер лезет в globalState.
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: h.accent, filter: h.filter),
        ),
        appUpdateProvider.overrideWith(
          () => _fake = _FakeUpdate(initial, checkResult: checkResult),
        ),
      ],
      child: _app(reduceMotion: reduceMotion),
    ),
  );
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

/// Первый кадр только заводит тикер, время идёт со второго.
Future<void> _settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _open(WidgetTester tester) async {
  unawaited(showM3eUpdateSheet(_ctx(tester)));
  await _settle(tester);
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

Rect _ref(String scene, String key, [int index = 0]) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  var e = elements[key];
  if (e is List) e = e[index];
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _near(Rect actual, Rect expected, String what, {double tol = 4}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(tol),
      reason: '$what left $actual vs $expected');
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(tol),
      reason: '$what top $actual vs $expected');
  expect((actual.width - expected.width).abs(), lessThanOrEqualTo(tol),
      reason: '$what width $actual vs $expected');
  expect((actual.height - expected.height).abs(), lessThanOrEqualTo(tol),
      reason: '$what height $actual vs $expected');
}

/// Тест с листом: в конце лист закрывается, иначе его Future не завершится и счётчик
/// открытых листов (`isM3eUpdateSheetOpen`) утечёт в следующие тесты.
void _sheetTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    if (find.byKey(_sheetKey).evaluate().isNotEmpty) {
      Navigator.of(_ctx(tester), rootNavigator: true).pop();
      await _settle(tester);
    }
  });
}

const _cases = [
  ('light', 0, Brightness.light),
  ('light', 5, Brightness.light),
  ('dark', 0, Brightness.dark),
  ('dark', 5, Brightness.dark),
];

void main() {
  group('golden', () {
    for (final (theme, p, brightness) in _cases) {
      _sheetTest('update_${theme}_p$p', (tester) async {
        await _pump(tester, provider: p, brightness: brightness, shadows: true);
        await _open(tester);
        await _golden(tester, 'update_${theme}_p$p');
      });
    }

    final phases = <String, AppUpdateState>{
      'downloading': const AppUpdateState(
        status: AppUpdateStatus.downloading,
        info: _info,
        progress: 0.42,
      ),
      'verifying': const AppUpdateState(
        status: AppUpdateStatus.verifying,
        info: _info,
        progress: 1,
      ),
      'ready': const AppUpdateState(
        status: AppUpdateStatus.readyToInstall,
        info: _info,
        progress: 1,
      ),
      'error': const AppUpdateState(
        status: AppUpdateStatus.error,
        info: _info,
        error: 'updateFailed',
      ),
    };
    for (final e in phases.entries) {
      _sheetTest('update_${e.key}_light_p0', (tester) async {
        await _pump(tester, initial: e.value, shadows: true);
        await _open(tester);
        await _golden(tester, 'update_${e.key}_light_p0');
      });
    }
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final (theme, p, brightness) in _cases) {
      _sheetTest('update-$theme-p$p', (tester) async {
        await _pump(tester, provider: p, brightness: brightness);
        await _open(tester);
        final scene = 'update-$theme-p$p';
        // Строки размера нет (манифест его не отдаёт): заметки и верх листа
        // сдвинуты вниз на 24 dp, низ и кнопки стоят там же, где на доске.
        const sizeRow = 24.0;
        final sheetRef = _ref(scene, 'sheet');
        final sheet = tester.getRect(find.byKey(_sheetKey));
        _near(
          sheet,
          Rect.fromLTRB(sheetRef.left, sheetRef.top + sizeRow, sheetRef.right,
              sheetRef.bottom),
          'sheet',
        );
        _near(
          tester.getRect(find.byKey(_titleKey)),
          _ref(scene, 'sheet.title').shift(const Offset(0, sizeRow)),
          'sheet.title',
        );
        final buttons = find.byType(M3eButton);
        expect(buttons, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          _near(tester.getRect(buttons.at(i)), _ref(scene, 'sheet.btn', i),
              'sheet.btn[$i]');
        }
      });
    }
  });

  group('фазы', () {
    _sheetTest('кнопки и тексты следуют за состоянием', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(find.text('dropweb 0.10.4'), findsOneWidget);
      expect(find.text('Что нового'), findsOneWidget);
      expect(find.text('Позже'), findsOneWidget);
      expect(find.text('Обновить'), findsOneWidget);
      // Строки размера нет.
      expect(find.textContaining('МБ'), findsNothing);

      await tester.tap(find.text('Обновить'));
      expect(_fake.downloads, 1);

      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.downloading,
        info: _info,
        progress: 0.5,
      ));
      await _settle(tester, 1000);
      expect(find.text('Загрузка… 50%'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Позже'), findsNothing);
      await tester.tap(find.text('Отмена'));
      expect(_fake.cancels, 1);

      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.verifying,
        info: _info,
        progress: 1,
      ));
      await _settle(tester, 1000);
      expect(find.text('Проверка…'), findsOneWidget);
      expect(find.byType(M3eButton), findsNothing);

      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.readyToInstall,
        info: _info,
        progress: 1,
      ));
      await _settle(tester);
      expect(find.text('Загружено, можно установить'), findsOneWidget);
      expect(find.text('Установить'), findsOneWidget);
      expect(find.text('Позже'), findsOneWidget);

      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.error,
        info: _info,
        error: 'updateFailed',
      ));
      await _settle(tester);
      expect(find.text('Не удалось обновить'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      expect(_fake.downloads, 2);
    });

    _sheetTest('прогресс-индикатор: подпись, значение и пружина',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.downloading,
          info: _info,
        ),
      );
      await _open(tester);
      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.downloading,
        info: _info,
        progress: 0.5,
      ));
      await tester.pump();
      // Пружина ещё едет: тикер жив.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      final node = tester.getSemantics(find.bySemanticsLabel(
        'Загрузка обновления',
      ));
      expect(node.value, '50%');
      handle.dispose();
    });

    _sheetTest('install: установщик, закрытие листа и тост через 300 мс',
        (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.readyToInstall,
          info: _info,
          progress: 1,
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Установить'));
      await _settle(tester);
      expect(_fake.installs, 1);
      expect(find.byKey(_sheetKey), findsNothing);
      // Тост отложен на 300 мс: дожидаемся, чтобы не осталось таймера.
      await tester.pump(kM3eUpdateToastDelay);
    });
  });

  group('контекст навигатора (выше M3eThemeScope)', () {
    // Так открывает лист автопредложение: `navigatorKey.currentContext` стоит выше
    // темы экрана. Тесты с контекстом внутри темы этого не ловили (урок a37c32df).
    BuildContext navigatorContext(WidgetTester tester) =>
        tester.element(find.byType(Navigator).first);

    _sheetTest('лист открывается без M3eThemeScope выше контекста',
        (tester) async {
      await _pump(tester);
      final ctx = navigatorContext(tester);
      expect(ctx.dependOnInheritedWidgetOfExactType<M3eColors>(), isNull);
      unawaited(showM3eUpdateSheet(ctx));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.text('dropweb 0.10.4'), findsOneWidget);
    });

    testWidgets('обязательное обновление: нет «Позже», скрим не закрывает',
        (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.available,
          info: AppUpdateInfo(
            version: '0.10.4',
            tag: 'v0.10.4',
            notes: ['Важное исправление'],
            primaryUrl: 'https://example.test/dropweb.apk',
            mandatory: true,
          ),
        ),
      );
      unawaited(showM3eUpdateSheet(navigatorContext(tester)));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.text('Позже'), findsNothing);
      await tester.tapAt(const Offset(200, 80));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      Navigator.of(navigatorContext(tester), rootNavigator: true).pop();
      await _settle(tester);
    });
  });

  group('установка', () {
    _sheetTest('без разрешения лист остаётся, версия не откладывается',
        (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.readyToInstall,
          info: _info,
          progress: 1,
        ),
      );
      await _open(tester);
      // Фейк создаётся при первом чтении провайдера, то есть при открытии листа.
      _fake.installOk = false;
      await tester.tap(find.text('Установить'));
      await _settle(tester);
      expect(_fake.installs, 1);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(_fake.snoozes, 0);

      // Разрешение выдано: второе нажатие запускает установщик и закрывает лист.
      _fake.installOk = true;
      await tester.tap(find.text('Установить'));
      await _settle(tester);
      expect(_fake.installs, 2);
      expect(find.byKey(_sheetKey), findsNothing);
      await tester.pump(kM3eUpdateToastDelay);
    });
  });

  group('закрытие', () {
    _sheetTest('«Позже» закрывает лист и откладывает версию', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(isM3eUpdateSheetOpen, isTrue);
      await tester.tap(find.text('Позже'));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(isM3eUpdateSheetOpen, isFalse);
      expect(_fake.snoozes, 1);
    });

    _sheetTest('обязательное обновление: нет «Позже», «Назад» не закрывает',
        (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.available,
          info: AppUpdateInfo(
            version: '0.10.4',
            tag: 'v0.10.4',
            notes: ['Важное исправление'],
            primaryUrl: 'https://example.test/dropweb.apk',
            mandatory: true,
          ),
        ),
      );
      await _open(tester);
      expect(find.text('Позже'), findsNothing);
      expect(find.text('Обновить'), findsOneWidget);
      expect(find.text('Рекомендуем обновиться'), findsOneWidget);
      await Navigator.of(_ctx(tester), rootNavigator: true).maybePop();
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets('после закрытия тикеров нет', (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(
          status: AppUpdateStatus.downloading,
          info: _info,
          progress: 0.3,
        ),
      );
      await _open(tester);
      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.downloading,
        info: _info,
        progress: 0.8,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      Navigator.of(_ctx(tester), rootNavigator: true).pop();
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reduced motion', () {
    _sheetTest('прогресс меняется без пружины и тикеров', (tester) async {
      await _pump(
        tester,
        reduceMotion: true,
        initial: const AppUpdateState(
          status: AppUpdateStatus.downloading,
          info: _info,
        ),
      );
      await _open(tester);
      expect(tester.binding.transientCallbackCount, 0);
      _fake.put(const AppUpdateState(
        status: AppUpdateStatus.downloading,
        info: _info,
        progress: 0.7,
      ));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('Загрузка… 70%'), findsOneWidget);
    });
  });

  group('m3eCheckForUpdate', () {
    _sheetTest('идущая проверка: повторный вызов игнорируется', (tester) async {
      await _pump(
        tester,
        initial: const AppUpdateState(status: AppUpdateStatus.checking),
        checkResult: _available,
      );
      unawaited(m3eCheckForUpdate(_ctx(tester)));
      await _settle(tester);
      expect(_fake.checks, 0);
      expect(find.byKey(_sheetKey), findsNothing);
    });

    _sheetTest('есть обновление — открывает лист', (tester) async {
      await _pump(tester,
          initial: const AppUpdateState(), checkResult: _available);
      unawaited(m3eCheckForUpdate(_ctx(tester)));
      await _settle(tester);
      expect(_fake.checks, 1);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.text('dropweb 0.10.4'), findsOneWidget);
    });

    for (final status in [
      AppUpdateStatus.upToDate,
      AppUpdateStatus.checkFailed,
    ]) {
      testWidgets('$status — листа нет', (tester) async {
        await _pump(tester,
            initial: const AppUpdateState(),
            checkResult: AppUpdateState(status: status));
        unawaited(m3eCheckForUpdate(_ctx(tester)));
        await _settle(tester);
        expect(_fake.checks, 1);
        expect(find.byKey(_sheetKey), findsNothing);
      });
    }
  });
}
