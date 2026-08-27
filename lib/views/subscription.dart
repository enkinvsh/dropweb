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
                  child: GlassTabBar(
                    controller: _tabController,
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
