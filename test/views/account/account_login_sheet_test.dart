import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подмена контроллера аккаунта: сеть, PoW и защищённое хранилище форме не
/// нужны — проверяем только её реакцию на ответы.
class _FakeAccount extends Account {
  _FakeAccount({
    this.initial = const AccountState(status: AccountStatus.loggedOut),
  });

  final AccountState initial;
  final List<String> requestedEmails = [];
  final List<String> submittedCodes = [];
  CodeRequestResult codeResult =
      const CodeRequestResult(resendAfter: 60, expiresIn: 600);
  SubscriptionSyncResult verifyResult = SubscriptionSyncResult.imported;
  AccountApiException? verifyError;

  /// Ответ сервера на запрос кода вместо результата (429 и т. п.).
  AccountApiException? requestError;
  int enableBiometricCalls = 0;

  /// Держит requestCode незавершённым, пока тест его не отпустит: так видно
  /// форму посреди PoW.
  Completer<void>? requestGate;

  /// Как настоящий импорт: addProfileFormURL снимает все маршруты до корня
  /// ещё до того, как verifyCode вернёт результат.
  bool popToRootDuringVerify = false;

  @override
  AccountState build() => initial;

  @override
  Future<CodeRequestResult> requestCode(String email) async {
    requestedEmails.add(email);
    final gate = requestGate;
    if (gate != null) {
      await gate.future;
    }
    final error = requestError;
    if (error != null) {
      throw error;
    }
    return codeResult;
  }

  @override
  Future<SubscriptionSyncResult> verifyCode(String email, String code) async {
    submittedCodes.add(code);
    final error = verifyError;
    if (error != null) {
      throw error;
    }
    state = state.copyWith(status: AccountStatus.ready, email: email);
    if (popToRootDuringVerify) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      // Импорт идёт секунды — дольше анимации закрытия: к возврату форма уже
      // размонтирована, как на устройстве.
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return verifyResult;
  }

  @override
  Future<bool> enableBiometric(String reason) async {
    enableBiometricCalls += 1;
    return true;
  }
}

/// CommonDialog читает размер окна из провайдера, который в тестах не
/// заполняется платформой.
class _TestViewSize extends ViewSize {
  @override
  Size build() => const Size(800, 600);
}

const _email = 'user@example.com';

/// Форма открывается отдельным маршрутом, как в приложении: успешный вход
/// закрывает её через `Navigator.pop`.
Future<_FakeAccount> _pumpLoginView(
  WidgetTester tester, {
  _FakeAccount? account,
  String? initialEmail,
}) async {
  final fake = account ?? _FakeAccount();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountProvider.overrideWith(() => fake),
        viewSizeProvider.overrideWith(_TestViewSize.new),
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
                    builder: (_) => Scaffold(
                      body: AccountLoginView(initialEmail: initialEmail),
                    ),
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
  return fake;
}

/// Круглая кнопка отправки справа в строке почты.
Finder get _sendButton => find.byType(LiquidCircleButton);

