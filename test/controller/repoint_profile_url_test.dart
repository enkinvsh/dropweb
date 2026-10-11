// AppController.repointProfileUrl: тихо меняет основной адрес подписки (через
// защищённое хранилище), сбрасывает память о зеркале и обновляет профиль.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
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

class _AcceptAllCore extends ClashHandlerInterface {
  @override
  FutureOr<String> validateConfig(String data) => '';
  @override
  Future<StartListenerOutcome> startListener() async => const StartListenerOk();
  @override
  Future<bool> stopListener() async => true;
  @override
  void sendMessage(String message) {}
  @override
  void reStart() {}
  @override
  FutureOr<bool> destroy() => true;
  @override
  Future<bool> preload() async => true;
}

const _yaml = '''
proxies:
  - name: a
    type: ss
    server: 1.1.1.1
    port: 8388
    cipher: aes-128-gcm
    password: x
proxy-groups:
  - name: VPN
    type: select
    proxies: [a]
rules:
  - MATCH,VPN
''';

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer server;
  late String base;
  late FakeSecureProfileStore store;
  late ClashHandlerInterface originalCore;
  final hits = <String>[];

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
      hits.add(req.uri.path);
      final res = req.response;
      if (req.uri.path.startsWith('/new')) {
        res.write(_yaml);
      } else {
        res.statusCode = HttpStatus.serviceUnavailable;
      }
      await res.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    hits.clear();
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
    originalCore = clashCore.clashInterface;
    clashCore.clashInterface = _AcceptAllCore();
  });

  tearDown(() {
    clashCore.clashInterface = originalCore;
    preferences.secureStore = secureProfileUrlStore;
  });

  testWidgets('новый адрес в защищённом хранилище, id прежний, обновлено',
      (tester) async {
    const profile = Profile(
      id: 'p1',
      label: 'Мой VPN',
      autoUpdateDuration: Duration(hours: 12),
    );
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      profiles: [profile],
    );
    store.urls['p1'] = '$base/old';
    store.preferred['p1'] = '$base/old-mirror';
    store.mirrors['p1'] = ['$base/old-mirror'];

    late AppController controller;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            controller = AppController(context, ref);
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.runAsync(
      () => controller.repointProfileUrl('p1', '$base/new'),
    );

    final profiles = widgetRef.read(profilesProvider);
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'p1');
    expect(profiles.single.label, 'Мой VPN');
    expect(profiles.single.lastUpdateDate, isNotNull);
    expect(await preferences.getProfileUrl(profiles.single), '$base/new');
    expect(store.preferred.containsKey('p1'), isFalse);
    expect(hits.first, '/new');
  });

  testWidgets('ошибка обновления пробрасывается, адрес уже сменён',
      (tester) async {
    const profile = Profile(
      id: 'p2',
      label: 'p',
      autoUpdateDuration: Duration(hours: 12),
    );
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      profiles: [profile],
    );
    store.urls['p2'] = '$base/old';

    late AppController controller;
    await tester.pumpWidget(
      ProviderScope(
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
        await controller.repointProfileUrl('p2', '$base/down');
      } catch (e) {
        error = e;
      }
    });
    expect(error, isNotNull);
    expect(store.urls['p2'], '$base/down');
  });
}
