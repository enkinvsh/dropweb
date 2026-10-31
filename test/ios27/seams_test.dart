// Швы старого кода к слоям iOS: CommonDialog, showCommonDialog/showMessage, showSheet, MessageManager.

import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_toast.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:dropweb/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';
import 'support/golden.dart';
import 'support/layer_harness.dart';

const _toastKey = ValueKey<String>('ios27.toast');
const _frameKey = ValueKey<String>('ios27.sheet.frame');

/// Корень как у приложения: `navigatorKey` из `globalState`, `ProviderScope` выше, тема Lumina
/// снаружи. Областей iOS над навигатором нет: каждый слой обязан принести свою тему.
Widget _app({Widget? home}) => ProviderScope(
      overrides: layerOverrides(),
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
        home: Scaffold(body: home ?? const SizedBox.expand()),
      ),
    );

BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  // commonPrint.log пишет в файловый журнал, которому нужен appPath. Без подмены на Linux
  // `getDownloadsDirectory()` бросает UnsupportedError раньше канала, и ошибка падает на
  // тест, который первым вывел плашку или строку журнала.
  useFakePathProvider();
  late bool savedDialog;
  late bool savedM3eDialog;
  late bool savedSheet;
  late bool savedM3eSheet;

  setUpAll(() {
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(411, 914),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
  });

  setUp(() {
    savedDialog = CommonDialog.defaultUseIos27;
    savedM3eDialog = CommonDialog.defaultUseM3e;
    savedSheet = SheetSkin.defaultUseIos27;
    savedM3eSheet = SheetSkin.defaultUseM3e;
    // Платформа теста macOS: по умолчанию все новые пути выключены.
    CommonDialog.defaultUseM3e = false;
    SheetSkin.defaultUseM3e = false;
  });
  tearDown(() {
    CommonDialog.defaultUseIos27 = savedDialog;
    CommonDialog.defaultUseM3e = savedM3eDialog;
    SheetSkin.defaultUseIos27 = savedSheet;
    SheetSkin.defaultUseM3e = savedM3eSheet;
  });

  group('CommonDialog', () {
    Future<void> show(WidgetTester tester, {bool? useIos27}) async {
      unawaited(
        showDialog<void>(
          context: _root(tester),
          builder: (_) => CommonDialog(
            title: 'Заголовок',
            useIos27: useIos27,
            actions: [TextButton(onPressed: () {}, child: const Text('Ок'))],
            child: const Text('Текст'),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('useIos27: true рисует алерт iOS в собственной теме',
        (tester) async {
      await pumpIos27Board(tester, _app());
      await show(tester, useIos27: true);
      expect(find.byType(Ios27Alert), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        Ios27Colors.maybeOf(tester.element(find.byType(Ios27Alert))),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('useIos27: false оставляет старый AlertDialog', (tester) async {
      await pumpIos27Board(tester, _app());
      await show(tester, useIos27: false);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Ios27Alert), findsNothing);
    });

    testWidgets(
        'по умолчанию (macOS) старый путь, defaultUseIos27 включает iOS',
        (tester) async {
      await pumpIos27Board(tester, _app());
      await show(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      CommonDialog.defaultUseIos27 = true;
      await show(tester);
      expect(find.byType(Ios27Alert), findsOneWidget);
    });
  });

  group('showCommonDialog / showMessage', () {
    setUp(() => CommonDialog.defaultUseIos27 = true);

    testWidgets('dismissible: false блокирует затемнение и «назад» (урок 25)',
        (tester) async {
      await pumpIos27Board(tester, _app());
      unawaited(
        globalState.showCommonDialog<bool>(
          dismissible: false,
          child: CommonDialog(
            title: 'Обязательное',
            actions: [
              TextButton(
                onPressed: () => Navigator.of(_root(tester)).pop(true),
                child: const Text('Продолжить'),
              ),
            ],
            child: const Text('Текст'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsOneWidget);
      await tester.tap(find.text('Продолжить'));
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsNothing);
    });

    testWidgets('dismissible: true закрывается затемнением', (tester) async {
      await pumpIos27Board(tester, _app());
      final result = globalState.showCommonDialog<bool>(
        child: const CommonDialog(title: 'Заголовок', child: Text('Текст')),
      );
      await _settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsNothing);
      expect(await result, isNull);
    });

    testWidgets(
        'showMessage: деструктивная кнопка красным текстом iOS, возвращает true',
        (tester) async {
      await pumpIos27Board(tester, _app());
      final result = globalState.showMessage(
        message: const TextSpan(text: 'Удалить подписку?'),
        confirmText: 'Удалить',
        destructive: true,
      );
      await _settle(tester);
      expect(find.byType(Ios27Alert), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.ancestor(
            of: find.text('Удалить'), matching: find.byType(TextButton)),
      );
      final fg = button.style!.foregroundColor!.resolve(<WidgetState>{});
      final palette =
          Ios27Colors.maybeOf(tester.element(find.byType(Ios27Alert)))!.palette;
      expect(fg, palette.redText);
      await tester.tap(find.text('Удалить'));
      await _settle(tester);
      expect(await result, isTrue);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('showSheet / AdaptiveSheetScaffold', () {
    Future<void> show(WidgetTester tester, {bool? useIos27}) async {
      unawaited(
        showSheet<void>(
          context: _root(tester),
          useIos27: useIos27,
          builder: (context, type) => AdaptiveSheetScaffold(
            type: type,
            title: 'Настройки',
            body: const SizedBox(height: 80),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('useIos27: true — лист iOS с шапкой', (tester) async {
      await pumpIos27Board(tester, _app());
      SheetSkin.defaultUseIos27 = true;
      await show(tester, useIos27: true);
      expect(find.byKey(_frameKey), findsOneWidget);
      expect(find.byType(Ios27SheetScaffold), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('useIos27: false — прежний нижний лист', (tester) async {
      await pumpIos27Board(tester, _app());
      await show(tester, useIos27: false);
      expect(find.byKey(_frameKey), findsNothing);
      expect(find.byType(Ios27SheetScaffold), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('useIos27: null на macOS — прежний путь', (tester) async {
      await pumpIos27Board(tester, _app());
      await show(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('MessageManager', () {
    Future<MessageManagerState> pump(
      WidgetTester tester, {
      bool? useIos27,
      bool useM3e = false,
    }) async {
      await pumpIos27Board(
        tester,
        ProviderScope(
          overrides: layerOverrides(),
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: MessageManager(
              useM3e: useM3e,
              useIos27: useIos27,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      return tester.state<MessageManagerState>(find.byType(MessageManager));
    }

    testWidgets('useIos27: true — стеклянный тост iOS, уходит сам',
        (tester) async {
      final manager = await pump(tester, useIos27: true);
      expect(find.byKey(_toastKey), findsNothing);
      unawaited(
          manager.message('Подписка обновлена', kind: M3eToastKind.check));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(_toastKey), findsOneWidget);
      expect(find.text('Подписка обновлена'), findsOneWidget);
      expect(find.byType(Ios27ToastPresenter), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('useIos27: false — прежний путь без тоста iOS', (tester) async {
      final manager = await pump(tester, useIos27: false);
      unawaited(manager.message('Привет'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Ios27ToastPresenter), findsNothing);
      expect(find.byKey(_toastKey), findsNothing);
      // Дорисовать хвост прежней очереди: таймеры сообщений.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('useIos27: null на macOS — прежний путь', (tester) async {
      final manager = await pump(tester);
      unawaited(manager.message('Привет'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Ios27ToastPresenter), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('useM3e идёт первым: без тоста iOS', (tester) async {
      final manager = await pump(tester, useIos27: true, useM3e: true);
      unawaited(manager.message('Привет'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(Ios27ToastPresenter), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
