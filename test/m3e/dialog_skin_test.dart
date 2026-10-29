import 'package:animations/animations.dart';
import 'package:dropweb/common/common.dart' show FixedList;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart' show AppState, Traffic;
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/color/color.dart' show scheme;
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_dialog_skin.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/fake_path_provider.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/surface.dart';

const _dialog = ValueKey<String>('m3e.dialog');
const _title = ValueKey<String>('m3e.dialog.title');
const _body = ValueKey<String>('m3e.dialog.body');

const _confirmText =
    'Подписка «DROPWEB» исчезнет из списка. Оплаченный доступ у провайдера '
    'останется, добавить её можно снова по ссылке.';

const _errorText =
    'Не удалось обновить подписку «DROPWEB»: сервер провайдера ответил кодом '
    '502 и закрыл соединение. Проверьте подключение к сети и повторите попытку '
    'чуть позже. Если ошибка не уходит, скопируйте журнал и отправьте его в '
    'поддержку провайдера.';

/// Корень как у приложения: навигатор с `navigatorKey` (через него `globalState` открывает
/// диалоги) и ТЁМНАЯ тема снаружи, как у старого Lumina. Диалог обязан перекраситься сам:
/// M3eThemeScope выше корневого навигатора нет.
Widget _app({
  required Brightness brightness,
  int provider = 0,
  double textScale = 1,
}) {
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
            textScaler: TextScaler.linear(textScale),
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
            home: const Scaffold(backgroundColor: Color(0xFF444444)),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool shadows = false,
}) async {
  debugDisableShadows = !shadows;
  await pumpM3eBoard(
    tester,
    _app(brightness: brightness, textScale: textScale),
  );
}

