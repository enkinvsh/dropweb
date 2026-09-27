import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/profiles/profiles.dart' show ProfileItem;
import 'package:dropweb/views/subscription/profiles_content.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The mobile «Подписка» page lives in subscription/subscription_page.dart.

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
