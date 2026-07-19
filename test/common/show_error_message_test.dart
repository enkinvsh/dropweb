import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _TestLogs extends Logs {
  @override
  FixedList<Log> build() => FixedList(
        500,
        list: [Log.app('[test] support line')],
      );
}

class _TestViewSize extends ViewSize {
  @override
  Size build() => const Size(800, 600);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  late Directory supportDirectory;
  String? clipboardText;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'dropweb_show_error_message_test',
    );
    clipboardText = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => supportDirectory.path,
    );
    await Future.wait([
      appPath.dataDir.future,
      appPath.tempDir.future,
      appPath.downloadDir.future,
    ]);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.8.6',
      buildNumber: '2050000001',
    );
  });

  tearDown(() async {
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    await supportDirectory.delete(recursive: true);
  });

  testWidgets(
    'error dialog copies diagnostics without closing and OK dismisses it',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logsProvider.overrideWith(_TestLogs.new),
            viewSizeProvider.overrideWith(_TestViewSize.new),
          ],
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            builder: (_, child) => MessageManager(child: child!),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialogFuture = globalState.showErrorMessage(
        message: const TextSpan(text: 'Сбой импорта'),
        diagnosticPhase: 'import',
      );
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.text('Ошибка'), findsOneWidget);
      expect(find.text('Скопировать логи'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Отмена'), findsNothing);
      expect(find.text('Подтвердить'), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Скопировать логи'));
      for (var attempt = 0; attempt < 100 && clipboardText == null; attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }

      final copiedText = clipboardText;
      final dialogStayedOpen = find.byType(AlertDialog).evaluate().length;
      final copiedNotifier = find.text('Логи скопированы').evaluate().length;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await dialogFuture;

      expect(copiedText, startsWith('dropweb diagnostics'));
      expect(dialogStayedOpen, 1);
      expect(copiedNotifier, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
