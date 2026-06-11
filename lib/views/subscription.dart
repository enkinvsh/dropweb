import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/work_mode_patch.dart';
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
/// - [countries]: flag-emoji → node names (plus the no-flag `''` bucket),
///   produced by [groupNodesByCountry] over [interceptLeafNodes] (rule-group
///   leaves only — the disconeko SOS pool baked into raw `proxies` is excluded
///   so the picker shows only panel-curated countries);
/// - [hasSmartCandidates]: whether the smart «Умный» group will be injectable
///   (a primary router exists AND resolves to ≥1 leaf node). Smart mode is
///   unavailable otherwise — matches [smartGroupWillInject], the exact
///   condition the work-mode patch uses to inject.
class _ModeProfileData {
  const _ModeProfileData({
    required this.countries,
    required this.nodeServers,
    required this.hasSmartCandidates,
  });

  final Map<String, List<String>> countries;

  /// node name → its `server` address (IP or host), for the strict-node list.
  final Map<String, String> nodeServers;
  final bool hasSmartCandidates;
}

/// File-scoped: only the modes tab consumes this. Keyed by profile id so a
/// profile switch re-reads the right config.
final _modeProfileDataProvider =
    FutureProvider.autoDispose.family<_ModeProfileData, String>(
  (ref, profileId) async {
    final cfg = await globalState.getProfileConfig(profileId);
    // Country candidates come from the rule-group leaves only (same structurally
    // SOS-free set as Smart) — NOT raw cfg['proxies'], which carries the
    // disconeko emergency pool. Otherwise the picker would surface SOS flags
    // (🇷🇺/🇬🇧/…) the panel subscription never offers. `interceptLeafNodes`
    // resolves rules from either the 'rules' or 'rule' key (`_resolveRules`),
    // and getProfileConfig output uses 'rules'.
    final nodeServers = <String, String>{};
    final proxies = cfg['proxies'];
    if (proxies is List) {
      for (final p in proxies) {
        if (p is Map && p['name'] != null && p['server'] != null) {
          nodeServers[p['name'].toString()] = p['server'].toString();
        }
      }
    }
    return _ModeProfileData(
      countries: groupNodesByCountry(interceptLeafNodes(cfg)),
      nodeServers: nodeServers,
      hasSmartCandidates: smartGroupWillInject(cfg),
    );
  },
);

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
    String? staticStrictNode,
  }) async {
    setState(() => _applying = true);
    try {
      await globalState.appController.applyWorkMode(
        mode,
        staticCountry: staticCountry,
        staticStrictNode: staticStrictNode,
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
        body: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const _RulesProxiesView(),
        ),
      ),
    );
  }

  /// Deep screen for «Страна»: full-page country picker (mirrors how
  /// [AddProfileView] is opened — [showExtend] + [AdaptiveSheetScaffold]).
  /// Selecting a country applies [WorkMode.country] through [_apply] (so the
  /// applying-state guard still covers the modes tab on return).
  void _openCountryDeep(Profile profile) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.workModeCountry,
        body: _CountryDeepView(
          profileId: profile.id,
          onApply: (country, strictNode) => _apply(
            WorkMode.country,
            staticCountry: country,
            staticStrictNode: strictNode,
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

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => NullStatus(label: appLocalizations.nullProfileDesc),
      data: (data) {
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
              onChevronTap: _openServersAndGroups,
            ),
            const SizedBox(height: 16),
            // «Умный»: no deep, no chevron.
            _ModeCard(
              icon: HugeIcons.strokeRoundedArtificialIntelligence01,
              title: appLocalizations.workModeSmart,
              description: appLocalizations.workModeSmartDesc,
              isSelected: profile.workMode == WorkMode.smart,
              enabled: data.hasSmartCandidates,
              onTap: () => _apply(WorkMode.smart),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            // «Игровой»: disabled, «скоро» badge, no chevron.
            _ModeCard(
              icon: HugeIcons.strokeRoundedGameController01,
              title: appLocalizations.workModeGaming,
              description: appLocalizations.workModeGamingDesc,
              isSelected: false,
              enabled: false,
              badge: CommonChip(label: appLocalizations.comingSoon),
              onTap: () {},
            ),
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
/// tapping the chevron fires [onChevronTap] (open deep). Disabled cards are
/// greyed with [DisabledMask] and never fire [onTap].
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.enabled = true,
    this.badge,
    this.onChevronTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? badge;
  final VoidCallback? onChevronTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = CommonCard(
      isSelected: isSelected,
      radius: Lumina.radiusLg,
      onPressed: enabled ? onTap : () {},
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
            if (onChevronTap != null) ...[
              const SizedBox(width: 8),
              _ChevronAffordance(onTap: onChevronTap!),
            ],
          ],
        ),
      ),
    );

    return enabled ? card : DisabledMask(child: card);
  }
}

