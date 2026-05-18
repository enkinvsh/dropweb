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

  group('isSafeCabinetPath rejects Telegram deep-link shapes', () {
    test('tg://resolve and other non-https schemes are never cabinet paths', () {
      expect(
        isSafeCabinetPath('tg://resolve?domain=bot&start=webauth_token'),
        isFalse,
      );
      expect(isSafeCabinetPath('tg://join?invite=abc'), isFalse);
      expect(isSafeCabinetPath('intent://resolve#Intent;end'), isFalse);
      expect(isSafeCabinetPath('javascript:alert(1)'), isFalse);
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
