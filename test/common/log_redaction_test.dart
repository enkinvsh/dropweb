import 'package:dropweb/common/log_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

// A dropweb subscription link is `https://sub.dropweb.org/<token>` — ONE path
// segment that IS the user's credential. Everything in the first group exists
// because that shape used to survive redaction verbatim.
const _hexToken = '9f2c4a7e18b3d05c6e1f8a3b4c7d2e90'; // 32 hex, real shape
const _opaqueToken = 'Kq3vN8pXsL2mWzR7bT5yUeAd'; // 24 chars, base64-ish

void main() {
  group('redactUrls / single-segment subscription tokens', () {
    test('redacts a short all-hex single segment', () {
      expect(
        redactUrls('https://sub.dropweb.org/8f3c2a1b9d'),
        'https://sub.dropweb.org/[REDACTED]',
      );
    });

    test('redacts a real 32-hex dropweb subscription token', () {
      expect(
        redactUrls('import https://sub.dropweb.org/$_hexToken ok'),
        'import https://sub.dropweb.org/[REDACTED] ok',
      );
    });

    test('redacts an opaque token longer than 12 characters', () {
      expect(
        redactUrls('https://sub.dropweb.org/$_opaqueToken'),
        'https://sub.dropweb.org/[REDACTED]',
      );
    });

    test('keeps scheme, host and port while redacting the token', () {
      expect(
        redactUrls('https://sub.dropweb.org:8443/$_hexToken'),
        'https://sub.dropweb.org:8443/[REDACTED]',
      );
    });

    test('redacts a token that also carries a query', () {
      expect(
        redactUrls('https://sub.dropweb.org/$_hexToken?os=android'),
        'https://sub.dropweb.org/[REDACTED]?[REDACTED]',
      );
    });

    test('redacts a token with a trailing slash', () {
      expect(
        redactUrls('https://sub.dropweb.org/$_hexToken/'),
        'https://sub.dropweb.org/[REDACTED]',
      );
    });
  });

  // Over-redaction is a real failure mode: this redactor feeds the support
  // bundle we use to debug user problems. Blinding it is a regression too.
  group('redactUrls / benign single segments stay readable', () {
    test('keeps the allowlisted diagnostic endpoints verbatim', () {
      for (final path in const [
        'version',
        'manifest.json',
        'favicon.ico',
        'health',
      ]) {
        expect(
          redactUrls('https://sub.dropweb.org/$path'),
          'https://sub.dropweb.org/$path',
          reason: '/$path is an allowlisted diagnostic endpoint',
        );
      }
    });

    test('keeps a short segment such as /api', () {
      expect(
        redactUrls('https://sub.dropweb.org/api'),
        'https://sub.dropweb.org/api',
      );
    });

    test('keeps the connectivity probe path /generate_204', () {
      expect(
        redactUrls('probe http://cp.cloudflare.com/generate_204 -> 204'),
        'probe http://cp.cloudflare.com/generate_204 -> 204',
      );
    });

    test('keeps product URLs used in logs (/privacy, /downloads)', () {
      expect(
        redactUrls('https://dropweb.org/privacy'),
        'https://dropweb.org/privacy',
      );
      expect(
        redactUrls('https://dropweb.org/downloads'),
        'https://dropweb.org/downloads',
      );
    });

    test('keeps a DoH endpoint path', () {
      expect(redactUrls('https://doh.pub/dns-query'), 'https://doh.pub/dns-query');
    });

    test('keeps the host-only deep-link authority of install-config', () {
      expect(
        redactUrls('clash://install-config?url=https://sub.dropweb.org/$_hexToken'),
        'clash://install-config?[REDACTED]',
      );
      expect(
        redactUrls('dropweb://install-config?url=secret'),
        'dropweb://install-config?[REDACTED]',
      );
    });
  });

  group('redactUrls / Authorization and Cookie headers', () {
    test('redacts a Bearer credential including the scheme token', () {
      expect(
        redactUrls('Authorization: Bearer abc.def'),
        'Authorization: [REDACTED]',
      );
    });

    test('redacts a lowercase authorization header', () {
      expect(
        redactUrls('authorization: bearer abc'),
        'authorization: [REDACTED]',
      );
    });

    test('redacts a Cookie header value', () {
      expect(redactUrls('Cookie: sp_dc=xyz'), 'Cookie: [REDACTED]');
    });

    test('redacts a Set-Cookie-free lowercase cookie header', () {
      expect(redactUrls('cookie: a=1; b=2'), 'cookie: [REDACTED]');
    });

    test('redacts a header that appears mid-string, not at line start', () {
      expect(
        redactUrls('[dropweb] sub fetch failed, Authorization: Bearer eyJhbGc'),
        '[dropweb] sub fetch failed, Authorization: [REDACTED]',
      );
    });

    test('redaction stops at the line break and spares the next line', () {
      expect(
        redactUrls('Authorization: Bearer secret\nHost: sub.dropweb.org'),
        'Authorization: [REDACTED]\nHost: sub.dropweb.org',
      );
    });

    test('preserves a CRLF separator', () {
      expect(
        redactUrls('Cookie: a=b\r\nX-Trace: 1'),
        'Cookie: [REDACTED]\r\nX-Trace: 1',
      );
    });

    test('leaves a valueless Authorization header alone', () {
      expect(redactUrls('Authorization:\n'), 'Authorization:\n');
    });

    test('does not touch unrelated headers', () {
      expect(
        redactUrls('Content-Type: application/json'),
        'Content-Type: application/json',
      );
    });
  });

  group('redactUrls / pre-existing rules must not regress', () {
    test('keeps the first segment of a deep subscription path', () {
      expect(
        redactUrls('https://panel.example/api/sub/$_hexToken'),
        'https://panel.example/api/[REDACTED]',
      );
    });

    test('redacts userinfo', () {
      expect(
        redactUrls('https://user:password@example.com/install'),
        'https://[REDACTED]@example.com/install',
      );
    });

    test('redacts the whole query — query redaction IS in scope already', () {
      expect(
        redactUrls('https://example.com/api?token=$_hexToken&os=android'),
        'https://example.com/api?[REDACTED]',
      );
    });

    test('redacts the fragment', () {
      expect(
        redactUrls('https://example.com/api#$_hexToken'),
        'https://example.com/api#[REDACTED]',
      );
    });

    test('a [REDACTED] marker injected into the query cannot bypass redaction',
        () {
      final redacted =
          redactUrls('https://example.com/api?note=[REDACTED]&token=$_hexToken');
      expect(redacted, 'https://example.com/api?[REDACTED]');
      expect(redacted, isNot(contains(_hexToken)));
    });

    test('leaves text without URLs untouched', () {
      expect(
        redactUrls('core started, mode=standard, 12 proxies'),
        'core started, mode=standard, 12 proxies',
      );
    });
  });

  // The support bundle redacts every line and then redacts the assembled text
  // again, so a second pass MUST be a no-op or the bundle degrades on each run.
  group('redactUrls / idempotency (the support bundle runs two passes)', () {
    for (final raw in const [
      'https://sub.dropweb.org/9f2c4a7e18b3d05c6e1f8a3b4c7d2e90',
      'https://sub.dropweb.org:8443/9f2c4a7e18b3d05c6e1f8a3b4c7d2e90?os=android',
      'https://panel.example/api/sub/9f2c4a7e18b3d05c6e1f8a3b4c7d2e90',
      'https://user:password@example.com/install?token=secret',
      'https://sub.dropweb.org/version',
      'Authorization: Bearer abc.def',
      'Cookie: sp_dc=xyz',
    ]) {
      test('second pass is a no-op for: $raw', () {
        final once = redactUrls(raw);
        expect(redactUrls(once), once);
      });
    }

    test('a token never survives a double pass', () {
      final once = redactUrls('https://sub.dropweb.org/$_hexToken');
      expect(redactUrls(once), isNot(contains(_hexToken)));
    });
  });
}
