import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/corner_badge.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/proxies/common.dart';
import 'package:dropweb/views/subscription/profiles_content.dart'
    show refreshProfiles;
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassCard,
        GlassMenu,
        GlassMenuAlignment,
        GlassMenuItem,
        GlassQuality,
        LiquidRoundedSuperellipse;

// Merged «Подписка» page in the «LiquidLumina» style.
//
// Every control performs the real action of the old tabbed page: picking an
// exit applies the work mode (aggregate → Стандарт, country → Страна), the
// switch toggles full tunnel, and the hero switches / adds / updates /
// deletes subscriptions.
//
// Glass sits only on the hero and the grouped card. The country picker is an
// opaque Material sheet: a scrolling list over glass re-refracts the mesh
// every frame.

/// Leading inset of a hairline inside the grouped card: row padding 16 +
/// icon 24 + gap 12, so the line starts under the title, iOS-style.
const double _groupedDividerIndent = 52;

/// Same readiness gate and invalidation as `modeProfileDataProvider`, plus
/// the name of the profile's primary router (the `MATCH` target).
final _routeDataProvider = FutureProvider.autoDispose
    .family<({bool fullTunnelAvailable, String? routerName}), String>(
  (ref, profileId) async {
    ref.watch(profilesProvider.select((profiles) {
      final p = profiles.getProfile(profileId);
      return (p?.lastUpdateDate, p?.providerHeaders.length);
    }));
    final config = await globalState.getProfileConfig(profileId);
    return (
      fullTunnelAvailable: fullTunnelAvailable(config),
      routerName: detectPrimaryRouter(config),
    );
  },
);

