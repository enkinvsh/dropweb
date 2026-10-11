import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/views/account/account_sheet.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подмена контроллера: экран аккаунта проверяем по реакции на ответы, без
/// сети, биометрии и защищённого хранилища.
class _FakeAccount extends Account {
  _FakeAccount(this.initial);

  final AccountState initial;
  bool unlockResult = false;
  int unlockCalls = 0;
  int syncCalls = 0;
  int logoutCalls = 0;

  /// Держит выход «в сети», пока тест не отпустит.
  Completer<void>? logoutGate;
  final List<bool> biometricChanges = [];
  SubscriptionSyncResult syncResult = SubscriptionSyncResult.alreadyPresent;
  int removeCalls = 0;

  @override
  AccountState build() => initial;

  @override
  Future<bool> unlock(String reason) async {
    unlockCalls += 1;
    if (unlockResult) {
      state = state.copyWith(status: AccountStatus.ready);
    }
    return unlockResult;
  }

  @override
  Future<bool> enableBiometric(String reason) async {
    biometricChanges.add(true);
    state = state.copyWith(biometricEnabled: true);
    return true;
  }

  @override
  Future<void> disableBiometric() async {
    biometricChanges.add(false);
    state = state.copyWith(biometricEnabled: false);
  }

  @override
  Future<SubscriptionSyncResult> syncSubscription() async {
    syncCalls += 1;
    return syncResult;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await logoutGate?.future;
    state = const AccountState(status: AccountStatus.loggedOut);
  }

  @override
  Future<void> removeFromDevice() async {
    removeCalls += 1;
    state = const AccountState(status: AccountStatus.loggedOut);
  }
}

/// CommonDialog читает размер окна из провайдера, который в тестах не
/// заполняется платформой.
class _TestViewSize extends ViewSize {
  @override
  Size build() => const Size(800, 600);
}

const _email = 'user@example.com';

const _readyState = AccountState(
  status: AccountStatus.ready,
  email: _email,
  biometricAvailable: true,
);

/// Профиль с кабинетом и поддержкой — как у провайдера с `dropweb-cabinet`.
const _cabinetProfile = Profile(
  id: 'test-profile',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {
    'dropweb-cabinet': 'https://cabinet.example.com',
    'support-url': 'https://t.me/example_support',
  },
);

