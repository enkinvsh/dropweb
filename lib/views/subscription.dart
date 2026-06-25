import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/common/smart_pool_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/profiles/profiles.dart' show ProfileItem;
import 'package:dropweb/views/proxies/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Profiles actions ──────────────────────────────────────────────────

  void _handleShowAddProfilePage() {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(context: context),
        title: appLocalizations.addProfile,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Lumina.void_ : Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: isDark,
      appBar: AppBar(
        title: Text(appLocalizations.subscription),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: MeshBackground()),
          Column(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GlassTabBar(
                  controller: _tabController,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  tabs: [
                    appLocalizations.workModes,
                    appLocalizations.profile,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const _ModesContent(),
                    _ProfilesContent(onAdd: _handleShowAddProfilePage),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Profiles content ──────────────────────────────────────────────────────

/// Refresh handler for the Profiles list pull-to-refresh.
///
/// If [current] is non-null, refreshes ONLY that profile — this is what
/// the user expects when they pull-to-refresh while viewing the active
/// subscription. Falls back to refreshing every profile when no current
/// profile is selected (first-time setup, profile just deleted, etc.).
///
/// IMPORTANT: do NOT branch on `Profile.type`. After the URL-encryption
/// migration, `profile.url` is stripped to `''` in memory and the real
/// URL lives in the encrypted store; `Profile.update()` resolves it
/// lazily. The `type` getter therefore reports `ProfileType.file` for
/// every URL subscription post-migration, and an `if file → return`
/// guard would silently no-op every refresh on real users (the bug we
/// just fixed). If a profile genuinely has no URL anywhere, [update]
/// throws and we surface the failure through the same path as any other
/// error.
Future<void> _refreshProfiles(BuildContext context, [Profile? current]) async {
  final controller = globalState.appController;
  // Fire the refresh cue up-front so the user gets immediate feedback,
  // mirroring the dashboard pull-to-refresh behavior. Fire-and-forget:
  // `playUiSound` never throws, and we must not block the network work.
  unawaited(App().playUiSound(DropwebSoundCue.subscriptionRefresh));
  if (current != null) {
    controller.setProfile(current.copyWith(isUpdating: true));
    try {
      await controller.updateProfile(current);
    } catch (e) {
      controller.setProfile(current.copyWith(isUpdating: false));
      if (context.mounted) {
        globalState.showMessage(
          title: appLocalizations.tip,
          message: TextSpan(
            text: "${current.label ?? current.id}: $e",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      }
    }
    return;
  }
  final profiles = globalState.config.profiles;
  final messages = <String>[];
  // ROBUSTNESS: `eagerError: false` — if one profile's update throws, the
  // others should still complete. Default Future.wait fails the whole
  // group on the first error, which previously meant a single broken
  // subscription could leave the rest stuck in `isUpdating=true`.
  await Future.wait(
    profiles.map((profile) async {
      controller.setProfile(profile.copyWith(isUpdating: true));
      try {
        await controller.updateProfile(profile);
      } catch (e) {
        messages.add("${profile.label ?? profile.id}: $e \n");
        controller.setProfile(profile.copyWith(isUpdating: false));
      }
    }),
    eagerError: false,
  );
  if (messages.isNotEmpty && context.mounted) {
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        children: [
          for (final msg in messages)
            TextSpan(text: msg, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ProfilesContent extends ConsumerStatefulWidget {
  final VoidCallback onAdd;
  const _ProfilesContent({required this.onAdd});

  @override
  ConsumerState<_ProfilesContent> createState() => _ProfilesContentState();
}

class _ProfilesContentState extends ConsumerState<_ProfilesContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final state = ref.watch(profilesSelectorStateProvider);
    final current = ref.watch(currentProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _AddProfileCard(onTap: widget.onAdd, isDark: isDark),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshProfiles(context, current),
      color: colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        children: [
          Grid(
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            crossAxisCount: state.columns,
            children: [
              for (int i = 0; i < state.profiles.length; i++)
                GridItem(
                  child: ProfileItem(
                    key: Key(state.profiles[i].id),
                    profile: state.profiles[i],
                    groupValue: state.currentProfileId,
                    onChanged: (id) {
                      ref.read(currentProfileIdProvider.notifier).value = id;
                      globalState.appController.handleChangeProfile();
                    },
                  ),
                ),
              GridItem(
                child: _AddProfileCard(onTap: widget.onAdd, isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _AddProfileCard({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Lumina.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Lumina.radiusLg),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Work modes content ────────────────────────────────────────────────────

/// Parsed work-mode inputs for the current profile, read from the profile's
/// resolved config so they reflect the actual subscription nodes:
/// - [countries]: flag-emoji → node names (flagless nodes appear as their own
///   single-node groups keyed by node name, see [groupNodesByCountry]),
///   produced over [interceptLeafNodes] (rule-group leaves only — the
///   disconeko SOS pool baked into raw `proxies` is excluded so the picker
///   shows only panel-curated countries);
/// - [hasSmartCandidates]: whether the smart «Умный» group will be injectable
///   (a primary router exists AND resolves to ≥1 leaf node). Smart mode is
///   unavailable otherwise — matches [smartGroupWillInject], the exact
///   condition the work-mode patch uses to inject.
class _ModeProfileData {
  const _ModeProfileData({
    required this.countries,
    required this.hasSmartCandidates,
  });

  final Map<String, List<String>> countries;
  final bool hasSmartCandidates;
}

/// File-scoped: only the modes tab consumes this. Keyed by profile id so a
/// profile switch re-reads the right config.
final _modeProfileDataProvider =
    FutureProvider.autoDispose.family<_ModeProfileData, String>(
  (ref, profileId) async {
    // Re-evaluate when THIS profile's subscription is updated: getProfileConfig
    // reads the saved file, whose content changes on update while `profileId`
    // (the family key) does NOT — without this watch the provider would keep a
    // stale (possibly mid-update empty) result, which is what made the country
    // list transiently vanish after a refresh. `lastUpdateDate` changes on every
    // successful update; `providerHeaders` covers a disconeko-header flip.
    ref.watch(profilesProvider.select((profiles) {
      final p = profiles.getProfile(profileId);
      return (p?.lastUpdateDate, p?.providerHeaders.length);
    }));
    final cfg = await globalState.getProfileConfig(profileId);
    // Country candidates come from the rule-group leaves only (same structurally
    // SOS-free set as Smart) — NOT raw cfg['proxies'], which carries the
    // disconeko emergency pool. Otherwise the picker would surface SOS flags
    // (🇷🇺/🇬🇧/…) the panel subscription never offers. `interceptLeafNodes`
    // resolves rules from either the 'rules' or 'rule' key (`_resolveRules`),
    // and getProfileConfig output uses 'rules'.
    return _ModeProfileData(
      countries: groupNodesByCountry(interceptLeafNodes(cfg)),
      hasSmartCandidates: smartGroupWillInject(cfg),
    );
  },
);

/// Runs a through-proxy delay test on [nodeNames] (resolved to live proxy
/// objects from the running core's groups state, via the [delayTest] primitive
/// with the app's default test URL). Populates the global delay state; callers
/// read liveness back via [getDelayProvider].
Future<void> _runCountryDelayTest(Ref ref, Set<String> nodeNames) async {
  if (nodeNames.isEmpty) return;
  final groups = ref.read(currentGroupsStateProvider).value;
  final proxies = <Proxy>[];
  final seen = <String>{};
  for (final group in groups) {
    for (final proxy in group.all) {
      if (nodeNames.contains(proxy.name) && seen.add(proxy.name)) {
        proxies.add(proxy);
      }
    }
  }
  if (proxies.isEmpty) return;
  await delayTest(proxies, null);
}

/// Resolves the country picker's liveness and returns the set of node names that
/// are ALIVE (delay > 0). The picker renders the SETTLED list from this in one
/// pass (skeleton → crossfade → complete list) — the canonical «load, then show
/// a stable list» pattern, no incremental row-by-row insertion (that was the
/// first-open jerkiness). It also populates the global delay state
/// ([getDelayProvider]) as a side effect so each row's latency badge is filled.
///
/// Always re-pings on (re)run — opening the picker and pull-to-refresh both
/// `invalidate`/`refresh` this, so latency is freshly measured (no stale cache).
/// First it waits (bounded) for the core to actually load THIS profile's nodes
/// (the core reloads asynchronously on a switch), then probes and AWAITS the
/// probe to completion (each node bounded by the core's per-node timeout): a
/// cold REALITY/gRPC handshake can take a few seconds on the first measure, so
/// capping early dropped real servers that then only appeared on the 2nd open.
/// Dead nodes (АВТО routers, decoys, anything mihomo can't dial) resolve to < 0
/// and are filtered out. During a re-run the picker keeps showing the PREVIOUS
/// alive set (cached in the widget), so the list stays stable while badges
/// refresh.
///
/// Watched by the modes tab (pre-warm) and the open picker; autoDispose +
/// family(profileId), kept alive while either watches it.
final _countryProbeProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, profileId) async {
  final data = await ref.watch(_modeProfileDataProvider(profileId).future);
  final names = {
    for (final e in countryPickerEntries(data.countries)) e.proxyName,
  };
  if (names.isEmpty) return const <String>{};

  Set<String> aliveSnapshot() => {
        for (final n in names)
          if ((ref.read(getDelayProvider(proxyName: n)) ?? 0) > 0) n,
      };

  // Wait (bounded ~3s) for the core groups to contain these nodes — after a
  // profile switch the core reloads asynchronously, so they can be missing for
  // a moment.

  var disposed = false;
  ref.onDispose(() => disposed = true);
  for (var i = 0; i < 20; i++) {
    if (disposed) return aliveSnapshot();
    final available = <String>{
      for (final g in ref.read(currentGroupsStateProvider).value)
        for (final p in g.all) p.name,
    };
    if (names.any(available.contains)) break;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  if (disposed) return aliveSnapshot();

  // One probe, awaited to COMPLETION (each node is already bounded by the
  // core's per-node timeout). A cold VLESS-REALITY / gRPC handshake can take a
  // few seconds on the FIRST measure, so an early cap dropped real servers that
  // then only showed up on the 2nd open. We wait for every node to resolve;
  // dead ones simply end up < 0 and are filtered out of the alive set.
  await _runCountryDelayTest(ref, names);
  return aliveSnapshot();
});

class _ModesContent extends ConsumerStatefulWidget {
  const _ModesContent();

  @override
  ConsumerState<_ModesContent> createState() => _ModesContentState();
}

class _ModesContentState extends ConsumerState<_ModesContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Applying a work mode is fast (a config rebuild). We disable the stack
  /// briefly so a double-tap can't race two applies.
  bool _applying = false;

  Future<void> _apply(
    WorkMode mode, {
    String? staticCountry,
  }) async {
    setState(() => _applying = true);
    try {
      await globalState.appController.applyWorkMode(
        mode,
        staticCountry: staticCountry,
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Deep screen for «Стандарт»: the existing proxies/groups UI
  /// ([_RulesProxiesView]) in a sheet — reuses the exact wiring the old
  /// bottom row used.
  void _openServersAndGroups() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.serversAndGroups,
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: const _RulesProxiesView(),
        ),
      ),
    );
  }

  /// Country picker: a popup modal sheet (same presentation as «Серверы и
  /// группы» — [showSheet] + [AdaptiveSheetScaffold], NOT a full-page push).
  /// Selecting a country applies [WorkMode.country] through [_apply] (so the
  /// applying-state guard still covers the modes tab) and closes the sheet.
  void _openCountryDeep(Profile profile) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.workModeCountry,
        // Adaptive: shrinkWrap content hugs the sheet to its height (few
        // countries → short, bottom-anchored sheet) capped at 85% where it
        // scrolls.
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: _CountryDeepView(
            profileId: profile.id,
            onApply: (country) => _apply(
              WorkMode.country,
              staticCountry: country,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }
    final dataAsync = ref.watch(_modeProfileDataProvider(profile.id));
    // Pre-warm country liveness while the user is on the mode cards, so the
    // picker opens onto an already-resolved (junk-free) list instead of
    // filtering visibly after open. Value ignored here — this only kicks off
    // (and keeps alive) the probe.
    ref.watch(_countryProbeProvider(profile.id));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => NullStatus(label: appLocalizations.nullProfileDesc),
      data: (_) {
        final stack = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // «Стандарт»: tap applies standard; chevron → «Серверы и группы».
            _ModeCard(
              icon: HugeIcons.strokeRoundedShield01,
              title: appLocalizations.workModeStandard,
              description: appLocalizations.workModeStandardDesc,
              isSelected: profile.workMode == WorkMode.standard,
              onTap: () => _apply(WorkMode.standard),
              // «Серверы и группы» (manual group/server picking) is only
              // meaningful in Standard mode → the chevron is tappable only when
              // Standard is the active mode; otherwise it's shown disabled.
              onChevronTap: profile.workMode == WorkMode.standard
                  ? _openServersAndGroups
                  : null,
              chevronDisabled: profile.workMode != WorkMode.standard,
            ),
            const SizedBox(height: 16),
            // «Умный» (Smart) is temporarily removed from the modes list and
            // will be reintroduced later. The WorkMode.smart code path stays
            // intact (work_mode_patch / detectPrimaryRouter / controller), only
            // the card is hidden for now.
            // «Страна»: selection requires a country → both card tap and
            // chevron open the deep country picker.
            _ModeCard(
              icon: HugeIcons.strokeRoundedGlobe02,
              title: appLocalizations.workModeCountry,
              description: appLocalizations.workModeCountryDesc,
              isSelected: profile.workMode == WorkMode.country,
              onTap: () => _openCountryDeep(profile),
              onChevronTap: () => _openCountryDeep(profile),
            ),
            // «Игровой» (Gaming): surfaced ONLY when the subscription advertises
            // gaming — gated by [gamingModeAvailableProvider] (true when the
            // profile's `dropweb-game` header parses to a valid URL). No deep
            // screen / chevron / badge: it's a real, enabled, selectable mode
            // whose nodes + rules come from the panel, so tapping just applies
            // it. The build path is fail-safe (silently falls back to standard
            // routing if gaming can't actually apply), so header-present ==
            // card-shown — no extra gate needed here.
            if (ref.watch(gamingModeAvailableProvider)) ...[
              const SizedBox(height: 16),
              _ModeCard(
                icon: HugeIcons.strokeRoundedGameController01,
                title: appLocalizations.workModeGaming,
                description: appLocalizations.workModeGamingDesc,
                isSelected: profile.workMode == WorkMode.gaming,
                onTap: () => _apply(WorkMode.gaming),
              ),
            ],
          ],
        );

        return IgnorePointer(
          ignoring: _applying,
          child: DisabledMask(status: _applying, child: stack),
        );
      },
    );
  }
}

/// A single work-mode card following the «case + deep» pattern. Composes
/// [CommonCard] (flagship radius + selected glow) with a leading [HugeIcon],
/// title/description, an optional [badge] (e.g. «скоро»), and — when the mode
/// has a deep screen — a trailing chevron affordance ([onChevronTap]) styled
/// like the [ListItem] chevron. Tapping the card fires [onTap] (select mode);
/// tapping the chevron fires [onChevronTap] (open deep).
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.onChevronTap,
    this.chevronDisabled = false,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? badge;
  final VoidCallback? onChevronTap;

  /// When true, the chevron is rendered but greyed and non-tappable (the deep
  /// screen is gated until this mode is selected — e.g. «Серверы и группы»
  /// only applies in Standard mode).
  final bool chevronDisabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = CommonCard(
      isSelected: isSelected,
      radius: Lumina.radiusLg,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: context.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onChevronTap != null || chevronDisabled) ...[
              const SizedBox(width: 8),
              _ChevronAffordance(
                onTap: onChevronTap,
                disabled: chevronDisabled,
              ),
            ],
          ],
        ),
      ),
    );

    return card;
  }
}

/// Trailing «провалиться в deep-экран» affordance. A nested [InkWell] so the
/// chevron tap wins the gesture arena over the card's own [CommonCard.onPressed]
/// (lets «Стандарт» distinguish select-mode from open-deep). Mirrors the
/// [ListItem] chevron visual (arrow-right glyph, onSurfaceVariant).
class _ChevronAffordance extends StatelessWidget {
  const _ChevronAffordance({this.onTap, this.disabled = false});

  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(Lumina.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: disabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Deep screen for «Страна»: a full-page country picker (opened via
/// [showExtend]). Lists detected countries as [ListItem] rows (Twemoji flag +
/// an availability delay badge — the same delay/ms surface the proxy-group
/// rows use); the active country is checkmarked. Tapping a country row applies
/// the mode through [onApply] (flag only) and pops back to the modes tab.
class _CountryDeepView extends ConsumerStatefulWidget {
  const _CountryDeepView({
    required this.profileId,
    required this.onApply,
  });

  final String profileId;
  final ValueChanged<String> onApply;

  @override
  ConsumerState<_CountryDeepView> createState() => _CountryDeepViewState();
}

class _CountryDeepViewState extends ConsumerState<_CountryDeepView> {
  /// One-shot guard: re-ping once when the picker opens so latency is freshly
  /// measured on open (the kept-alive probe would otherwise serve the modes-tab
  /// pre-warm result without re-testing).
  bool _autoPinged = false;

  /// Last settled ALIVE set — kept locally so the list stays stable across a
  /// re-ping (open / pull-to-refresh) regardless of how the AsyncValue reports
  /// the in-flight reload. `null` only before the very first settle.
  Set<String>? _lastAlive;

  /// Pull-to-refresh: re-run the probe (fresh ping) and await its settle so the
  /// [RefreshIndicator] spinner stays until measurements are in.
  Future<void> _refresh() async {
    ref.invalidate(_countryProbeProvider(widget.profileId));
    await ref.read(_countryProbeProvider(widget.profileId).future);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentProfileProvider);
    final dataAsync = ref.watch(_modeProfileDataProvider(widget.profileId));
    // Liveness probe (pre-warmed on the modes tab). During a re-ping (open /
    // pull-to-refresh) the AsyncValue RETAINS the previous alive set, so the
    // list stays stable while badges refresh — only `null` means «never settled».
    final probeAsync = ref.watch(_countryProbeProvider(widget.profileId));

    if (profile == null) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    // Auto-ping on open: force ONE fresh measurement when the picker opens (the
    // kept-alive provider would otherwise serve the pre-warm result untouched).
    if (!_autoPinged) {
      _autoPinged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(_countryProbeProvider(widget.profileId));
      });
    }

    final activeCountry = profile.staticCountry;

    Widget buildRow(CountryPickerEntry entry) => ListItem(
          // No reserved leading checkmark column: it skewed the row inset
          // (~48px left vs 16px right). The active row is marked by the primary
          // color + weight instead, keeping insets symmetric.
          title: EmojiText(
            // «<flag>  <name>»: a country/server row keeps its real flag.
            '${entry.flag}  ${entry.label}',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: entry.key == activeCountry
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: entry.key == activeCountry ? colorScheme.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _CountryAvailabilityBadge(proxyName: entry.proxyName),
          onTap: () {
            widget.onApply(entry.key);
            Navigator.of(context).pop();
          },
        );

    // The ALIVE set. Cache the last settled value locally so a re-ping (open /
    // pull-to-refresh) never flickers the list to skeleton — it keeps the
    // previous set until the new one settles, refreshing only the badges.
    // `null` only before the very first settle. Canonical «load → stable list».
    final live = probeAsync.valueOrNull;
    if (live != null) _lastAlive = live;
    final alive = _lastAlive;

    final Widget child;
    final String stateKey;
    if (dataAsync.hasError || probeAsync.hasError) {
      stateKey = 'error';
      child = NullStatus(label: appLocalizations.nullProfileDesc);
    } else if (dataAsync.isLoading || alive == null) {
      stateKey = 'skeleton';
      child = const _CountrySkeletonList();
    } else {
      // Only probe-confirmed-alive nodes survive (АВТО routers, decoys, anything
      // mihomo can't dial are dropped); the active selection is always kept.
      // Same-flag servers stay expanded (one row per server).
      final entries = [
        for (final entry
            in countryPickerEntries(dataAsync.requireValue.countries))
          if (entry.key == activeCountry || alive.contains(entry.proxyName))
            entry,
      ];
      if (entries.isEmpty) {
        stateKey = 'empty';
        child = RefreshIndicator(
          onRefresh: _refresh,
          color: colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 240,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    appLocalizations.countriesNotDetected,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        stateKey = 'list';
        child = RefreshIndicator(
          onRefresh: _refresh,
          color: colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, entry) in entries.indexed)
                  _RowReveal(
                    key: ValueKey(entry.key),
                    delay: Duration(milliseconds: i.clamp(0, 7) * 40),
                    child: buildRow(entry),
                  ),
              ],
            ),
          ),
        );
      }
    }

    return AnimatedSwitcher(
      duration: Lumina.luminaDuration,
      switchInCurve: Lumina.luminaCurve,
      switchOutCurve: Lumina.luminaCurve,
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}

/// Premium entrance for a country-picker row: it FADES in while gently RISING
/// into place (slide-up), on the Lumina motion tokens. The settled list mounts
/// all at once, and a small per-index [delay] staggers the rows into a cascade.
/// The slide is paint-only (no layout reflow), so the sheet stays put while rows
/// settle in. Keyed by entry so an already-shown row never re-animates on
/// rebuild.
class _RowReveal extends StatefulWidget {
  const _RowReveal(
      {super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_RowReveal> createState() => _RowRevealState();
}

class _RowRevealState extends State<_RowReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Lumina.luminaDuration,
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Lumina.luminaCurve);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(_curve);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Availability delay badge for a country row. Reuses the EXACT mechanism the
/// proxy-group rows use ([_ProxySelectorRow] / [_RulesGroupCard]):
/// [getDelayProvider] for the country's leaf node (default test URL),
/// [utils.delayBadgeLabel] for the ms label and [utils.getDelayColor] for the
/// tint. Renders nothing (a fixed-width spacer for alignment) until a delay
/// sample exists.
class _CountryAvailabilityBadge extends ConsumerWidget {
  const _CountryAvailabilityBadge({required this.proxyName});

  final String proxyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(getDelayProvider(proxyName: proxyName));
    final label = utils.delayBadgeLabel(delay);

    final Widget content;
    if (label == null) {
      // Probe still in flight (delay null = not measured yet, 0 = testing):
      // the latency «loads INSIDE the card» via a Lumina glass shimmer pill —
      // never a blocking overlay. The row itself is already visible.
      content = const _ShimmerBadge(key: ValueKey('loading'));
    } else {
      final delayColor = utils.getDelayColor(delay);
      content = Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: delayColor?.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: delayColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Smooth crossfade between the loading spinner and the resolved latency
    // badge (Lumina motion tokens) — the «smooth loading inside the card».
    return AnimatedSwitcher(
      duration: Lumina.luminaDuration,
      switchInCurve: Lumina.luminaCurve,
      switchOutCurve: Lumina.luminaCurve,
      child: content,
    );
  }
}

/// Lumina-styled loading skeleton for a latency badge: a dark glass pill with a
/// soft accent-glow band sweeping across it (the canonical sliding-LinearGradient
/// shimmer technique, driven on a repeating controller). Sized to match the
/// resolved latency pill so the row doesn't jump when it crossfades in.
class _ShimmerBadge extends StatefulWidget {
  const _ShimmerBadge({super.key});

  @override
  State<_ShimmerBadge> createState() => _ShimmerBadgeState();
}

class _ShimmerBadgeState extends State<_ShimmerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: _shimmerGradient(_controller.value),
            ),
          ),
        ),
      );
}

