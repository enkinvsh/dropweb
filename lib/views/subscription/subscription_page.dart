import 'dart:async';
import 'dart:math' as math;

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
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuAlignment;

// Merged «Подписка» page in the «LiquidLumina» style.
//
// Every control performs the real action of the old tabbed page: picking an
// exit applies the work mode (aggregate → Стандарт, country → Страна), the
// switch toggles full tunnel, and the hero switches / adds / updates /
// deletes subscriptions.
//
// On mobile the page is a glass sheet that morphs out of the dashboard
// subscription card; its cards are flat fills (glass is never nested in
// glass). On desktop it is a page with a glass hero and grouped card. The
// country picker stays an opaque Material sheet: a scrolling list over glass
// re-refracts every frame.

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
  const SubscriptionPage({super.key, this.inSheet = false});

  /// Presented inside the mobile glass sheet: no Scaffold, mesh or app bar,
  /// and flat cards — glass is never nested in glass, the sheet itself is
  /// the glass.
  final bool inSheet;

  /// На мобильном открывает стеклянный шит. С [origin] стекло растёт из
  /// источника (карточка подписки на дашборде или панель меню MENU) и
  /// возвращается в него при закрытии; без [origin] выезжает снизу. Шит один и
  /// тот же из любого входа: те же форма, высота, ручка и жест закрытия.
  /// На десктопе открывает страницу с zoom-переходом: с [source] страница
  /// вырастает из этой карточки (её собственная шапка встаёт ровно поверх
  /// неё) и сжимается обратно.
  ///
  /// Морф меряет источник в глобальных координатах, а масштабированный холст
  /// popover на macOS (500×800) их промахнул бы — одна из причин, почему
  /// десктоп остаётся на zoom-маршруте.
  static Future<void> open(
    BuildContext context, {
    BuildContext? source,
    GlassMorphOrigin? origin,
  }) {
    if (system.isDesktop) {
      return Navigator.of(context).push(
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
    }
    final height = _sheetHeight(context);
    return showGlassMorph<void>(
      context,
      GlassMorphSpec(
        source: origin?.rect,
        target: (size) => glassSheetTarget(size, height),
        ghost: origin?.ghost,
        ghostAlignment: origin?.ghostAlignment ?? Alignment.topLeft,
        hideSource: origin?.hide,
        closeOrigin: origin?.returnTo,
        // Внешний радиус и вложенные карточки подобраны концентрично:
        // 48 (внешний) - 16 (поле) = 32 у карточек внутри шита.
        fromRadius: origin?.radius ?? kLiquidSheetRadius,
        toRadius: kLiquidSheetRadius,
        fromSettings: origin?.settings ?? Lumina.liquidMenu,
        toSettings: Lumina.liquidMenu,
        dragToDismiss: true,
        showHandle: true,
        content: (_) => const SubscriptionPage(inSheet: true),
      ),
    );
  }

  /// GlassModalSheet can't size itself to its content, so the height is
  /// summed from the same constants the content uses. A small miss only
  /// shifts the bottom inset, because the content is a ListView.
  static double _sheetHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final state = ProviderScope.containerOf(context, listen: false)
        .read(profilesSelectorStateProvider);
    final profile = state.profiles.getProfile(state.currentProfileId) ??
        (state.profiles.isEmpty ? null : state.profiles.first);
    if (profile == null) return size.height * 0.45;
    final textTheme = context.textTheme;
    double line(TextStyle? style) => liquidLineHeight(context, style);

    // Hero: padding 12 + name row (≥ the 40px «⋯») + optional summary + 16.
    final hero = 12 +
        math.max(40.0, line(textTheme.headlineSmall)) +
        (profile.subscriptionInfo == null
            ? 0
            : 8 + line(textTheme.bodyMedium)) +
        16;
    // Grouped card: exit, full tunnel (Switch 48 + 24 padding), servers; two
    // hairlines. Assumes the tunnel row is present (its availability loads
    // async).
    final row = math.max(52.0, 24 + line(textTheme.bodyLarge));
    final rows = row + 1 + math.max(row, 72.0) + 1 + row;
    final content = kLiquidSheetTopInset +
        hero +
        12 +
        rows +
        kLiquidSheetBottomInset +
        MediaQuery.paddingOf(context).bottom;
    return math.min(content + kLiquidSheetBottomMargin, size.height * 0.85);
  }

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

    if (widget.inSheet) {
      // Без RefreshIndicator: жест вниз закрывает шит, обновление живёт в «⋯».
      return Material(
        type: MaterialType.transparency,
        child: profile == null
            ? NullStatus(label: appLocalizations.nullProfileDesc)
            : ListView(
                physics: const SheetFitPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  kLiquidSheetTopInset,
                  16,
                  kLiquidSheetBottomInset + padding.bottom,
                ),
                children: _buildSections(profile, profiles),
              ),
      );
    }

    return Scaffold(
      backgroundColor: Lumina.void_,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: system.showsPageHeader,
        title:
            system.showsPageHeader ? Text(appLocalizations.subscription) : null,
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
    // Внутри шита карточки концентричны его углам: радиусы 48 и 32.
    final cardRadius = widget.inSheet ? Lumina.radiusXl : Lumina.radiusLg;
    final bodyLarge = context.textTheme.bodyLarge?.copyWith(
      color: context.colorScheme.onSurface,
    );

    final rows = <Widget>[
      _buildExitTile(profile, routeData),
      if (fullTunnelAvailable)
        Semantics(
          identifier: 'dw_tunnel',
          child: LiquidTile(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            title: Text(appLocalizations.fullTunnelTitle, style: bodyLarge),
            trailing: Switch(
              value: profile.fullTunnel,
              onChanged: _setFullTunnel,
            ),
            onTap: () => _setFullTunnel(!profile.fullTunnel),
          ),
        ),
      LiquidTile(
        icon: HugeIcons.strokeRoundedServerStack01,
        title: Text(appLocalizations.serversAndGroups, style: bodyLarge),
        trailing: const LiquidChevron(),
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
        flat: widget.inSheet,
        radius: cardRadius,
      ),
      const SizedBox(height: 12),
      // Taps are held off while a mode/tunnel change applies, but the card is
      // not dimmed: the switch or the exit row already shows the change, and
      // a grey flash over the whole card read as a glitch.
      IgnorePointer(
        ignoring: _applying,
        child: LiquidCard(
          flat: widget.inSheet,
          radius: cardRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const LiquidHairline(indent: kLiquidDividerIndent),
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
      return LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: title(appLocalizations.genericErrorMessage),
      );
    }
    final data = routeData.valueOrNull;
    final routerName = data?.routerName;
    if (data != null && routerName == null) {
      return LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: title(appLocalizations.routeUndetected),
      );
    }
    final group = routerName == null
        ? null
        : ref.watch(groupsProvider).getGroup(routerName);
    if (group == null) {
      return LiquidTile(
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
      child: LiquidTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        title: titleWidget,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (proxy != null) ...[
              _DelayBadge(proxyName: proxy.name, testUrl: group.testUrl),
              const SizedBox(width: 8),
            ],
            const LiquidChevron(),
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
    this.flat = false,
    this.radius = Lumina.radiusLg,
  });

  final Profile profile;
  final List<Profile> profiles;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAdd;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final bool flat;
  final double radius;

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
    return LiquidCard(
      flat: flat,
      radius: radius,
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
                          ? const LiquidUpdatingIndicator()
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
          liquidMenuItem(
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
        liquidMenuItem(
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
    final supportUrl = profile.providerHeaders['support-url'];
    final hasSupport = supportUrl != null && supportUrl.isNotEmpty;
    final updated = profile.lastUpdateDate?.lastUpdateTimeDesc;
    return LiquidMoreMenu(
      items: [
        liquidMenuItem(
          context,
          title: appLocalizations.update,
          subtitle: updated == null || updated.isEmpty
              ? null
              : '${appLocalizations.updated} $updated',
          icon: HugeIcons.strokeRoundedRefresh,
          onTap: onUpdate,
        ),
        if (hasSupport)
          liquidMenuItem(
            context,
            title: appLocalizations.support,
            icon: supportUrl.toLowerCase().contains('t.me')
                ? HugeIcons.strokeRoundedTelegram
                : HugeIcons.strokeRoundedCustomerSupport,
            onTap: () => globalState.openUrl(supportUrl),
          ),
        liquidMenuItem(
          context,
          title: appLocalizations.delete,
          icon: HugeIcons.strokeRoundedDelete02,
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
    );
  }
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
      separatorBuilder: (_, __) => const LiquidHairline(),
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
