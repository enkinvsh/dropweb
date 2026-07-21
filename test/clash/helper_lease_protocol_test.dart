import 'dart:convert';
import 'dart:math';

import 'package:dropweb/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('run token is exactly 128 random bits encoded as lowercase hex', () {
    final token = generateCoreRunToken(Random(7));

    expect(token, hasLength(32));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(token), isTrue);
  });

  test('start response requires the helper to echo the requested token', () {
    const token = '0123456789abcdef0123456789abcdef';

    final response = decodeHelperStartResponse(
      statusCode: 200,
      body: jsonEncode({
        'corePid': 42,
        'coreCreationTime100ns': 1337,
        'runToken': token,
      }),
      expectedRunToken: token,
    );

    expect(response.corePid, 42);
    expect(response.coreCreationTime100ns, 1337);
    expect(response.runToken, token);
  });

  test('typed helper conflict is preserved without direct fallback semantics',
      () {
    expect(
      () => decodeHelperStartResponse(
        statusCode: 409,
        body: jsonEncode({'code': 'activeInAnotherSession'}),
        expectedRunToken: '0123456789abcdef0123456789abcdef',
      ),
      throwsA(isA<HelperLifecycleConflictException>()),
    );
  });

  test('helper token mismatch fails closed', () {
    expect(
      () => decodeHelperStartResponse(
        statusCode: 200,
        body: jsonEncode({
          'corePid': 42,
          'coreCreationTime100ns': 1337,
          'runToken': 'fedcba9876543210fedcba9876543210',
        }),
        expectedRunToken: '0123456789abcdef0123456789abcdef',
      ),
      throwsA(isA<HelperLifecycleProtocolException>()),
    );
  });

  test('helper 500 response preserves structured code and message', () {
    expect(
      () => decodeHelperStartResponse(
        statusCode: 500,
        body: jsonEncode({
          'code': 'unknownLease',
          'message': 'lifecycle directory owner mismatch',
        }),
        expectedRunToken: '0123456789abcdef0123456789abcdef',
      ),
      throwsA(
        isA<HelperLifecycleProtocolException>().having(
          (error) => error.message,
          'message',
          allOf(contains('unknownLease'), contains('owner mismatch')),
        ),
      ),
    );
  });

  test('only typed helper conflict disables direct spawn fallback', () {
    final cases = <(Object, bool)>[
      (const HelperLifecycleConflictException(), false),
      (const HelperLifecycleProtocolException('HTTP 500'), true),
      (StateError('transport failed'), true),
    ];

    for (final (error, expectedFallback) in cases) {
      expect(shouldFallBackToDirectSpawn(error), expectedFallback);
    }
  });

  test('stop request always serializes the exact core identity', () {
    final body = encodeHelperStopRequest(const HelperCoreIdentity(
      corePid: 42,
      coreCreationTime100ns: 1337,
      runToken: '0123456789abcdef0123456789abcdef',
    ));

    expect(jsonDecode(body), {
      'corePid': 42,
      'coreCreationTime100ns': 1337,
      'runToken': '0123456789abcdef0123456789abcdef',
    });
  });

  test('Windows FILETIME combines unsigned high and low words', () {
    expect(composeWindowsFileTime(0x01234567, 0x89abcdef), 0x0123456789abcdef);
  });

  test('Windows app identity is loaded once per cache', () async {
    var loads = 0;
    final cache = HelperAppIdentityCache(() async {
      loads += 1;
      return const HelperAppIdentity(
        appPid: 42,
        appCreationTime100ns: 1337,
        appSessionId: 7,
      );
    });

    final firstLoad = cache.current();
    final concurrentLoad = cache.current();
    final first = await firstLoad;
    final second = await concurrentLoad;

    expect(concurrentLoad, same(firstLoad));
    expect(first, same(second));
    expect(loads, 1);
  });

  test('failed Windows app identity load is retried then success is cached',
      () async {
    var loads = 0;
    final cache = HelperAppIdentityCache(() async {
      loads += 1;
      if (loads == 1) throw StateError('transient Win32 failure');
      return const HelperAppIdentity(
        appPid: 42,
        appCreationTime100ns: 1337,
        appSessionId: 7,
      );
    });

    await expectLater(cache.current(), throwsStateError);
    final recovered = await cache.current();
    final cached = await cache.current();

    expect(cached, same(recovered));
    expect(loads, 2);
  });

  test('helper HTTP deadlines exceed the helper stop budget', () {
    expect(helperStartTimeout, const Duration(seconds: 15));
    expect(helperStopTimeout, const Duration(seconds: 12));
  });
}
