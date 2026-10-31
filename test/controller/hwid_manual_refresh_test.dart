// Лимит устройств (HWID) при ручном и автоматическом обновлении подписки.
//
// Панель отвечает на загрузку заголовком `x-hwid-limit: true` и отдаёт файл-заглушку,
// который проходит проверку тела, поэтому загрузка «успешна». Ручное «Обновить» обязано
// сказать про лимит заново (окно или плашка) даже при уже идущем эпизоде, а автоповторы
// (опрос, возврат в приложение, таймер) молчат: окно один раз на эпизод.
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/services/hwid_recovery.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

/// Содержит пробел и двоеточие: это не base64, значит окно покажет текст как есть.
const _announce = 'Device limit: free a slot';
const _removeUrl = 'https://example.test/devices';

const _body = '''
proxies:
  - name: real-1
    type: ss
    server: 203.0.113.7
    port: 443
    cipher: aes-128-gcm
    password: secret
''';

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer server;
  late String base;
  late FakeSecureProfileStore store;

  // Что панель отвечает на следующую загрузку.
  var limited = true;
  var withAnnounce = true;

  late List<String> logs;
  late DebugPrintCallback savedDebugPrint;

  setUpAll(() async {
    // Без device-заголовков: их сбор ходит в платформенные плагины.
    SharedPreferences.setMockInitialValues({'sendDeviceHeaders': false});
    // CommonDialog читает размер окна из состояния приложения.
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
      version: '0.8.1',
      buildNumber: '1',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final res = req.response
        ..statusCode = HttpStatus.ok
        ..headers.set('content-type', 'text/plain; charset=utf-8');
      if (limited) {
        res.headers.set('x-hwid-limit', 'true');
        if (withAnnounce) {
          res.headers
            ..set('announce', _announce)
            ..set('dropweb-device-remove', _removeUrl);
        }
      }
      res.write(_body);
      await res.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
    limited = true;
    withAnnounce = true;
    // Плашки пишут текст в журнал до показа: по журналу считаем, сколько их было.
    logs = [];
    savedDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  });

  tearDown(() => preferences.secureStore = secureProfileUrlStore);

  /// Плашки с текстом [text] (журнал пишет их строкой `[dropweb] <text>`).
  int toasts(String text) => logs.where((l) => l == '[dropweb] $text').length;

  int hwidLines(String verdict) => logs
      .where((l) => l.contains('[hwid] manual refresh p1: $verdict'))
      .length;

  Future<AppController> boot(
    WidgetTester tester, {
    Map<String, String> providerHeaders = const {},
  }) async {
    final profile = Profile(
      id: 'p1',
      label: 'p',
      autoUpdateDuration: const Duration(hours: 12),
      providerHeaders: providerHeaders,
    );
    globalState.config = Config(
      themeProps: defaultThemeProps,
      profiles: [profile],
      currentProfileId: 'p1',
    );
    store.urls['p1'] = '$base/sub';

    late AppController controller;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          // Как в приложении: менеджер плашек над навигатором.
          builder: (context, child) => MessageManager(
            useM3e: false,
            useIos27: false,
            child: child!,
          ),
          home: Consumer(
            builder: (context, ref, _) {
              controller = AppController(context, ref);
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  Profile current(AppController controller) =>
      globalState.config.profiles.first;

  Future<void> auto(WidgetTester tester, AppController c) =>
      tester.runAsync(() => c.updateProfile(current(c)));

  Future<HwidVerdict> manual(WidgetTester tester, AppController c) async {
    final verdict =
        await tester.runAsync(() => c.updateProfileByUser(current(c)));
    return verdict!;
  }

  Future<void> dismissDialog(WidgetTester tester) async {
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  }

  /// Эпизод держит живой таймер опроса: чистая загрузка закрывает его, иначе таймер
  /// переживёт тест и дёрнет сеть у уже снятого контроллера.
  Future<void> closeEpisode(WidgetTester tester, AppController c) async {
    limited = false;
    await auto(tester, c);
    await tester.pump(const Duration(seconds: 30));
  }

  /// Фреймворк проверяет инварианты сразу после тела теста, раньше любого tearDown, и
  /// падает на подменённом `debugPrint`: возвращаем его в самом теле.
  void hwidTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        debugPrint = savedDebugPrint;
      }
    });
  }

  hwidTest(
      'ручное обновление при том же лимите показывает окно заново, даже при '
      'идущем эпизоде', (tester) async {
    final c = await boot(tester);

    // Первая загрузка открывает эпизод и окно (как в приложении).
    await auto(tester, c);
    await tester.pumpAndSettle();
    expect(find.text(_announce), findsOneWidget);
    await dismissDialog(tester);
    expect(find.text(_announce), findsNothing);

    // Пользователь освободил не то устройство и нажал «Обновить»: панель снова отказала.
    final verdict = await manual(tester, c);
    await tester.pumpAndSettle();

    expect(verdict, HwidVerdict.limited);
    expect(find.text(_announce), findsOneWidget);
    expect(find.text(AppLocalizations.current.hwidFreeSlot), findsOneWidget);
    expect(hwidLines('limited'), 1);

    await dismissDialog(tester);
    await closeEpisode(tester, c);
  });

  hwidTest('автоповтор при идущем эпизоде молчит: ни окна, ни плашки',
      (tester) async {
    final c = await boot(tester);

    await auto(tester, c);
    await tester.pumpAndSettle();
    await dismissDialog(tester);

    // Опрос, возврат в приложение, 20-минутный таймер.
    await auto(tester, c);
    await auto(tester, c);
    await tester.pumpAndSettle();

    expect(find.text(_announce), findsNothing);
    expect(toasts(AppLocalizations.current.hwidLimitReached), 0);
    expect(logs.where((l) => l.contains('[hwid] manual refresh')), isEmpty);

    await closeEpisode(tester, c);
  });

  hwidTest('без объявления: ручное обновление даёт плашку, автоповтор молчит',
      (tester) async {
    withAnnounce = false;
    final c = await boot(tester);
    final text = AppLocalizations.current.hwidLimitReached;

    await auto(tester, c);
    await auto(tester, c);
    await tester.pump();
    expect(toasts(text), 0);

    final verdict = await manual(tester, c);
    await tester.pump();

    expect(verdict, HwidVerdict.limited);
    expect(toasts(text), 1);
    expect(find.text(_announce), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    await closeEpisode(tester, c);
  });

  hwidTest(
      'ручное обновление после освобождения слота: одна плашка «зарегистрировано», '
      'эпизод закрыт', (tester) async {
    final c = await boot(tester);
    final recovered = AppLocalizations.current.hwidRecovered;

    await auto(tester, c);
    await tester.pumpAndSettle();
    await dismissDialog(tester);

    limited = false;
    final verdict = await manual(tester, c);
    await tester.pump();

    expect(verdict, HwidVerdict.recovered);
    expect(toasts(recovered), 1);
    expect(hwidLines('recovered'), 1);
    expect(find.text(_announce), findsNothing);
    // Файл подписки заменён настоящим конфигом.
    final saved = await tester.runAsync(
      () async => File(await appPath.getProfilePath('p1')).readAsString(),
    );
    expect(saved, contains('real-1'));

    // Эпизод закрыт: следующая чистая загрузка уже не празднует повторно.
    await auto(tester, c);
    await tester.pump();
    expect(toasts(recovered), 1);

    await tester.pump(const Duration(seconds: 30));
  });

  hwidTest(
      'эпизода в памяти нет (перезапуск), но прошлая загрузка несла лимит: '
      'ручное обновление тоже празднует', (tester) async {
    limited = false;
    final c = await boot(tester, providerHeaders: {'x-hwid-limit': 'true'});
    final recovered = AppLocalizations.current.hwidRecovered;

    final verdict = await manual(tester, c);
    await tester.pump();

    expect(verdict, HwidVerdict.recovered);
    expect(toasts(recovered), 1);

    // Заголовок в профиле обновился: повторное ручное обновление уже чистое.
    final again = await manual(tester, c);
    await tester.pump();
    expect(again, HwidVerdict.clean);
    expect(toasts(recovered), 1);
    expect(hwidLines('clean'), 1);

    await tester.pump(const Duration(seconds: 30));
  });

  hwidTest('автоматическая чистая загрузка без эпизода ничего не говорит',
      (tester) async {
    limited = false;
    final c = await boot(tester, providerHeaders: {'x-hwid-limit': 'true'});

    await auto(tester, c);
    await tester.pump();

    expect(toasts(AppLocalizations.current.hwidRecovered), 0);
    await tester.pump(const Duration(seconds: 30));
  });
}
