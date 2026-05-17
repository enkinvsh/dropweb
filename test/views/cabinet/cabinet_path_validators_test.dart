import 'package:dropweb/views/cabinet/cabinet_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeSupportPath', () {
    test('accepts /support root and nested paths', () {
      expect(isSafeSupportPath('/support'), isTrue);
      expect(isSafeSupportPath('/support/'), isTrue);
      expect(isSafeSupportPath('/support/ticket/123'), isTrue);
    });

    test('rejects unrelated, absolute, and unsafe paths', () {
      expect(isSafeSupportPath('/supportx'), isFalse);
      expect(isSafeSupportPath('/balance'), isFalse);
      expect(isSafeSupportPath('support'), isFalse);
      expect(isSafeSupportPath('//evil.com/support'), isFalse);
      expect(isSafeSupportPath('https://cab.dropweb.org/support'), isFalse);
      expect(isSafeSupportPath(''), isFalse);
    });

    test('rejects path traversal segments', () {
      expect(isSafeSupportPath('/support/../etc'), isFalse);
      expect(isSafeSupportPath('/support/./ticket'), isFalse);
      expect(isSafeSupportPath('/support//ticket'), isFalse);
      expect(isSafeSupportPath('/support/ticket/../../admin'), isFalse);
      expect(isSafeSupportPath('/support/..'), isFalse);
      expect(isSafeSupportPath('/support/.'), isFalse);
    });
  });

  group('isSafeTelegramLoginUri', () {
    Uri parse(String raw) => Uri.parse(raw);

    test('accepts tg://resolve with domain and webauth_<token> start', () {
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=dropwebpay_bot&start=webauth_test'),
        ),
        isTrue,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=A_bot9&start=webauth_abc123-XYZ_0'),
        ),
        isTrue,
      );
    });

    test('rejects wrong scheme', () {
      expect(
        isSafeTelegramLoginUri(
          parse('https://t.me/dropwebpay_bot?start=webauth_test'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('http://resolve?domain=x&start=webauth_y'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('intent://resolve?domain=x&start=webauth_y#Intent;end'),
        ),
        isFalse,
      );
    });

    test('rejects wrong host / non-resolve targets', () {
      expect(
        isSafeTelegramLoginUri(parse('tg://join?invite=abc')),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://msg?to=evil&text=webauth_x'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve.evil?domain=x&start=webauth_y'),
        ),
        isFalse,
      );
    });

    test('rejects missing or empty domain', () {
      expect(
        isSafeTelegramLoginUri(parse('tg://resolve?start=webauth_test')),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=&start=webauth_test'),
        ),
        isFalse,
      );
    });

    test('rejects start that is missing, lacks webauth_ prefix, or empty token', () {
      expect(
        isSafeTelegramLoginUri(parse('tg://resolve?domain=x')),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(parse('tg://resolve?domain=x&start=hello')),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(parse('tg://resolve?domain=x&start=webauth_')),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(parse('tg://resolve?domain=x&start=')),
        isFalse,
      );
    });

    test('rejects unsafe characters in domain or start token', () {
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=evil/path&start=webauth_test'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=evil%20bot&start=webauth_test'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=x&start=webauth_evil%2Fy'),
        ),
        isFalse,
      );
    });

    test('rejects extra query parameters, paths, or fragments', () {
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=x&start=webauth_y&extra=1'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve/extra?domain=x&start=webauth_y'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=x&start=webauth_y#frag'),
        ),
        isFalse,
      );
    });

    test('rejects duplicate query keys', () {
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=x&domain=y&start=webauth_z'),
        ),
        isFalse,
      );
      expect(
        isSafeTelegramLoginUri(
          parse('tg://resolve?domain=x&start=webauth_a&start=webauth_b'),
        ),
        isFalse,
      );
    });
  });

  group('isSafePaymentPath', () {
    test('accepts known zencab payment routes', () {
      expect(isSafePaymentPath('/balance'), isTrue);
      expect(isSafePaymentPath('/balance/top-up'), isTrue);
      expect(isSafePaymentPath('/balance/top-up/123'), isTrue);
      expect(isSafePaymentPath('/balance/saved-cards'), isTrue);
      expect(isSafePaymentPath('/subscription/purchase'), isTrue);
      expect(isSafePaymentPath('/subscriptions/abc/renew'), isTrue);
      expect(isSafePaymentPath('/buy/foo'), isTrue);
      expect(isSafePaymentPath('/buy/success/token'), isTrue);
    });

    test('rejects unrelated and malformed payment paths', () {
      expect(isSafePaymentPath('/support'), isFalse);
      expect(isSafePaymentPath('/subscriptions'), isFalse);
      expect(isSafePaymentPath('/subscriptions//renew'), isFalse);
      expect(isSafePaymentPath('/subscriptions/abc/def/renew'), isFalse);
      expect(isSafePaymentPath('/balancex'), isFalse);
      expect(isSafePaymentPath('/subscription/purchasex'), isFalse);
      expect(isSafePaymentPath('//evil.com/balance'), isFalse);
      expect(isSafePaymentPath('https://cab.dropweb.org/balance'), isFalse);
      expect(isSafePaymentPath(''), isFalse);
    });

    test('rejects path traversal segments', () {
      expect(isSafePaymentPath('/balance/../admin'), isFalse);
      expect(isSafePaymentPath('/balance/./top-up'), isFalse);
      expect(isSafePaymentPath('/balance//top-up'), isFalse);
      expect(isSafePaymentPath('/buy/../admin'), isFalse);
      expect(isSafePaymentPath('/subscriptions/../admin/renew'), isFalse);
      expect(isSafePaymentPath('/subscriptions/./abc/renew'), isFalse);
      expect(isSafePaymentPath('/balance/..'), isFalse);
    });
  });
}
