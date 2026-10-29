import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/account/account_gate.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// Базовая проверка `x@y.z`: ровно одна «@», без пробелов, в домене есть
/// точка. Кириллические домены и `+теги` проходят; остальное решает бэкенд
/// (emailRejected).
final accountEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Предел длины адреса по RFC 5321: длиннее сервер всё равно отвергнет.
const accountEmailMaxLength = 254;

/// Длина кода из письма: бэкенд шлёт ровно 6 цифр, на этой длине форма
/// отправляет код сама.
const accountCodeLength = 6;

/// Текст ошибки аккаунта по её виду, а не по тексту сервера: сообщения
/// бэкенда не переведены на язык приложения.
String accountErrorText(Object error) {
  if (error is! AccountApiException) {
    return appLocalizations.accountErrorGeneric;
  }
  final retryAfter = error.retryAfter;
  return switch (error.kind) {
    AccountApiErrorKind.invalidCode => appLocalizations.accountErrorInvalidCode,
    AccountApiErrorKind.codeExpiredOrLocked =>
      appLocalizations.accountErrorCodeExpired,
    AccountApiErrorKind.rateLimited => retryAfter != null && retryAfter > 0
        ? appLocalizations.accountErrorRateLimited(accountWaitText(retryAfter))
        : appLocalizations.accountErrorRateLimitedLater,
    AccountApiErrorKind.emailRejected =>
      appLocalizations.accountErrorEmailRejected,
    AccountApiErrorKind.network => appLocalizations.accountErrorNetwork,
    // 503 (почта не уходит, техработы) для человека то же, что выключенный
    // вход: подождать, а не гадать над «Не получилось».
    AccountApiErrorKind.disabled ||
    AccountApiErrorKind.unavailable =>
      appLocalizations.accountErrorDisabled,
    _ => appLocalizations.accountErrorGeneric,
  };
}

/// Сколько ждать, когда сервер ограничил запросы, но не сказал срок:
/// ориентир на минуту, чтобы кнопка не оставалась активной под 429.
const accountRateLimitFallback = 60;

/// Секунды блокировки после 429: срок сервера или запасная минута.
int accountRateLimitSeconds(Object error) {
  final retryAfter = error is AccountApiException ? error.retryAfter : null;
  return retryAfter != null && retryAfter > 0
      ? retryAfter
      : accountRateLimitFallback;
}

bool isAccountRateLimited(Object error) =>
    error is AccountApiException &&
    error.kind == AccountApiErrorKind.rateLimited;

/// Ожидание крупной единицей с округлением вверх: сервер может дать сутки,
/// и «86400 с» или «1439:59» ничего не говорят человеку.
String accountWaitText(int seconds) {
  if (seconds < 60) {
    return appLocalizations.accountWaitSeconds(seconds);
  }
  if (seconds < 3600) {
    return appLocalizations.accountWaitMinutes((seconds + 59) ~/ 60);
  }
  return appLocalizations.accountWaitHours((seconds + 3599) ~/ 3600);
}

/// Почта для показа: пробел нулевой ширины после «@» даёт длинному адресу
/// перенестись целиком доменом, а не обрезаться посреди. Только для
/// отображения — в запросы уходит исходная строка.
String accountEmailDisplay(String email) {
  final at = email.indexOf('@');
  if (at < 0) return email;
  return '${email.substring(0, at + 1)}\u200B${email.substring(at + 1)}';
}

/// Значок итога синхронизации: подключили, уже было и «вошли, подписки нет» — вход
/// удался, поэтому все три итога идут как успех.
M3eToastKind accountSyncResultKind(SubscriptionSyncResult result) =>
    M3eToastKind.check;

String accountSyncResultText(SubscriptionSyncResult result) => switch (result) {
      SubscriptionSyncResult.imported =>
        appLocalizations.accountSubscriptionImported,
      SubscriptionSyncResult.alreadyPresent =>
        appLocalizations.accountSubscriptionAlreadyPresent,
      SubscriptionSyncResult.noSubscription =>
        appLocalizations.accountNoSubscription,
    };

/// Предложение входа по отпечатку сразу после входа по коду. Спрашиваем один
/// раз за вход: отказ не повторяем, включить можно на экране аккаунта.
/// [account] берётся до закрытия формы — её ref к этому моменту уже мёртв.
Future<void> offerAccountBiometric(Account account) async {
  // showMessage требует текст: пустой оставил бы дыру между заголовком и
  // кнопками, поэтому одна короткая фраза.
  final accepted = await globalState.showMessage(
    title: appLocalizations.accountBiometricOfferTitle,
    message: TextSpan(text: appLocalizations.accountBiometricOfferText),
    confirmText: appLocalizations.accountBiometricEnable,
  );
  if (accepted != true) {
    return;
  }
  try {
    // false — пользователь закрыл системный диалог; сообщать тут нечего.
    await account.enableBiometric(
      appLocalizations.accountBiometricEnableReason,
    );
  } catch (error) {
    globalState.showNotifier(
      accountErrorText(error),
      kind: M3eToastKind.alert,
    );
  }
}

