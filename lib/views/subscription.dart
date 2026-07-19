import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/profiles/profiles.dart' show ProfileItem;
import 'package:dropweb/views/subscription/modes_content.dart';
import 'package:dropweb/views/subscription/profiles_content.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          DeferredPageBody(
            child: Column(
              children: [
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
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
                      const ModesContent(),
                      ProfilesContent(onAdd: _handleShowAddProfilePage),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return const RulesProxiesView();
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
          child: AddProfileCard(onTap: () => _openAdd(context), isDark: isDark),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => refreshProfiles(context, current),
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
                    },
                  ),
                ),
              GridItem(
                child: AddProfileCard(
                    onTap: () => _openAdd(context), isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
