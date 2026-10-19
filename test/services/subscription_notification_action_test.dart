// Кнопка «Продлить» в уведомлении об истечении подписки: в магазинных
// сборках её нет, само напоминание остаётся.
import 'package:dropweb/services/subscription_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const headers = {'support-url': 'https://t.me/provider_support'};

  group('SubscriptionNotificationService.renewActionUrl', () {
    test('store build: ссылки для кнопки нет даже при support-url', () {
      expect(
        SubscriptionNotificationService.renewActionUrl(
          headers,
          isStoreBuild: true,
        ),
        isEmpty,
      );
    });

    test('sideload build: кнопка ведёт на support-url провайдера', () {
      expect(
        SubscriptionNotificationService.renewActionUrl(
          headers,
          isStoreBuild: false,
        ),
        'https://t.me/provider_support',
      );
    });

    test('sideload build без support-url: кнопки нет', () {
      expect(
        SubscriptionNotificationService.renewActionUrl(
          const {},
          isStoreBuild: false,
        ),
        isEmpty,
      );
    });
  });
}
