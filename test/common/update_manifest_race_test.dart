// Request.fetchFirstUpdateManifest races every mirror in parallel and returns
// the FIRST valid manifest; bad mirrors (5xx, garbage, no version, oversized)
// are misses, and an all-miss race yields null (never a fake "up to date").
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding installs a mock HttpClient (all 400s); use the real one.
  HttpOverrides.global = null;
  late HttpServer server;
  late String base;
  const slowDelay = Duration(milliseconds: 1500);

  setUpAll(() async {
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
      try {
        switch (req.uri.path) {
          case '/fast':
            res.headers.contentType = ContentType.json;
            res.write(jsonEncode({'version': '9.9.9'}));
          case '/slow':
            await Future<void>.delayed(slowDelay);
            res.headers.contentType = ContentType.json;
            res.write(jsonEncode({'version': '1.0.0'}));
          case '/500':
            res.statusCode = HttpStatus.internalServerError;
            res.write('boom');
          case '/garbage':
            res.write('<html>not json</html>');
          case '/noversion':
            res.headers.contentType = ContentType.json;
            res.write('{}');
          case '/big':
            res.headers.contentType = ContentType.json;
            res.write(jsonEncode({
              'version': '9.9.9',
              'pad': 'x' * (300 * 1024),
            }));
          default:
            res.statusCode = HttpStatus.notFound;
        }
        await res.close();
      } catch (e) {
        // The client may cancel a loser mid-flight; that is expected.
        debugPrint('race test server: ${req.uri.path}: ${e.runtimeType}');
      }
    });
  });

  tearDownAll(() => server.close(force: true));

  test('fast mirror beats slow mirror', () async {
    final sw = Stopwatch()..start();
    final m = await request.fetchFirstUpdateManifest(
      ['$base/slow', '$base/fast'],
    );
    sw.stop();
    expect(m?['version'], '9.9.9');
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 1000)));
  });

  test('all bad mirrors => null', () async {
    final m = await request.fetchFirstUpdateManifest([
      '$base/500',
      '$base/garbage',
      '$base/noversion',
      '$base/big',
      '$base/missing',
    ]);
    expect(m, isNull);
  });

  test('bad mirrors are skipped when one good exists', () async {
    final m = await request.fetchFirstUpdateManifest([
      '$base/500',
      '$base/garbage',
      '$base/noversion',
      '$base/slow',
    ]);
    expect(m?['version'], '1.0.0');
  });

  test('oversized manifest is rejected', () async {
    expect(await request.fetchFirstUpdateManifest(['$base/big']), isNull);
  });

  test('empty list => null', () async {
    expect(await request.fetchFirstUpdateManifest(const []), isNull);
  });
}
