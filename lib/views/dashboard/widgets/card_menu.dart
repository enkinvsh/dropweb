import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/views/account/account_sheet.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:dropweb/views/subscription/profiles_content.dart'
    show refreshProfiles;
import 'package:dropweb/views/subscription/subscription_page.dart';
import 'package:dropweb/views/tools.dart';
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassMenu,
        GlassMenuAlignment,
        GlassMenuController,
        GlassMenuItem,
        GlassQuality,
        LiquidRoundedRectangle;

// Developer-mode unlock counter for 5 rapid taps on the Settings sheet
// title. Module-level so the streak survives across repeated openings of the
// only entry point — the dashboard MENU (tap or swipe-up) — within a single
// app session; the 3-second window inside `DevUnlockCounter` self-resets
// stale streaks.
final DevUnlockCounter _devUnlockCounter = DevUnlockCounter();

/// МЕНЮ дашборда: надпись превращается в панель Liquid Glass (морф GlassMenu
/// в духе iOS 26), растущую вверх, и сворачивается обратно по тапу снаружи или
/// выбору пункта. Открывается тапом по полосе или свайпом вверх. Строки:
/// Аккаунт (только Android — вход по почте пока есть только там), затем
/// зависящие от активного профиля Подписка, Личный кабинет, Поддержка,
/// Обновить подписку и всегда Настройки.
class DashboardGlassMenu extends ConsumerStatefulWidget {
  const DashboardGlassMenu({super.key});

  @override
  ConsumerState<DashboardGlassMenu> createState() => _DashboardGlassMenuState();
}

class _DashboardGlassMenuState extends ConsumerState<DashboardGlassMenu> {
  static const double _pillHeight = 36;
  static const double _menuWidth = 264;
  static const double _menuItemHeight = 44;
  static const double _menuPad = 8;
  static const double _menuRadius = 28;

  final GlassMenuController _controller = GlassMenuController();
  bool _pressed = false;
  final GlobalKey _pillKey = GlobalKey();
  final GlassMorphHide _pillHidden = GlassMorphHide();

  // Задаётся на время тапа по пункту меню: пункт, который открывает шит, может
  // забрать панель меню как источник стекла (передача меню -> шит).
  GlassMorphOrigin? Function()? _handoff;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void dispose() {
    _pillHidden.dispose();
    super.dispose();
  }

