import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Readiness gate for the modes tab: resolves when the current profile's
/// config has been loaded, and carries the load error when it has not.
///
/// It intentionally yields NO value. The modes tab renders from `profile`
/// (work mode, id) alone; it only needs to know whether the profile's config
/// is still loading, failed to load, or is available — so the three
/// `AsyncValue` states ARE the payload. Anything that needs the parsed config
/// (country pools, smart availability) reads it where it is used, not here.
///
/// Keyed by profile id so a profile switch re-reads the right config.
final modeProfileDataProvider =
    FutureProvider.autoDispose.family<void, String>(
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
    // Awaited purely for its timing and its failure mode: this is what makes
    // the tab wait (loading) and what surfaces a broken profile (error). The
    // resolved config itself is deliberately discarded — no consumer reads it.
    await globalState.getProfileConfig(profileId);
  },
);

