import 'package:dropweb/common/clipboard_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractSubscriptionUrl', () {
    test('returns https URL as-is', () {
      const url = 'https://panel.example.com/api/sub/token123';
      expect(extractSubscriptionUrl(url), url);
    });

    test('returns http URL as-is', () {
      const url = 'http://panel.example.com/sub';
      expect(extractSubscriptionUrl(url), url);
    });

    test('trims surrounding whitespace on a plain URL', () {
      expect(
        extractSubscriptionUrl('  https://panel.example.com/sub \n'),
        'https://panel.example.com/sub',
      );
    });

    test('unwraps dropweb://install-config?url= to the inner URL', () {
      expect(
        extractSubscriptionUrl(
          'dropweb://install-config?url=https://panel.example.com/sub',
        ),
        'https://panel.example.com/sub',
      );
    });

    test('unwraps clash://install-config?url= to the inner URL', () {
      expect(
        extractSubscriptionUrl(
          'clash://install-config?url=https://panel.example.com/sub',
        ),
        'https://panel.example.com/sub',
      );
    });

    test('unwraps a URL-encoded inner URL', () {
      expect(
        extractSubscriptionUrl(
          'clash://install-config?url=https%3A%2F%2Fprovider.example%2Fsub%3Ftoken%3Dsecret',
        ),
        'https://provider.example/sub?token=secret',
      );
    });

    test('returns null for an install-config wrapper with no url param', () {
      expect(
        extractSubscriptionUrl('dropweb://install-config'),
        isNull,
      );
    });

    test('returns null when the unwrapped inner URL is not http/https', () {
      expect(
        extractSubscriptionUrl('dropweb://install-config?url=vmess://abc'),
        isNull,
      );
    });

    test('returns null for a non-subscription scheme', () {
      expect(extractSubscriptionUrl('vmess://abcdef'), isNull);
    });

    test('returns null for a bare token / random text', () {
      expect(extractSubscriptionUrl('just-some-random-text'), isNull);
    });

    test('returns null for an http(s) URL with no host', () {
      expect(extractSubscriptionUrl('https://'), isNull);
    });

    test('returns null for empty string', () {
      expect(extractSubscriptionUrl(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(extractSubscriptionUrl('   '), isNull);
    });

    test('returns null for null input', () {
      expect(extractSubscriptionUrl(null), isNull);
    });
  });
}
