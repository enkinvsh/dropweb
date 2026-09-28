// Subscription fetch while our VPN is on but its servers are dead: the
// normal (in-tunnel) leg races a delayed out-of-tunnel leg. These tests pin
// the race semantics, the shared redirect walker, and the Android channel
// contract of App.fetchBypassingVpn.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dropweb/common/request.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('raceWithDelayedFallback', () {
    test('primary succeeds before the delay -> fallback never invoked',
        () async {
      var fallbackCalls = 0;
      final result = await raceWithDelayedFallback<String>(
        primary: (_) async => 'primary',
        fallback: () async {
          fallbackCalls++;
          return 'fallback';
        },
        delay: const Duration(milliseconds: 50),
      );
      expect(result, 'primary');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fallbackCalls, 0);
    });

    test('primary fails immediately -> fallback starts right away and wins',
        () async {
      var fallbackCalls = 0;
      final result = await raceWithDelayedFallback<String>(
        primary: (_) async => throw StateError('tunnel dead'),
        fallback: () async {
          fallbackCalls++;
          return 'fallback';
        },
        delay: const Duration(hours: 1),
      );
      expect(result, 'fallback');
      expect(fallbackCalls, 1);
    });

    test('primary hangs -> fallback after delay wins and primary is cancelled',
        () async {
      final primary = Completer<String>();
      CancelToken? token;
      var fallbackCalls = 0;
      final result = await raceWithDelayedFallback<String>(
        primary: (t) {
          token = t;
          return primary.future;
        },
        fallback: () async {
          fallbackCalls++;
          return 'fallback';
        },
        delay: const Duration(milliseconds: 20),
      );
      expect(result, 'fallback');
      expect(fallbackCalls, 1);
      expect(token!.isCancelled, isTrue);
    });

    test('both fail -> the primary error is thrown', () async {
      final primaryError = StateError('primary');
      await expectLater(
        raceWithDelayedFallback<String>(
          primary: (_) async => throw primaryError,
          fallback: () async => throw StateError('fallback'),
          delay: const Duration(hours: 1),
        ),
        throwsA(same(primaryError)),
      );
    });

    test('fallback fails first, primary succeeds later -> primary value',
        () async {
      final primary = Completer<String>();
      final future = raceWithDelayedFallback<String>(
        primary: (_) => primary.future,
        fallback: () async => throw StateError('fallback'),
        delay: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      primary.complete('primary');
      expect(await future, 'primary');
    });

    test('fallback started but primary succeeds first -> primary value',
        () async {
      final primary = Completer<String>();
      final fallback = Completer<String>();
      var fallbackCalls = 0;
      final future = raceWithDelayedFallback<String>(
        primary: (_) => primary.future,
        fallback: () {
          fallbackCalls++;
          return fallback.future;
        },
        delay: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(fallbackCalls, 1);
      primary.complete('primary');
      expect(await future, 'primary');
      fallback.complete('fallback');
      await pumpEventQueue();
    });

    test('synchronous throw in primary is treated as a failure', () async {
      final result = await raceWithDelayedFallback<String>(
        primary: (_) => throw StateError('sync'),
        fallback: () async => 'fallback',
        delay: const Duration(hours: 1),
      );
      expect(result, 'fallback');
    });
  });

  group('followSubscriptionHops', () {
    Response<Uint8List> resp(
      Uri uri,
      int status, {
      Map<String, List<String>> headers = const {},
      List<int> body = const [],
    }) =>
        Response<Uint8List>(
          requestOptions: RequestOptions(path: uri.toString()),
          statusCode: status,
          headers: Headers.fromMap(headers),
          data: Uint8List.fromList(body),
        );

    test('relative redirect chain resolves against the current hop', () async {
      final seen = <Uri>[];
      final result = await followSubscriptionHops(
        Uri.parse('https://sub.example/dir/a'),
        (uri) async {
          seen.add(uri);
          if (uri.path == '/dir/a') {
            return resp(uri, 302, headers: {
              'location': ['b'],
            });
          }
          return resp(uri, 200, body: [7, 8, 9]);
        },
      );
      expect(seen.map((u) => u.toString()), [
        'https://sub.example/dir/a',
        'https://sub.example/dir/b',
      ]);
      expect(result.data, [7, 8, 9]);
    });

    test('non-2xx/3xx hop fails the fetch', () async {
      await expectLater(
        followSubscriptionHops(
          Uri.parse('https://sub.example/x'),
          (uri) async => resp(uri, 403),
        ),
        throwsA(predicate((e) => '$e'.contains('Unexpected HTTP 403'))),
      );
    });

    test('body over maxBytes fails the fetch', () async {
      await expectLater(
        followSubscriptionHops(
          Uri.parse('https://sub.example/x'),
          (uri) async => resp(uri, 200, body: List.filled(16, 1)),
          maxBytes: 8,
        ),
        throwsA(predicate((e) => '$e'.contains('Subscription too large'))),
      );
    });
  });

  group('App.fetchBypassingVpn', () {
    const channel = MethodChannel('app');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('sends url/headers/maxBytes and parses the native result', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return <String, Object?>{
          'status': 200,
          'headers': {
            'content-type': ['text/yaml'],
          },
          'body': Uint8List.fromList([1, 2, 3]),
        };
      });

      final r = await App().fetchBypassingVpn(
        Uri.parse('https://sub.example/s/token'),
        {'User-Agent': 'dropweb/1', 'x-hwid': 'abc'},
        maxBytes: 1024,
      );

      expect(received!.method, 'fetchBypassingVpn');
      expect(received!.arguments, {
        'url': 'https://sub.example/s/token',
        'headers': {'User-Agent': 'dropweb/1', 'x-hwid': 'abc'},
        'maxBytes': 1024,
      });
      expect(r.status, 200);
      expect(r.headers, {
        'content-type': ['text/yaml'],
      });
      expect(r.body, [1, 2, 3]);
    });

    test('native error surfaces as PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BYPASS_FETCH_FAILED', message: 'x');
      });
      await expectLater(
        App().fetchBypassingVpn(Uri.parse('https://a.b/'), const {},
            maxBytes: 1),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
