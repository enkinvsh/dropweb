// Автопредложение обновления (Android sideload): результат автоматической
// проверки available открывает шит ровно один раз, «Позже» откладывает эту
// версию на сутки и следующий результат с той же версией шит уже не открывает.
import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/app_update_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _info = AppUpdateInfo(
  version: '0.9.0',
  tag: 'v0.9.0',
  primaryUrl: 'https://yc/apk',
);

/// Сеть и Platform-гейт подменены: каждый вызов check() отдаёт следующий
/// заготовленный результат, пустая очередь = проверка не запускалась
/// (интервал не прошёл) и состояние не меняется.
class _FakeAppUpdate extends AppUpdate {
  final results = <AppUpdateState>[];

  @override
  Future<void> check({bool manual = false}) async {
    if (results.isNotEmpty) state = results.removeAt(0);
  }
}

void main() {
  late _FakeAppUpdate fake;

  setUp(() {
    globalState.config = const Config(themeProps: defaultThemeProps);
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(400, 800),
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
    );
    fake = _FakeAppUpdate();
  });

  testWidgets('auto check result opens the sheet once and «Позже» snoozes',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdateProvider.overrideWith(() => fake)],
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
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = globalState.navigatorKey.currentContext!;
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(appUpdateProvider.notifier);

    fake.results.add(
      const AppUpdateState(status: AppUpdateStatus.available, info: _info),
    );
    expect(await notifier.autoCheck(), isTrue);
    unawaited(offerUpdateSheet(context));
    await tester.pumpAndSettle();
    expect(find.text('$appName 0.9.0'), findsOneWidget);

    // Проверка не прошла по интервалу — нового результата нет, повтора нет;
    // и даже прямой вызов не кладёт второй шит поверх открытого.
    expect(await notifier.autoCheck(), isFalse);
    unawaited(offerUpdateSheet(context));
    await tester.pumpAndSettle();
    expect(find.text('$appName 0.9.0'), findsOneWidget);

    final before = DateTime.now();
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(find.text('$appName 0.9.0'), findsNothing);

    final setting = container.read(appSettingProvider);
    expect(setting.updateSnoozedVersion, '0.9.0');
    expect(
      setting.updateSnoozedUntilMs,
      greaterThanOrEqualTo(
        before.add(kUpdateSnoozeDuration).millisecondsSinceEpoch,
      ),
    );

    // Та же версия в течение суток — не предлагаем; новая — сразу.
    fake.results.add(
      const AppUpdateState(status: AppUpdateStatus.available, info: _info),
    );
    expect(await notifier.autoCheck(), isFalse);
    fake.results.add(
      AppUpdateState(
        status: AppUpdateStatus.available,
        info: _info.copyWith(version: '0.9.1', tag: 'v0.9.1'),
      ),
    );
    expect(await notifier.autoCheck(), isTrue);
  });

  // Юзер ушёл в почту за кодом и вернулся — шит обновления не должен лечь
  // поверх открытой шторки входа; обновление ждёт в настройках.
  testWidgets('another sheet or dialog is open => no auto offer',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdateProvider.overrideWith(() => fake)],
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
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = globalState.navigatorKey.currentContext!;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('login')),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(context);
    fake.results.add(
      const AppUpdateState(status: AppUpdateStatus.available, info: _info),
    );
    expect(await container.read(appUpdateProvider.notifier).autoCheck(),
        isTrue);
    unawaited(offerUpdateSheet(context));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
    expect(find.text('$appName 0.9.0'), findsNothing);
  });

  test('autoCheckUpdate off => no auto offer', () async {
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      appSetting: AppSettingProps(autoCheckUpdate: false),
    );
    final container = ProviderContainer(
      overrides: [appUpdateProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);
    fake.results.add(
      const AppUpdateState(status: AppUpdateStatus.available, info: _info),
    );
    expect(
        await container.read(appUpdateProvider.notifier).autoCheck(), isFalse);
  });
}
