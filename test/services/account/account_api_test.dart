import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropweb/services/account/account_api.dart';
import 'package:dropweb/services/account/account_api_exception.dart';
import 'package:dropweb/services/account/account_pow.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

const _a = 'https://a.example/api';
const _b = 'https://b.example/api';

AccountApi _api(FakeAdapter adapter, {List<String> bases = const [_a, _b]}) =>
    AccountApi(
      baseUrls: () => bases,
      userAgent: () => 'dropweb/test',
      dio: fakeDio(adapter),
    );

Future<AccountApiException> _error(Future<Object?> call) async {
  try {
    await call;
  } on AccountApiException catch (e) {
    return e;
  }
  fail('ожидалось AccountApiException');
}

void main() {
  group('маппинг ошибок бэкенда', () {
    AccountApiException map(int status, Object body, {String? retryAfter}) =>
        AccountApiException.fromResponse(status, body,
            retryAfterHeader: retryAfter);

    test('api_error коды из email_otp_service', () {
      expect(
        map(400, {
          'detail': {
            'code': 'invalid_code',
            'message': 'Invalid or expired code'
          }
        }).kind,
        AccountApiErrorKind.invalidCode,
      );
      expect(
        map(429, {
          'detail': {
            'code': 'email_code_locked',
            'message': 'Too many failed attempts'
          }
        }).kind,
        AccountApiErrorKind.codeExpiredOrLocked,
      );
      final cooldown = map(
        429,
        {
          'detail': {'code': 'email_code_cooldown', 'message': 'Wait'}
        },
        retryAfter: '42',
      );
      expect(cooldown.kind, AccountApiErrorKind.rateLimited);
      expect(cooldown.retryAfter, 42);
      expect(cooldown.code, 'email_code_cooldown');
      expect(
        map(
                429,
                {
                  'detail': {'code': 'rate_limited', 'message': 'x'}
                },
                retryAfter: '600')
            .retryAfter,
        600,
      );
      expect(
        map(400, {
          'detail': {'code': 'email_disposable', 'message': 'x'}
        }).kind,
        AccountApiErrorKind.emailRejected,
      );
      expect(
        map(400, {
          'detail': {'code': 'captcha_failed', 'message': 'x'}
        }).kind,
        AccountApiErrorKind.captchaFailed,
      );
      expect(
        map(503, {
          'detail': {'code': 'email_code_unavailable', 'message': 'x'}
        }).kind,
        AccountApiErrorKind.unavailable,
      );
      expect(
        map(403, {
          'detail': {'code': 'blacklisted', 'message': 'x'}
        }).kind,
        AccountApiErrorKind.forbidden,
      );
    });

    test('строковые detail FastAPI', () {
      expect(map(403, {'detail': 'Email authentication is disabled'}).kind,
          AccountApiErrorKind.disabled);
      expect(
          map(403, {
            'detail':
                'Administrator accounts cannot be deleted from the cabinet'
          }).kind,
          AccountApiErrorKind.forbidden);
      expect(map(401, {'detail': 'Refresh token reuse detected'}).kind,
          AccountApiErrorKind.unauthorized);
      expect(map(404, {'detail': 'Not Found'}).kind,
          AccountApiErrorKind.notAvailable);
      expect(map(404, {'detail': 'User not found'}).kind,
          AccountApiErrorKind.unauthorized);
      final tooMany =
          map(429, {'detail': 'Too many requests'}, retryAfter: '60');
      expect(tooMany.kind, AccountApiErrorKind.rateLimited);
      expect(tooMany.retryAfter, 60);
      expect(map(500, {'detail': 'Account deletion failed'}).kind,
          AccountApiErrorKind.server);
    });

    test('422 pydantic по полю email/code', () {
      expect(
        map(422, {
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'value is not a valid email address'
            }
          ]
        }).kind,
        AccountApiErrorKind.emailRejected,
      );
      expect(
        map(422, {
          'detail': [
            {
              'loc': ['body', 'code'],
              'msg': 'String should match pattern'
            }
          ]
        }).kind,
        AccountApiErrorKind.invalidCode,
      );
    });
  });

  group('запросы', () {
    test('requestCode: challenge → PoW → тело с pow и language', () async {
      const salt = '0123456789abcdef01234567?expires=1791676800';
      final challengeHex = powHash(salt, 7);
      final adapter = FakeAdapter((o) {
        if (o.path.endsWith('/cabinet/auth/email/challenge')) {
          return jsonResponse(200, {
            'algorithm': 'SHA-256',
            'challenge': challengeHex,
            'salt': salt,
            'signature': 's' * 64,
            'maxnumber': 50000,
          });
        }
        return jsonResponse(
            200, {'status': 'sent', 'resend_after': 60, 'expires_in': 600});
      });
      final api = _api(adapter);

      final result = await api.requestCode(email: 'a@b.c', language: 'ru');

      expect(result.resendAfter, 60);
      expect(result.expiresIn, 600);
      expect(adapter.paths, [
        '$_a/cabinet/auth/email/challenge',
        '$_a/cabinet/auth/email/code/request',
      ]);
      final body = adapter.requests.last.data as Map;
      expect(body['email'], 'a@b.c');
      expect(body['language'], 'ru');
      expect((body['pow'] as Map)['number'], 7);
      expect(adapter.requests.last.headers['User-Agent'], 'dropweb/test');
    });

    test('Bearer в авторизованных вызовах', () async {
      final adapter = FakeAdapter((o) => jsonResponse(200, {
            'has_subscription': true,
            'subscription': {
              'subscription_url': 'https://sub.example/x',
              'is_active': true,
              'days_left': 12,
            }
          }));
      final sub = await _api(adapter).subscription('acc');
      expect(sub.url, 'https://sub.example/x');
      expect(sub.daysLeft, 12);
      expect(adapter.requests.single.headers['Authorization'], 'Bearer acc');
    });
  });

  group('failover баз API', () {
    test('ошибка соединения → следующая база, она запоминается', () async {
      final adapter = FakeAdapter((o) {
        if (o.uri.toString().startsWith(_a)) {
          throw DioException.connectionError(
              requestOptions: o, reason: 'refused');
        }
        return jsonResponse(200, {'enabled': true});
      });
      final api = _api(adapter);

      expect(await api.emailAuthEnabled(), isTrue);
      expect(api.activeBaseUrl, _b);
      expect(await api.emailAuthEnabled(), isTrue);
      expect(adapter.paths, [
        '$_a/cabinet/branding/email-auth',
        '$_b/cabinet/branding/email-auth',
        '$_b/cabinet/branding/email-auth',
      ]);
    });

    test('TLS handshake → тоже failover', () async {
      final adapter = FakeAdapter((o) {
        if (o.uri.toString().startsWith(_a)) {
          throw DioException(
            requestOptions: o,
            error: const HandshakeException('bad'),
          );
        }
        return jsonResponse(200, {'enabled': false});
      });
      expect(await _api(adapter).emailAuthEnabled(), isFalse);
      expect(adapter.requests, hasLength(2));
    });

    test('HTTP-статус не переключает базу', () async {
      final adapter = FakeAdapter(
          (o) => jsonResponse(503, {'detail': 'Service Unavailable'}));
      final e = await _error(_api(adapter).emailAuthEnabled());
      expect(e.kind, AccountApiErrorKind.unavailable);
      expect(adapter.paths, ['$_a/cabinet/branding/email-auth']);
    });

    test('receiveTimeout не переключает базу — сервер мог выполнить запрос',
        () async {
      final adapter = FakeAdapter((o) => throw DioException.receiveTimeout(
          requestOptions: o, timeout: const Duration(seconds: 30)));
      final e = await _error(_api(adapter).refresh('r1'));
      expect(e.kind, AccountApiErrorKind.network);
      expect(adapter.requests, hasLength(1));
    });

    test('все базы недоступны → network', () async {
      final adapter = FakeAdapter((o) => throw DioException.connectionTimeout(
          requestOptions: o, timeout: const Duration(seconds: 15)));
      final e = await _error(_api(adapter).emailAuthEnabled());
      expect(e.kind, AccountApiErrorKind.network);
      expect(adapter.requests, hasLength(2));
    });

    test('дубликаты баз схлопываются', () async {
      final adapter = FakeAdapter((o) =>
          throw DioException.connectionError(requestOptions: o, reason: 'x'));
      await _error(_api(adapter, bases: [_a, _a, '$_a/']).emailAuthEnabled());
      expect(adapter.requests, hasLength(1));
    });
  });
}
