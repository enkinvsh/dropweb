// Профиль помнит HWID, с которым его скачали без отказа по лимиту устройств.
// Настоящий Profile.update() против локального HTTP-сервера: запись идёт из
// того же места, что и в приложении, а не из копии логики в тесте.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/utils/device_info_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

const _hwid = 'AAAAAAAAAAAAAAAA';
const _oldHwid = 'BBBBBBBBBBBBBBBB';

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

/// Ядро-заглушка: проверка синтаксиса всегда проходит.
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

/// Сервис устройства с заданным HWID (на хосте нет ни Keychain, ни iOS).
class _FakeDeviceInfo implements DeviceInfoService {
  _FakeDeviceInfo(this.hwid);

  final String? hwid;

  @override
  Future<DeviceDetails> getDeviceDetails() async =>
      DeviceDetails(hwid: hwid, os: 'iOS', osVersion: '27', model: 'iPhone');

  @override
  Future<String?> getPersistentHwid() async => hwid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();
  HttpOverrides.global = null;

  late HttpServer server;
  late String base;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences.secureStore = FakeSecureProfileStore();
    globalState.packageInfo = PackageInfo(
      appName: 'dropweb',
      packageName: 'app.dropweb',
      version: '0.10.3',
      buildNumber: '1',
    );
    globalState.config = const Config(themeProps: defaultThemeProps);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final res = req.response;
      if (req.uri.path == '/limited') {
        res.headers.set('x-hwid-limit', 'true');
      }
      res.write(_goodYaml);
      await res.close();
    });
  });

  setUp(() {
    // Прежнее ядро не читаем: его геттер поднимает настоящий процесс ядра.
    clashCore.clashInterface = _AcceptAllCore();
    DeviceInfoService.testInstance = _FakeDeviceInfo(_hwid);
  });

  tearDown(() {
    DeviceInfoService.testInstance = null;
  });

  tearDownAll(() => server.close(force: true));

  Profile profile(String path, {String? fetchedHwid}) =>
      Profile.normal(url: '$base$path', label: 'p')
          .copyWith(fetchedHwid: fetchedHwid);

  test('чистая загрузка записывает отправленный HWID', () async {
    final updated = await profile('/ok').update();

    expect(updated.fetchedHwid, _hwid);
  });

  test('загрузка с отказом по лимиту прежний HWID не заменяет', () async {
    final updated = await profile('/limited', fetchedHwid: _oldHwid).update();

    expect(updated.fetchedHwid, _oldHwid);
  });

  test('первая загрузка с отказом по лимиту HWID не записывает', () async {
    final updated = await profile('/limited').update();

    expect(updated.fetchedHwid, isNull);
  });

  test('отправка заголовков выключена: значение остаётся прежним', () async {
    final updated = await profile('/ok', fetchedHwid: _oldHwid)
        .update(shouldSendHeaders: false);

    expect(updated.fetchedHwid, _oldHwid);
  });

  test('HWID неизвестен (не отправлен): значение остаётся прежним', () async {
    DeviceInfoService.testInstance = _FakeDeviceInfo(null);

    final updated = await profile('/ok', fetchedHwid: _oldHwid).update();

    expect(updated.fetchedHwid, _oldHwid);
  });

  test('импорт и повторное добавление переносят HWID в профиль из хранилища',
      () async {
    final downloaded = await profile('/ok').update();
    final fresh = profile('/ok');

    final merged = applyFetchedProfileFields(fresh: fresh, fetched: downloaded);

    expect(merged.fetchedHwid, _hwid);
  });

  test('слияние не стирает известный HWID, если загрузка его не принесла', () {
    final fresh = profile('/ok', fetchedHwid: _oldHwid);
    final fetched = profile('/ok');

    final merged = applyFetchedProfileFields(fresh: fresh, fetched: fetched);

    expect(merged.fetchedHwid, _oldHwid);
  });
}
