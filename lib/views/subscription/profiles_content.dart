import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/profiles/profiles.dart' show ProfileItem;
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
Future<void> refreshProfiles(BuildContext context, [Profile? current]) async {
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
      commonPrint.log("$e");
      controller.setProfile(current.copyWith(isUpdating: false));
      if (context.mounted) {
        final message =
            ErrorMapper.mapError("$e") ?? appLocalizations.genericErrorMessage;
        globalState.showErrorMessage(
          title: appLocalizations.errorTitle,
          diagnosticPhase: 'profile-update',
          message: TextSpan(
            text: "${current.label ?? current.id}: $message",
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
        commonPrint.log("$e");
        final message =
            ErrorMapper.mapError("$e") ?? appLocalizations.genericErrorMessage;
        messages.add("«${profile.label ?? profile.id}»: $message \n");
        controller.setProfile(profile.copyWith(isUpdating: false));
      }
    }),
    eagerError: false,
  );
  if (messages.isNotEmpty && context.mounted) {
    globalState.showErrorMessage(
      title: appLocalizations.errorTitle,
      diagnosticPhase: 'profile-update',
      message: TextSpan(
        children: [
          for (final msg in messages)
            TextSpan(text: msg, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class ProfilesContent extends ConsumerStatefulWidget {
  final VoidCallback onAdd;
  const ProfilesContent({required this.onAdd});

  @override
  ConsumerState<ProfilesContent> createState() => _ProfilesContentState();
}

class _ProfilesContentState extends ConsumerState<ProfilesContent>
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
          child: AddProfileCard(onTap: widget.onAdd, isDark: isDark),
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
                child: AddProfileCard(onTap: widget.onAdd, isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const AddProfileCard({required this.onTap, required this.isDark});

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
