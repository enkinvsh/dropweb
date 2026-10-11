// AppController.updateProfile: сбой загрузки профиля сообщается слою
// аккаунта (починка адреса подписки), а исходная ошибка уходит вызывающему
// без изменений — на ней держится обычный UX обновления.
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

/// Аккаунт, который только записывает вызовы хука.
class _RecordingAccount extends Account {
  final failed = <String>[];

  @override
  Future<void> onProfileUpdateFailed(String profileId) async {
    failed.add(profileId);
  }
}

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer server;
  late String base;
  late FakeSecureProfileStore store;

  setUpAll(() async {
    // Без device-заголовков: их сбор ходит в платформенные плагины.
    SharedPreferences.setMockInitialValues({'sendDeviceHeaders': false});
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.8.1',
      buildNumber: '1',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      req.response.statusCode = HttpStatus.serviceUnavailable;
      await req.response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
  });

  tearDown(() => preferences.secureStore = secureProfileUrlStore);

  testWidgets('загрузка упала → хук аккаунта один раз, ошибка проброшена',
      (tester) async {
    const profile = Profile(
      id: 'p1',
      label: 'p',
      autoUpdateDuration: Duration(hours: 12),
    );
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      profiles: [profile],
    );
    store.urls['p1'] = '$base/down';
    final account = _RecordingAccount();

    late AppController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountProvider.overrideWith(() => account)],
        child: Consumer(
          builder: (context, ref, _) {
            controller = AppController(context, ref);
            return const SizedBox();
          },
        ),
      ),
    );

    Object? error;
    await tester.runAsync(() async {
      try {
        await controller.updateProfile(profile);
      } catch (e) {
        error = e;
      }
    });

    expect(error, isNotNull);
    expect(account.failed, ['p1']);
  });

  test('notifyAccountOnFetchFailure: хук бросил — ошибка загрузки та же',
      () async {
    final original = StateError('fetch');
    Object? error;
    try {
      await notifyAccountOnFetchFailure<void>(
        () async => throw original,
        () => throw Exception('hook'),
      );
    } catch (e) {
      error = e;
    }
    expect(identical(error, original), isTrue);
  });

  test('notifyAccountOnFetchFailure: успех — хук не зовётся', () async {
    var calls = 0;
    final result = await notifyAccountOnFetchFailure(
      () async => 42,
      () async => calls++,
    );
    expect(result, 42);
    expect(calls, 0);
  });
}
