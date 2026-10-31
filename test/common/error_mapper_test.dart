import 'package:dropweb/clash/start_listener_result.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  // Default locale for the bulk of the assertions. Individual groups override
  // Intl.defaultLocale to exercise the Russian branch.
  setUp(() {
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = 'en';
  });

  group('ErrorMapper.mapError — Dio timeouts', () {
    final listenerTimeout =
        StartListenerTimeoutException(const Duration(seconds: 30)).toString();

    test('maps TUN listener timeout to a short wait hint', () {
      expect(
        ErrorMapper.mapError(listenerTimeout),
        'VPN is taking longer than usual to start',
      );
    });

    test('maps TUN listener timeout to a short wait hint in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(listenerTimeout),
        'VPN запускается дольше обычного',
      );
    });

    test('maps our Android TUN-ack timeout', () {
      expect(
        ErrorMapper.mapError('tun start timeout'),
        'VPN is taking longer than usual to start',
      );
    });

    test('maps the exact connection-timeout message from the bug report', () {
      const raw =
          'DioException [connection timeout]: The request connection took '
          'longer than 0:00:15.000000. It was aborted.';
      final mapped = ErrorMapper.mapError(raw);
      expect(mapped, isNotNull);
      expect(
        mapped,
        'Server is not responding',
      );
    });

    test('maps the connection-timeout message in Russian', () {
      Intl.defaultLocale = 'ru';
      const raw =
          'DioException [connection timeout]: The request connection took '
          'longer than 0:00:15.000000. It was aborted.';
      expect(
        ErrorMapper.mapError(raw),
        'Сервер не отвечает',
      );
    });

    test('maps receive timeout', () {
      expect(
        ErrorMapper.mapError('DioException [receive timeout]: ...'),
        'Server is not responding',
      );
    });

    test('maps send timeout', () {
      expect(
        ErrorMapper.mapError('DioException [send timeout]: ...'),
        'Server is not responding',
      );
    });

    test('maps Dart TimeoutException', () {
      expect(
        ErrorMapper.mapError('TimeoutException after 0:00:30.000000'),
        'Server is not responding',
      );
    });
  });

  group('ErrorMapper.mapError — connectivity', () {
    test('maps Dio connection error', () {
      expect(
        ErrorMapper.mapError('DioException [connection error]: ...'),
        'No internet connection',
      );
    });

    test('maps SocketException / failed host lookup', () {
      expect(
        ErrorMapper.mapError(
            "SocketException: Failed host lookup: 'example.com'"),
        'No internet connection',
      );
    });

    test('maps connection error in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError('DioException [connection error]: ...'),
        'Нет подключения к интернету',
      );
    });
  });

  group('ErrorMapper.mapError — bad response status', () {
    test('maps known 404 to subscription-not-found', () {
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 404 ...'),
        'Subscription not found',
      );
    });

    test('maps an arbitrary status code to "Server returned error N"', () {
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 429 ...'),
        'Server returned error 429',
      );
    });

    test('maps an arbitrary status code in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 429 ...'),
        'Сервер вернул ошибку 429',
      );
    });
  });

  group('ErrorMapper.mapError — certificate', () {
    test('maps bad certificate', () {
      expect(
        ErrorMapper.mapError('DioException [bad certificate]: ...'),
        'Server certificate check failed',
      );
    });

    test('maps HandshakeException certificate verify failure', () {
      expect(
        ErrorMapper.mapError(
            'HandshakeException: Handshake error in client (CERTIFICATE_VERIFY_FAILED)'),
        'Server certificate check failed',
      );
    });
  });

  group('ErrorMapper.mapError — format / plugin', () {
    test('maps FormatException', () {
      expect(
        ErrorMapper.mapError(
            'FormatException: Unexpected character (at line 1)'),
        'Invalid server response',
      );
    });

    test('maps the exact MissingPluginException from the bug report', () {
      const raw = 'MissingPluginException(No implementation found for method '
          'analyzeImage on channel '
          'dev.steenbakker.mobile_scanner/scanner/method)';
      expect(
        ErrorMapper.mapError(raw),
        'Not available on this platform',
      );
    });

    test('maps MissingPluginException in Russian', () {
      Intl.defaultLocale = 'ru';
      const raw = 'MissingPluginException(No implementation found for method '
          'analyzeImage on channel '
          'dev.steenbakker.mobile_scanner/scanner/method)';
      expect(
        ErrorMapper.mapError(raw),
        'Недоступно на этой платформе',
      );
    });
  });

  group('ErrorMapper.mapError — our own raw throws', () {
    const coreDidNotAnswer =
        'error: core did not answer (timeout) — config not validated';
    const coreCallTimedOut = 'error: core call timed out (setupConfig)';

    test('maps fail-closed core timeouts', () {
      expect(
        ErrorMapper.mapError(coreDidNotAnswer),
        'VPN core is not responding',
      );
      expect(
        ErrorMapper.mapError(coreCallTimedOut),
        'VPN core is not responding',
      );
    });

    test('maps fail-closed core timeouts in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(coreDidNotAnswer),
        'VPN-ядро не отвечает',
      );
      expect(
        ErrorMapper.mapError(coreCallTimedOut),
        'VPN-ядро не отвечает',
      );
    });

    test('maps "Subscription too large"', () {
      expect(
        ErrorMapper.mapError(
            'Exception: Subscription too large (5242880 bytes)'),
        'Subscription is too large',
      );
    });

    test('maps "Subscription too large" in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(
            'Exception: Subscription too large (5242880 bytes)'),
        'Подписка слишком большая',
      );
    });

    test('maps "Redirect detected, but no location"', () {
      expect(
        ErrorMapper.mapError(
            'Exception: Redirect detected, but no location header'),
        'Subscription server replied incorrectly',
      );
    });

    test('maps "Redirect detected, but no location" in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(
            'Exception: Redirect detected, but no location header'),
        'Сервер подписки ответил некорректно',
      );
    });
  });

  group('ErrorMapper — тост короткий', () {
    // По одному сырому тексту на каждую ветку шаблонов и на динамический код.
    const samples = <String>[
      'activeInAnotherSession',
      'TUN listener start timed out',
      'core did not answer (timeout)',
      'dial tcp: network is unreachable',
      'lookup host: no such host',
      'dial tcp 1.2.3.4:443: i/o timeout',
      'DioException [receive timeout]: ...',
      'dial tcp 1.2.3.4:443: connection refused',
      'read tcp: connection reset by peer',
      'read tcp: unexpected EOF',
      'DioException [bad certificate]: ...',
      'tls: handshake failure',
      'proxy [Germany] not found',
      'listen tcp: address already in use',
      'accept: too many open files',
      'authentication failed',
      'status code of 404',
      'status code of 403',
      'status code of 503',
      'status code of 429',
      'yaml: unmarshal errors: line 1',
      'yaml: found character that cannot start any token',
      'Subscription too large (5242880 bytes)',
      'Redirect detected, but no location header',
      'SocketException: Failed host lookup',
      'MissingPluginException(No implementation found)',
      'FormatException: Unexpected character',
    ];

    test('каждый текст во всех локалях — одна короткая фраза', () {
      for (final locale in ['ru', 'en', 'ja', 'zh_CN']) {
        Intl.defaultLocale = locale;
        final texts = <String>[
          ...samples.map((raw) => ErrorMapper.mapError(raw)!),
          ErrorMapper.generic,
          ErrorMapper.vpnStartFailed,
          ErrorMapper.vpnPermissionDenied,
        ];
        for (final text in texts) {
          // Тост вмещает две строки; совет вторым предложением — это уже длинный тост.
          expect(text.length, lessThanOrEqualTo(45), reason: '$locale: $text');
          expect(text, isNot(contains('. ')), reason: '$locale: $text');
        }
      }
    });
  });

  group('ErrorMapper.mapError — unmapped', () {
    test('returns null for an unrecognised error', () {
      expect(ErrorMapper.mapError('some totally unknown gibberish'), isNull);
    });

    test('falls through to the generic message for an unrelated error', () {
      final message = ErrorMapper.mapError('some totally unknown gibberish') ??
          ErrorMapper.generic;

      expect(message, 'Something went wrong');
    });
  });

  group('ErrorMapper.generic', () {
    test('returns the English generic fallback by default', () {
      expect(ErrorMapper.generic, 'Something went wrong');
    });

    test('returns the Russian generic fallback for ru locale', () {
      Intl.defaultLocale = 'ru';
      expect(ErrorMapper.generic, 'Что-то пошло не так');
    });
  });

  group('ErrorMapper — ja/zh locales', () {
    const raw = 'dial tcp 1.2.3.4:443: connection refused';

    test('maps patterns and getters to Japanese for ja locale', () {
      Intl.defaultLocale = 'ja_JP';
      expect(
        ErrorMapper.mapError(raw),
        'サーバーが接続を拒否しました',
      );
      expect(ErrorMapper.generic, '問題が発生しました');
      expect(
        ErrorMapper.mapError('status code of 418'),
        'サーバーがエラー418を返しました',
      );
    });

    test('maps patterns and getters to Simplified Chinese for zh locale', () {
      Intl.defaultLocale = 'zh_CN';
      expect(ErrorMapper.mapError(raw), '服务器拒绝了连接');
      expect(ErrorMapper.vpnPermissionDenied, '没有 VPN 权限');
    });

    test('falls back to English for other locales', () {
      Intl.defaultLocale = 'de';
      expect(
        ErrorMapper.mapError(raw),
        'Server refused the connection',
      );
      expect(ErrorMapper.vpnStartFailed, 'Could not start VPN');
    });
  });
}
