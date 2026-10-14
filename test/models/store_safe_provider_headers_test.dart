import 'package:dropweb/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const headers = {
    'support-url': 'https://t.me/provider_support',
    'dropweb-renew-url': 'https://pay.example.com/renew',
    'dropweb-topup-url': 'https://pay.example.com/topup',
    'dropweb-cabinet': 'https://cab.example.com',
    'dropweb-device-remove': 'https://cab.example.com/devices',
    'announce': 'Maintenance tonight',
    'x-hwid-limit': 'true',
    'profile-update-interval': '12',
    'dropweb-theme': 'emerald',
    'dropweb-servicename': 'Example VPN',
  };

  group('storeSafeProviderHeaders', () {
    // Store build (Google Play, iOS): payment and cabinet links never reach
    // the profile, so every UI read site sees them as absent. Support and
    // device removal stay, as in other store VPN clients.
    test('store build drops payment and cabinet headers', () {
      final result = storeSafeProviderHeaders(headers, isStoreBuild: true);

      for (final key in [
        'dropweb-renew-url',
        'dropweb-topup-url',
        'dropweb-cabinet',
      ]) {
        expect(result.containsKey(key), isFalse, reason: key);
      }
      expect(result, {
        'support-url': 'https://t.me/provider_support',
        'dropweb-device-remove': 'https://cab.example.com/devices',
        'announce': 'Maintenance tonight',
        'x-hwid-limit': 'true',
        'profile-update-interval': '12',
        'dropweb-theme': 'emerald',
        'dropweb-servicename': 'Example VPN',
      });
    });

    // Sideload build: headers pass through untouched.
    test('sideload build keeps every header', () {
      expect(storeSafeProviderHeaders(headers, isStoreBuild: false), headers);
    });
  });

  group('announceLinksTappable', () {
    // Текст announce в магазинной сборке остаётся, но ссылки в нём не живые:
    // провайдер не может увести на оплату или в бота через объявление.
    test('store build: ссылки в announce не кликабельны', () {
      expect(announceLinksTappable(isStoreBuild: true), isFalse);
    });

    test('sideload build: ссылки в announce кликабельны', () {
      expect(announceLinksTappable(isStoreBuild: false), isTrue);
    });
  });
}
