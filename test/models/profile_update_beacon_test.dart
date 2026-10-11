// Profile.update: когда упали все известные адреса подписки, новый фронт
// берётся из подписанного маяка. Реальный update() против локального сервера.
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

import '../support/beacon_signing.dart';
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

const _subId = 'SUBID';

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer server;
  late String base;
  late ClashHandlerInterface originalCore;
  late FakeSecureProfileStore store;
  final key = TestBeaconKey(3);
  late String pub;
  final hits = <String>[];
  final requestHeaders = <String, HttpHeaders>{};
  final beaconDocs = <String, String>{};
  final responseHeaders = <String, Map<String, String>>{};
  var idSeq = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(
      {'app_persistent_hwid': 'HWID-TEST'},
    );
    PackageInfo.setMockInitialValues(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.8.1',
      buildNumber: '1',
      buildSignature: '',
    );
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.8.1',
      buildNumber: '1',
    );
    globalState.config = const Config(themeProps: defaultThemeProps);
    pub = await key.publicKeyBase64();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final path = req.uri.path;
      hits.add(path);
      requestHeaders[path] = req.headers;
      final res = req.response;
      if (path.startsWith('/beacon/')) {
        final doc = beaconDocs[path.substring('/beacon/'.length)];
        if (doc == null) {
          res.statusCode = HttpStatus.notFound;
        } else {
          res.write(doc);
        }
      } else if (path.startsWith('/ok')) {
        responseHeaders[path]?.forEach(res.headers.set);
        res.write(_goodYaml);
      } else if (path.startsWith('/html')) {
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
    requestHeaders.clear();
    beaconDocs.clear();
    responseHeaders.clear();
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
    originalCore = clashCore.clashInterface;
    clashCore.clashInterface = _AcceptAllCore();
  });

  tearDown(() => clashCore.clashInterface = originalCore);
  tearDownAll(() => server.close(force: true));

  Future<String> doc(List<String> templates, {int seq = 1}) => key.sign({
        'v': 1,
        'seq': seq,
        'mirrors': [for (final t in templates) '$base$t'],
      });

  /// Профиль с известным маяком: адреса маяка и ключ уже в хранилище.
  Profile profile({
    required String primary,
    List<String> mirrors = const [],
    String? subId = _subId,
    List<String> beacons = const ['/beacon/a'],
  }) {
    final p = Profile(
      id: 'beacon-${idSeq++}',
      label: 'p',
      url: '$base$primary',
      mirrorUrls: [for (final m in mirrors) '$base$m'],
      subId: subId,
      autoUpdateDuration: const Duration(hours: 12),
    );
    store.beaconUrls[p.id] = [for (final b in beacons) '$base$b'];
    store.beaconKeys[p.id] = [pub];
    return p;
  }

  Future<Object?> updateError(Profile p) async {
    try {
      await p.update(shouldSendHeaders: false);
      return null;
    } catch (e) {
      return e;
    }
  }

  test('все известные адреса упали → адрес из маяка, он запоминается',
      () async {
    beaconDocs['a'] = await doc(['/ok-front/{id}'], seq: 2);
    final p = profile(primary: '/down-p', mirrors: ['/down-m1']);

    final updated = await p.update(shouldSendHeaders: false);

    expect(hits, ['/down-p', '/down-m1', '/beacon/a', '/ok-front/$_subId']);
    expect(await (await p.getFile()).readAsString(), _goodYaml);
    expect(updated.url, '$base/down-p');
    expect(updated.mirrorUrls, ['$base/ok-front/$_subId', '$base/down-m1']);
    expect(store.preferred[p.id], '$base/ok-front/$_subId');
    expect(BeaconState.decode(store.beaconStates[p.id])!.seq, 2);
  });

  test('маяк не нужен, пока жив хоть один известный адрес', () async {
    beaconDocs['a'] = await doc(['/ok-front/{id}']);
    final p = profile(primary: '/down-p', mirrors: ['/ok-m1']);

    await p.update(shouldSendHeaders: false);

    expect(hits, ['/down-p', '/ok-m1']);
  });

  test('хостинг маяка недоступен → используется сохранённый документ',
      () async {
    final p = profile(primary: '/down-p', beacons: ['/beacon/missing']);
    store.beaconStates[p.id] = BeaconState(
      seq: 3,
      document: await doc(['/ok-cached/{id}'], seq: 3),
    ).encode();

    await p.update(shouldSendHeaders: false);

    expect(hits, ['/down-p', '/beacon/missing', '/ok-cached/$_subId']);
    expect(store.preferred[p.id], '$base/ok-cached/$_subId');
  });

  test('без sub-id маяк не запрашивается', () async {
    beaconDocs['a'] = await doc(['/ok-front/{id}']);
    final p = profile(primary: '/html-p', subId: null);

    final error = await updateError(p);

    expect(hits, ['/html-p']);
    expect(error.toString(), contains('Invalid subscription response'));
  });

  test('запрос к маяку без заголовков устройства', () async {
    beaconDocs['a'] = await doc(['/ok-front/{id}']);
    final p = profile(primary: '/down-p');

    await p.update();

    expect(requestHeaders['/down-p']!.value('x-hwid'), 'HWID-TEST');
    final beaconHeaders = requestHeaders['/beacon/a']!;
    for (final name in [
      'x-hwid',
      'x-device-os',
      'x-ver-os',
      'x-device-model',
    ]) {
      expect(beaconHeaders.value(name), isNull, reason: name);
    }
    // Адрес из маяка — фронт подписки: устройство ему представляется.
    expect(
      requestHeaders['/ok-front/$_subId']!.value('x-hwid'),
      'HWID-TEST',
    );
  });

  test('всё упало (и маяк тоже) → ошибка ПЕРВОГО кандидата', () async {
    beaconDocs['a'] = await doc(['/down-front/{id}']);
    final p = profile(primary: '/html-p');

    final error = await updateError(p);

    expect(hits, ['/html-p', '/beacon/a', '/down-front/$_subId']);
    expect(error, isA<Exception>());
    expect(error.toString(), contains('Invalid subscription response'));
    expect(store.preferred.containsKey(p.id), isFalse);
  });

  test(
      'адреса из маяка, уже испробованные в этом обновлении, пропускаются; '
      'не больше 4 попыток', () async {
    beaconDocs['a'] = await doc([
      '/down-{id}',
      for (var i = 0; i < 6; i++) '/down-f$i/{id}',
    ]);
    final p = profile(primary: '/down-$_subId');

    await updateError(p);

    expect(hits, [
      '/down-$_subId',
      '/beacon/a',
      for (var i = 0; i < 4; i++) '/down-f$i/$_subId',
    ]);
  });

  test('невалидная подпись маяка → адреса не пробуются', () async {
    beaconDocs['a'] = await TestBeaconKey(99).sign({
      'v': 1,
      'seq': 1,
      'mirrors': ['$base/ok-evil/{id}'],
    });
    final p = profile(primary: '/down-p');

    expect(await updateError(p), isNotNull);
    expect(hits, ['/down-p', '/beacon/a']);
  });

  test('заголовки маяка сохраняются в хранилище и не попадают в headers',
      () async {
    responseHeaders['/ok-p'] = {
      'dropweb-sub-beacon':
          'https://beacon.example/d.json, http://beacon.example/x',
      'dropweb-sub-beacon-key': '$pub, bad',
      'dropweb-theme': 'fidelity',
    };
    final p = profile(primary: '/ok-p', beacons: const []);
    store.beaconKeys.remove(p.id);

    final updated = await p.update(shouldSendHeaders: false);

    expect(store.beaconUrls[p.id], ['https://beacon.example/d.json']);
    expect(store.beaconKeys[p.id], [pub]);
    expect(updated.providerHeaders['dropweb-theme'], 'fidelity');
    for (final name in subscriptionBeaconHeaders) {
      expect(updated.providerHeaders.containsKey(name), isFalse, reason: name);
    }
  });

  test('без заголовков маяка сохранённые значения остаются', () async {
    final p = profile(primary: '/ok-p');

    await p.update(shouldSendHeaders: false);

    expect(store.beaconUrls[p.id], ['$base/beacon/a']);
    expect(store.beaconKeys[p.id], [pub]);
  });
}
