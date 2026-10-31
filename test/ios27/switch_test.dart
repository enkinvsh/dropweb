// Выбор главной экрана: iOS-редизайн только на iOS в мобильной раскладке.

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/ui/ios27/ios27_switch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useIos27HomeFor', () {
    test('таблица истинности: iOS и мобильная раскладка', () {
      for (final isIOS in [false, true]) {
        for (final mode in ViewMode.values) {
          expect(
            useIos27HomeFor(isIOS: isIOS, viewMode: mode),
            isIOS && mode == ViewMode.mobile,
            reason: 'isIOS=$isIOS, viewMode=$mode',
          );
        }
      }
    });

    test('единственный истинный случай: iOS + mobile', () {
      final truthy = <(bool, ViewMode)>[
        for (final isIOS in [false, true])
          for (final mode in ViewMode.values)
            if (useIos27HomeFor(isIOS: isIOS, viewMode: mode)) (isIOS, mode),
      ];
      expect(truthy, [(true, ViewMode.mobile)]);
    });

    test('все режимы раскладки учтены: их ровно три', () {
      // Новый режим в ViewMode потребует осознанного решения для iOS: тест напомнит о нём.
      expect(ViewMode.values,
          [ViewMode.mobile, ViewMode.laptop, ViewMode.desktop]);
    });

    test('на Android и десктопе iOS-главная выключена независимо от раскладки',
        () {
      for (final mode in ViewMode.values) {
        expect(useIos27HomeFor(isIOS: false, viewMode: mode), isFalse);
      }
    });

    test(
        'iOS в планшетной или десктопной раскладке остаётся на прежней главной',
        () {
      expect(useIos27HomeFor(isIOS: true, viewMode: ViewMode.laptop), isFalse);
      expect(useIos27HomeFor(isIOS: true, viewMode: ViewMode.desktop), isFalse);
    });
  });
}
