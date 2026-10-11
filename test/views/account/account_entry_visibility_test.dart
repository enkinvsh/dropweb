// Входы в аккаунт: «Войти по почте» в добавлении профиля и «Аккаунт» в
// меню. Platform.isAndroid в тестах на хосте всегда false, поэтому условие
// показа проверяем как чистую функцию — виджеты зовут ровно её.
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountLoginEntryVisible (add_profile)', () {
    test('вход доступен + нет сессии → видно', () {
      for (final status in [AccountStatus.loggedOut, AccountStatus.unknown]) {
        expect(
          accountLoginEntryVisible(
              isAndroid: true, status: status, loginAvailable: true),
          isTrue,
          reason: status.name,
        );
      }
    });

    test('вход недоступен → скрыто', () {
      expect(
        accountLoginEntryVisible(
          isAndroid: true,
          status: AccountStatus.loggedOut,
          loginAvailable: false,
        ),
        isFalse,
      );
    });

    test('сессия есть (ready/locked) → скрыто', () {
      for (final status in [AccountStatus.ready, AccountStatus.locked]) {
        expect(
          accountLoginEntryVisible(
              isAndroid: true, status: status, loginAvailable: true),
          isFalse,
          reason: status.name,
        );
      }
    });

    test('не Android → скрыто', () {
      expect(
        accountLoginEntryVisible(
          isAndroid: false,
          status: AccountStatus.loggedOut,
          loginAvailable: true,
        ),
        isFalse,
      );
    });
  });

  group('accountMenuEntryVisible (меню «Аккаунт»)', () {
    test('сессия есть → видно даже без доступного входа', () {
      for (final status in [AccountStatus.ready, AccountStatus.locked]) {
        expect(
          accountMenuEntryVisible(
              isAndroid: true, status: status, loginAvailable: false),
          isTrue,
          reason: status.name,
        );
      }
    });

    test('нет сессии: видно только когда вход доступен', () {
      expect(
        accountMenuEntryVisible(
          isAndroid: true,
          status: AccountStatus.loggedOut,
          loginAvailable: true,
        ),
        isTrue,
      );
      for (final status in [AccountStatus.loggedOut, AccountStatus.unknown]) {
        expect(
          accountMenuEntryVisible(
              isAndroid: true, status: status, loginAvailable: false),
          isFalse,
          reason: status.name,
        );
      }
    });

    test('не Android → скрыто', () {
      expect(
        accountMenuEntryVisible(
          isAndroid: false,
          status: AccountStatus.ready,
          loginAvailable: true,
        ),
        isFalse,
      );
    });
  });
}
