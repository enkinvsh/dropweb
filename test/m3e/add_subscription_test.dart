import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _homeKey = ValueKey<String>('home');
const _sheetKey = ValueKey<String>('m3e.sheet');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _backKey = ValueKey<String>('m3e.sheet.back');
const _pushKey = ValueKey<String>('push');

/// Ссылка с доски (`LINK` в android.js).
const _link = 'https://sub.dropweb.org/s/4f9c1a7e2b';

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

class _Calls {
  final imports = <String>[];
  int scans = 0;
}

List<Override> _overrides(
  _Calls calls, {
  bool loginAvailable = false,
}) =>
    [
      m3eAddImportProvider.overrideWithValue((url) async {
        calls.imports.add(url);
      }),
      m3eAddScanProvider.overrideWithValue((context) async {
        calls.scans++;
      }),
      accountLoginAvailableProvider.overrideWithValue(loginAvailable),
    ];

/// Фон кадра `home.bg`, как у остальных листовых тестов; [textScale] — крупный шрифт.
Widget _app({double textScale = 1}) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: ColoredBox(
          key: _homeKey,
          color: M3eColors.of(context).home.bg,
          child: const SizedBox.expand(),
        ),
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool shadows = false,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  debugDisableShadows = !shadows;
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      overrides: overrides,
      child: _app(textScale: textScale),
    ),
  );
}

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

/// Самостоятельный лист (глубина 1, без стрелки «Назад»).
Future<void> _openStandalone(WidgetTester tester, {String? initial}) async {
  unawaited(showM3eAddSubscription(_ctx(tester), initialValue: initial));
  await _settle(tester);
}