/// The Lumina shimmer fill: a dark-glass base with a soft accent-glow band that
/// [_SlideGradient] sweeps across as [t] runs 0→1. Shared by the latency-badge
/// shimmer and the country-list skeleton so they pulse identically.
LinearGradient _shimmerGradient(double t) => LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Lumina.surface3,
        Lumina.surface5,
        Color.lerp(Lumina.surface5, Lumina.glowAccent, 0.45)!,
        Lumina.surface5,
        Lumina.surface3,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      transform: _SlideGradient(t),
    );

/// Translates a gradient horizontally by [t] (0→1 sweeps the highlight band
/// from off-left to off-right across the painted bounds), turning a fixed
/// multi-stop gradient into a moving shimmer.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
}

/// Lumina loading skeleton for the country picker: a column of placeholder rows
/// (shimmer flag + name bar + latency pill) on a single shared controller, so
/// the user sees a premium loading state — never junk that pops in and out —
/// while the liveness probe resolves. No real (possibly-dead) node names are
/// rendered here.
class _CountrySkeletonList extends StatefulWidget {
  const _CountrySkeletonList();

  /// Placeholder row count — a typical short picker height; the sheet is
  /// scroll-capped anyway.
  static const int _rowCount = 7;

  @override
  State<_CountrySkeletonList> createState() => _CountrySkeletonListState();
}