/// Открывает диалог и доигрывает вход (FadeScale ~150 мс).
Future<Future<T>> _open<T>(
  WidgetTester tester,
  Future<T> Function() show,
) async {
  final future = show();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return future;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  useFakePathProvider();
  late bool savedDefault;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('ru'));
    // Старые провайдеры (размер окна, журнал) читают состояние из globalState.
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(411, 914),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.0.0',
      buildNumber: '1',
    );
  });

  // Платформа теста macOS: Android-ветку включаем флагом, как `MessageManager.useM3e`.
  setUp(() {
    savedDefault = CommonDialog.defaultUseM3e;
    CommonDialog.defaultUseM3e = true;
  });
  tearDown(() {
    CommonDialog.defaultUseM3e = savedDefault;
    debugDisableShadows = true;
  });

  group('golden', () {
    for (final brightness in Brightness.values) {
      testWidgets('dialog_skin_confirm_${brightness.name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        final result = await _open(
          tester,
          () => globalState.showMessage(
            title: 'Удалить профиль?',
            message: const TextSpan(text: _confirmText),
            confirmText: 'Удалить',
            destructive: true,
          ),
        );
        await _golden(tester, 'dialog_skin_confirm_${brightness.name}_p0');
        await tester.tap(find.text('Отмена'));
        await _close(tester);
        expect(await result, isFalse);
      });

      testWidgets('dialog_skin_error_${brightness.name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        await _open(
          tester,
          () async => globalState.showErrorMessage(
            message: const TextSpan(text: _errorText),
          ),
        );
        await _golden(tester, 'dialog_skin_error_${brightness.name}_p0');
        await tester.tap(find.text('OK'));
        await _close(tester);
      });
    }

    testWidgets('dialog_skin_worst_light_p0', (tester) async {
      await _pump(tester, textScale: 2, shadows: true);
      await _open(
        tester,
        () => globalState.showCommonDialog<void>(
          child: Builder(
            builder: (_) => CommonDialog(
              title: 'Лицензионное соглашение и условия использования',
              actions: [
                TextButton(onPressed: () {}, child: const Text('Отмена')),
                TextButton(onPressed: () {}, child: const Text('Принять')),
              ],
              child: Text('Очень длинный текст. ' * 100),
            ),
          ),
        ),
      );
      await _golden(tester, 'dialog_skin_worst_light_p0');
    });
  });

  group('WORST: 2000 знаков и шрифт 2,0', () {
    testWidgets('заголовок и кнопки закреплены, на экране целиком',
        (tester) async {
      await _pump(tester, textScale: 2);
      await _open(
        tester,
        () => globalState.showCommonDialog<void>(
          child: CommonDialog(
            title: 'Заголовок диалога',
            actions: [
              TextButton(onPressed: () {}, child: const Text('Отмена')),
              TextButton(onPressed: () {}, child: const Text('Принять')),
            ],
            child: Text('Длинное слово и ещё слова. ' * 80),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final dialog = tester.getRect(find.byKey(_dialog));
      expect(dialog.top, greaterThanOrEqualTo(0));
      expect(dialog.bottom, lessThanOrEqualTo(914));
      for (final label in ['Отмена', 'Принять']) {
        final b = tester.getRect(find.widgetWithText(TextButton, label));
        expect(b.bottom, lessThanOrEqualTo(dialog.bottom), reason: label);
        expect(b.bottom, lessThanOrEqualTo(914 - 24), reason: label);
      }
      expect(tester.getRect(find.byKey(_title)).top, greaterThanOrEqualTo(0));
      // Текст прокручивается: он выше окна прокрутки.
      final viewport = tester.getRect(find.byKey(_body));
      final text = tester.getRect(find.descendant(
        of: find.byKey(_body),
        matching: find.byType(Text),
      ));
      expect(text.height, greaterThan(viewport.height));
      final before = tester.getTopLeft(find.descendant(
        of: find.byKey(_body),
        matching: find.byType(Text),
      ));
      await tester.drag(find.byKey(_body), const Offset(0, -200));
      await tester.pump();
      final after = tester.getTopLeft(find.descendant(
        of: find.byKey(_body),
        matching: find.byType(Text),
      ));
      expect(after.dy, lessThan(before.dy));
      // Кнопки при прокрутке на месте.
      expect(
        tester.getRect(find.widgetWithText(TextButton, 'Принять')).bottom,
        lessThanOrEqualTo(dialog.bottom),
      );
    });

    testWidgets('showMessage с текстом 2000 знаков: кнопки на экране',
        (tester) async {
      await _pump(tester, textScale: 2);
      await _open(
        tester,
        () => globalState.showMessage(
          title: 'Ошибка импорта',
          message: TextSpan(text: 'слово ' * 340),
        ),
      );
      expect(tester.takeException(), isNull);
      final dialog = tester.getRect(find.byKey(_dialog));
      expect(dialog.bottom, lessThanOrEqualTo(914));
      expect(
        tester.getRect(find.widgetWithText(TextButton, 'Подтвердить')).bottom,
        lessThanOrEqualTo(dialog.bottom),
      );
    });
  });

  group('поведение', () {
    testWidgets('showMessage: «Подтвердить» → true, «Отмена» → false',
        (tester) async {
      await _pump(tester);
      var result = await _open(
        tester,
        () => globalState.showMessage(message: const TextSpan(text: 'a')),
      );
      expect(find.byKey(_dialog), findsOneWidget);
      await tester.tap(find.text('Подтвердить'));
      await _close(tester);
      expect(await result, isTrue);
      expect(find.byKey(_dialog), findsNothing);

      result = await _open(
        tester,
        () => globalState.showMessage(message: const TextSpan(text: 'a')),
      );
      await tester.tap(find.text('Отмена'));
      await _close(tester);
      expect(await result, isFalse);
    });

    testWidgets('cancelable: false прячет «Отмена»', (tester) async {
      await _pump(tester);
      await _open(
        tester,
        () => globalState.showMessage(
          message: const TextSpan(text: 'a'),
          cancelable: false,
        ),
      );
      expect(find.text('Отмена'), findsNothing);
      expect(find.text('Подтвердить'), findsOneWidget);
    });

    testWidgets('касание затемнения закрывает диалог и даёт null',
        (tester) async {
      await _pump(tester);
      final result = await _open(
        tester,
        () => globalState.showMessage(message: const TextSpan(text: 'a')),
      );
      await tester.tapAt(const Offset(10, 10));
      await _close(tester);
      expect(await result, isNull);
    });

    testWidgets('destructive: кнопка цветом error схемы M3E, не Lumina',
        (tester) async {
      await _pump(tester);
      await _open(
        tester,
        () => globalState.showMessage(
          message: const TextSpan(text: 'a'),
          destructive: true,
        ),
      );
      final button = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Подтвердить'));
      final expected = scheme(
              kBoardProviders[0].theme.split(',')[1], 'fidelity',
              dark: false)
          .error;
      expect(
        button.style!.foregroundColor!.resolve(<WidgetState>{}),
        expected,
      );
    });

    testWidgets('showErrorMessage: «копировать журнал» кладёт текст в буфер',
        (tester) async {
      await _pump(tester);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _open(
        tester,
        () async => globalState.showErrorMessage(
          message: const TextSpan(text: 'ошибка'),
          diagnosticPhase: 'test',
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Скопировать логи'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(copied, hasLength(1));
      expect(copied.single, isNotEmpty);
      // Диалог после копирования остаётся: закрывает его «ОК».
      expect(find.byKey(_dialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await _close(tester);
      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('затемнение M3E без блюра', (tester) async {
      await _pump(tester);
      await _open(
        tester,
        () => globalState.showMessage(message: const TextSpan(text: 'a')),
      );
      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((b) => b.color)
          .whereType<Color>()
          .toList();
      expect(barrier, contains(kM3eDialogBarrierColor));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('не Android: старый AlertDialog, затемнение без изменений',
        (tester) async {
      CommonDialog.defaultUseM3e = false;
      await _pump(tester);
      await _open(
        tester,
        () => globalState.showMessage(message: const TextSpan(text: 'a')),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(_dialog), findsNothing);
      final modal = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(modal.color, Colors.black38);
    });

    testWidgets('параметр useM3e перекрывает флаг по умолчанию',
        (tester) async {
      CommonDialog.defaultUseM3e = false;
      await _pump(tester);
      await _open(
        tester,
        () => showModal<void>(
          context: globalState.navigatorKey.currentContext!,
          builder: (_) => const CommonDialog(
            title: 'T',
            useM3e: true,
            child: Text('x'),
          ),
        ),
      );
      expect(find.byKey(_dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('поле ввода внутри скина работает', (tester) async {
      await _pump(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _open(
        tester,
        () => globalState.showCommonDialog<void>(
          child: CommonDialog(
            title: 'Ссылка',
            actions: [TextButton(onPressed: () {}, child: const Text('Ок'))],
            child: TextField(controller: controller),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'https://x');
      expect(controller.text, 'https://x');
      expect(tester.takeException(), isNull);
    });
  });

  group('m3eDialogMessageSpan', () {
    test('убирает цвет и фон, оставляет размер, насыщенность и дерево', () {
      const light = Color(0xFFFFFFFF);
      const span = TextSpan(
        text: 'a',
        style: TextStyle(
          color: light,
          backgroundColor: light,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: light,
        ),
        children: [
          TextSpan(text: 'b', style: TextStyle(color: light, fontSize: 10)),
          TextSpan(text: 'c'),
        ],
      );
      final out = m3eDialogMessageSpan(span) as TextSpan;
      expect(out.style!.color, isNull);
      expect(out.style!.backgroundColor, isNull);
      expect(out.style!.decorationColor, isNull);
      expect(out.style!.fontSize, 24);
      expect(out.style!.fontWeight, FontWeight.bold);
      expect(out.style!.decoration, TextDecoration.underline);
      expect(out.text, 'a');
      final kids = out.children!.cast<TextSpan>();
      expect(kids[0].style!.color, isNull);
      expect(kids[0].style!.fontSize, 10);
      expect(kids[1].style, isNull);
    });

    testWidgets('в диалоге светлый цвет Lumina не доходит до текста',
        (tester) async {
      await _pump(tester);
      await _open(
        tester,
        () => globalState.showMessage(
          message: const TextSpan(
            text: 'невидимый на светлом',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
      final text = tester.widget<EditableText>(find.byType(EditableText));
      final span = text.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        style: text.style,
        withComposing: false,
      );
      Color? colorOf(InlineSpan s) {
        if (s is! TextSpan) return null;
        return s.style?.color ??
            s.children?.map(colorOf).whereType<Color>().firstOrNull;
      }

      // Явного белого в цепочке стилей нет: цвет приходит от DefaultTextStyle скина.
      expect(colorOf(span), isNot(Colors.white));
    });
  });
}
