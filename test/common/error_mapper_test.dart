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
    test('maps the exact connection-timeout message from the bug report', () {
      const raw =
          'DioException [connection timeout]: The request connection took '
          'longer than 0:00:15.000000. It was aborted.';
      final mapped = ErrorMapper.mapError(raw);
      expect(mapped, isNotNull);
      expect(
        mapped,
        'Server is not responding. Check your internet connection and try again.',
      );
    });

    test('maps the connection-timeout message in Russian', () {
      Intl.defaultLocale = 'ru';
      const raw =
          'DioException [connection timeout]: The request connection took '
          'longer than 0:00:15.000000. It was aborted.';
      expect(
        ErrorMapper.mapError(raw),
        'Сервер не отвечает. Проверьте подключение к интернету и попробуйте ещё раз.',
      );
    });

    test('maps receive timeout', () {
      expect(
        ErrorMapper.mapError('DioException [receive timeout]: ...'),
        'Server is not responding. Check your internet connection and try again.',
      );
    });

    test('maps send timeout', () {
      expect(
        ErrorMapper.mapError('DioException [send timeout]: ...'),
        'Server is not responding. Check your internet connection and try again.',
      );
    });

    test('maps Dart TimeoutException', () {
      expect(
        ErrorMapper.mapError('TimeoutException after 0:00:30.000000'),
        'Server is not responding. Check your internet connection and try again.',
      );
    });
  });

  group('ErrorMapper.mapError — connectivity', () {
    test('maps Dio connection error', () {
      expect(
        ErrorMapper.mapError('DioException [connection error]: ...'),
        'No internet connection. Check your connection and try again.',
      );
    });

    test('maps SocketException / failed host lookup', () {
      expect(
        ErrorMapper.mapError(
            "SocketException: Failed host lookup: 'example.com'"),
        'No internet connection. Check your connection and try again.',
      );
    });

    test('maps connection error in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError('DioException [connection error]: ...'),
        'Нет подключения к интернету. Проверьте соединение и попробуйте ещё раз.',
      );
    });
  });

  group('ErrorMapper.mapError — bad response status', () {
    test('maps known 404 to subscription-not-found', () {
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 404 ...'),
        'Subscription not found. Check the link.',
      );
    });

    test('maps an arbitrary status code to "Server returned error N"', () {
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 429 ...'),
        'Server returned error 429. Try again later.',
      );
    });

    test('maps an arbitrary status code in Russian', () {
      Intl.defaultLocale = 'ru';
      expect(
        ErrorMapper.mapError(
            'DioException [bad response]: ... status code of 429 ...'),
        'Сервер вернул ошибку 429. Попробуйте позже.',
      );
    });
  });

  group('ErrorMapper.mapError — certificate', () {
    test('maps bad certificate', () {
      expect(
        ErrorMapper.mapError('DioException [bad certificate]: ...'),
        'Could not verify the server certificate. Check your device date and time or try a different server.',
      );
    });

    test('maps HandshakeException certificate verify failure', () {
      expect(
        ErrorMapper.mapError(
            'HandshakeException: Handshake error in client (CERTIFICATE_VERIFY_FAILED)'),
        'Could not verify the server certificate. Check your device date and time or try a different server.',
      );
    });
  });

  group('ErrorMapper.mapError — format / plugin', () {
    test('maps FormatException', () {
      expect(
        ErrorMapper.mapError('FormatException: Unexpected character (at line 1)'),
        'Received an invalid response. Check the link or configuration.',
      );
    });

    test('maps the exact MissingPluginException from the bug report', () {
      const raw =
          'MissingPluginException(No implementation found for method '
          'analyzeImage on channel '
          'dev.steenbakker.mobile_scanner/scanner/method)';
      expect(
        ErrorMapper.mapError(raw),
        'This feature is not available on your platform.',
      );
    });

    test('maps MissingPluginException in Russian', () {
      Intl.defaultLocale = 'ru';
      const raw =
          'MissingPluginException(No implementation found for method '
          'analyzeImage on channel '
          'dev.steenbakker.mobile_scanner/scanner/method)';
      expect(
        ErrorMapper.mapError(raw),
        'Эта функция недоступна на вашей платформе.',
      );
    });
  });

  group('ErrorMapper.mapError — unmapped', () {
    test('returns null for an unrecognised error', () {
      expect(ErrorMapper.mapError('some totally unknown gibberish'), isNull);
    });
  });

  group('ErrorMapper.generic', () {
    test('returns the English generic fallback by default', () {
      expect(ErrorMapper.generic, 'Something went wrong. Please try again.');
    });

    test('returns the Russian generic fallback for ru locale', () {
      Intl.defaultLocale = 'ru';
      expect(ErrorMapper.generic, 'Что-то пошло не так. Попробуйте ещё раз.');
    });
  });
}
