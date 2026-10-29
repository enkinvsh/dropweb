import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/color.dart' show scheme;
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart' show m3ePrivacyUrl;
import 'package:dropweb/ui/m3e/screens/m3e_dialogs.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart'
    show m3eLogoSvgProvider;
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

final String _logoSvg =
    File('test/m3e/fixtures/board_logo.svg').readAsStringSync();

const _dialog = ValueKey<String>('m3e.dialog');
const _title = ValueKey<String>('m3e.dialog.title');
const _text = ValueKey<String>('m3e.dialog.text');
const _scrim = ValueKey<String>('m3e.dialog.scrim');
const _link = ValueKey<String>('m3e.dialog.link');
const _action0 = ValueKey<String>('m3e.dialog.action.0');
const _action1 = ValueKey<String>('m3e.dialog.action.1');

/// Главная сцены home-off под диалогом: эталон `disclosure-*` снят поверх неё.
Widget _app(int provider, Brightness brightness, {bool reduced = true}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    overrides: [
      m3eHomeInputProvider.overrideWithValue(homeInputFor('home-off')),
      m3eHomeClockProvider.overrideWithValue(() => kHomeNow),
      m3eIpCheckSignalProvider.overrideWithValue((0, false)),
      m3eIpRefreshProvider.overrideWithValue(
        M3eIpRefresh(read: () => null, reset: () {}, checkQuiet: () async {}),
      ),
      m3eIpLogProvider.overrideWithValue((_) {}),
      m3eRouteNodeProvider.overrideWithValue(null),
      m3eLogoSvgProvider(kBoardNormal.logos[0]!)
          .overrideWith((ref) => _logoSvg),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: const M3eHome(),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  int provider,
  Brightness brightness, {
  bool shadows = false,
}) async {
  // Тени нужны golden: без этого flutter_test рисует их жёсткой обводкой.
  debugDisableShadows = !shadows;
  await pumpM3eBoard(tester, _app(provider, brightness));
  await tester.pump(const Duration(seconds: 1));
}

/// Открывает диалог и доигрывает вход. Возвращает будущее результата.
Future<Future<T>> _open<T>(
  WidgetTester tester,
  Future<T> Function(BuildContext context) show,
) async {
  final context = tester.element(find.byType(M3eHomeScreen));
  final future = show(context);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return future;
}

/// Закрытие: первый кадр после нажатия только заводит тикер, время идёт со второго.
Future<void> _settleClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

Rect _rect(Object? raw) {
  final m = (raw is List ? raw.first : raw) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _near(Rect a, Rect e, String what, {double tol = 4}) {
  for (final (n, x, y) in [
    ('left', a.left, e.left),
    ('top', a.top, e.top),
    ('width', a.width, e.width),
    ('height', a.height, e.height),
  ]) {
    expect((x - y).abs(), lessThanOrEqualTo(tol), reason: '$what $n: $a vs $e');
  }
}

void main() {
  late AppLocalizations l;
  final layout = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  tearDown(() => debugDisableShadows = true);

  group('golden', () {
    for (final brightness in Brightness.values) {
      for (final p in const [0, 5]) {
        final name = 'disclosure_${brightness.name}_p$p';
        testWidgets(name, (tester) async {
          await _pump(tester, p, brightness, shadows: true);
          final result = await _open(tester, showM3eVpnDisclosure);
          await _golden(tester, name);
          await tester.tap(find.byKey(_action0));
          await _settleClose(tester);
          expect(await result, isFalse);
        });
      }
      testWidgets('delete_${brightness.name}_p0', (tester) async {
        await _pump(tester, 0, brightness, shadows: true);
        final result = await _open(
          tester,
          (c) => showM3eDeleteSubscription(c, name: kBoardNormal.profiles[0]),
        );
        await _golden(tester, 'delete_${brightness.name}_p0');
        await tester.tap(find.byKey(_action0));
        await _settleClose(tester);
        expect(await result, isFalse);
      });
    }
  });

  group('раскрытие VPN', () {
    testWidgets('«Продолжить» → true, диалог уходит', (tester) async {
      await _pump(tester, 0, Brightness.light);
      final result = await _open(tester, showM3eVpnDisclosure);
      expect(find.byKey(_dialog), findsOneWidget);
      await tester.tap(find.byKey(_action1));
      await _settleClose(tester);
      expect(await result, isTrue);
      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('«Отмена», «Назад» и scrim → false', (tester) async {
      await _pump(tester, 0, Brightness.light);
      var result = await _open(tester, showM3eVpnDisclosure);
      await tester.tap(find.byKey(_action0));
      await _settleClose(tester);
      expect(await result, isFalse);

      result = await _open(tester, showM3eVpnDisclosure);
      await tester.binding.handlePopRoute();
      await _settleClose(tester);
      expect(await result, isFalse);

      result = await _open(tester, showM3eVpnDisclosure);
      await tester.tapAt(const Offset(10, 10));
      await _settleClose(tester);
      expect(await result, isFalse);
      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('тексты: короткое раскрытие, заголовок и кнопки доски',
        (tester) async {
      await _pump(tester, 0, Brightness.light);
      await _open(tester, showM3eVpnDisclosure);
      expect(
          tester.widget<Text>(find.byKey(_title)).data, 'Перед подключением');
      // Тело выделяемое: SelectableText, а не Text.
      final body = tester.widget<SelectableText>(find.byKey(_text));
      expect(body.data, l.m3eDisclosureBody);
      // Полный юридический текст остался за политикой: в диалоге он втрое короче.
      expect(body.data, isNot(l.vpnDisclosureBody));
      expect(body.data!.length, lessThan(l.vpnDisclosureBody.length));
      expect(body.data!.length, lessThan(330));
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(
        tester
            .widget<M3eSymbolIcon>(find.descendant(
              of: find.byKey(_dialog),
              matching: find.byType(M3eSymbolIcon),
            ))
            .symbol,
        M3eSymbol.vpnKey,
      );
    });

    testWidgets('ссылка на политику открывает адрес и не закрывает диалог',
        (tester) async {
      await _pump(tester, 0, Brightness.light);
      final opened = <String>[];
      final result = await _open(
        tester,
        (c) => showM3eVpnDisclosure(c, openUrl: (u) async => opened.add(u)),
      );
      await tester.tap(find.byKey(_link));
      await tester.pump();
      expect(opened, [m3ePrivacyUrl()]);
      expect(opened.single, startsWith('https://dropweb.org/'));
      // Диалог на месте, согласие не записано: результат ещё не пришёл.
      expect(find.byKey(_dialog), findsOneWidget);
      var done = false;
      unawaited(result.then((_) => done = true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isFalse);
      await tester.tap(find.byKey(_action1));
      await _settleClose(tester);
      expect(await result, isTrue);
    });

    testWidgets('диалог укладывается в экран без прокрутки', (tester) async {
      await _pump(tester, 0, Brightness.light);
      await _open(tester, showM3eVpnDisclosure);
      final rect = tester.getRect(find.byKey(_dialog));
      // Доска с текстом в 4 строки даёт 280; наш текст девять строк плюс ссылка 40 и отступ 4.
      expect(rect.height, lessThan(440));
      final body =
          tester.getRect(find.byKey(const ValueKey<String>('m3e.dialog.body')));
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('m3e.dialog.body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, 0, reason: 'тело $body');
    });

    testWidgets('WORST: шрифт 2,0 без переполнения, кнопки видны',
        (tester) async {
      await _pump(tester, 0, Brightness.light);
      final context = tester.element(find.byType(M3eHomeScreen));
      final future = showM3eVpnDisclosure(
        context,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(_dialog));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(914));
      final a1 = tester.getRect(find.byKey(_action1));
      expect(a1.bottom, lessThanOrEqualTo(rect.bottom));
      await tester.tap(find.byKey(_action1));
      await _settleClose(tester);
      expect(await future, isTrue);
    });

    testWidgets('диалог не вылезает за экран, по центру', (tester) async {
      await _pump(tester, 0, Brightness.light);
      await _open(tester, showM3eVpnDisclosure);
      final rect = tester.getRect(find.byKey(_dialog));
      expect(rect.width, 312);
      expect(rect.center.dx, closeTo(411 / 2, 0.5));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(914));
      expect(tester.takeException(), isNull);
    });

    testWidgets('контекст без M3eThemeScope: цвета берутся из провайдера',
        (tester) async {
      // «Старый экран»: ProviderScope есть, M3eThemeScope выше диалога нет.
      debugDisableShadows = true;
      late BuildContext outside;
      await pumpM3eBoard(
        tester,
        ProviderScope(
          overrides: [
            m3eThemeSourceProvider.overrideWithValue(
              const M3eThemeSource(seed: '#EF4444', filter: 'fidelity'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: Builder(
              builder: (context) {
                outside = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final result = showM3eVpnDisclosure(outside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final material = tester.widget<Material>(find.byKey(_dialog));
      final expected = scheme('#EF4444', 'fidelity', dark: false);
      expect(material.color, expected.surfaceContainerHigh);
      await tester.tap(find.byKey(_action1));
      await _settleClose(tester);
      expect(await result, isTrue);
    });
  });

  group('удаление подписки', () {
    testWidgets('«Удалить» → true, красная кнопка', (tester) async {
      await _pump(tester, 0, Brightness.light);
      final result = await _open(
        tester,
        (c) => showM3eDeleteSubscription(c, name: 'DROPWEB'),
      );
      expect(
          tester.widget<Text>(find.byKey(_title)).data, 'Удалить «DROPWEB»?');
      expect(tester.widget<Text>(find.byKey(_text)).data, l.m3eDeleteBody);
      expect(find.text('Удалить'), findsOneWidget);
      await tester.tap(find.byKey(_action1));
      await _settleClose(tester);
      expect(await result, isTrue);
    });

    testWidgets('«Назад» и scrim → false', (tester) async {
      await _pump(tester, 0, Brightness.light);
      var result = await _open(
        tester,
        (c) => showM3eDeleteSubscription(c, name: 'x'),
      );
      await tester.binding.handlePopRoute();
      await _settleClose(tester);
      expect(await result, isFalse);
      result = await _open(
        tester,
        (c) => showM3eDeleteSubscription(c, name: 'x'),
      );
      // Центр scrim закрыт диалогом, поэтому касаемся угла экрана.
      await tester.tapAt(const Offset(10, 10));
      await _settleClose(tester);
      expect(await result, isFalse);
    });

    testWidgets('WORST: длинное имя переносится без переполнения',
        (tester) async {
      await _pump(tester, 0, Brightness.light);
      for (final name in [
        kBoardWorst.profiles.first,
        'Ы' * 80,
        'https://${'очень-длинное-имя' * 6}',
      ]) {
        final result = await _open(
          tester,
          (c) => showM3eDeleteSubscription(c, name: name),
        );
        expect(tester.takeException(), isNull, reason: name);
        final rect = tester.getRect(find.byKey(_dialog));
        expect(rect.width, 312, reason: name);
        expect(rect.top, greaterThanOrEqualTo(0), reason: name);
        expect(rect.bottom, lessThanOrEqualTo(914), reason: name);
        expect(
            tester.getRect(find.byKey(_title)).width, lessThanOrEqualTo(264));
        await tester.tap(find.byKey(_action0));
        await _settleClose(tester);
        expect(await result, isFalse);
      }
    });
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final (brightness, p) in [
      (Brightness.light, 0),
      (Brightness.dark, 5),
    ]) {
      final scene = 'disclosure-${brightness.name}-p$p';
      final els = (layout[scene] as Map<String, dynamic>)['elements']
          as Map<String, dynamic>;

      testWidgets(
          '$scene: x, ширина, значок, заголовок; высота = доска + лишний текст + ссылка',
          (tester) async {
        await _pump(tester, p, brightness);
        await _open(tester, showM3eVpnDisclosure);
        final dialog = tester.getRect(find.byKey(_dialog));
        final ref = _rect(els['dialog']);
        expect((dialog.left - ref.left).abs(), lessThanOrEqualTo(4));
        expect((dialog.width - ref.width).abs(), lessThanOrEqualTo(4));
        // Диалог выше доски ровно на лишние строки текста и ссылку (40 + отступ 4).
        final textDelta = tester.getRect(find.byKey(_text)).height -
            _rect(els['dialog.text']).height;
        final link = tester.getRect(find.byKey(_link));
        expect(link.height, 40);
        expect(dialog.height - ref.height,
            closeTo(textDelta + link.height + 4, 1));
        final dy = dialog.top - ref.top;
        _near(tester.getRect(find.byKey(_title)),
            _rect(els['dialog.title']).shift(Offset(0, dy)), 'title');
        _near(
          tester.getRect(find.descendant(
            of: find.byKey(_dialog),
            matching: find.byType(M3eSymbolIcon),
          )),
          _rect(els['dialog.icon']).shift(Offset(0, dy)),
          'dialog.icon',
        );
        _near(tester.getRect(find.byKey(_scrim)), _rect(els['scrim']), 'scrim');
      });

      testWidgets('$scene: юридический текст — x, ширина, значок, заголовок',
          (tester) async {
        await _pump(tester, p, brightness);
        await _open(tester, showM3eVpnDisclosure);
        final dialog = tester.getRect(find.byKey(_dialog));
        final ref = _rect(els['dialog']);
        expect((dialog.left - ref.left).abs(), lessThanOrEqualTo(4));
        expect((dialog.width - ref.width).abs(), lessThanOrEqualTo(4));
        // Значок и заголовок стоят в верху диалога и от длины текста не зависят:
        // сдвиг по y равен сдвигу верха диалога.
        final dy = dialog.top - ref.top;
        _near(
          tester.getRect(find.byKey(_title)),
          _rect(els['dialog.title']).shift(Offset(0, dy)),
          'title',
        );
        // Кнопки прижаты к низу диалога, их ширина от текста не зависит.
        final a0 = tester.getRect(find.byKey(_action0));
        final a1 = tester.getRect(find.byKey(_action1));
        final actions = els['dialog.action'] as List;
        expect(
            (a0.width - _rect(actions[0]).width).abs(), lessThanOrEqualTo(4));
        expect(
            (a1.width - _rect(actions[1]).width).abs(), lessThanOrEqualTo(4));
        expect(
            (a1.right - _rect(actions[1]).right).abs(), lessThanOrEqualTo(4));
      });
    }
  });

  test('контракт: Future<bool> новой функции подходит под Future<bool?> старой',
      () {
    // Платформа теста macOS: ветку Platform.isAndroid здесь не включить, поэтому
    // проверяем, что контракт старой функции (bool?) совместим с bool новой.
    const Future<bool?> Function(BuildContext) legacy = showM3eVpnDisclosure;
    expect(legacy, isNotNull);
  });
}
