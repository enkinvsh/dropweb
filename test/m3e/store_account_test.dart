// Магазинные сборки (Google Play, iOS) без аккаунта и личного кабинета —
// решение владельца 2026-10-29. Тесты идут на macOS, поэтому «магазин»
// включается подменой `debugAccountStoreBlocked`.
import 'dart:async';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/account/account_gate.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/views/account/account_sheet.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _homeKey = ValueKey<String>('home');
const _sheetKey = ValueKey<String>('m3e.sheet');

const _cabinetProfile = Profile(
  id: 'p1',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {
    'dropweb-cabinet': 'https://cab.example.com',
    'dropweb-account': 'https://api.example.com',
    'support-url': 'https://t.me/support',
  },
);

const _legacyMarker = Profile(
  id: 'p2',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {'dropweb-cabinet': 'cabinet'},
);

/// Шпион вместо настоящего аккаунта: считает обращения к кабинету и замку.
class _SpyAccount extends Account {
  int cabinetCalls = 0;
  int unlockCalls = 0;

  @override
  AccountState build() => const AccountState(status: AccountStatus.ready);

  @override
  Future<Uri?> cabinetUriFor(String? profileId) async {
    cabinetCalls++;
    return null;
  }

  @override
  Future<bool> unlock(String reason) async {
    unlockCalls++;
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  debugDisableShadows = true;
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: Brightness.light,
      overrides: overrides,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: ColoredBox(
            key: _homeKey,
            color: M3eColors.of(context).home.bg,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  tearDown(() {
    debugAccountStoreBlocked = null;
  });

  group('лист «Добавить подписку»', () {
    testWidgets(
        'магазин: «Вход по почте» скрыт, даже если провайдер его объявил',
        (tester) async {
      debugAccountStoreBlocked = true;
      await _pump(
        tester,
        overrides: [
          m3eAddImportProvider.overrideWithValue((url) async {}),
          m3eAddScanProvider.overrideWithValue((context) async {}),
          accountLoginAvailableProvider.overrideWithValue(true),
        ],
      );
      unawaited(showM3eAddSubscription(_ctx(tester)));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('m3e.add.email')), findsNothing);
    });

    testWidgets('вне магазина пункта входа тоже нет (M3E без аккаунта)',
        (tester) async {
      debugAccountStoreBlocked = false;
      await _pump(
        tester,
        overrides: [
          m3eAddImportProvider.overrideWithValue((url) async {}),
          m3eAddScanProvider.overrideWithValue((context) async {}),
          accountLoginAvailableProvider.overrideWithValue(true),
        ],
      );
      unawaited(showM3eAddSubscription(_ctx(tester)));
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('m3e.add.email')), findsNothing);
    });
  });

  group('точки входа', () {
    testWidgets(
        'магазин: openAccountLoginSheet и openAccountSheet ничего не открывают',
        (tester) async {
      debugAccountStoreBlocked = true;
      await _pump(tester);
      unawaited(openAccountLoginSheet(_ctx(tester)));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      unawaited(openAccountSheet(_ctx(tester)));
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(Navigator.of(_ctx(tester)).canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });

    test('видимость пунктов входа и меню гасится в магазине', () {
      debugAccountStoreBlocked = true;
      expect(
        accountLoginEntryVisible(
          isAndroid: true,
          status: AccountStatus.loggedOut,
          loginAvailable: true,
        ),
        isFalse,
      );
      expect(
        accountMenuEntryVisible(
          isAndroid: true,
          status: AccountStatus.ready,
          loginAvailable: true,
        ),
        isFalse,
      );
      debugAccountStoreBlocked = false;
      expect(
        accountMenuEntryVisible(
          isAndroid: true,
          status: AccountStatus.ready,
          loginAvailable: false,
        ),
        isTrue,
      );
    });
  });

  group('заголовки провайдера', () {
    test('dropweb-account и dropweb-cabinet вырезаются при импорте', () {
      final result = storeSafeProviderHeaders(
        _cabinetProfile.providerHeaders,
        isStoreBuild: true,
      );
      expect(result, {'support-url': 'https://t.me/support'});
    });

    test('уже сохранённый dropweb-account в магазине игнорируется', () {
      debugAccountStoreBlocked = true;
      expect(profileAccountApiBases(_cabinetProfile), isEmpty);
      debugAccountStoreBlocked = false;
      expect(
        profileAccountApiBases(_cabinetProfile),
        ['https://api.example.com'],
      );
    });

    test('вход недоступен: провайдер доступности false', () {
      debugAccountStoreBlocked = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(accountFeatureEnabledProvider), isFalse);
      expect(container.read(accountLoginAvailableProvider), isFalse);
    });
  });

  group('кабинет', () {
    test('profileCabinetUri: в магазине пусто, в том числе по legacy-маркеру',
        () {
      debugAccountStoreBlocked = true;
      expect(profileCabinetUri(_cabinetProfile), isNull);
      expect(profileCabinetUri(_legacyMarker), isNull);
      debugAccountStoreBlocked = false;
      expect(
        profileCabinetUri(_cabinetProfile),
        Uri.parse('https://cab.example.com'),
      );
      expect(profileCabinetUri(_legacyMarker), isNotNull);
    });

    test('openCabinetBrowser в магазине ничего не запускает', () async {
      debugAccountStoreBlocked = true;
      expect(await openCabinetBrowser(Uri.parse('https://cab.example.com')),
          isFalse);
    });

    test('openAccountCabinet в магазине не трогает аккаунт', () async {
      final spy = _SpyAccount();
      final container = ProviderContainer(
        overrides: [accountProvider.overrideWith(() => spy)],
      );
      addTearDown(container.dispose);
      final account = container.read(accountProvider.notifier);

      debugAccountStoreBlocked = true;
      await openAccountCabinet(
        account: account,
        status: AccountStatus.locked,
        profileId: 'p1',
        accountProfileId: 'p1',
        fallback: Uri.parse('https://cab.example.com'),
      );
      expect(spy.cabinetCalls, 0);
      expect(spy.unlockCalls, 0);

      // Контроль: вне магазина тот же вызов доходит до аккаунта.
      debugAccountStoreBlocked = false;
      await openAccountCabinet(
        account: account,
        status: AccountStatus.locked,
        profileId: 'p1',
        accountProfileId: 'p1',
        fallback: Uri.parse('https://cab.example.com'),
      );
      expect(spy.unlockCalls, 1);
      expect(spy.cabinetCalls, 1);
    });
  });

  group('нотификатор аккаунта', () {
    test('магазин: ни сети, ни хранилища — методы отказывают или молчат',
        () async {
      debugAccountStoreBlocked = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final account = container.read(accountProvider.notifier);

      // restore / repair / onProfileUpdateFailed — тихий no-op.
      await account.restore();
      expect(await account.repairSubscription(), isFalse);
      await account.onProfileUpdateFailed('p1');
      expect(container.read(accountProvider).status, AccountStatus.unknown);

      // Всё, что дошло бы до шлюза, отказывает до создания контроллера.
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
