// Android-телефон без фоновой работы аккаунта — решение владельца 2026-10-29.
// Тесты идут на macOS, поэтому «телефон» включается подменой
// `debugAccountPhoneBlocked`, а «магазин» — `debugAccountStoreBlocked`.
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/account/account_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugAccountStoreBlocked = null;
    debugAccountPhoneBlocked = null;
  });

  group('гейт', () {
    test('без подмены на macOS ничего не блокируется', () {
      debugAccountStoreBlocked = false;
      expect(accountPhoneBlocked, isFalse);
      expect(accountBackgroundBlocked, isFalse);
    });

    test('телефон блокирует фон, но не интерфейсный гейт магазина', () {
      debugAccountStoreBlocked = false;
      debugAccountPhoneBlocked = true;
      expect(accountBackgroundBlocked, isTrue);
      expect(accountStoreBlocked, isFalse);
    });

    test('магазин блокирует фон и без телефона', () {
      debugAccountStoreBlocked = true;
      debugAccountPhoneBlocked = false;
      expect(accountBackgroundBlocked, isTrue);
    });

    test('планшет/ТВ (не телефон) вне магазина: фон работает', () {
      debugAccountStoreBlocked = false;
      debugAccountPhoneBlocked = false;
      expect(accountBackgroundBlocked, isFalse);
    });
  });

  group('нотификатор аккаунта на телефоне', () {
    test('restore / repair / onProfileUpdateFailed молчат, контроллера нет',
        () async {
      debugAccountStoreBlocked = false;
      debugAccountPhoneBlocked = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final account = container.read(accountProvider.notifier);

      await account.restore();
      expect(await account.repairSubscription(), isFalse);
      await account.onProfileUpdateFailed('p1');
      expect(container.read(accountProvider).status, AccountStatus.unknown);

      // Всё, что дошло бы до шлюза или хранилища, отказывает до создания
      // контроллера (геттер бросает раньше `_controller ??=`).
      for (final call in <Future<Object?> Function()>[
        () async => account.requestCode('a@example.com'),
        () async => account.verifyCode('a@example.com', '123456'),
        () async => account.syncSubscription(),
        () async => account.cabinetUriFor('p1'),
        () async => account.removeFromDevice(),
        () async => account.logout(),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<AccountApiException>().having(
              (e) => e.kind,
              'kind',
              AccountApiErrorKind.disabled,
            ),
          ),
        );
      }
    });
  });
}
