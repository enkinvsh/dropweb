import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/account/account_gate.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// Аккаунт — стеклянный шит из тех же блоков, что и «Подписка». [origin] —
/// откуда он вырастает (панель меню); без него выезжает снизу.
Future<void> openAccountSheet(
  BuildContext context, {
  GlassMorphOrigin? origin,
}) {
  // Магазинная сборка (решение владельца 2026-10-29) аккаунт не открывает.
  // `kIsPlayBuild` — const: в Play остальной код не попадает в AAB; на iOS
  // срабатывает рантайм-проверка.
  if (kIsPlayBuild || accountStoreBlocked) return Future<void>.value();
  return showLiquidSheet<void>(
    context,
    builder: (_) => const AccountView(),
    halfSize: _accountSheetHeight(context),
    origin: origin,
  );
}

/// Стартовая высота под текущий статус — суммой тех же констант, что у
/// контента. Дальше шит подстраивается сам, например после разблокировки.
double _accountSheetHeight(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(accountProvider);
  final hasCabinet =
      profileCabinetUri(container.read(accountProfileProvider)) != null;
  final textTheme = context.textTheme;
  final width = MediaQuery.sizeOf(context).width;
  final bodyLine = liquidLineHeight(context, textTheme.bodyLarge);
  // Подпись строки: поля шита 16+16, паддинги плитки 16+16, иконка 24+12
  // и хвост (шеврон или Switch) с отступом 8. На 320 dp с крупным шрифтом
  // подпись уходит во вторую строку — высоту считаем по числу строк.
  double row(String title, {double trailing = 32, double min = 52}) {
    final titleWidth = width - 100 - trailing;
    return math.max(
      min,
      24 +
          bodyLine *
              _textLines(
                context,
                title,
                _fitLongestWord(
                  context,
                  title,
                  textTheme.bodyLarge,
                  titleWidth,
                ),
                titleWidth,
              ),
    );
  }

  final rows = switch (state.status) {
    AccountStatus.ready => [
        // Строка со Switch: сам Switch 48 + паддинги 24.
        if (state.biometricAvailable)
          row(
            appLocalizations.accountBiometricSwitch,
            trailing: 60,
            min: 72,
          ),
        if (hasCabinet) row(appLocalizations.personalCabinet),
        row(appLocalizations.accountSyncSubscription),
      ],
    AccountStatus.locked => [
        row(appLocalizations.accountUnlock),
        if (container.read(accountLoginAvailableProvider))
          row(appLocalizations.accountSignInWithCode),
      ],
    AccountStatus.loggedOut => [
        if (container.read(accountLoginAvailableProvider))
          row(appLocalizations.accountLoginByEmail),
      ],
    AccountStatus.unknown => <double>[],
  };
  // Hero: паддинги 12 + почта не ниже круга «⋯» (40). Почта, не влезшая
  // одной строкой даже мелким стилем, переносится на вторую.
  final heroText = state.email ?? appLocalizations.account;
  final heroWidth = width - 32 - 16 - 8 - 8 - 40;
  final heroLines =
      _textLines(context, heroText, textTheme.bodyLarge, heroWidth);
  final hero = state.status == AccountStatus.loggedOut
      ? 0.0
      : 24 +
          math.max(
            40.0,
            heroLines > 1
                ? bodyLine * heroLines
                : liquidLineHeight(context, textTheme.titleLarge),
          );
  final card = rows.isEmpty
      ? 0.0
      : (hero > 0 ? 12 : 0) + rows.reduce((a, b) => a + b) + rows.length - 1;
  final content = kLiquidSheetTopInset +
      hero +
      card +
      kLiquidSheetBottomInset +
      MediaQuery.paddingOf(context).bottom;
  return math.min(
    content + kLiquidSheetBottomMargin,
    MediaQuery.sizeOf(context).height * 0.85,
  );
}

final _wordPattern =
    RegExp(r'[\p{Script=Latin}\p{Script=Cyrillic}]+', unicode: true);

