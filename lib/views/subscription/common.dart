import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class ModeProfileData {
  const ModeProfileData({
    required this.countries,
    required this.hasSmartCandidates,
  });

  final Map<String, List<String>> countries;
  final bool hasSmartCandidates;
}

/// File-scoped: only the modes tab consumes this. Keyed by profile id so a
/// profile switch re-reads the right config.
final modeProfileDataProvider =
    FutureProvider.autoDispose.family<ModeProfileData, String>(
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
    // and getProfileConfig output uses 'rules'. Native Remnawave Hy2 nodes flow
    // through here as ordinary leaf nodes — no special-case overlay needed.
    return ModeProfileData(
      countries: groupNodesByCountry(interceptLeafNodes(cfg)),
      hasSmartCandidates: smartGroupWillInject(cfg),
    );
  },
);

