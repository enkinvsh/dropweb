import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';

/// Обновление подписок: меню дашборда, жест «потянуть» и кнопка в листе.
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
    // isUpdating toggles go through updateProfileById: it transforms the
    // CURRENT store value and never appends, so a failure can't write back
    // the stale `current` snapshot over concurrent edits or resurrect a
    // profile deleted during the fetch.
    controller.updateProfileById(
        current.id, (p) => p.copyWith(isUpdating: true));
    try {
      await controller.updateProfile(current);
    } catch (e) {
      commonPrint.log("$e");
      controller.updateProfileById(
          current.id, (p) => p.copyWith(isUpdating: false));
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
      controller.updateProfileById(
          profile.id, (p) => p.copyWith(isUpdating: true));
      try {
        await controller.updateProfile(profile);
      } catch (e) {
        commonPrint.log("$e");
        final message =
            ErrorMapper.mapError("$e") ?? appLocalizations.genericErrorMessage;
        messages.add("«${profile.label ?? profile.id}»: $message \n");
        controller.updateProfileById(
            profile.id, (p) => p.copyWith(isUpdating: false));
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