/// Стиль, в котором самое длинное слово подписи влезает в строку целиком.
/// На 320 dp ×1.4 «Разблокировать» шире строки, и перенос рвал его на
/// «Разблокироват / ь». CJK не трогаем: там перенос между знаками — норма.
TextStyle? _fitLongestWord(
  BuildContext context,
  String text,
  TextStyle? style,
  double maxWidth,
) {
  final fontSize = style?.fontSize;
  if (fontSize == null || !maxWidth.isFinite || maxWidth <= 0) return style;
  var widest = 0.0;
  for (final match in _wordPattern.allMatches(text)) {
    final painter = TextPainter(
      text: TextSpan(text: match.group(0), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth) return style;
  // Ширина глифов растёт с кеглем не строго линейно (округление advance):
  // без запаса в 2 % слово при точном масштабе всё ещё рвалось.
  return style?.copyWith(fontSize: fontSize * maxWidth / widest * 0.98);
}

/// Сколько строк (не больше двух) займёт текст на ширине [maxWidth].
int _textLines(
  BuildContext context,
  String text,
  TextStyle? style,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(text: accountEmailDisplay(text), style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
  )..layout(maxWidth: math.max(0, maxWidth));
  final lines = painter.computeLineMetrics().length.clamp(1, 2);
  painter.dispose();
  return lines;
}

enum _AccountAction { unlock, biometric, cabinet, sync, logout, remove }

class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  /// Одно действие за раз: все они ходят в сеть или в биометрию, а
  /// параллельные запросы делят одну сессию.
  _AccountAction? _busy;
  bool _autoUnlockTried = false;

  /// Пустой шит уже закрывается — второй pop снял бы экран под ним.
  bool _closingEmpty = false;

  /// Что показывал шит до выхода или удаления с устройства. Держим это, пока
  /// шит уезжает: иначе на полсекунды мелькает экран «не вошли».
  AccountState? _frozen;

  @override
  void initState() {
    super.initState();
    // Закрытый замком экран бесполезен — просим отпечаток сразу. Слушаем
    // статус, а не читаем его разово: при открытии restore может ещё идти.
    ref.listenManual<AccountStatus>(
      accountProvider.select((state) => state.status),
      (_, status) => _autoUnlock(status),
      fireImmediately: true,
    );
  }

  void _autoUnlock(AccountStatus status) {
    if (status != AccountStatus.locked || _autoUnlockTried) {
      return;
    }
    _autoUnlockTried = true;
    // Из initState нельзя звать setState, поэтому после первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_unlock());
      }
    });
  }

  Future<void> _run(
    _AccountAction action,
    Future<void> Function() body,
  ) async {
    if (_busy != null) {
      return;
    }
    setState(() => _busy = action);
    try {
      await body();
    } catch (error) {
      globalState.showNotifier(
        accountErrorText(error),
        kind: M3eToastKind.alert,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  // false из unlock — системный диалог закрыли: остаёмся на экране замка.
  Future<void> _unlock() => _run(
        _AccountAction.unlock,
        () => ref
            .read(accountProvider.notifier)
            .unlock(appLocalizations.accountBiometricUnlockReason),
      );

  Future<void> _setBiometric({required bool enabled}) => _run(
        _AccountAction.biometric,
        () async {
          final account = ref.read(accountProvider.notifier);
          if (enabled) {
            await account.enableBiometric(
              appLocalizations.accountBiometricEnableReason,
            );
          } else {
            await account.disableBiometric();
          }
        },
      );

  /// Только кабинет профиля аккаунта: строка строится из него же.
  Future<void> _openCabinet(String profileId, Uri fallback) => _run(
        _AccountAction.cabinet,
        () => openAccountCabinet(
          account: ref.read(accountProvider.notifier),
          status: ref.read(accountProvider).status,
          profileId: profileId,
          accountProfileId: profileId,
          fallback: fallback,
        ),
      );

  Future<void> _syncSubscription() => _run(
        _AccountAction.sync,
        () async {
          final result =
              await ref.read(accountProvider.notifier).syncSubscription();
          globalState.showNotifier(
            accountSyncResultText(result),
            kind: accountSyncResultKind(result),
          );
        },
      );

  /// Закрывает шит, оставив на нём то, что было видно до выхода или
  /// удаления с устройства.
  void _close(AccountState shown) {
    if (!mounted) {
      return;
    }
    setState(() => _frozen = shown);
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  /// Без подтверждения: выход обратим, войти снова можно по коду.
  Future<void> _logout() async {
    if (_busy != null) {
      return;
    }
    final account = ref.read(accountProvider.notifier);
    final shown = ref.read(accountProvider);
    setState(() => _busy = _AccountAction.logout);
    try {
      await account.logout();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = null);
      }
      globalState.showNotifier(
        accountErrorText(error),
        kind: M3eToastKind.alert,
      );
      return;
    }
    // Сессия уже стёрта: уезжающий шит держит снимок аккаунта до выхода.
    _close(shown);
    globalState.showNotifier(
      appLocalizations.accountLoggedOut,
      kind: M3eToastKind.check,
    );
  }

  /// Подтверждение обязательно: в отличие от выхода, с устройства пропадёт
  /// и VPN-профиль подписки этого аккаунта.
  Future<void> _removeFromDevice() async {
    if (_busy != null) {
      return;
    }
    final confirmed = await globalState.showMessage(
      title: appLocalizations.accountRemoveFromDeviceTitle,
      message: TextSpan(text: appLocalizations.accountRemoveFromDeviceText),
      confirmText: appLocalizations.delete,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final account = ref.read(accountProvider.notifier);
    final shown = ref.read(accountProvider);
    await _run(_AccountAction.remove, () async {
      await account.removeFromDevice();
      // Итог показываем и тогда, когда шит уже закрыли: тост глобальный.
      globalState.showNotifier(
        appLocalizations.accountRemovedFromDevice,
        kind: M3eToastKind.check,
      );
      _close(shown);
    });
  }

  /// Вход заменяет шит аккаунта, а не ложится поверх: два стеклянных шита
  /// стопкой на устройстве выглядели как сбой. Новый шит ждёт, пока старый
  /// доедет вниз (`completed` маршрута — после анимации ухода), и открывается
  /// от навигатора: контекст этого шита к тому времени размонтирован.
  Future<void> _signInWithCode({String? email}) async {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    navigator.pop();
    await route?.completed;
    if (!navigator.mounted) {
      return;
    }
    await openAccountLoginSheet(navigator.context, email: email);
  }

  /// Вошедших нет, а входа в этой сборке нет — показывать нечего: пустой
  /// шит с одной ручкой выглядит как сбой, закрываем его.
  void _closeEmpty() {
    if (_closingEmpty) {
      return;
    }
    _closingEmpty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Подписку держим и на закрытии: замороженный снимок лишь подменяет то,
    // что видно, пока лист уезжает вниз.
    final live = ref.watch(accountProvider);
    final state = _frozen ?? live;
    // Кабинет — только своего профиля аккаунта: в кабинет текущего профиля
    // другого провайдера автовход вести нельзя.
    final accountProfile = ref.watch(accountProfileProvider);
    final body = switch (state.status) {
      AccountStatus.unknown => null,
      AccountStatus.loggedOut =>
        ref.watch(accountLoginAvailableProvider) ? _buildLoggedOut() : null,
      AccountStatus.locked => _buildLocked(
          loginAvailable: ref.watch(accountLoginAvailableProvider),
        ),
      AccountStatus.ready => _buildReady(
          state,
          cabinetProfileId: accountProfile?.id,
          cabinetUri: profileCabinetUri(accountProfile),
        ),
    };
    if (body == null &&
        state.status == AccountStatus.loggedOut &&
        _frozen == null) {
      _closeEmpty();
    }
    final showHero = state.status != AccountStatus.loggedOut;
    return LiquidSheetBody(
      children: [
        if (showHero)
          _AccountHero(
            // Без почты (сессия восстановлена не полностью) шапка не должна
            // пустовать.
            email: state.email ?? appLocalizations.account,
            trailing: _buildHeroTrailing(state),
          ),
        if (body != null) ...[
          if (showHero) const SizedBox(height: 12),
          FadeThroughBox(alignment: Alignment.topCenter, child: body),
        ],
      ],
    );
  }

  Widget _buildHeroTrailing(AccountState state) {
    final working = state.status == AccountStatus.unknown ||
        _busy == _AccountAction.logout ||
        _busy == _AccountAction.remove;
    if (working) {
      return const LiquidUpdatingIndicator();
    }
    if (state.status != AccountStatus.ready) {
      return const SizedBox.square(dimension: 40);
    }
    return LiquidMoreMenu(
      semanticLabel: appLocalizations.more,
      items: [
        liquidMenuItem(
          context,
          title: appLocalizations.accountLogout,
          icon: HugeIcons.strokeRoundedLogout01,
          onTap: () => unawaited(_logout()),
        ),
        liquidMenuItem(
          context,
          title: appLocalizations.accountRemoveFromDevice,
          icon: HugeIcons.strokeRoundedDelete02,
          isDestructive: true,
          onTap: () => unawaited(_removeFromDevice()),
        ),
      ],
    );
  }

  /// Две строки: на 320 dp с крупным шрифтом «Вход по отпечатку» не влезает
  /// в одну, а многоточие прятало смысл. Высоту шита оценка считает так же.
  Widget _rowTitle(String text) => LayoutBuilder(
        builder: (context, constraints) => Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _fitLongestWord(
            context,
            text,
            context.textTheme.bodyLarge,
            constraints.maxWidth,
          )?.copyWith(color: context.colorScheme.onSurface),
        ),
      );

  Widget _group(Key key, List<Widget> rows) => LiquidCard(
        key: key,
        flat: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const LiquidHairline(indent: kLiquidDividerIndent),
              rows[i],
            ],
          ],
        ),
      );

  Widget _trailingFor(_AccountAction action, {Widget? idle}) =>
      _busy == action ? const AccountInlineSpinner() : idle ?? const SizedBox();

  /// Сессию могли сбросить, пока шит открыт (refresh не прошёл) — вместо
  /// пустоты предлагаем войти снова.
  Widget _buildLoggedOut() => _group(const ValueKey('loggedOut'), [
        LiquidTile(
          icon: HugeIcons.strokeRoundedMail01,
          title: _rowTitle(appLocalizations.accountLoginByEmail),
          trailing: const LiquidChevron(),
          onTap: () => unawaited(_signInWithCode()),
        ),
      ]);

  /// «Войти по коду» — только когда у текущего профиля есть бэкенд входа:
  /// без него запрос кода заканчивался ошибкой, а не входом.
  Widget _buildLocked({required bool loginAvailable}) =>
      _group(const ValueKey('locked'), [
        LiquidTile(
          icon: HugeIcons.strokeRoundedFingerPrint,
          title: _rowTitle(appLocalizations.accountUnlock),
          trailing: _trailingFor(
            _AccountAction.unlock,
            idle: const LiquidChevron(),
          ),
          onTap: () => unawaited(_unlock()),
        ),
        if (loginAvailable)
          LiquidTile(
            icon: HugeIcons.strokeRoundedMail01,
            title: _rowTitle(appLocalizations.accountSignInWithCode),
            trailing: const LiquidChevron(),
            onTap: _busy == null
                ? () => _signInWithCode(email: ref.read(accountProvider).email)
                : null,
          ),
      ]);

  Widget _buildReady(
    AccountState state, {
    required String? cabinetProfileId,
    required Uri? cabinetUri,
  }) =>
      _group(const ValueKey('ready'), [
        if (state.biometricAvailable)
          LiquidTile(
            icon: HugeIcons.strokeRoundedFingerPrint,
            title: _rowTitle(appLocalizations.accountBiometricSwitch),
            trailing: Switch(
              value: state.biometricEnabled,
              onChanged: (enabled) =>
                  unawaited(_setBiometric(enabled: enabled)),
            ),
            onTap: () =>
                unawaited(_setBiometric(enabled: !state.biometricEnabled)),
          ),
        if (cabinetProfileId != null && cabinetUri != null)
          LiquidTile(
            icon: HugeIcons.strokeRoundedUserCircle,
            title: _rowTitle(appLocalizations.personalCabinet),
            trailing: _trailingFor(
              _AccountAction.cabinet,
              idle: const LiquidChevron(),
            ),
            onTap: () => unawaited(_openCabinet(cabinetProfileId, cabinetUri)),
          ),
        LiquidTile(
          icon: HugeIcons.strokeRoundedRefresh,
          title: _rowTitle(appLocalizations.accountSyncSubscription),
          trailing: _trailingFor(_AccountAction.sync),
          onTap: () => unawaited(_syncSubscription()),
        ),
      ]);
}

/// Шапка как у «Подписки»: почта крупно и круг справа («⋯» или спиннер).
class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.email, required this.trailing});

  final String email;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => LiquidCard(
        flat: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(child: _AccountEmail(email)),
              const SizedBox(width: 8),
              FadeThroughBox(alignment: Alignment.center, child: trailing),
            ],
          ),
        ),
      );
}

/// Почта самым крупным стилем, в который адрес влезает одной строкой:
/// длинный адрес мельчает, а совсем длинный переносится после «@» на вторую
/// строку — обрезка с конца теряла домен.
class _AccountEmail extends StatelessWidget {
  const _AccountEmail(this.email);

  final String email;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final styles = [
      textTheme.titleLarge,
      textTheme.titleMedium,
      textTheme.bodyLarge,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        var style = styles.last;
        for (final candidate in styles) {
          final painter = TextPainter(
            text: TextSpan(text: email, style: candidate),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);
          final fits = !painter.didExceedMaxLines;
          painter.dispose();
          if (fits) {
            style = candidate;
            break;
          }
        }
        return Text(
          accountEmailDisplay(email),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(color: context.colorScheme.onSurface),
        );
      },
    );
  }
}