/// Явные кадры вместо pumpAndSettle: так часы обратного отсчёта сдвигаются
/// предсказуемо — на полсекунды, меньше первого тика таймера.
Future<void> _submitEmail(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _email);
  // Кнопка оживает только после перерисовки с валидным адресом.
  await tester.pump();
  await tester.tap(_sendButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// Уведомление MessageManager живёт 1 + 3 с на таймерах; их надо дожечь,
/// иначе тест упадёт на незавершённых таймерах.
Future<void> _flushNotifier(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('ru'));
  });

  testWidgets('email → code → success closes the form and reports import',
      (tester) async {
    final fake = await _pumpLoginView(tester);
    // Одна строка ввода с подсказкой «Почта» — без заголовков и пояснений.
    expect(find.text('Почта'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await _submitEmail(tester);
    expect(fake.requestedEmails, [_email]);
    // Под строкой кода — адрес и отсчёт до повторной отправки.
    expect(find.text(accountEmailDisplay(_email)), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);

    // Шестая цифра отправляет код без нажатия «Войти».
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(fake.submittedCodes, ['123456']);
    expect(find.byType(AccountLoginView), findsNothing);
    expect(find.text('Подписка подключена'), findsOneWidget);
    // Отпечаток недоступен — предложения включить его быть не должно.
    expect(find.text('Входить по отпечатку?'), findsNothing);

    await _flushNotifier(tester);
  });

  testWidgets('offers biometric sign-in once after login when available',
      (tester) async {
    final fake = await _pumpLoginView(
      tester,
      account: _FakeAccount(
        initial: const AccountState(
          status: AccountStatus.loggedOut,
          biometricAvailable: true,
        ),
      )..verifyResult = SubscriptionSyncResult.noSubscription,
    );

    await _submitEmail(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.text('Вы вошли, подписки пока нет'), findsOneWidget);
    expect(find.text('Входить по отпечатку?'), findsOneWidget);
    // Обычный диалог: подтверждение в цвете темы, красным только удаление.
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Включить'))
          .style,
      isNull,
    );

    await tester.tap(find.text('Включить'));
    await tester.pumpAndSettle();

    expect(fake.enableBiometricCalls, 1);
    expect(find.text('Входить по отпечатку?'), findsNothing);

    await _flushNotifier(tester);
  });

  testWidgets(
      'import closing the form mid-login still reports and offers biometric',
      (tester) async {
    final fake = await _pumpLoginView(
      tester,
      account: _FakeAccount(
        initial: const AccountState(
          status: AccountStatus.loggedOut,
          biometricAvailable: true,
        ),
      )..popToRootDuringVerify = true,
    );

    await _submitEmail(tester);
    await tester.enterText(find.byType(TextField), '123456');
    // Отдельные кадры: анимация закрытия должна доиграть и размонтировать
    // форму раньше, чем «импорт» вернёт результат.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(AccountLoginView), findsNothing);
    expect(find.text('Подписка подключена'), findsOneWidget);
    expect(find.text('Входить по отпечатку?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(fake.enableBiometricCalls, 0);
    // Форма не должна была закрыть чужой маршрут: корень остался на месте.
    expect(find.text('open'), findsOneWidget);

    await _flushNotifier(tester);
  });

  testWidgets('invalid email is rejected inline without a request',
      (tester) async {
    final fake = await _pumpLoginView(tester);

    await tester.enterText(find.byType(TextField), 'user@example');
    await tester.pump();
    // Кнопка неактивна, пока адрес не похож на почту.
    await tester.tap(_sendButton);
    await tester.pump();
    expect(find.text('Проверьте адрес почты'), findsNothing);

    // Отправка с клавиатуры объясняет, что не так, одной строкой.
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();

    expect(find.text('Проверьте адрес почты'), findsOneWidget);
    // Фокус остаётся в поле: клавиатура не прячется, адрес правят сразу.
    expect(tester.testTextInput.isVisible, isTrue);
    expect(fake.requestedEmails, isEmpty);
  });

  testWidgets('keyboard stays up while the code is being requested',
      (tester) async {
    final fake = await _pumpLoginView(tester);
    final gate = Completer<void>();
    fake.requestGate = gate;

    await tester.enterText(find.byType(TextField), _email);
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pump();

    // Пока идёт PoW, вместо кнопки спиннер, а клавиатура на месте: иначе
    // шторка падает вниз и взлетает обратно со вторым шагом.
    expect(find.byType(LiquidUpdatingIndicator), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text(accountEmailDisplay(_email)), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('keyboard go action sends the code', (tester) async {
    final fake = await _pumpLoginView(tester);

    await tester.enterText(find.byType(TextField), _email);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fake.requestedEmails, [_email]);
  });

  testWidgets('tapping the address on the code step goes back to the email',
      (tester) async {
    final fake = await _pumpLoginView(tester);

    await _submitEmail(tester);
    await tester.tap(find.text(accountEmailDisplay(_email)));
    await tester.pumpAndSettle();

    // Снова первый шаг с тем же адресом; новый код без нажатия не уходит.
    expect(_sendButton, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      _email,
    );
    expect(fake.requestedEmails, [_email]);
  });

  testWidgets('prefilled email is kept for the locked-account re-login',
      (tester) async {
    await _pumpLoginView(tester, initialEmail: _email);

    expect(find.text(_email), findsOneWidget);
  });

  testWidgets('code step takes focus so the keyboard opens by itself',
      (tester) async {
    await _pumpLoginView(tester);

    await _submitEmail(tester);

    // Поле почты держит фокус до конца смены шагов, поэтому одного
    // autofocus у поля кода мало — фокус должен перейти явно.
    final codeField = tester.widget<EditableText>(find.byType(EditableText));
    expect(codeField.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('invalid code shows the inline error and keeps the form',
      (tester) async {
    final fake = await _pumpLoginView(tester)
      ..verifyError = const AccountApiException(
        AccountApiErrorKind.invalidCode,
        statusCode: 400,
      );

    await _submitEmail(tester);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(fake.submittedCodes, ['000000']);
    expect(find.text('Неверный код'), findsOneWidget);
    expect(find.byType(AccountLoginView), findsOneWidget);
  });

  testWidgets('resend waits for the countdown, then sends again',
      (tester) async {
    final fake = await _pumpLoginView(tester)
      ..codeResult = const CodeRequestResult(resendAfter: 3, expiresIn: 600);

    await _submitEmail(tester);
    // Пока идёт отсчёт, повторной отправки нет — только таймер.
    expect(find.text('0:03'), findsOneWidget);
    expect(find.text('Отправить ещё раз'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:02'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Отправить ещё раз'), findsOneWidget);

    await tester.tap(find.text('Отправить ещё раз'));
    await tester.pump();

    expect(fake.requestedEmails, [_email, _email]);
    expect(find.text('0:03'), findsOneWidget);
  });

  testWidgets('wait of an hour and more is shown in hours, not as a timer',
      (tester) async {
    await _pumpLoginView(
      tester,
      account: _FakeAccount()
        ..codeResult =
            const CodeRequestResult(resendAfter: 86400, expiresIn: 600),
    );

    await _submitEmail(tester);

    expect(find.text('24\u00A0ч'), findsOneWidget);
    expect(find.text('1440:00'), findsNothing);
  });

  testWidgets('step 1: 429 blocks sending and counts down live',
      (tester) async {
    final fake = await _pumpLoginView(tester)
      ..requestError = const AccountApiException(
        AccountApiErrorKind.rateLimited,
        statusCode: 429,
        retryAfter: 3,
      );

    await _submitEmail(tester);
    expect(find.text('Слишком часто, подождите 3\u00A0с'), findsOneWidget);

    // Пока блок, ни кнопка, ни «→» с клавиатуры запрос не шлют.
    fake.requestError = null;
    await tester.tap(_sendButton);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    expect(fake.requestedEmails, [_email]);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Слишком часто, подождите 2\u00A0с'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Слишком часто'), findsNothing);

    await tester.tap(_sendButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.requestedEmails, [_email, _email]);
  });

  testWidgets('429 without Retry-After on verify blocks for 60 s',
      (tester) async {
    final fake = await _pumpLoginView(tester)
      ..codeResult = const CodeRequestResult(resendAfter: 0, expiresIn: 600);

    await _submitEmail(tester);
    fake.verifyError = const AccountApiException(
      AccountApiErrorKind.rateLimited,
      statusCode: 429,
    );
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.pump();
    expect(find.text('Слишком часто, подождите 1\u00A0мин'), findsOneWidget);

    // Сервер только что запретил: ни повторной отправки, ни новой проверки.
    await tester.tap(find.text('Отправить ещё раз'));
    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    expect(fake.requestedEmails, [_email]);
    expect(fake.submittedCodes, ['000000']);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Слишком часто, подождите 59\u00A0с'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.textContaining('Слишком часто'), findsNothing);

    await tester.tap(find.text('Отправить ещё раз'));
    await tester.pump();
    expect(fake.requestedEmails, [_email, _email]);
  });

  testWidgets('resend 429 keeps «Отправить ещё раз» disabled until it ends',
      (tester) async {
    final fake = await _pumpLoginView(tester)
      ..codeResult = const CodeRequestResult(resendAfter: 0, expiresIn: 600);

    await _submitEmail(tester);
    fake.requestError = const AccountApiException(
      AccountApiErrorKind.rateLimited,
      statusCode: 429,
      retryAfter: 5,
    );
    await tester.tap(find.text('Отправить ещё раз'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Слишком часто, подождите 5\u00A0с'), findsOneWidget);

    fake.requestError = null;
    await tester.tap(find.text('Отправить ещё раз'));
    await tester.pump();
    expect(fake.requestedEmails, [_email, _email]);

    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Слишком часто'), findsNothing);
    await tester.tap(find.text('Отправить ещё раз'));
    await tester.pump();
    expect(fake.requestedEmails, [_email, _email, _email]);
  });

  testWidgets('expired code makes «Отправить ещё раз» available at once',
      (tester) async {
    final fake = await _pumpLoginView(tester);

    await _submitEmail(tester);
    expect(find.text('1:00'), findsOneWidget);
    fake.verifyError = const AccountApiException(
      AccountApiErrorKind.codeExpiredOrLocked,
      statusCode: 400,
    );
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.pump();

    expect(find.text('Код истёк — запросите новый'), findsOneWidget);
    expect(find.text('Отправить ещё раз'), findsOneWidget);
    expect(find.text('1:00'), findsNothing);
  });

  testWidgets('code hint does not inherit the code letter spacing',
      (tester) async {
    await _pumpLoginView(tester);

    await _submitEmail(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.letterSpacing, 4);
    final hintSpacing = field.decoration?.hintStyle?.letterSpacing;
    expect(hintSpacing, isNotNull);
    expect(hintSpacing, isNot(4));
  });

  testWidgets('email input is capped at 254 chars; IDN and plus-tags pass',
      (tester) async {
    await _pumpLoginView(tester);

    await tester.enterText(
      find.byType(TextField),
      '${'a' * 300}@example.com',
    );
    await tester.pump();
    final controller =
        tester.widget<EditableText>(find.byType(EditableText)).controller;
    expect(controller.text.length, 254);

    for (final bad in ['a@@b.co', 'a b@c.co', '@b.co', 'a@b', 'a@b c.co']) {
      await tester.enterText(find.byType(TextField), bad);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();
      expect(find.text('Проверьте адрес почты'), findsOneWidget, reason: bad);
    }
    for (final good in [
      'пользователь@пример.рф',
      'first.last+billing@example.com',
    ]) {
      await tester.enterText(find.byType(TextField), good);
      await tester.pump();
      expect(find.text('Проверьте адрес почты'), findsNothing, reason: good);
      final send = tester.widget<LiquidCircleButton>(_sendButton);
      expect(send.onTap, isNotNull, reason: good);
    }
  });

  group('accountWaitText', () {
    test('seconds, then minutes and hours rounded up, with NBSP', () {
      expect(accountWaitText(30), '30\u00A0с');
      expect(accountWaitText(59), '59\u00A0с');
      expect(accountWaitText(60), '1\u00A0мин');
      expect(accountWaitText(61), '2\u00A0мин');
      expect(accountWaitText(3600), '1\u00A0ч');
      expect(accountWaitText(3601), '2\u00A0ч');
      expect(accountWaitText(86400), '24\u00A0ч');
    });
  });

  group('accountEmailDisplay', () {
    test('breaks only after @ and keeps the address otherwise intact', () {
      expect(accountEmailDisplay('a@b.co'), 'a@\u200Bb.co');
      expect(accountEmailDisplay('no-at'), 'no-at');
    });
  });

  group('accountErrorText', () {
    test('maps error kinds to localized inline messages', () {
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.invalidCode),
        ),
        'Неверный код',
      );
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.codeExpiredOrLocked),
        ),
        'Код истёк — запросите новый',
      );
      expect(
        accountErrorText(
          const AccountApiException(
            AccountApiErrorKind.rateLimited,
            retryAfter: 42,
          ),
        ),
        'Слишком часто, подождите 42\u00A0с',
      );
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.emailRejected),
        ),
        'Почта не подходит',
      );
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.network),
        ),
        'Нет связи с сервером',
      );
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.disabled),
        ),
        'Вход временно недоступен',
      );
      // 503 (почта не уходит, техработы) — для человека то же, что выключенный
      // вход: подождать, а не гадать над «Не получилось».
      expect(
        accountErrorText(
          const AccountApiException(AccountApiErrorKind.unavailable),
        ),
        'Вход временно недоступен',
      );
      expect(
        accountErrorText(const AccountApiException(AccountApiErrorKind.server)),
        'Не получилось',
      );
      expect(
        accountErrorText(StateError('boom')),
        'Не получилось',
      );
    });
  });
}
