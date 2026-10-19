import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// Базовая проверка `x@y.z`: ровно одна «@», без пробелов, в домене есть
/// точка. Кириллические домены и `+теги` проходят; остальное решает бэкенд
/// (emailRejected).
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Предел длины адреса по RFC 5321: длиннее сервер всё равно отвергнет.
const _emailMaxLength = 254;

/// Вход по почте — стеклянный шит как «Подписка». [email] подставляется,
/// когда вход повторяют из заблокированного аккаунта. [origin] — откуда шит
/// вырастает (панель меню); без него выезжает снизу.
Future<void> openAccountLoginSheet(
  BuildContext context, {
  String? email,
  GlassMorphOrigin? origin,
}) =>
    showLiquidSheet<void>(
      context,
      builder: (_) => AccountLoginView(initialEmail: email),
      halfSize: _loginSheetHeight(context),
      origin: origin,
    );

/// Стартовая высота — первый шаг: одна строка ввода (круг 40 + паддинги 12).
/// Дальше шит сам подстраивается под шаг и строку ошибки.
double _loginSheetHeight(BuildContext context) {
  final row = math.max(
    64.0,
    24 + liquidLineHeight(context, context.textTheme.bodyLarge),
  );
  return kLiquidSheetTopInset +
      row +
      kLiquidSheetBottomInset +
      MediaQuery.paddingOf(context).bottom +
      kLiquidSheetBottomMargin;
}

enum _LoginStep { email, code }