Proxy? _findProxy(Group group, String name) {
  for (final proxy in group.all) {
    if (proxy.name == name) return proxy;
  }
  return null;
}

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  /// Opens the page with the Liquid zoom. With [source] (the dashboard
  /// subscription card) the page grows out of that card — its own header card
  /// starts right on top of it — and shrinks back into it on close.
  static Future<void> open(BuildContext context, {BuildContext? source}) =>
      Navigator.of(context).push(
        LiquidZoomRoute<void>(
          source: source == null ? null : () => zoomSourceRectOf(source),
          // Where the header card sits on this page (the ListView padding).
          anchor: (context) => Offset(
            16,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          ),
          builder: (_) => const SubscriptionPage(),
        ),
      );

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  /// Applying a work mode is fast (a config rebuild). We disable the stack
  /// briefly so a double-tap can't race two applies.
  bool _applying = false;

  // Exit whose latency was already probed on this page, so the row badge
  // never shows a stale «n/a» left over from an earlier failed test.
  String? _probedExit;

  Future<void> _apply(
    WorkMode mode, {
    String? staticCountry,
    String? routerPin,
  }) async {
    setState(() => _applying = true);
    try {
      await globalState.appController.applyWorkMode(
        mode,
        staticCountry: staticCountry,
        routerPin: routerPin,
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _setFullTunnel(bool enabled) async {
    setState(() => _applying = true);
    try {
      await globalState.appController.setFullTunnel(enabled: enabled);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showAddProfile() {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(context: context),
        title: appLocalizations.addProfile,
      ),
    );
  }

  Future<void> _deleteProfile(Profile profile) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.appController.deleteProfile(profile.id);
  }

  void _openServersAndGroups() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.serversAndGroups,
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: const RulesProxiesView(),
        ),
      ),
    );
  }

  /// Opaque Material sheet, same presentation as the old «Страна» picker:
  /// a scrolling list over glass re-refracts the animated mesh every frame.
  void _openCountrySheet(Group group, String selectedName) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.workModeCountry,
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: _CountrySheet(
            routerName: group.name,
            selectedName: selectedName,
            // The pick decides the mode: aggregate («Авто») → Стандарт,
            // leaf country → Страна. `routerPin` is always passed: it is the
            // lock that keeps a misclassified country group from falling
            // back to the router's first member.
            onPicked: (name, {required isAggregate}) => _apply(
              isAggregate ? WorkMode.standard : WorkMode.country,
              staticCountry: isAggregate ? null : name,
              routerPin: name,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profilesSelectorStateProvider);
    final profiles = state.profiles;
    final profile = profiles.getProfile(state.currentProfileId) ??
        (profiles.isEmpty ? null : profiles.first);
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Lumina.void_,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: system.isDesktop,
        title: system.isDesktop ? Text(appLocalizations.subscription) : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: MeshBackground()),
          if (profile == null)
            NullStatus(label: appLocalizations.nullProfileDesc)
          else
            RefreshIndicator(
              edgeOffset: padding.top + kToolbarHeight,
              onRefresh: () => refreshProfiles(context, profile),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  padding.top + kToolbarHeight + 8,
                  16,
                  32 + padding.bottom,
                ),
                children: _buildSections(profile, profiles),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(Profile profile, List<Profile> profiles) {
    final routeData = ref.watch(_routeDataProvider(profile.id));
    final fullTunnelAvailable =
        routeData.valueOrNull?.fullTunnelAvailable ?? false;
    final bodyLarge = context.textTheme.bodyLarge?.copyWith(
      color: context.colorScheme.onSurface,
    );

    final rows = <Widget>[
      _buildExitTile(profile, routeData),
      if (fullTunnelAvailable)
        Semantics(
          identifier: 'dw_tunnel',
          child: _LiquidTile(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            title: Text(appLocalizations.fullTunnelTitle, style: bodyLarge),
            trailing: Switch(
              value: profile.fullTunnel,
              onChanged: _setFullTunnel,
            ),
            onTap: () => _setFullTunnel(!profile.fullTunnel),
          ),
        ),
      _LiquidTile(
        icon: HugeIcons.strokeRoundedServerStack01,
        title: Text(appLocalizations.serversAndGroups, style: bodyLarge),
        trailing: const _Chevron(),
        onTap: _openServersAndGroups,
      ),
    ];

    return [
      _Hero(
        profile: profile,
        profiles: profiles,
        onSelectProfile: (id) =>
            ref.read(currentProfileIdProvider.notifier).value = id,
        onAdd: _showAddProfile,
        // Same path as the dashboard pull-to-refresh and MENU «Обновить
        // подписку»: sound cue, isUpdating spinner, mapped error dialog.
        onUpdate: () => refreshProfiles(context, profile),
        onDelete: () => _deleteProfile(profile),
      ),
      const SizedBox(height: 12),
      // Taps are held off while a mode/tunnel change applies, but the card is
      // not dimmed: the switch or the exit row already shows the change, and
      // a grey flash over the whole card read as a glitch.
      IgnorePointer(
        ignoring: _applying,
        child: _LiquidCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const _Hairline(indent: _groupedDividerIndent),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildExitTile(
    Profile profile,
    AsyncValue<({bool fullTunnelAvailable, String? routerName})> routeData,
  ) {
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;
    Widget title(String text, {Color? color}) => EmojiText(
          text,
          style: textTheme.bodyLarge?.copyWith(
            color: color ?? colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    if (routeData.hasError && !routeData.isLoading) {
      return _LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: title(appLocalizations.genericErrorMessage),
      );
    }
    final data = routeData.valueOrNull;
    final routerName = data?.routerName;
    if (data != null && routerName == null) {
      return _LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: title(appLocalizations.routeUndetected),
      );
    }
    final group = routerName == null
        ? null
        : ref.watch(groupsProvider).getGroup(routerName);
    if (group == null) {
      return _LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: title(appLocalizations.loadingEllipsis),
        trailing: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    final realSelected = group.resolveSelectedName(
      ref.watch(getProxyNameProvider(group.name)) ?? '',
    );
    final exitName = realSelected;
    final proxy = _findProxy(group, exitName);
    if (proxy != null && _probedExit != proxy.name) {
      _probedExit = proxy.name;
      // Read-only latency probe of the shown exit, once per selection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(delayTest([proxy], group.testUrl));
      });
    }

    final titleWidget = title(
      proxy?.name ?? (exitName.isEmpty ? group.name : exitName),
    );

    return Semantics(
      identifier: 'dw_exit',
      child: _LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: titleWidget,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (proxy != null) ...[
              _DelayBadge(proxyName: proxy.name, testUrl: group.testUrl),
              const SizedBox(width: 8),
            ],
            const _Chevron(),
          ],
        ),
        onTap: () => _openCountrySheet(group, exitName),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({
    required this.profile,
    required this.profiles,
    required this.onSelectProfile,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  final Profile profile;
  final List<Profile> profiles;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAdd;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  /// `<traffic> · <expiry>` on one line; null when the provider sends no
  /// subscription info.
  String? _summary() {
    final info = profile.subscriptionInfo;
    if (info == null) return null;
    final String traffic;
    if (info.total == 0) {
      traffic = appLocalizations.trafficUnlimited;
    } else {
      final used = TrafficValue(value: info.upload + info.download);
      final total = TrafficValue(value: info.total);
      traffic = '${used.showValue} ${used.showUnit} / '
          '${total.showValue} ${total.showUnit}';
    }
    final expiry = info.expire > 0
        ? appLocalizations.validUntil(
            DateFormat('dd.MM.yyyy').format(
              DateTime.fromMillisecondsSinceEpoch(info.expire * 1000),
            ),
          )
        : appLocalizations.subscriptionUnlimited;
    return '$traffic · $expiry';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    return _LiquidCard(
      child: Stack(
        children: [
          Positioned.fill(
            child: SubscriptionCardLogo(headers: profile.providerHeaders),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _ProfileSwitcher(
                          profile: profile,
                          profiles: profiles,
                          onSelect: onSelectProfile,
                          onAdd: onAdd,
                        ),
                      ),
                    ),
                    // While the subscription updates (from any entry point)
                    // «⋯» turns into a spinner, like the old profile card.
                    FadeThroughBox(
                      child: profile.isUpdating
                          ? const _UpdatingIndicator()
                          : _ActionsMenu(
                              profile: profile,
                              onUpdate: onUpdate,
                              onDelete: onDelete,
                            ),
                    ),
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

GlassMenuItem _menuItem(
  BuildContext context, {
  required String title,
  required VoidCallback onTap,
  List<List<dynamic>>? icon,
  String? subtitle,
  Widget? trailing,
  bool isSelected = false,
  bool isDestructive = false,
}) {
  final colorScheme = context.colorScheme;
  final textTheme = context.textTheme;
  final color = isDestructive ? colorScheme.error : colorScheme.onSurface;
  return GlassMenuItem(
    title: title,
    subtitle: subtitle,
    // Two-line row: the package's own 44pt default fits the title only.
    height: subtitle == null ? 44 : 56,
    icon: icon == null ? null : HugeIcon(icon: icon, size: 20, color: color),
    iconColor: color,
    titleStyle: textTheme.bodyLarge?.copyWith(color: color),
    subtitleStyle: textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    trailing: trailing,
    isSelected: isSelected,
    isDestructive: isDestructive,
    onTap: onTap,
  );
}

/// Subscription name that morphs into the list of subscriptions. Selecting
/// one switches the active subscription.
class _ProfileSwitcher extends StatelessWidget {
  const _ProfileSwitcher({
    required this.profile,
    required this.profiles,
    required this.onSelect,
    required this.onAdd,
  });

  final Profile profile;
  final List<Profile> profiles;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GlassMenu(
      trigger: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: EmojiText(
              profile.serviceName,
              style: context.textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      items: [
        for (final item in profiles)
          _menuItem(
            context,
            title: item.serviceName,
            isSelected: item.id == profile.id,
            trailing: item.id == profile.id
                ? HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 18,
                    color: colorScheme.primary,
                  )
                : null,
            onTap: () => onSelect(item.id),
          ),
        _menuItem(
          context,
          title: appLocalizations.addSubscription,
          icon: HugeIcons.strokeRoundedAdd01,
          onTap: onAdd,
        ),
      ],
      menuAlignment: GlassMenuAlignment.topLeft,
      autoAdjustToScreen: true,
      menuWidth: 280,
      settings: Lumina.liquidMenu,
      quality: Lumina.liquidOverlayQuality,
      selectionColor: colorScheme.primary.opacity15,
      glowColor: colorScheme.primary,
    );
  }
}

/// Stand-in for «⋯» while the subscription updates: the same 32px circle
/// with a spinner, so the hero doesn't jump.
class _UpdatingIndicator extends StatelessWidget {
  const _UpdatingIndicator();

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 40,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lumina.surface5.opacity60,
              border: Border.all(
                color: context.colorScheme.outlineVariant.opacity50,
                width: 0.5,
              ),
            ),
            child: const SizedBox.square(
              dimension: 32,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
}

/// «⋯» actions of the shown subscription: update, provider support, delete.
class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.profile,
    required this.onUpdate,
    required this.onDelete,
  });

  final Profile profile;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final supportUrl = profile.providerHeaders['support-url'];
    final hasSupport = supportUrl != null && supportUrl.isNotEmpty;
    final updated = profile.lastUpdateDate?.lastUpdateTimeDesc;
    return GlassMenu(
      // Builder + opaque detector: the whole 40×40 box is the hit target,
      // not just the glyph's painted pixels.
      triggerBuilder: (_, toggle) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: SizedBox.square(
          dimension: 40,
          // Filled circle keeps the glyph legible over the provider logo
          // watermark (iOS «ellipsis.circle.fill»).
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Lumina.surface5.opacity60,
                border: Border.all(
                  color: colorScheme.outlineVariant.opacity50,
                  width: 0.5,
                ),
              ),
              child: SizedBox.square(
                dimension: 32,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreHorizontal,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      items: [
        _menuItem(
          context,
          title: appLocalizations.update,
          subtitle: updated == null || updated.isEmpty
              ? null
              : '${appLocalizations.updated} $updated',
          icon: HugeIcons.strokeRoundedRefresh,
          onTap: onUpdate,
        ),
        if (hasSupport)
          _menuItem(
            context,
            title: appLocalizations.support,
            icon: supportUrl.toLowerCase().contains('t.me')
                ? HugeIcons.strokeRoundedTelegram
                : HugeIcons.strokeRoundedCustomerSupport,
            onTap: () => globalState.openUrl(supportUrl),
          ),
        _menuItem(
          context,
          title: appLocalizations.delete,
          icon: HugeIcons.strokeRoundedDelete02,
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
      menuAlignment: GlassMenuAlignment.topRight,
      autoAdjustToScreen: true,
      menuWidth: 240,
      settings: Lumina.liquidMenu,
      quality: Lumina.liquidOverlayQuality,
      selectionColor: colorScheme.primary.opacity15,
      glowColor: colorScheme.primary,
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────────

/// Card substrate, identical to the dashboard subscription card's glass.
/// Its Material clips the ink of the rows inside to the card shape.
class _LiquidCard extends StatelessWidget {
  const _LiquidCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GlassCard(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: Lumina.radiusLg),
        settings: Lumina.liquidCard,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Lumina.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
}

/// One settings-style row of the grouped card: icon, title, trailing.
class _LiquidTile extends StatelessWidget {
  const _LiquidTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 22,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: title),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS grouped-list separator.
class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        indent: indent,
        color: context.colorScheme.outlineVariant.opacity50,
      );
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        size: 18,
        color: context.colorScheme.onSurfaceVariant,
      );
}

/// Latency pill, same look as `ProxySelectorRow`.
class _DelayBadge extends ConsumerWidget {
  const _DelayBadge({required this.proxyName, required this.testUrl});

  final String proxyName;
  final String? testUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(
      getDelayProvider(proxyName: proxyName, testUrl: testUrl),
    );
    final label = utils.delayBadgeLabel(delay);
    if (label == null) return const SizedBox.shrink();
    final color = utils.getDelayColor(delay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Country sheet ─────────────────────────────────────────────────────────

/// Members of the primary router as a plain grouped list. Picking a row
/// selects it in the core and reports it back so the page applies the mode.
class _CountrySheet extends ConsumerStatefulWidget {
  const _CountrySheet({
    required this.routerName,
    required this.selectedName,
    required this.onPicked,
  });

  final String routerName;
  final String selectedName;
  final void Function(String name, {required bool isAggregate}) onPicked;

  @override
  ConsumerState<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends ConsumerState<_CountrySheet> {
  @override
  void initState() {
    super.initState();
    // Latency probe, once per opening (same as ProxySelectorSheet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final group = ref.read(groupsProvider).getGroup(widget.routerName);
      if (group == null || group.all.isEmpty) return;
      unawaited(delayTest(group.all, group.testUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final group = groups.getGroup(widget.routerName);
    final groupNames = aggregateGroupNames(groups);
    final members = group?.all ?? const <Proxy>[];
    final selectedName = group == null
        ? widget.selectedName
        : group.resolveSelectedName(
            ref.watch(getProxyNameProvider(group.name)) ?? '',
          );

    return ListView.separated(
      // Hugs its rows inside the sheet's max-height box: few countries give
      // a short sheet, many scroll.
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length,
      separatorBuilder: (_, __) => const _Hairline(),
      itemBuilder: (context, index) {
        final proxy = members[index];
        return _CountryRow(
          proxy: proxy,
          testUrl: group?.testUrl,
          isSelected: proxy.name == selectedName,
          onTap: () {
            globalState.appController
              ..updateCurrentSelectedMap(widget.routerName, proxy.name)
              ..changeProxyDebounce(widget.routerName, proxy.name);
            widget.onPicked(
              proxy.name,
              isAggregate: isAggregateMember(
                proxyName: proxy.name,
                routerName: widget.routerName,
                allGroupNames: groupNames,
              ),
            );
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

/// iOS grouped-list row: no card, no fill, check mark trailing.
class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.proxy,
    required this.testUrl,
    required this.isSelected,
    required this.onTap,
  });

  final Proxy proxy;
  final String? testUrl;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiText(
                    proxy.name,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    proxy.type,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DelayBadge(proxyName: proxy.name, testUrl: testUrl),
            if (isSelected) ...[
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 20,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