/// «Войти по почте» в добавлении профиля: только если провайдер объявил
/// бэкенд входа (или это пустое состояние сборки с дефолтом) и сессии ещё
/// нет — при живой, даже заблокированной, сессии повторный вход ничего не даст.
bool accountLoginEntryVisible({
  required bool isAndroid,
  required AccountStatus status,
  required bool loginAvailable,
}) =>
    !accountStoreBlocked &&
    isAndroid &&
    loginAvailable &&
    (status == AccountStatus.loggedOut || status == AccountStatus.unknown);

/// «Аккаунт» в меню: при сессии — всегда, чтобы выход и удаление с устройства
/// оставались доступны и после переключения на профиль без
/// `dropweb-account`; без
/// сессии — только когда вход доступен.
bool accountMenuEntryVisible({
  required bool isAndroid,
  required AccountStatus status,
  required bool loginAvailable,
}) =>
    !accountStoreBlocked &&
    isAndroid &&
    (status == AccountStatus.ready ||
        status == AccountStatus.locked ||
        loginAvailable);

/// Личный кабинет профиля [profileId]. Автовход (одноразовая ссылка
/// `/auto-login`) — только для профиля с подпиской аккаунта
/// ([accountProfileId]): кабинет другого провайдера получает обычную ссылку,
/// как без аккаунта, и отпечаток ради него не спрашиваем. Любой сбой обмена
/// тоже ведёт на обычную ссылку: тап не должен пропадать.
Future<void> openAccountCabinet({
  required Account account,
  required AccountStatus status,
  required String? profileId,
  required String? accountProfileId,
  required Uri fallback,
}) async {
  // В магазинной сборке кабинета нет (решение владельца 2026-10-29).
  if (accountStoreBlocked) return;
  var target = fallback;
  if (profileId != null && profileId == accountProfileId) {
    try {
      switch (status) {
        case AccountStatus.ready:
          target = await account.cabinetUriFor(profileId) ?? fallback;
        case AccountStatus.locked:
          // Отмена отпечатка — не отказ от кабинета: открываем без автологина.
          if (await account.unlock(
            appLocalizations.accountBiometricUnlockReason,
          )) {
            target = await account.cabinetUriFor(profileId) ?? fallback;
          }
        case AccountStatus.unknown:
        case AccountStatus.loggedOut:
          break;
      }
    } catch (error) {
      commonPrint.log('[account] cabinet handoff failed: $error');
    }
  }
  await openCabinetBrowser(target);
}

/// Поле без рамки и плавающей подписи: само поле — строка LiquidTile, а
/// рамку ему даёт карточка.
InputDecoration accountInputDecoration(
  BuildContext context, {
  required String hint,
}) =>
    InputDecoration(
      isCollapsed: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintText: hint,
      hintStyle: context.textTheme.bodyLarge?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );

/// Строка ввода кода из письма для входа; кнопки нет — код уходит сам на
/// 6-й цифре.
class AccountCodeCard extends StatelessWidget {
  const AccountCodeCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => LiquidCard(
        flat: true,
        child: LiquidTile(
          icon: HugeIcons.strokeRoundedLockPassword,
          title: TextField(
            controller: controller,
            focusNode: focusNode,
            // Без readOnly на время проверки: readOnly рвёт связь с
            // клавиатурой, она прячется, шторка падает вниз, а при неверном
            // коде взлетает обратно. Проверяется код, снятый при отправке.
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(accountCodeLength),
            ],
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurface,
              letterSpacing: 4,
            ),
            // Подсказка наследует стиль поля; разрядка цифр кода растягивает
            // её за край узкой строки, поэтому возвращаем ей обычную
            // разрядку темы.
            decoration: accountInputDecoration(
              context,
              hint: appLocalizations.accountCodeLabel,
            ).copyWith(
              hintStyle: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                letterSpacing: context.textTheme.bodyLarge?.letterSpacing ?? 0,
              ),
            ),
            onChanged: onChanged,
            // Пустой onEditingComplete оставляет фокус после «Готово»: иначе
            // Flutter его снимает, и неверный код правится лишним тапом.
            onEditingComplete: () {},
            onSubmitted: onSubmitted,
          ),
          // Место под спиннер держим и без него, чтобы строка не прыгала.
          trailing: busy
              ? const LiquidUpdatingIndicator()
              : const SizedBox.square(dimension: 40),
        ),
      );
}

/// Ошибка под карточкой: одна строка вровень с иконкой строки.
class AccountFieldError extends StatelessWidget {
  const AccountFieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          text,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
}

/// Тихое действие под карточкой кода (почта, повтор, отмена): мелкий текст,
/// но зона нажатия — полные 40 px.
class AccountFooterAction extends StatelessWidget {
  const AccountFooterAction({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Lumina.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(widthFactor: 1, child: child),
            ),
          ),
        ),
      );
}

/// Маленький спиннер для строки списка и действия под карточкой.
class AccountInlineSpinner extends StatelessWidget {
  const AccountInlineSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