  Widget _pillBody(ThemeData theme, ColorScheme colorScheme) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_pillHeight / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Lumina.lensHighlight.opacity30,
              Lumina.lensHighlight.opacity0,
              Lumina.lensShadow.opacity0,
              Lumina.lensShadow.opacity30,
            ],
            stops: const [0, 0.5, 0.55, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Center(
            widthFactor: 1,
            child: Text(
              appLocalizations.menu,
              // Одна строка без переноса: в призраке ширина задана жёстко, и
              // запас в долю пикселя не должен ронять последнюю букву вниз.
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );

  /// Строки меню. [onTap] == null — неинтерактивная копия для призрака шита.
  Widget _menuRows(
    List<GlassMenuItem> items,
    void Function(GlassMenuItem item)? onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.all(_menuPad),
        child: Column(
          children: [
            for (final i in items)
              GlassMenuItem(
                title: i.title,
                icon: i.icon,
                iconColor: i.iconColor,
                titleStyle: i.titleStyle,
                enabled: i.enabled,
                trailing: i.trailing,
                onTap: onTap == null ? () {} : () => onTap(i),
              ),
          ],
        ),
      );

  /// Если пункт открывает шит, он зовёт это: панель меню исчезает без
  /// анимации в тот же кадр, когда шит встаёт на её место, и стекло меню
  /// продолжается стеклом шита, без второго «выезда».
  GlassMorphOrigin? _takeHandoff() {
    final handoff = _handoff;
    _handoff = null;
    return handoff?.call();
  }

  void _openApple(BuildContext context, List<Widget> items) {
    final box = _pillKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final pill = box.localToGlobal(Offset.zero) & box.size;
    final menuItems = items.whereType<GlassMenuItem>().toList();
    final height = menuItems.length * _menuItemHeight + _menuPad * 2;
    final pillGhost =
        _pillBody(Theme.of(context), Theme.of(context).colorScheme);
    showGlassMorph<void>(
      context,
      GlassMorphSpec(
        source: () => pill,
        target: (size) => glassMenuTarget(size, pill, _menuWidth, height),
        hideSource: _pillHidden,
        ghostAlignment: Alignment.bottomCenter,
        fromRadius: _pillHeight / 2,
        toRadius: _menuRadius,
        fromSettings: Lumina.liquidButton,
        toSettings: Lumina.liquidMenu,
        openSpring: const SpringDescription(
          mass: 1,
          stiffness: 260,
          damping: 24,
        ),
        closeSpring: const SpringDescription(
          mass: 1,
          stiffness: 300,
          damping: 28,
        ),
        // Надпись MENU гаснет до 0.22, строки проявляются с 0.30: окна не
        // пересекаются, и строка меню не ложится на буквы пилюли.
        ghostFadeEnd: 0.22,
        contentFadeStart: 0.30,
        contentFadeEnd: 0.62,
        ghost: IgnorePointer(child: pillGhost),
        content: (ctx) => _menuRows(menuItems, (item) {
          final route = ModalRoute.of(ctx);
          // Прямоугольник панели в момент тапа: с него шит продолжит стекло.
          final panel = ctx.findRenderObject();
          final menuRect = panel is RenderBox && panel.attached
              ? panel.localToGlobal(Offset.zero) & panel.size
              : null;
          var handedOff = false;
          _handoff = () {
            if (menuRect == null || route == null || !route.isActive) {
              return null;
            }
            handedOff = true;
            Navigator.of(ctx).removeRoute(route);
            return GlassMorphOrigin(
              rect: () => menuRect,
              ghost: IgnorePointer(child: _menuRows(menuItems, null)),
              radius: _menuRadius,
              settings: Lumina.liquidMenu,
              hide: _pillHidden,
              // Закрытие шита сворачивает стекло в пилюлю MENU, а не в
              // опустевшую панель меню.
              returnTo: GlassMorphOrigin(
                rect: () => pill,
                ghost: IgnorePointer(child: pillGhost),
                radius: _pillHeight / 2,
                settings: Lumina.liquidButton,
                ghostAlignment: Alignment.bottomCenter,
              ),
            );
          };
          item.onTap();
          _handoff = null;
          if (!handedOff && route != null) {
            dismissGlassMorph(Navigator.of(ctx), route);
          }
        }),
      ),
    );
  }

  Widget _buildApple(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Profile? currentProfile,
  ) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    void open() => _openApple(
          context,
          _buildItems(context, currentProfile, theme),
        );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: open,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -250) open();
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ValueListenableBuilder<bool>(
            valueListenable: _pillHidden,
            builder: (context, hidden, child) =>
                Opacity(opacity: hidden ? 0 : 1, child: child),
            child: KeyedSubtree(
              key: _pillKey,
              child: AnimatedScale(
                scale: _pressed && !reduceMotion ? 1.06 : 1.0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Lumina.luminaCurve,
                child: GlassContainer(
                  useOwnLayer: true,
                  quality: GlassQuality.standard,
                  height: _pillHeight,
                  shape: const LiquidRoundedRectangle(
                    borderRadius: _pillHeight / 2,
                  ),
                  settings: Lumina.liquidButton,
                  child: _pillBody(theme, colorScheme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentProfile = ref.watch(currentProfileProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Мобильный путь: свой кусок стекла. Десктоп остаётся на GlassMenu пакета:
    // морф меряет источник в глобальных координатах, а холст popover на macOS
    // масштабирован.
    if (!system.isDesktop) {
      return _buildApple(context, theme, colorScheme, currentProfile);
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _controller.open,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -250) _controller.open();
      },
      child: Align(
        alignment: Alignment.topCenter,
        // Padding sits outside GlassMenu so the morph starts from the pill's
        // exact rect (GlassMenu measures its own box, radius = height / 2).
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GlassMenu(
            controller: _controller,
            // No GestureDetector here: the strip above is the single gesture
            // owner and drives the menu through the controller.
            triggerBuilder: (context, _) => AnimatedScale(
              scale: _pressed && !reduceMotion ? 1.06 : 1.0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              curve: Lumina.luminaCurve,
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.standard,
                height: _pillHeight,
                shape: const LiquidRoundedRectangle(
                  borderRadius: _pillHeight / 2,
                ),
                settings: Lumina.liquidButton,
                // Volume on top of the glass body (same as the segmented
                // thumb): specular band from above, contact shade below.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_pillHeight / 2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Lumina.lensHighlight.opacity30,
                        Lumina.lensHighlight.opacity0,
                        Lumina.lensShadow.opacity0,
                        Lumina.lensShadow.opacity30,
                      ],
                      stops: const [0, 0.5, 0.55, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        appLocalizations.menu,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            items: _buildItems(context, currentProfile, theme),
            menuAlignment: GlassMenuAlignment.bottomCenter,
            autoAdjustToScreen: true,
            menuPadding: const EdgeInsets.all(16),
            menuWidth: 264,
            settings: Lumina.liquidMenu,
            quality: Lumina.liquidOverlayQuality,
            selectionColor: colorScheme.primary.opacity15,
            glowColor: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Menu rows, derived from the active profile exactly like the former
  /// dialog menu. No `Navigator.pop()`: GlassMenu runs `item.onTap()` and
  /// then closes itself.
  List<Widget> _buildItems(
    BuildContext context,
    Profile? currentProfile,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final cabinetUri = profileCabinetUri(currentProfile);
    final headers = currentProfile?.providerHeaders ?? const {};
    final supportUrl = headers['support-url'];
    final hasSupport = supportUrl != null && supportUrl.isNotEmpty;

    GlassMenuItem item({
      required List<List<dynamic>> icon,
      required String title,
      required VoidCallback onTap,
    }) =>
        GlassMenuItem(
          title: title,
          icon: HugeIcon(icon: icon, size: 20, color: colorScheme.onSurface),
          iconColor: colorScheme.onSurface,
          titleStyle: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          onTap: onTap,
        );

    final showAccount = accountMenuEntryVisible(
      isAndroid: Platform.isAndroid,
      status: ref.watch(accountProvider.select((state) => state.status)),
      loginAvailable: ref.watch(accountLoginAvailableProvider),
    );

    return [
      if (showAccount)
        item(
          icon: HugeIcons.strokeRoundedUserAccount,
          title: appLocalizations.account,
          onTap: () => unawaited(_openAccount(context)),
        ),
      if (currentProfile != null)
        item(
          icon: HugeIcons.strokeRoundedCreditCard,
          title: appLocalizations.subscription,
          onTap: () => SubscriptionPage.open(context, origin: _takeHandoff()),
        ),
      if (cabinetUri != null)
        item(
          icon: HugeIcons.strokeRoundedUserCircle,
          title: appLocalizations.personalCabinet,
          onTap: () => _openCabinet(currentProfile?.id, cabinetUri),
        ),
      if (hasSupport)
        item(
          icon: supportUrl.toLowerCase().contains('t.me')
              ? HugeIcons.strokeRoundedTelegram
              : HugeIcons.strokeRoundedCustomerSupport,
          title: appLocalizations.support,
          onTap: () => globalState.openUrl(supportUrl),
        ),
      if (currentProfile != null)
        GlassMenuItem(
          title: appLocalizations.updateSubscription,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedRefresh,
            size: 20,
            color: colorScheme.onSurface,
          ),
          iconColor: colorScheme.onSurface,
          titleStyle: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          // An update already running (from any entry point) shows here too.
          enabled: !currentProfile.isUpdating,
          trailing: currentProfile.isUpdating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          // Same path as the dashboard pull-to-refresh and «⋯ → Обновить».
          onTap: () => refreshProfiles(context, currentProfile),
        ),
      item(
        icon: HugeIcons.strokeRoundedSettings02,
        title: appLocalizations.tools,
        onTap: () => _openToolsSheet(context, ref, _takeHandoff()),
      ),
    ];
  }

  /// Статус читаем в момент тапа, а не при сборке меню: restore() мог
  /// завершиться, пока панель была открыта. Без сессии сразу ведём во вход;
  /// заблокированную сессию экран аккаунта сам предложит открыть отпечатком.
  Future<void> _openAccount(BuildContext context) {
    // Передачу забираем сразу, до любого await: она живёт только на время тапа.
    final origin = _takeHandoff();
    return switch (ref.read(accountProvider).status) {
      AccountStatus.unknown ||
      AccountStatus.loggedOut =>
        openAccountLoginSheet(context, origin: origin),
      AccountStatus.locked ||
      AccountStatus.ready =>
        openAccountSheet(context, origin: origin),
    };
  }

  /// На Android кабинет профиля аккаунта открывается уже залогиненным
  /// (одноразовый handoff-токен). Кабинет любого другого профиля — обычной
  /// ссылкой, как до появления аккаунта: токен нашего бэкенда чужому
  /// провайдеру не отдаём. Отмена отпечатка или сбой тоже ведут на обычную
  /// ссылку — тап никогда не остаётся «мёртвым».
  Future<void> _openCabinet(String? profileId, Uri cabinetUri) async {
    if (!Platform.isAndroid) {
      await openCabinetBrowser(cabinetUri);
      return;
    }
    final account = ref.read(accountProvider);
    await openAccountCabinet(
      account: ref.read(accountProvider.notifier),
      status: account.status,
      profileId: profileId,
      accountProfileId: account.profileId,
      fallback: cabinetUri,
    );
  }
}

void _openToolsSheet(
  BuildContext context,
  WidgetRef ref,
  GlassMorphOrigin? origin,
) {
  // На десктопе настройки остаются боковой панелью / страницей.
  if (system.isDesktop) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        disableBackground: false,
        body: const ToolsView(),
        title: appLocalizations.tools,
        titleBuilder: (context) => AppLocalizations.of(context).tools,
        onTitleTap: () => _onSettingsTitleTap(ref),
      ),
    );
    return;
  }
  // Высокий шит: список длинный, но над ним остаётся статус-бар.
  final topPad = MediaQuery.viewPaddingOf(context).top;
  showGlassMorph<void>(
    context,
    GlassMorphSpec(
      target: (overlay) => glassSheetTarget(
        overlay,
        math.min(overlay.height * 0.9, overlay.height - topPad - 16),
      ),
      content: (_) => ToolsSheetBody(
        onTitleTap: () => _onSettingsTitleTap(ref),
      ),
      source: origin?.rect,
      ghost: origin?.ghost,
      ghostAlignment: origin?.ghostAlignment ?? Alignment.topLeft,
      hideSource: origin?.hide,
      closeOrigin: origin?.returnTo,
      fromRadius: origin?.radius ?? kLiquidSheetRadius,
      toRadius: kLiquidSheetRadius,
      fromSettings: origin?.settings ?? Lumina.liquidMenu,
      toSettings: Lumina.liquidMenu,
      dragToDismiss: true,
      showHandle: true,
    ),
  );
}

// 5 rapid taps on the Settings screen title unlock developer / advanced
// mode (Access Control, Config, Application settings entries).
void _onSettingsTitleTap(WidgetRef ref) {
  if (!_devUnlockCounter.registerTap()) return;
  final alreadyEnabled = ref.read(appSettingProvider).developerMode;
  if (alreadyEnabled) return;
  ref.read(appSettingProvider.notifier).updateState(
        (state) => state.copyWith(developerMode: true),
      );
  globalState.showNotifier(appLocalizations.developerModeEnableTip);
}
