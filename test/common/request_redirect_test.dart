// Regression: Request.getFileResponseForUrl must accept ONLY a 2xx as the
// final subscription response on every hop, and must resolve relative
// `Location` headers (audit A4-1).
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding installs a mock HttpClient (all 400s); use the real one.
  HttpOverrides.global = null;
  late HttpServer server;
  late String base;

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
      switch (req.uri.path) {
        case '/sub/abs': // moved subscription → absolute redirect to a 404
          res.statusCode = HttpStatus.movedPermanently;
          res.headers.set('location', '$base/api/sub/revoked');
        case '/sub/abs-403':
          res.statusCode = HttpStatus.found;
          res.headers.set('location', '$base/api/sub/forbidden');
        case '/sub/rel': // RFC 7231 absolute-path relative Location
          res.statusCode = HttpStatus.found;
          res.headers.set('location', '/api/sub/ok');
        case '/sub/dir/rel2': // path-relative Location
          res.statusCode = HttpStatus.temporaryRedirect;
          res.headers.set('location', 'next');
        case '/sub/dir/next':
          res.statusCode = HttpStatus.found;
          res.headers.set('location', '../../api/sub/ok');
        case '/sub/loop':
          res.statusCode = HttpStatus.found;
          res.headers.set('location', '/sub/loop');
        case '/sub/no-location':
          res.statusCode = HttpStatus.found;
        case '/api/sub/revoked': // NestJS/Remnawave-style 404 body
          res.statusCode = HttpStatus.notFound;
          res.headers.contentType = ContentType.json;
          res.write('{"message":"Not Found","statusCode":404}');
        case '/api/sub/forbidden':
          res.statusCode = HttpStatus.forbidden;
          res.write('forbidden');
        case '/api/sub/ok':
          res.write('proxies: []\n');
        case '/direct404':
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  Future<Object?> fetchError(String path) async {
    try {
      await request.getFileResponseForUrl('$base$path');
      return null;
    } catch (e) {
      return e;
    }
  }

  test('404 AFTER a redirect fails instead of returning the error page',
      () async {
    final e = await fetchError('/sub/abs');
    expect(e, isA<DioException>());
    expect((e! as DioException).response?.statusCode, 404);
  });

  test('403 AFTER a redirect fails', () async {
    final e = await fetchError('/sub/abs-403');
    expect(e, isA<DioException>());
    expect((e! as DioException).response?.statusCode, 403);
  });

  test('404 on the first hop still fails', () async {
    expect(await fetchError('/direct404'), isA<DioException>());
  });

  test('relative Location (absolute path) is resolved', () async {
    final r = await request.getFileResponseForUrl('$base/sub/rel');
    expect(r.statusCode, 200);
    expect(utf8.decode(r.data!), 'proxies: []\n');
  });

  test('path-relative Location chain is resolved per hop', () async {
    final r = await request.getFileResponseForUrl('$base/sub/dir/rel2');
    expect(r.statusCode, 200);
    expect(utf8.decode(r.data!), 'proxies: []\n');
  });

  test('redirect loop is bounded', () async {
    final e = await fetchError('/sub/loop');
    expect('$e', contains('Too many redirects'));
  });

  test('redirect without Location fails', () async {
    final e = await fetchError('/sub/no-location');
    expect('$e', contains('no location header'));
  });
}
