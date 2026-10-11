// Хук сбоя обновления в Riverpod-нотифайере аккаунта: магазинная сборка и
// процесс без restore() ничего не делают — ни сети, ни хранилища сессии.
import 'package:dropweb/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('магазинная сборка: onProfileUpdateFailed и repair — no-op', () async {
    final container = ProviderContainer(
      overrides: [accountFeatureEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    final account = container.read(accountProvider.notifier);

    await account.onProfileUpdateFailed('p1');
    expect(await account.repairSubscription(), isFalse);

    expect(container.read(accountProvider).status, AccountStatus.unknown);
  });

  test('сессия не восстанавливалась → хук ничего не делает', () async {
    final container = ProviderContainer(
      overrides: [accountFeatureEnabledProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).onProfileUpdateFailed('p1');

    expect(container.read(accountProvider).status, AccountStatus.unknown);
  });
}