/// Как в листе «Подписка»: шаг стека, поэтому в заголовке стрелка «Назад»
/// (так снят эталон `add-*`).
Future<void> _openInStack(WidgetTester tester, {String? initial}) async {
  unawaited(
    showM3eSheet<void>(
      _ctx(tester),
      builder: (context) => M3eSheetStack(
        root: (context) => M3eSheetScaffold(
          title: 'Подписка',
          body: TextButton(
            key: _pushKey,
            onPressed: () => M3eSheetStack.of(context).push(
              (c) => M3eAddSubscriptionView(initialValue: initial),
            ),
            child: const Text('Добавить'),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  await tester.tap(find.byKey(_pushKey));
  await _settle(tester);
}

Rect _ref(String scene, String key) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  var e = elements[key];
  if (e is List) e = e.first;
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _expectRectNear(Rect actual, Rect expected, String what,
    {double tol = 4}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(tol),
      reason: '$what left $actual vs $expected');
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(tol),
      reason: '$what top $actual vs $expected');
  expect((actual.width - expected.width).abs(), lessThanOrEqualTo(tol),
      reason: '$what width $actual vs $expected');
  expect((actual.height - expected.height).abs(), lessThanOrEqualTo(tol),
      reason: '$what height $actual vs $expected');
}

/// Подмена буфера обмена платформенного канала.
void _mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return text == null ? null : <String, dynamic>{'text': text};
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(kM3eAddFieldInputKey)).controller!.text;

const _cases = [
  ('light', 0, Brightness.light),
  ('light', 5, Brightness.light),
  ('dark', 0, Brightness.dark),
  ('dark', 5, Brightness.dark),
];

void main() {
  group('golden', () {
    for (final (theme, p, brightness) in _cases) {
      testWidgets('add_${theme}_p$p', (tester) async {
        await _pump(
          tester,
          provider: p,
          brightness: brightness,
          shadows: true,
          overrides: _overrides(_Calls()),
        );
        await _openInStack(tester);
        await _golden(tester, 'add_${theme}_p$p');
      });
    }

    testWidgets('add_error_light_p0: ссылка не подходит', (tester) async {
      await _pump(
        tester,
        shadows: true,
        overrides: _overrides(_Calls()),
      );
      await _openInStack(tester, initial: 'не ссылка');
      await tester.tap(find.byKey(kM3eAddSubmitKey));
      await _settle(tester, 300);
      await _golden(tester, 'add_error_light_p0');
    });

    testWidgets('add_link_dark_p0: ссылка в поле, аккаунт доступен, входа нет',
        (tester) async {
      await _pump(
        tester,
        brightness: Brightness.dark,
        shadows: true,
        overrides: _overrides(_Calls(), loginAvailable: true),
      );
      await _openInStack(tester, initial: _link);
      await _golden(tester, 'add_link_dark_p0');
    });
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final (theme, p, brightness) in _cases) {
      testWidgets('add-$theme-p$p', (tester) async {
        await _pump(
          tester,
          provider: p,
          brightness: brightness,
          overrides: _overrides(_Calls()),
        );
        await _openInStack(tester);
        final scene = 'add-$theme-p$p';
        final keys = <String, Key>{
          'sheet': _sheetKey,
          'sheet.title': _titleKey,
          'sheet.back': _backKey,
          'field': kM3eAddFieldKey,
          'field.input': kM3eAddFieldInputKey,
          'field.label': kM3eAddFieldLabelKey,
          'field.paste': kM3eAddFieldPasteKey,
          'sheet.item': kM3eAddQrKey,
          'sheet.btn': kM3eAddSubmitKey,
        };
        for (final e in keys.entries) {
          var rect = tester.getRect(find.byKey(e.value));
          // Поле ввода на доске равно рамке: TextField внутри уже, сверяем рамку.
          if (e.key == 'field.input') {
            rect = tester.getRect(find.byKey(kM3eAddFieldKey));
          }
          _expectRectNear(rect, _ref(scene, e.key), e.key);
        }
      });
    }
  });

  group('поведение', () {
    testWidgets('вставка из буфера заполняет поле и включает «Добавить»',
        (tester) async {
      _mockClipboard(tester, '  $_link  ');
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester);
      var submit = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(kM3eAddSubmitKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(submit.onTap, isNull, reason: 'пустое поле — кнопка выключена');
      await tester.tap(find.byKey(kM3eAddFieldPasteKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fieldText(tester), _link);
      submit = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(kM3eAddSubmitKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(submit.onTap, isNotNull);
    });

    testWidgets('пустой буфер оставляет поле как было', (tester) async {
      _mockClipboard(tester, null);
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester, initial: 'abc');
      await tester.tap(find.byKey(kM3eAddFieldPasteKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fieldText(tester), 'abc');
    });

    testWidgets('обёртка dropweb://install-config в буфере разворачивается',
        (tester) async {
      _mockClipboard(
        tester,
        'dropweb://install-config?url=${Uri.encodeComponent(_link)}',
      );
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester);
      await tester.tap(find.byKey(kM3eAddFieldPasteKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fieldText(tester), _link);
    });

    testWidgets('неверная ссылка: ошибка под полем, импорта нет, лист открыт',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, overrides: _overrides(calls));
      await _openStandalone(tester, initial: 'vmess://abc');
      expect(find.byKey(kM3eAddFieldSupKey), findsNothing);
      await tester.tap(find.byKey(kM3eAddSubmitKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(kM3eAddFieldSupKey), findsOneWidget);
      expect(
          find.text(AppLocalizations.current.m3eAddFieldError), findsOneWidget);
      expect(calls.imports, isEmpty);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets('верная ссылка (http и https): импорт и закрытие листа',
        (tester) async {
      for (final url in ['https://a.example.org/sub', 'http://10.0.0.1/s/x']) {
        final calls = _Calls();
        await _pump(tester, overrides: _overrides(calls));
        await _openStandalone(tester, initial: '  $url ');
        await tester.tap(find.byKey(kM3eAddSubmitKey));
        await _settle(tester, 400);
        expect(calls.imports, [url], reason: url);
        expect(find.byKey(_sheetKey), findsNothing, reason: url);
        expect(tester.binding.transientCallbackCount, 0);
      }
    });

    testWidgets('в стеке «Подписка» отправка закрывает весь лист',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, overrides: _overrides(calls));
      await _openInStack(tester, initial: _link);
      await tester.tap(find.byKey(kM3eAddSubmitKey));
      await _settle(tester, 400);
      expect(calls.imports, [_link]);
      expect(find.byKey(_sheetKey), findsNothing);
    });

    testWidgets('onDone вызывается вместо закрытия маршрута', (tester) async {
      final calls = _Calls();
      var done = 0;
      await _pump(tester, overrides: _overrides(calls));
      unawaited(
        showM3eSheet<void>(
          _ctx(tester),
          builder: (context) => M3eAddSubscriptionView(
            initialValue: _link,
            onDone: () => done++,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(kM3eAddSubmitKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(done, 1);
      expect(calls.imports, [_link]);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets('Enter в поле отправляет форму', (tester) async {
      final calls = _Calls();
      await _pump(tester, overrides: _overrides(calls));
      await _openStandalone(tester, initial: _link);
      await tester.showKeyboard(find.byKey(kM3eAddFieldInputKey));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester, 400);
      expect(calls.imports, [_link]);
    });

    testWidgets('«Сканировать QR-код» вызывает сканер и не закрывает лист',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, overrides: _overrides(calls));
      await _openStandalone(tester);
      await tester.tap(find.byKey(kM3eAddQrKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.scans, 1);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets(
        'сборка вне магазинов, аккаунт доступен, dropweb-account объявлен: '
        'входа по почте нет', (tester) async {
      // Решение владельца 2026-10-29: в M3E-интерфейсе аккаунта нет ни в одной
      // сборке, даже когда провайдер объявил бэкенд входа.
      await _pump(
        tester,
        overrides: [
          m3eAddImportProvider.overrideWithValue((url) async {}),
          m3eAddScanProvider.overrideWithValue((context) async {}),
          accountFeatureEnabledProvider.overrideWithValue(true),
          accountLoginBasesProvider
              .overrideWithValue(['https://api.example.org']),
        ],
      );
      await _openStandalone(tester);
      expect(find.byKey(const ValueKey<String>('m3e.add.email')), findsNothing);
      expect(find.text(AppLocalizations.current.accountLoginByEmail),
          findsNothing);
      expect(find.byKey(kM3eAddQrKey), findsOneWidget);
    });

    testWidgets('семантика: подписи поля, вставки, QR и «Добавить»',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester, initial: _link);
      final l10n = AppLocalizations.current;
      expect(tester.getSemantics(find.byKey(kM3eAddFieldPasteKey)).label,
          contains(l10n.paste));
      expect(
        tester.getSemantics(find.byKey(kM3eAddFieldInputKey)).label,
        contains(l10n.m3eAddFieldLabel),
      );
      expect(tester.getSemantics(find.byKey(kM3eAddQrKey)).label,
          contains(l10n.m3eEmptyScanQr));
      expect(tester.getSemantics(find.byKey(kM3eAddSubmitKey)).label,
          contains(l10n.add));
      semantics.dispose();
    });

    testWidgets('клавиатура поднимает содержимое над собой', (tester) async {
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester);
      final before = tester.getRect(find.byKey(kM3eAddSubmitKey)).bottom;
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final after = tester.getRect(find.byKey(kM3eAddSubmitKey)).bottom;
      expect(before - after, greaterThan(100));
      expect(tester.takeException(), isNull);
    });
  });

  group('Android TV: «Получить с телефона»', () {
    List<Override> tv(
      _Calls calls, {
      required bool isTv,
      String? received,
    }) =>
        [
          ..._overrides(calls),
          m3eAddIsTvProvider.overrideWith((ref) async => isTv),
          m3eAddReceiveProvider.overrideWithValue((context) async => received),
        ];

    testWidgets('не телевизор: пункта нет', (tester) async {
      await _pump(tester, overrides: tv(_Calls(), isTv: false));
      await _openStandalone(tester);
      expect(find.byKey(kM3eAddPhoneKey), findsNothing);
    });

    testWidgets(
        'телевизор: пункт с подписью, тап принимает ссылку и импортирует',
        (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        overrides: tv(calls, isTv: true, received: _link),
      );
      await _openStandalone(tester);
      expect(find.byKey(kM3eAddPhoneKey), findsOneWidget);
      expect(find.text(AppLocalizations.current.addFromPhoneTitle),
          findsOneWidget);
      expect(find.text(AppLocalizations.current.addFromPhoneSubtitle),
          findsOneWidget);
      await tester.tap(find.byKey(kM3eAddPhoneKey));
      await _settle(tester, 400);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls.imports, [_link]);
      expect(find.byKey(_sheetKey), findsNothing);
    });

    testWidgets('диалог закрыт без ссылки: импорта нет, лист открыт',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, overrides: tv(calls, isTv: true));
      await _openStandalone(tester);
      await tester.tap(find.byKey(kM3eAddPhoneKey));
      await _settle(tester, 400);
      expect(calls.imports, isEmpty);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });
  });

  group('worst case', () {
    testWidgets('очень длинная ссылка без пробелов не ломает поле',
        (tester) async {
      final long =
          'https://${'very-long-subdomain-' * 20}example.org/${'x' * 300}';
      await _pump(tester, overrides: _overrides(_Calls()));
      await _openStandalone(tester, initial: long);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byKey(kM3eAddFieldKey));
      expect(field.width, 379);
      expect(field.height, 56);
    });

    testWidgets('шрифт 2,0 с ошибкой: без переполнения', (tester) async {
      await _pump(
        tester,
        textScale: 2,
        overrides: _overrides(_Calls(), loginAvailable: true),
      );
      await _openStandalone(tester, initial: 'мусор');
      await tester.tap(find.byKey(kM3eAddSubmitKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(kM3eAddFieldSupKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('низкое окно: лист прокручивается', (tester) async {
      await _pump(
        tester,
        textScale: 1.3,
        overrides: _overrides(_Calls(), loginAvailable: true),
      );
      tester.view.physicalSize = const Size(411 * 2, 420 * 2);
      await _openStandalone(tester, initial: _link);
      expect(tester.takeException(), isNull);
    });

    testWidgets('узкое окно 320 dp', (tester) async {
      await _pump(
        tester,
        textScale: 1.3,
        overrides: _overrides(_Calls(), loginAvailable: true),
      );
      tester.view.physicalSize = const Size(320 * 2, 914 * 2);
      await _openStandalone(tester, initial: _link);
      expect(tester.takeException(), isNull);
    });
  });
}
