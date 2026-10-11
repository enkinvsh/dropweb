// Profile.update перебирает адреса подписки: preferred → основной → зеркала →
// fallback. Реальный update() против локального HTTP-сервера.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
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

const _goodYaml = '''
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
  late ClashHandlerInterface originalCore;
  late FakeSecureProfileStore store;
  final hits = <String>[];
  var idSeq = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.8.1',
      buildNumber: '1',
    );
    globalState.config = const Config(themeProps: defaultThemeProps);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      hits.add(req.uri.path);
      final res = req.response;
      if (req.uri.path.startsWith('/ok')) {
        if (req.uri.path == '/ok-headers') {
          res.headers.set(
            'dropweb-sub-mirrors',
            '$base/m1, https://mirror.example/x;ftp://bad',
          );
          res.headers.set('dropweb-sub-id', '  SUBID  ');
          res.headers.set('fallback-url', '$base/fb');
          res.headers.set('dropweb-theme', 'fidelity');
        }
        res.write(_goodYaml);
      } else if (req.uri.path.startsWith('/html')) {
        res.headers.contentType = ContentType.html;
        res.write('<html><body>captive</body></html>');
      } else {
        res.statusCode = HttpStatus.serviceUnavailable;
      }
      await res.close();
    });
  });

  setUp(() {
    hits.clear();
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
    originalCore = clashCore.clashInterface;
    clashCore.clashInterface = _AcceptAllCore();
  });

  tearDown(() => clashCore.clashInterface = originalCore);
  tearDownAll(() => server.close(force: true));

  Profile profile({
    required String primary,
    List<String> mirrors = const [],
    String? fallback,
  }) =>
      Profile(
        id: 'cand-${idSeq++}',
        label: 'p',
        url: '$base$primary',
        mirrorUrls: [for (final m in mirrors) '$base$m'],
        fallbackUrl: fallback == null ? null : '$base$fallback',
        autoUpdateDuration: const Duration(hours: 12),
      );

  Future<Object?> updateError(Profile p) async {
    try {
      await p.update(shouldSendHeaders: false);
      return null;
    } catch (e) {
      return e;
    }
  }

  test('порядок: preferred, основной, зеркала, fallback', () async {
    final p = profile(
      primary: '/down-p',
      mirrors: ['/down-m1', '/down-m2'],
      fallback: '/down-fb',
    );
    store.preferred[p.id] = '$base/down-m2';

    expect(await updateError(p), isNotNull);
    expect(hits, ['/down-m2', '/down-p', '/down-m1', '/down-fb']);
  });

  test('устаревший preferred игнорируется', () async {
    final p = profile(primary: '/down-p', mirrors: ['/down-m1']);
    store.preferred[p.id] = '$base/down-stale';

    expect(await updateError(p), isNotNull);
    expect(hits, ['/down-p', '/down-m1']);
  });

  test('успех зеркала запоминается как preferred, основной не меняется',
      () async {
    final p = profile(primary: '/down-p', mirrors: ['/ok-m1']);

    final updated = await p.update(shouldSendHeaders: false);

    expect(store.preferred[p.id], '$base/ok-m1');
    expect(updated.url, '$base/down-p');
    expect(await (await p.getFile()).readAsString(), _goodYaml);
  });

  test('успех основного стирает preferred', () async {
    final p = profile(primary: '/ok-p', mirrors: ['/down-m1']);
    store.preferred[p.id] = '$base/down-m1';

    await p.update(shouldSendHeaders: false);

    expect(hits, ['/down-m1', '/ok-p']);
    expect(store.preferred.containsKey(p.id), isFalse);
  });

  test('сбой записи preferred не роняет обновление', () async {
    final p = profile(primary: '/down-p', mirrors: ['/ok-m1']);
    store.failPreferredFor.add(p.id);

    final updated = await p.update(shouldSendHeaders: false);
    expect(updated.lastUpdateDate, isNotNull);
  });

  test('все упали → ошибка ПЕРВОГО кандидата', () async {
    final p = profile(primary: '/html-p', mirrors: ['/down-m1']);

    final error = await updateError(p);

    expect(hits, ['/html-p', '/down-m1']);
    expect(error, isA<Exception>());
    expect(error.toString(), contains('Invalid subscription response'));
  });

  test('HTML-страница вместо подписки → пробуем следующего', () async {
    final p = profile(primary: '/html-p', mirrors: ['/ok-m1']);
    final file = await p.getFile();
    await file.writeAsString('old');

    await p.update(shouldSendHeaders: false);

    expect(hits, ['/html-p', '/ok-m1']);
    expect(await file.readAsString(), _goodYaml);
    expect(store.preferred[p.id], '$base/ok-m1');
  });

  test('зеркала / sub-id / fallback берутся из ответа и не лежат в headers',
      () async {
    final p = profile(primary: '/ok-headers');

    final updated = await p.update(shouldSendHeaders: false);

    expect(updated.mirrorUrls, ['$base/m1', 'https://mirror.example/x']);
    expect(updated.subId, 'SUBID');
    expect(updated.fallbackUrl, '$base/fb');
    expect(updated.providerHeaders['dropweb-theme'], 'fidelity');
    for (final secret in subscriptionSecretHeaders) {
      expect(updated.providerHeaders.containsKey(secret), isFalse,
          reason: '$secret несёт токен');
    }
  });

  test('без заголовков зеркала / sub-id / fallback остаются прежними',
      () async {
    final p = profile(primary: '/ok-p', fallback: '/fb-old')
        .copyWith(mirrorUrls: ['$base/m-old'], subId: 'OLD');

    final updated = await p.update(shouldSendHeaders: false);

    expect(updated.mirrorUrls, ['$base/m-old']);
    expect(updated.subId, 'OLD');
    expect(updated.fallbackUrl, '$base/fb-old');
  });
}
