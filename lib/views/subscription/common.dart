import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Readiness gate for the modes tab: resolves when the current profile's
/// config has been loaded, and carries the load error when it has not.
///
/// The modes tab renders from `profile` (work mode, id); the three `AsyncValue`
/// states tell it whether the config is loading, broken or available. The one
/// value it carries is whether the full-tunnel choice applies to this config
/// ([fullTunnelAvailable] over the SAVED, unpatched file, so it stays stable
/// while full tunnel is on). Anything else that needs the parsed config
/// (country pools, smart availability) reads it where it is used.
///
/// Keyed by profile id so a profile switch re-reads the right config.
final modeProfileDataProvider =
    FutureProvider.autoDispose.family<({bool fullTunnelAvailable}), String>(
  (ref, profileId) async {
    // Re-evaluate when THIS profile's subscription is updated: getProfileConfig
    // reads the saved file, whose content changes on update while `profileId`
    // (the family key) does NOT — without this watch the provider would keep a
    // stale (possibly mid-update empty) result, which is what made the country
    // list transiently vanish after a refresh. `lastUpdateDate` changes on every
    // successful update; `providerHeaders` covers a provider-header flip.
    ref.watch(profilesProvider.select((profiles) {
      final p = profiles.getProfile(profileId);
      return (p?.lastUpdateDate, p?.providerHeaders.length);
    }));
    // Also what makes the tab wait (loading) and surfaces a broken profile
    // (error).
    final config = await globalState.getProfileConfig(profileId);
    return (fullTunnelAvailable: fullTunnelAvailable(config));
  },
);
