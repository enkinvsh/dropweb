import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';

import 'work_mode_patch.dart'
    show workModeCountryGroupPrefix, workModeSmartGroupName;

/// Whether a saved `selectedMap` value was written by the app's work-mode
/// wiring instead of being picked by the user.
///
/// `applyWorkMode` owns every entry pointing at the injected «Умный» / «Страна
/// <flag>» group: those express the active mode, so they must outlive a core
/// failover — forgetting one would silently unwire the mode until the user
/// re-applies it.
bool isWorkModeOwnedSelection(String selectedName) =>
    selectedName == workModeSmartGroupName ||
    selectedName.startsWith('$workModeCountryGroupPrefix ');

/// Group names whose saved pin the core has already abandoned.
///
/// A computed group (url-test / fallback / smart) drops its pinned member the
/// moment that member fails its health check: mihomo clears its own `selected`,
/// fails over to the next healthy member and reports `fixed: ""`. The profile
/// keeps the pin, so every later setup force-applies it again
/// (`patchSelectGroup` → `ForceSet`) and the UI keeps rendering a member the
/// core abandoned — the «залипание на мёртвом каскаде» symptom. Naming those
/// groups lets the caller forget the pin and follow the core again.
///
/// Deliberately left alone: selector groups (there the saved pin IS the routing
/// decision and mihomo reports no `fixed` at all), work-mode keys, empty pins,
/// and groups missing from the core snapshot.
Set<String> staleSelectedGroupNames({
  required List<Group> groups,
  required SelectedMap selectedMap,
}) {
  final stale = <String>{};
  for (final group in groups) {
    if (!group.type.isComputedSelected) continue;
    final pinned = selectedMap[group.name] ?? '';
    if (pinned.isEmpty || isWorkModeOwnedSelection(pinned)) continue;
    if (group.fixed.isEmpty) stale.add(group.name);
  }
  return stale;
}
