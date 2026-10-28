import 'package:dropweb/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRunAutoUpdateCheck', () {
    test('магазинная сборка не ищет обновлений мимо магазина', () {
      // iOS: не Android, но магазинная — окно «скачать с GitHub» запрещено.
      expect(
        shouldRunAutoUpdateCheck(
          isAndroid: false,
          isStoreBuild: true,
          autoCheckUpdate: true,
        ),
        isFalse,
      );
    });

    test('Android не запускает старую проверку ни в какой сборке', () {
      for (final isStoreBuild in [true, false]) {
        expect(
          shouldRunAutoUpdateCheck(
            isAndroid: true,
            isStoreBuild: isStoreBuild,
            autoCheckUpdate: true,
          ),
          isFalse,
        );
      }
    });

    test('десктоп слушается настройки', () {
      expect(
        shouldRunAutoUpdateCheck(
          isAndroid: false,
          isStoreBuild: false,
          autoCheckUpdate: true,
        ),
        isTrue,
      );
      expect(
        shouldRunAutoUpdateCheck(
          isAndroid: false,
          isStoreBuild: false,
          autoCheckUpdate: false,
        ),
        isFalse,
      );
    });
  });
}