/// Trailing «провалиться в deep-экран» affordance. A nested [InkWell] so the
/// chevron tap wins the gesture arena over the card's own [CommonCard.onPressed]
/// (lets «Стандарт» distinguish select-mode from open-deep). Mirrors the
/// [ListItem] chevron visual (arrow-right glyph, onSurfaceVariant).
class _ChevronAffordance extends StatelessWidget {
  const _ChevronAffordance({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Lumina.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Deep screen for «Страна»: a full-page country picker (opened via
/// [showExtend]). Lists detected countries as [ListItem] rows (Twemoji flag +
/// node count); the active country is checkmarked. Below the list sits the
/// «Строгая нода» switch and — when ON for the active country — a node-picker
/// row. Tapping a country row applies the mode through [onApply] and pops back
/// to the modes tab; strict-node refinements apply in-place without popping.
class _CountryDeepView extends ConsumerStatefulWidget {
  const _CountryDeepView({
    required this.profileId,
    required this.onApply,
  });

  final String profileId;
  final void Function(String country, String? strictNode) onApply;

  @override
  ConsumerState<_CountryDeepView> createState() => _CountryDeepViewState();
}

class _CountryDeepViewState extends ConsumerState<_CountryDeepView> {
  /// Local strict-node toggle override (null → derive from the profile).
  bool? _strictOn;

  

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentProfileProvider);
    final dataAsync = ref.watch(_modeProfileDataProvider(widget.profileId));

    if (profile == null) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => NullStatus(label: appLocalizations.nullProfileDesc),
      data: (data) {
        final countryKeys =
            data.countries.keys.where((key) => key.isNotEmpty).toList();

        if (countryKeys.isEmpty) {
          return Center(
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
          );
        }

        final activeCountry = profile.staticCountry;
        final countryApplied = activeCountry != null &&
            activeCountry.isNotEmpty &&
            data.countries.containsKey(activeCountry);
        final strictOn = _strictOn ?? (profile.staticStrictNode != null);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final flag in countryKeys)
              ListItem(
                leading: SizedBox(
                  width: 24,
                  child: flag == activeCountry
                      ? HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          size: 18,
                          color: colorScheme.primary,
                        )
                      : null,
                ),
                horizontalTitleGap: 8,
                title: EmojiText(
                  '$flag  ${countryDisplayName(flag, data.countries[flag]!)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: flag == activeCountry
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: flag == activeCountry ? colorScheme.primary : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${data.countries[flag]!.length}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  final isActive = flag == activeCountry;
                  // New country → drop any strict node; same active country →
                  // keep the current strict pick. Stay on the screen (no pop):
                  // the user may want to toggle «Строгая нода» and pick a node
                  // for the country they just selected; they return manually.
                  final strictPick =
                      isActive && strictOn ? profile.staticStrictNode : null;
                  if (!isActive) setState(() => _strictOn = null);
                  widget.onApply(flag, strictPick);
                },
              ),
            // The no-flag bucket is shown last and is NOT selectable. Uses the
            // SAME trailing-count convention as the country rows for a uniform
            // list (label-only title + trailing count, not count-in-label).
            if (data.countries.containsKey(''))
              ListItem(
                horizontalTitleGap: 8,
                leading: const SizedBox(width: 24),
                title: Text(
                  appLocalizations.otherCountries,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  '${data.countries['']!.length}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (countryApplied) ...[
              const Divider(height: 0),
              ListItem.switchItem(
                title: Text(
                  appLocalizations.strictNode,
                  style: context.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  appLocalizations.strictNodeDesc,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                delegate: SwitchDelegate(
                  value: strictOn,
                  onChanged: (value) {
                    if (value) {
                      setState(() => _strictOn = true);
                    } else {
                      setState(() => _strictOn = false);
                      // Drop the strict node in-place (stay on the deep screen).
                      widget.onApply(activeCountry, null);
                    }
                  },
                ),
              ),
              // Inline node list (no extra modal): pick the strict node right
              // here. The country's flag is redundant inside its own section,
              // so node titles are shown flag-stripped; the FULL node name is
              // what gets applied.
              if (strictOn)
                for (final node in data.countries[activeCountry]!)
                  ListItem(
                    leading: SizedBox(
                      width: 24,
                      child: node == profile.staticStrictNode
                          ? HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              size: 18,
                              color: colorScheme.primary,
                            )
                          : null,
                    ),
                    horizontalTitleGap: 8,
                    title: EmojiText(
                      node,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: node == profile.staticStrictNode
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: node == profile.staticStrictNode
                            ? colorScheme.primary
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: data.nodeServers[node] != null
                        ? Text(
                            maskServerAddress(data.nodeServers[node]!),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    // Apply the picked node in-place (stay on the deep screen).
                    onTap: () => widget.onApply(activeCountry, node),
                  ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> _pingAllProxies(WidgetRef ref) async {
  final groups = ref.read(currentGroupsStateProvider).value;
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

class _RulesProxiesView extends ConsumerWidget {
  const _RulesProxiesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    return RefreshIndicator(
      onRefresh: () => _pingAllProxies(ref),
      color: colorScheme.primary,
      child: ListView.builder(
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openSelector(context),
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06)
            : null,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: utils.getDelayColor(delay)?.withValues(alpha: 0.15),
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