class _CountrySkeletonListState extends State<_CountrySkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double t,
          {double? width, required double height, double radius = 6}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: _shimmerGradient(t),
        ),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _CountrySkeletonList._rowCount; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _bar(t, width: 30, height: 22, radius: 6),
                        const SizedBox(width: 16),
                        Expanded(child: _bar(t, height: 16)),
                        const SizedBox(width: 16),
                        _bar(t, width: 48, height: 22, radius: 8),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

Future<void> _pingAllProxies(WidgetRef ref) async {
  // Use the RAW groups (not currentGroupsState, which drops hidden:true groups)
  // so the disconeko 🧠 Smart pool is still delay-tested — otherwise the
  // 📶 First Available row (now = 🧠 Smart) loses its availability badge.
  final groups = ref.read(groupsProvider);
  final allProxies = <Proxy>[];
  final seenNames = <String>{};
  for (final group in groups) {
    for (final proxy in group.all) {
      if (!seenNames.contains(proxy.name)) {
        seenNames.add(proxy.name);
        allProxies.add(proxy);
      }
    }
  }
  if (allProxies.isNotEmpty) await delayTest(allProxies, null);
}

// ── Proxies view (shared across all 3 modes) ─────────────────────────────

class _RulesProxiesView extends ConsumerStatefulWidget {
  const _RulesProxiesView();

