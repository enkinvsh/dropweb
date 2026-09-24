// Regression: real Profile.update() against a local HTTP server (audit A4-1,
// A4-4).
//  - Header shapes seen in the wild (duplicated `profile-title`, malformed
//    `subscription-userinfo`) must not abort the update.
//  - A 2xx body with no usable proxy source (blank, JSON/HTML error page,
//    `proxies: []`) must be rejected BEFORE saveFile, leaving the stored
//    profile file untouched.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';

class _NoSecureStore implements SecureProfileUrlStoreInterface {
  @override
  Future<String?> getUrl(String profileId) async => null;
  @override
  Future<String?> getFallbackUrl(String profileId) async => null;
  @override
  Future<bool> setUrl(String profileId, String? url) async => true;
  @override
  Future<bool> setFallbackUrl(String profileId, String? url) async => true;
  @override
  Future<void> removeProfile(String profileId) async {}
  @override
  Future<bool> isMigrated() async => true;
  @override
  Future<bool> markMigrated() async => true;
}

/// Core stand-in: syntax validation always passes (like the real
/// `UnmarshalRawConfig` does for an empty doc or a JSON error page).
class _AcceptAllCore extends ClashHandlerInterface {
  final List<String> validated = [];

  @override
  FutureOr<String> validateConfig(String data) {
    validated.add(data);
    return '';
  }

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

const _providersOnlyYaml = '''
proxy-providers:
  p1:
    type: http
    url: https://example.com/p1
    path: ./p1.yaml
    interval: 3600
proxy-groups:
  - name: VPN
    type: select
    use: [p1]
rules:
  - MATCH,VPN
''';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real sockets (binding installs a 400-mock)
  late HttpServer server;
  late String base;
  late ClashHandlerInterface originalCore;
  late _AcceptAllCore core;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences.secureStore = _NoSecureStore();
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
      final res = req.response;
      switch (req.uri.path) {
        case '/userinfo-trailing':
          res.headers.set(
            'subscription-userinfo',
            'upload=1; download=2; total=3; expire=4;',
          );
          res.write(_goodYaml);
        case '/userinfo-empty':
          res.headers.set('subscription-userinfo', '');
          res.write(_goodYaml);
        case '/providers-only':
          res.write(_providersOnlyYaml);
        case '/share-links':
          res.write('vless://$_uuid@a.example.com:443?security=tls#keep\n');
        case '/empty200':
          break;
        case '/blank':
          res.write('  \n\n');
        case '/empty204':
          res.statusCode = HttpStatus.noContent;
        case '/json-error':
          res.headers.contentType = ContentType.json;
          res.write('{"message":"Not Found","statusCode":404}');
        case '/html':
          res.headers.contentType = ContentType.html;
          res.write('<html><body>Subscription expired</body></html>');
        case '/empty-proxies':
          res.write('proxies: []\nproxy-groups: []\nrules:\n  - MATCH,DIRECT\n');
        case '/redirect-404':
          res.statusCode = HttpStatus.found;
          res.headers.set('location', '/gone');
        case '/gone':
          res.statusCode = HttpStatus.notFound;
          res.write('{"message":"Not Found"}');
      }
      await res.close();
    });
  });

  setUp(() {
    originalCore = clashCore.clashInterface;
    core = _AcceptAllCore();
    clashCore.clashInterface = core;
  });

  tearDown(() => clashCore.clashInterface = originalCore);

  tearDownAll(() => server.close(force: true));

  group('header parsing does not abort the update', () {
    test('duplicated profile-title uses the first value', () async {
      // dart:io's HttpServer folds duplicates into one line, so speak raw
      // HTTP to emit two separate `profile-title:` lines.
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      raw.listen((sock) async {
        await sock.first;
        sock.write('HTTP/1.1 200 OK\r\n'
            'content-type: text/yaml\r\n'
            'profile-title: Provider\r\n'
            'profile-title: Other\r\n'
            'subscription-userinfo: upload=1\r\n'
            'subscription-userinfo: upload=2\r\n'
            'content-length: ${_goodYaml.length}\r\n'
            'connection: close\r\n\r\n'
            '$_goodYaml');
        await sock.flush();
        await sock.close();
      });
      try {
        final p = await Profile.normal(
          url: 'http://127.0.0.1:${raw.port}/dup-title',
          label: 'p',
        ).update(shouldSendHeaders: false);
        expect(p.providerHeaders['profile-title'], 'Provider');
        expect(p.subscriptionInfo?.upload, 1);
      } finally {
        await raw.close();
      }
    });

    test('subscription-userinfo with trailing ";" is parsed', () async {
      final p = await Profile.normal(url: '$base/userinfo-trailing', label: 'p')
          .update(shouldSendHeaders: false);
      expect(
        p.subscriptionInfo,
        const SubscriptionInfo(upload: 1, download: 2, total: 3, expire: 4),
      );
    });

    test('empty subscription-userinfo yields zero info', () async {
      final p = await Profile.normal(url: '$base/userinfo-empty', label: 'p')
          .update(shouldSendHeaders: false);
      expect(p.subscriptionInfo, const SubscriptionInfo());
    });
  });

  group('usable bodies are saved', () {
    test('proxy-providers-only config is accepted', () async {
      final profile = Profile.normal(url: '$base/providers-only', label: 'p');
      await profile.update(shouldSendHeaders: false);
      expect(
        await (await profile.getFile()).readAsString(),
        _providersOnlyYaml,
      );
    });

    test('share-link body is converted and accepted', () async {
      final profile = Profile.normal(url: '$base/share-links', label: 'p');
      await profile.update(shouldSendHeaders: false);
      final saved = await (await profile.getFile()).readAsString();
      expect(saved, contains('name: keep'));
    });
  });

  group('unusable bodies never overwrite the stored profile', () {
    for (final path in [
      '/empty200',
      '/blank',
      '/empty204',
      '/json-error',
      '/html',
      '/empty-proxies',
      '/redirect-404',
    ]) {
      test('$path is rejected and the old file is kept', () async {
        final profile = Profile.normal(url: '$base$path', label: 'p');
        final file = await profile.getFile();
        await file.writeAsString(_goodYaml);

        Object? error;
        try {
          await profile.update(shouldSendHeaders: false);
        } catch (e) {
          error = e;
        }

        expect(error, isA<Exception>());
        expect(await file.readAsString(), _goodYaml);
        expect(core.validated, isEmpty,
            reason: 'rejected before saveFile/validateConfig');
      });
    }
  });
}
