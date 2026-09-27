import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:dropweb/views/subscription/profiles_content.dart'
    show refreshProfiles;
import 'package:dropweb/views/subscription/subscription_page.dart';
import 'package:dropweb/views/tools.dart';
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

/// Dashboard MENU: the label condenses into a Liquid Glass panel (iOS-26
/// GlassMenu morph) that grows upward from it, and collapses back into the
/// label on outside tap / item select. Tap anywhere on the strip or swipe up
/// to open. Rows are conditional on the active profile: Подписка, Личный
/// кабинет, Поддержка, Обновить подписку, Настройки.
class DashboardGlassMenu extends ConsumerStatefulWidget {
  const DashboardGlassMenu({super.key});

  @override
  ConsumerState<DashboardGlassMenu> createState() => _DashboardGlassMenuState();
}

class _DashboardGlassMenuState extends ConsumerState<DashboardGlassMenu> {
  static const double _pillHeight = 36;

  final GlassMenuController _controller = GlassMenuController();
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentProfile = ref.watch(currentProfileProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
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
                          color: colorScheme.primary,
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

    return [
      if (currentProfile != null)
        item(
          icon: HugeIcons.strokeRoundedCreditCard,
          title: appLocalizations.subscription,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()),
          ),
        ),
      if (cabinetUri != null)
        item(
          icon: HugeIcons.strokeRoundedUserCircle,
          title: appLocalizations.personalCabinet,
          onTap: () => openCabinetBrowser(cabinetUri),
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
        onTap: () => _openToolsSheet(context, ref),
      ),
    ];
  }
}

void _openToolsSheet(BuildContext context, WidgetRef ref) {
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