  @override
  ConsumerState<_RulesProxiesView> createState() => _RulesProxiesViewState();
}

class _RulesProxiesViewState extends ConsumerState<_RulesProxiesView> {
  bool _pingTriggered = false;

  @override
  Widget build(BuildContext context) {
    // Filter the disconeko 🧠 Smart pool out of the LIST (UI-only, by name) so
    // it is never a standalone selectable row — while it stays a real,
    // health-checked group in the config so 📶 First Available (which
    // references it) still auto-selects and shows its availability badge.
    final groups = ref
        .watch(currentGroupsStateProvider)
        .value
        .where((g) => g.name != disconekoSmartGroupName)
        .toList();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    // Populate availability badges on open (incl. the 🧠 Smart pool that backs
    // 📶 First Available), once per open — matching the old behavior where
    // badges showed immediately. Pull-to-refresh re-tests.
    if (!_pingTriggered) {
      _pingTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _pingAllProxies(ref));
    }

    return RefreshIndicator(
      onRefresh: () => _pingAllProxies(ref),
      color: colorScheme.primary,
      child: ListView.builder(
        // shrinkWrap so the sheet hugs its content (few groups → short sheet,
        // anchored to the bottom); the parent ConstrainedBox caps + scrolls.
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groups.length,
        itemBuilder: (_, index) => _RulesGroupCard(
            key: ValueKey(groups[index].name),
            group: groups[index],
            isDark: isDark),
      ),
    );
  }
}