/// Два шага: почта → код из письма. Аккаунт создаётся на бэкенде при первом
/// входе, отдельной регистрации нет.
class AccountLoginView extends ConsumerStatefulWidget {
  const AccountLoginView({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<AccountLoginView> createState() => _AccountLoginViewState();
}

class _AccountLoginViewState extends ConsumerState<AccountLoginView> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  _LoginStep _step = _LoginStep.email;

  /// Адрес, на который реально ушёл код: поле почты могут поправить, пока
  /// открыт второй шаг.
  String _sentTo = '';
  bool _busy = false;
  bool _resending = false;
  String? _emailError;
  String? _codeError;
  int _resendLeft = 0;

  /// Сколько ещё молчать после 429. Блок общий для отправки, повторной
  /// отправки и проверки кода: сервер считает их одним лимитом.
  int _blockedLeft = 0;
  Timer? _ticker;

  bool get _codeComplete => _codeController.text.length == accountCodeLength;

  bool get _emailValid => _emailPattern.hasMatch(_emailController.text.trim());

  bool get _blocked => _blockedLeft > 0;

  /// Пока идёт блок, строка ошибки сама показывает остаток ожидания.
  String? _withBlock(String? error) => _blocked
      ? appLocalizations.accountErrorRateLimited(accountWaitText(_blockedLeft))
      : error;

  @override
  void dispose() {
    _ticker?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy || _blocked) {
      return;
    }
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _emailError = appLocalizations.accountEmailInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _emailError = null;
    });
    try {
      final result =
          await ref.read(accountProvider.notifier).requestCode(email);
      if (!mounted) {
        return;
      }
      _codeController.clear();
      setState(() {
        _busy = false;
        _sentTo = email;
        _codeError = null;
        _step = _LoginStep.code;
      });
      // autofocus поля кода не срабатывает: пока AnimatedSwitcher держит
      // старый шаг, фокус остаётся у поля почты, и клавиатура не открывалась
      // (видно на Pixel). Переводим фокус явно.
      _codeFocus.requestFocus();
      _startResendCountdown(result.resendAfter);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _emailError = _blockOn(error) ? null : accountErrorText(error);
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_busy || _blocked) {
      return;
    }
    if (!_codeComplete) {
      setState(() => _codeError = appLocalizations.accountErrorInvalidCode);
      return;
    }
    final account = ref.read(accountProvider.notifier);
    // Импорт профиля закрывает все шторки до корня (addProfileFormURL →
    // popUntil), поэтому к концу verifyCode форма обычно уже снята и её ref
    // мёртв. Итог входа всё равно надо показать — читаем через контейнер.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final result = await account.verifyCode(_sentTo, _codeController.text);
      _finish(container, account, accountSyncResultText(result));
    } catch (error) {
      // verifyCode сохраняет сессию раньше, чем подключает подписку: статус
      // ready значит, что вход состоялся и сорвался только импорт профиля.
      if (container.read(accountProvider).status == AccountStatus.ready) {
        _finish(container, account, appLocalizations.accountSyncFailed);
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _codeError = _blockOn(error) ? null : accountErrorText(error);
        // Истёкший код ждать бессмысленно: новый можно просить сразу, а если
        // сервер ещё держит лимит, ответит 429 и включится блок.
        if (error is AccountApiException &&
            error.kind == AccountApiErrorKind.codeExpiredOrLocked) {
          _resendLeft = 0;
        }
      });
    }
  }

  void _finish(ProviderContainer container, Account account, String message) {
    final state = container.read(accountProvider);
    final offerBiometric = state.biometricAvailable && !state.biometricEnabled;
    // Закрываем только свою шторку и только если она ещё сверху: снятый
    // импортом маршрут мог оставить наверху корень, и pop() закрыл бы его.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
    globalState.showNotifier(message);
    if (offerBiometric) {
      unawaited(offerAccountBiometric(account));
    }
  }

  Future<void> _resendCode() async {
    if (_busy || _resending || _resendLeft > 0 || _blocked) {
      return;
    }
    setState(() {
      _resending = true;
      _codeError = null;
    });
    try {
      final result =
          await ref.read(accountProvider.notifier).requestCode(_sentTo);
      if (!mounted) {
        return;
      }
      _codeController.clear();
      setState(() => _resending = false);
      _startResendCountdown(result.resendAfter);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resending = false;
        _codeError = _blockOn(error) ? null : accountErrorText(error);
      });
    }
  }

  /// На 429 запоминает срок блока (сервера или запасную минуту) и запускает
  /// отсчёт. Вызывается внутри setState.
  bool _blockOn(Object error) {
    if (!isAccountRateLimited(error)) {
      return false;
    }
    _blockedLeft = accountRateLimitSeconds(error);
    _restartTicker();
    return true;
  }

  void _startResendCountdown(int seconds) {
    setState(() => _resendLeft = seconds > 0 ? seconds : 0);
    _restartTicker();
  }

  /// Один тикер на оба отсчёта. Тики по секунде, а не дедлайн по часам:
  /// так время управляемо из тестов через `tester.pump`.
  void _restartTicker() {
    _ticker?.cancel();
    if (_resendLeft <= 0 && _blockedLeft <= 0) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendLeft > 0) _resendLeft -= 1;
        if (_blockedLeft > 0) _blockedLeft -= 1;
      });
      if (_resendLeft <= 0 && _blockedLeft <= 0) {
        timer.cancel();
      }
    });
  }

  void _changeEmail() {
    setState(() {
      _step = _LoginStep.email;
      _codeError = null;
      _resendLeft = 0;
    });
  }

  void _onCodeChanged(String value) {
    setState(() => _codeError = null);
    if (value.length == accountCodeLength) {
      unawaited(_verifyCode());
    }
  }

  @override
  Widget build(BuildContext context) => LiquidSheetBody(
        children: [
          AnimatedSwitcher(
            duration: Lumina.luminaDuration,
            switchInCurve: Lumina.luminaCurve,
            switchOutCurve: Lumina.luminaCurve,
            // Шаги разной высоты: прижимаем к верху, иначе короткий шаг
            // уезжает в середину на время перехода.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: switch (_step) {
              _LoginStep.email => _buildEmailStep(context),
              _LoginStep.code => _buildCodeStep(context),
            },
          ),
        ],
      );

  Widget _buildEmailStep(BuildContext context) {
    final colorScheme = context.colorScheme;
    final emailError = _withBlock(_emailError);
    final canSend = _emailValid && !_blocked;
    return Column(
      key: const ValueKey(_LoginStep.email),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidCard(
          flat: true,
          child: LiquidTile(
            icon: HugeIcons.strokeRoundedMail01,
            title: TextField(
              controller: _emailController,
              // С подставленной почтой клавиатура не нужна: обычно её просто
              // отправляют.
              autofocus: (widget.initialEmail ?? '').isEmpty,
              // Без readOnly на время PoW: readOnly прячет клавиатуру, и
              // шторка падает вниз, чтобы через секунду взлететь со вторым
              // шагом. Код уходит на адрес, снятый в момент отправки.
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.go,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_emailMaxLength),
              ],
              style: context.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: accountInputDecoration(
                context,
                hint: appLocalizations.accountEmailLabel,
              ),
              // Перерисовка нужна и без ошибки: от адреса зависит вид кнопки.
              onChanged: (_) => setState(() => _emailError = null),
              // Пустой onEditingComplete оставляет фокус после «→»: иначе
              // Flutter его снимает, клавиатура прячется, и ошибку под полем
              // правят лишним тапом.
              onEditingComplete: () {},
              onSubmitted: (_) => _requestCode(),
            ),
            // PoW перед запросом идёт до пары секунд — спиннер встаёт на
            // место кнопки, не сдвигая строку.
            trailing: _busy
                ? const LiquidUpdatingIndicator()
                : LiquidCircleButton(
                    onTap: canSend ? _requestCode : null,
                    semanticLabel: appLocalizations.accountGetCode,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight02,
                      size: 20,
                      color: canSend
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.opacity38,
                    ),
                  ),
          ),
        ),
        if (emailError != null) AccountFieldError(emailError),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    final colorScheme = context.colorScheme;
    final codeError = _withBlock(_codeError);
    return Column(
      key: const ValueKey(_LoginStep.code),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountCodeCard(
          controller: _codeController,
          focusNode: _codeFocus,
          busy: _busy,
          onChanged: _onCodeChanged,
          onSubmitted: (_) => _verifyCode(),
        ),
        if (codeError != null) AccountFieldError(codeError),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          // Влезают в строку — почта слева, повтор справа. Не влезают на
          // узком экране с крупным шрифтом — повтор уходит под почту, а не
          // сжимает её до «а…».
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.start,
            overflowSpacing: 4,
            children: [
              AccountFooterAction(
                onTap: _busy ? null : _changeEmail,
                semanticLabel: appLocalizations.accountChangeEmail,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        accountEmailDisplay(_sentTo),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPencilEdit01,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              _buildResend(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResend(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = context.textTheme.bodySmall;
    if (_resending) {
      return const AccountFooterAction(child: AccountInlineSpinner());
    }
    final left = _resendLeft;
    if (left > 0) {
      return AccountFooterAction(
        child: Text(
          // Таймер «1439:59» не читается: от часа показываем часы.
          left < 3600
              ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}'
              : accountWaitText(left),
          style: style?.copyWith(
            color: colorScheme.onSurfaceVariant,
            // Цифры одной ширины: иначе отсчёт дрожит у правого края.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    // Под 429 кнопка видна, но выключена: срок ожидания уже в строке ошибки.
    final enabled = !_busy && !_blocked;
    return AccountFooterAction(
      onTap: enabled ? _resendCode : null,
      child: Text(
        appLocalizations.accountResend,
        style: style?.copyWith(
          color:
              _blocked ? colorScheme.onSurface.opacity38 : colorScheme.primary,
        ),
      ),
    );
  }
}
