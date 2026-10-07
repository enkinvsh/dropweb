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
    // Store build: payment, cabinet and provider-support links never reach
    // the profile, so every UI read site sees them as absent.
    test('store build drops payment/cabinet/support headers', () {
      final result = storeSafeProviderHeaders(headers, isPlayBuild: true);

      for (final key in [
        'support-url',
        'dropweb-renew-url',
        'dropweb-topup-url',
        'dropweb-cabinet',
        'dropweb-device-remove',
      ]) {
        expect(result.containsKey(key), isFalse, reason: key);
      }
      expect(result, {
        'announce': 'Maintenance tonight',
        'x-hwid-limit': 'true',
        'profile-update-interval': '12',
        'dropweb-theme': 'emerald',
        'dropweb-servicename': 'Example VPN',
      });
    });

    // Sideload build: headers pass through untouched.
    test('sideload build keeps every header', () {
      expect(storeSafeProviderHeaders(headers, isPlayBuild: false), headers);
    });
  });
}