class _RulesGroupCard extends ConsumerWidget {
  final Group group;
  final bool isDark;
  const _RulesGroupCard({super.key, required this.group, required this.isDark});

  void _openSelector(BuildContext context) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: group.name,
        body: _ProxySelectorSheet(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(getProxyNameProvider(group.name));
    final selectedName =
        proxyName != null && proxyName.isNotEmpty ? proxyName : group.realNow;
    final selectedProxy =
        group.all.where((p) => p.name == selectedName).firstOrNull;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        child: InkWell(
          onTap: () => _openSelector(context),
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lumina.radiusLg),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                if (group.icon.isNotEmpty && !group.icon.startsWith('http'))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: EmojiText(
                      group.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiText(
                        group.name,
                        style: context.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      EmojiText(
                        selectedProxy != null
                            ? '${selectedProxy.type} · $selectedName'
                            : selectedName.isNotEmpty
                                ? selectedName
                                : '...',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (selectedName.isNotEmpty)
                  Consumer(
                    builder: (context, ref, _) {
                      final delay = ref.watch(getDelayProvider(
                        proxyName: selectedName,
                        testUrl: group.testUrl,
                      ));
                      final label = utils.delayBadgeLabel(delay);
                      if (label == null) {
                        return const SizedBox(width: 48);
                      }
                      final delayColor = utils.getDelayColor(delay);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: delayColor?.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: delayColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 14,
                    color: isDark
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Proxy selector sheet ──────────────────────────────────────────────────

class _ProxySelectorSheet extends ConsumerWidget {
  final Group group;
  const _ProxySelectorSheet({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final proxyName = ref.watch(getProxyNameProvider(group.name));
    final selectedName =
        proxyName != null && proxyName.isNotEmpty ? proxyName : group.realNow;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: group.all.length,
        itemBuilder: (context, index) {
          final proxy = group.all[index];
          final isSelected = proxy.name == selectedName;
          return _ProxySelectorRow(
            proxy: proxy,
            testUrl: group.testUrl,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () {
              final appController = globalState.appController;
              appController.updateCurrentSelectedMap(
                group.name,
                proxy.name,
              );
              appController.changeProxyDebounce(
                group.name,
                proxy.name,
              );
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

class _ProxySelectorRow extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProxySelectorRow({
    required this.proxy,
    required this.testUrl,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: testUrl,
    ));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.08)
            : isDark
                ? Colors.white.withValues(alpha: 0.04)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lumina.radiusLg),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiText(
                        proxy.name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        proxy.type,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (utils.delayBadgeLabel(delay) != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          utils.getDelayColor(delay)?.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      utils.delayBadgeLabel(delay)!,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: utils.getDelayColor(delay),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass tab bar ─────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  final bool isDark;
  final ColorScheme colorScheme;
  final List<String> tabs;

  const _GlassTabBar({
    required this.controller,
    required this.isDark,
    required this.colorScheme,
    required this.tabs,
  });

  Widget _buildContent() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: isDark
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Lumina.radiusLg - 6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerHeight: 0,
        // Suppress the default Material ink ripple + hover/press overlay.
        // The Tab hit-rect is the full tab cell, which makes the default
        // overlay bleed into a rectangle that ignores the pill indicator's
        // border radius. The mode bottom bar uses GestureDetector and
        // doesn't have this problem; matching that visual contract here.
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: [for (final label in tabs) Tab(text: label)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        boxShadow: isDark ? Lumina.glassShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        // BackdropFilter disabled for perf test
        child: _buildContent(),
      ),
    );
  }
}

// ── Shared body widgets for desktop pages ─────────────────────────────────

class SharedProxiesBody extends StatelessWidget {
  const SharedProxiesBody({super.key});

  @override
  Widget build(BuildContext context) {
    // The proxy/group list is the same regardless of work mode — mode only
    // changes mihomo routing, never the on-screen list. The rule/global mode
    // switch is gone (mode is now derived from the per-profile work mode).
    return const _RulesProxiesView();
  }
}

class SharedProfilesBody extends ConsumerWidget {
  const SharedProfilesBody({super.key});

  void _openAdd(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(context: context),
        title: appLocalizations.addProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesSelectorStateProvider);
    final current = ref.watch(currentProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child:
              _AddProfileCard(onTap: () => _openAdd(context), isDark: isDark),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshProfiles(context, current),
      color: colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        children: [
          Grid(
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            crossAxisCount: state.columns,
            children: [
              for (int i = 0; i < state.profiles.length; i++)
                GridItem(
                  child: ProfileItem(
                    key: Key(state.profiles[i].id),
                    profile: state.profiles[i],
                    groupValue: state.currentProfileId,
                    onChanged: (id) {
                      ref.read(currentProfileIdProvider.notifier).value = id;
                      globalState.appController.handleChangeProfile();
                    },
                  ),
                ),
              GridItem(
                child: _AddProfileCard(
                    onTap: () => _openAdd(context), isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