/// Экран открывается отдельным маршрутом, как в приложении: выход и
/// удаление с устройства закрывают его через `Navigator.pop`.
Future<void> _pumpAccountView(
  WidgetTester tester,
  _FakeAccount account, {
  Profile? profile,
  Profile? accountProfile,
  bool loginAvailable = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountProvider.overrideWith(() => account),
        viewSizeProvider.overrideWith(_TestViewSize.new),
        // Настоящие провайдеры профилей тянут конфиг приложения из globalState.
        currentProfileProvider.overrideWith((ref) => profile),
        accountProfileProvider.overrideWith((ref) => accountProfile),
        accountLoginAvailableProvider.overrideWith((ref) => loginAvailable),
      ],
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (_, child) => MessageManager(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: AccountView()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Уведомление MessageManager живёт 1 + 3 с на таймерах; их надо дожечь,
/// иначе тест упадёт на незавершённых таймерах.
Future<void> _flushNotifier(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// «⋯» в шапке: выход и удаление живут только там.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(LiquidMoreMenu));
  await tester.pumpAndSettle();
}

/// «⋯» → «Удалить с устройства» → диалог подтверждения открыт.
Future<void> _openRemoveDialog(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text('Удалить с устройства'));
  await tester.pumpAndSettle();
  expect(find.text('Удалить с устройства?'), findsOneWidget);
  expect(
    find.text(
      'Аккаунт и его подписка исчезнут с устройства. '
      'Войти снова можно по почте.',
    ),
    findsOneWidget,
  );
}

/// Настоящий стеклянный шит через openAccountSheet — для переходов между
/// шитами и самозакрытия.
Future<void> _pumpAccountSheet(
  WidgetTester tester,
  _FakeAccount account, {
  bool loginAvailable = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountProvider.overrideWith(() => account),
        viewSizeProvider.overrideWith(_TestViewSize.new),
        currentProfileProvider.overrideWith((ref) => null),
        accountProfileProvider.overrideWith((ref) => null),
        accountLoginAvailableProvider.overrideWith((ref) => loginAvailable),
      ],
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (_, child) => MessageManager(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openAccountSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('ru'));
  });

  testWidgets('ready: email hero with «⋯», rows, cabinet only with profile',
      (tester) async {
    await _pumpAccountView(
      tester,
      _FakeAccount(_readyState),
      profile: _cabinetProfile,
      accountProfile: _cabinetProfile,
    );

    expect(find.text(accountEmailDisplay(_email)), findsOneWidget);
    expect(find.byType(LiquidMoreMenu), findsOneWidget);
    // Ни заголовка, ни подписей — только почта и строки.
    expect(find.text('Аккаунт'), findsNothing);
    expect(find.text('Вход по отпечатку'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Личный кабинет'), findsOneWidget);
    expect(find.text('Обновить подписку'), findsOneWidget);
    // Выход и удаление с устройства спрятаны в «⋯».
    expect(find.text('Выйти'), findsNothing);
    expect(find.text('Удалить с устройства'), findsNothing);

    await _openMenu(tester);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.text('Удалить с устройства'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsNothing);
  });

  testWidgets('ready: no biometric switch or cabinet when unavailable',
      (tester) async {
    await _pumpAccountView(
      tester,
      _FakeAccount(_readyState.copyWith(biometricAvailable: false)),
    );

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Личный кабинет'), findsNothing);
    expect(find.text('Обновить подписку'), findsOneWidget);
  });

  testWidgets('ready: кабинет только из своего профиля аккаунта',
      (tester) async {
    // Текущий профиль чужого провайдера с кабинетом, у своего кабинета нет:
    // строки нет — токен аккаунта не должен уйти в чужой кабинет.
    await _pumpAccountView(
      tester,
      _FakeAccount(_readyState),
      profile: _cabinetProfile,
      accountProfile: const Profile(
        id: 'own',
        autoUpdateDuration: Duration(hours: 12),
      ),
    );
    expect(find.text('Личный кабинет'), findsNothing);
    expect(find.text('Обновить подписку'), findsOneWidget);
  });

  testWidgets('loggedOut: «Войти по почте» только когда вход доступен',
      (tester) async {
    await _pumpAccountView(
      tester,
      _FakeAccount(const AccountState(status: AccountStatus.loggedOut)),
    );
    expect(find.text('Войти по почте'), findsOneWidget);
  });

  testWidgets('loggedOut: вход недоступен — строки входа нет', (tester) async {
    await _pumpAccountView(
      tester,
      _FakeAccount(const AccountState(status: AccountStatus.loggedOut)),
      loginAvailable: false,
    );
    expect(find.text('Войти по почте'), findsNothing);
  });

  testWidgets('biometric switch and its row both toggle', (tester) async {
    final account = _FakeAccount(_readyState);
    await _pumpAccountView(tester, account);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(account.biometricChanges, [true]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Как у строки полного туннеля: тап по строке переключает Switch.
    await tester.tap(find.text('Вход по отпечатку'));
    await tester.pumpAndSettle();
    expect(account.biometricChanges, [true, false]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('update subscription notifies the sync result', (tester) async {
    final account = _FakeAccount(_readyState);
    await _pumpAccountView(tester, account);

    await tester.tap(find.text('Обновить подписку'));
    await tester.pump();
    await tester.pump();

    expect(account.syncCalls, 1);
    expect(find.text('Подписка уже в приложении'), findsOneWidget);
    await _flushNotifier(tester);
  });

  testWidgets('logout from «⋯» needs no confirmation and closes the sheet',
      (tester) async {
    final account = _FakeAccount(_readyState)..logoutGate = Completer<void>();
    await _pumpAccountView(tester, account);

    await _openMenu(tester);
    await tester.tap(find.text('Выйти'));
    await tester.pump();

    // Пока идёт выход, шит открыт: спиннер на месте «⋯», тоста ещё нет.
    expect(account.logoutCalls, 1);
    expect(find.byType(LiquidUpdatingIndicator), findsOneWidget);
    expect(find.text('Вы вышли'), findsNothing);
    expect(find.byType(AccountView), findsOneWidget);

    account.logoutGate!.complete();
    await tester.pump();
    await tester.pump();

    // Сессия стёрта, но уезжающий шит не показывает экран «не вошли».
    expect(find.text('Войти по почте'), findsNothing);
    expect(find.text('Вы вышли'), findsOneWidget);
    await _flushNotifier(tester);
    expect(find.byType(AccountView), findsNothing);
  });

  testWidgets('locked: asks for the fingerprint at once, keeps fallbacks',
      (tester) async {
    final account = _FakeAccount(
      const AccountState(
        status: AccountStatus.locked,
        email: _email,
        biometricEnabled: true,
        biometricAvailable: true,
      ),
    );
    await _pumpAccountView(tester, account);

    // Системный диалог закрыли — остаётся экран замка с запасными путями.
    expect(account.unlockCalls, 1);
    expect(find.text(accountEmailDisplay(_email)), findsOneWidget);
    expect(find.byType(LiquidMoreMenu), findsNothing);
    expect(find.text('Разблокировать'), findsOneWidget);
    expect(find.text('Войти по коду'), findsOneWidget);
    expect(find.text('Обновить подписку'), findsNothing);

    account.unlockResult = true;
    await tester.tap(find.text('Разблокировать'));
    await tester.pumpAndSettle();

    expect(account.unlockCalls, 2);
    expect(find.text('Обновить подписку'), findsOneWidget);
    expect(find.byType(LiquidMoreMenu), findsOneWidget);
  });

  testWidgets('locked without login backend: no «Войти по коду» dead end',
      (tester) async {
    final account = _FakeAccount(
      const AccountState(
        status: AccountStatus.locked,
        email: _email,
        biometricEnabled: true,
        biometricAvailable: true,
      ),
    );
    // Профиль без dropweb-account: код запросить негде, строка вела к ошибке.
    await _pumpAccountView(tester, account, loginAvailable: false);

    expect(find.text('Разблокировать'), findsOneWidget);
    expect(find.text('Войти по коду'), findsNothing);
  });

  testWidgets('locked: «Войти по коду» opens the login sheet prefilled',
      (tester) async {
    final account = _FakeAccount(
      const AccountState(
        status: AccountStatus.locked,
        email: _email,
        biometricEnabled: true,
        biometricAvailable: true,
      ),
    );
    await _pumpAccountView(tester, account);

    await tester.tap(find.text('Войти по коду'));
    await tester.pumpAndSettle();

    // Шит аккаунта уходит: два стеклянных шита стопкой выглядят как сбой.
    expect(find.byType(AccountView), findsNothing);
    expect(find.byType(AccountLoginView), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      _email,
    );
  });

  testWidgets('unknown status shows a loader instead of rows', (tester) async {
    final account = _FakeAccount(const AccountState());
    await _pumpAccountViewWithoutSettle(tester, account);

    expect(find.byType(LiquidUpdatingIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LiquidMoreMenu), findsNothing);
    expect(find.text('Обновить подписку'), findsNothing);
    expect(account.unlockCalls, 0);
  });

  testWidgets('remove from device: confirm removes, toasts, closes the sheet',
      (tester) async {
    final account = _FakeAccount(_readyState);
    await _pumpAccountView(tester, account);

    await _openRemoveDialog(tester);
    await tester.tap(find.text('Удалить'));
    await tester.pump();
    await tester.pump();

    expect(account.removeCalls, 1);
    expect(find.text('Удалено с устройства'), findsOneWidget);
    await _flushNotifier(tester);
    expect(find.byType(AccountView), findsNothing);
  });

  testWidgets('remove from device: «Отмена» keeps everything', (tester) async {
    final account = _FakeAccount(_readyState);
    await _pumpAccountView(tester, account);

    await _openRemoveDialog(tester);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(account.removeCalls, 0);
    expect(find.byType(AccountView), findsOneWidget);
    expect(find.text('Обновить подписку'), findsOneWidget);
  });

  testWidgets('locked → «Войти по коду»: never two sheets at once',
      (tester) async {
    final account = _FakeAccount(
      const AccountState(
        status: AccountStatus.locked,
        email: _email,
        biometricEnabled: true,
        biometricAvailable: true,
      ),
    );
    await _pumpAccountSheet(tester, account);
    expect(find.byType(AccountView), findsOneWidget);

    await tester.tap(find.text('Войти по коду'));
    var sawLogin = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final both = find.byType(AccountView).evaluate().isNotEmpty &&
          find.byType(AccountLoginView).evaluate().isNotEmpty;
      expect(both, isFalse, reason: 'кадр ${i * 50} мс');
      sawLogin |= find.byType(AccountLoginView).evaluate().isNotEmpty;
    }
    await tester.pumpAndSettle();
    expect(sawLogin, isTrue);
    expect(find.byType(AccountLoginView), findsOneWidget);
  });

  testWidgets('loggedOut without login closes the empty sheet', (tester) async {
    await _pumpAccountSheet(
      tester,
      _FakeAccount(const AccountState(status: AccountStatus.loggedOut)),
      loginAvailable: false,
    );
    expect(find.byType(AccountView), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('locked without email shows «Аккаунт» in the header',
      (tester) async {
    await _pumpAccountView(
      tester,
      _FakeAccount(const AccountState(status: AccountStatus.locked)),
    );
    expect(find.text('Аккаунт'), findsOneWidget);
  });

  testWidgets('remove confirmation: only «Удалить» is error-colored',
      (tester) async {
    await _pumpAccountView(tester, _FakeAccount(_readyState));
    await _openRemoveDialog(tester);

    TextButton button(String text) => tester.widget<TextButton>(
          find.ancestor(of: find.text(text), matching: find.byType(TextButton)),
        );
    final error =
        Theme.of(tester.element(find.text('Удалить'))).colorScheme.error;
    expect(
      button('Удалить').style?.foregroundColor?.resolve(<WidgetState>{}),
      error,
    );
    expect(button('Отмена').style, isNull);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });
}

/// Для `unknown` крутится бесконечный индикатор: pumpAndSettle не дождётся
/// конца анимации, поэтому кадры прокручиваем вручную.
Future<void> _pumpAccountViewWithoutSettle(
  WidgetTester tester,
  _FakeAccount account,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountProvider.overrideWith(() => account),
        viewSizeProvider.overrideWith(_TestViewSize.new),
        currentProfileProvider.overrideWith((ref) => null),
        accountProfileProvider.overrideWith((ref) => null),
        accountLoginAvailableProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const Scaffold(body: AccountView()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
