import 'package:dropweb/common/log_redaction.dart';
import 'package:dropweb/common/print.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactUrls', () {
    test('strips query string with token from https URL', () {
      const input = 'fetching https://example.com/sub?token=secret&user=abc now';

      final out = redactUrls(input);

      expect(out, isNot(contains('secret')));
      expect(out, isNot(contains('token=secret')));
      expect(out, isNot(contains('user=abc')));
      // host/scheme/path preserved so logs stay useful
      expect(out, contains('https://example.com/sub'));
      expect(out, contains('?[REDACTED]'));
    });

    test('strips userinfo credentials from https URL', () {
      const input = 'connecting https://user:pass@example.com/path';

      final out = redactUrls(input);

      expect(out, isNot(contains('user:pass')));
      expect(out, isNot(contains('pass')));
      expect(out, contains('[REDACTED]@example.com/path'));
    });

    test('redacts encoded subscription inside clash:// install-config deep link',
        () {
      const input =
          'onAppLink: clash://install-config?url=https%3A%2F%2Fprovider.example%2Fsub%3Ftoken%3Dsecret';

      final out = redactUrls(input);

      expect(out, isNot(contains('secret')));
      expect(out, isNot(contains('provider.example')));
      expect(out, isNot(contains('token%3Dsecret')));
      expect(out, isNot(contains('https%3A%2F%2F')));
      expect(out, contains('clash://install-config?[REDACTED]'));
    });

    test(
        'redacts encoded subscription inside dropweb:// install-config deep link',
        () {
      const input =
          'onAppLink: dropweb://install-config?url=https%3A%2F%2Fprovider.example%2Fsub%3Ftoken%3Dsecret';

      final out = redactUrls(input);

      expect(out, isNot(contains('secret')));
      expect(out, isNot(contains('provider.example')));
      expect(out, isNot(contains('token%3Dsecret')));
      expect(out, contains('dropweb://install-config?[REDACTED]'));
    });

    test('redacts fragment data so #access_token=... never leaks', () {
      const input = 'callback https://example.com/cb#access_token=secret';

      final out = redactUrls(input);

      expect(out, isNot(contains('secret')));
      expect(out, isNot(contains('access_token')));
      expect(out, contains('https://example.com/cb'));
      expect(out, contains('#[REDACTED]'));
    });

    test('preserves URLs that have neither userinfo, query, nor fragment', () {
      const input = 'ping http://127.0.0.1:7890/version ok';

      final out = redactUrls(input);

      // Non-sensitive helper-port log should stay readable.
      expect(out, contains('http://127.0.0.1:7890/version'));
      expect(out, isNot(contains('[REDACTED]')));
    });

    test('redacts multiple URLs in one log line', () {
      const input =
          'redirect from https://a.example/x?t=1 to https://b.example/y?t=2';

      final out = redactUrls(input);

      expect(out, isNot(contains('t=1')));
      expect(out, isNot(contains('t=2')));
      expect(out, contains('https://a.example/x?[REDACTED]'));
      expect(out, contains('https://b.example/y?[REDACTED]'));
    });

    test('leaves text without URLs untouched', () {
      const input = 'shutdown core';

      expect(redactUrls(input), equals(input));
    });

    test(
        'redacts URLs even when raw query already contains the [REDACTED] marker as a decoy',
        () {
      // Regression: a loose `contains("[REDACTED]")` idempotency shortcut
      // would let an attacker bypass redaction by stuffing the marker into
      // an unrelated query value. `token=secret` MUST be stripped.
      const input =
          'fetching https://example.com/sub?note=[REDACTED]&token=secret done';

      final out = redactUrls(input);

      expect(out, isNot(contains('secret')),
          reason: 'token value must be removed regardless of decoy marker');
      expect(out, isNot(contains('token=secret')));
      expect(out, isNot(contains('note=[REDACTED]&token=')));
      // The malicious query is either fully replaced with our marker (when
      // Uri.parse accepts `[` in the query) or the whole URL collapses to
      // `[URL_REDACTED]` (when parsing rejects it). Both are safe.
      expect(
        out,
        anyOf(contains('?[REDACTED]'), contains('[URL_REDACTED]')),
      );
    });

    test('is idempotent — second pass keeps the redacted form intact', () {
      // The file logger and CommonPrint both call redactUrls; a payload
      // that flows through both must not regress to `[URL_REDACTED]` or
      // re-leak the original token.
      const input =
          'visiting https://user:pass@example.com/sub?token=secret#access_token=abc';
      final once = redactUrls(input);
      final twice = redactUrls(once);

      expect(twice, equals(once),
          reason: 'double redaction must be a no-op');
      expect(twice, isNot(contains('secret')));
      expect(twice, isNot(contains('user:pass')));
      expect(twice, isNot(contains('access_token=abc')));
      expect(twice, contains('[REDACTED]@example.com/sub'));
      expect(twice, contains('?[REDACTED]'));
      expect(twice, contains('#[REDACTED]'));
    });

    test(
        'is idempotent on clash:// install-config form — no [URL_REDACTED] downgrade',
        () {
      const input =
          'onAppLink: clash://install-config?url=https%3A%2F%2Fprovider.example%2Fsub%3Ftoken%3Dsecret';
      final once = redactUrls(input);
      final twice = redactUrls(once);

      expect(twice, equals(once));
      expect(twice, isNot(contains('[URL_REDACTED]')),
          reason: 'second pass must keep the partial URL, not nuke it');
      expect(twice, contains('clash://install-config?[REDACTED]'));
    });
  });

  group('commonPrint.log central chokepoint', () {
    // Capture whatever the logging path forwards to `debugPrint`. Because
    // `CommonPrint.log` redacts ONCE and reuses the same payload string for
    // debug console, file logger, and the in-app log buffer, proving the
    // debug-console emission is clean proves the other two sinks are too.
    late List<String> captured;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      captured = <String>[];
      originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) captured.add(message);
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test(
        'redacts userinfo, query, and fragment from a real URL passed through commonPrint.log',
        () {
      commonPrint.log(
        'opening https://user:pass@example.com/sub?token=secret#access_token=abc',
      );

      expect(captured, isNotEmpty,
          reason: 'commonPrint.log must forward to debugPrint');
      final joined = captured.join('\n');

      // Sensitive substrings must NEVER reach the debug console.
      expect(joined, isNot(contains('secret')));
      expect(joined, isNot(contains('token=secret')));
      expect(joined, isNot(contains('user:pass')));
      expect(joined, isNot(contains('pass@example')));
      expect(joined, isNot(contains('access_token=abc')));

      // The message must still be debuggable: tag, scheme, and at least one
      // redaction marker must be present so operators can see something
      // happened without the secret.
      expect(joined, contains('[dropweb]'));
      expect(joined, contains('https://'));
      expect(
        joined,
        anyOf(contains('?[REDACTED]'), contains('[REDACTED]@')),
        reason: 'central chokepoint must mark the redacted region',
      );
    });

    test(
        'redacts encoded subscription URL inside clash:// install-config when logged via commonPrint.log',
        () {
      commonPrint.log(
        'onAppLink: clash://install-config?url=https%3A%2F%2Fprovider.example%2Fsub%3Ftoken%3Dsecret',
      );

      final joined = captured.join('\n');

      expect(joined, isNot(contains('secret')));
      expect(joined, isNot(contains('provider.example')));
      expect(joined, isNot(contains('token%3Dsecret')));
      expect(joined, isNot(contains('https%3A%2F%2F')));
      expect(joined, contains('[dropweb]'));
      expect(joined, contains('clash://install-config?[REDACTED]'));
    });
  });
}
