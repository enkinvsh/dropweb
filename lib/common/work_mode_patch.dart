import 'package:dropweb/enum/enum.dart';

import 'country.dart';

/// Name of the additive smart auto-selecting group injected for [WorkMode.smart].
/// Distinct from `smart_pool_patch.dart`'s `🧠 Smart` (emergency-pool surface):
/// this is the user-facing "Умный" work mode the primary router is pointed at.
const workModeSmartGroupName = 'Умный';

/// Prefix for the additive per-country `fallback` group injected for
/// [WorkMode.country]. The full name is `Страна <flag-emoji>`.
const workModeCountryGroupPrefix = 'Страна';

/// Builds the full country-group name for the given flag-emoji key.
String workModeCountryGroupName(String flag) =>
    '$workModeCountryGroupPrefix $flag';

/// Additively patches a parsed Mihomo/Clash config [rawConfig] for the given
/// [workMode]. PURE: returns a new top-level map; the input map and its nested
/// lists/maps are never mutated.
///
/// This injects ONLY additive proxy-groups — it NEVER reshapes the panel
/// subscription's existing groups, rules or proxies. Mode selection and
/// `selectedMap` wiring are applied elsewhere (the controller), NOT here.
///
/// Semantics:
///   * [WorkMode.standard] / [WorkMode.gaming] — no-op (returns a shallow copy).
///   * [WorkMode.smart] — ensures an additive `Умный` group
///     (`type: smart`, `include-all: true`, `collectdata: false`) exists.
///   * [WorkMode.country] — ensures an additive `Страна <flag>` group
///     (`type: fallback`) whose members are exactly the subscription nodes of
///     [staticCountry] (the flag-emoji key, grouped via [groupNodesByCountry]).
///     When [staticCountry] is null/unknown or has no nodes, nothing is
///     injected (the caller is expected to have revalidated first).
///
/// Idempotent: re-applying never duplicates an already-present group.
Map<String, dynamic> applyWorkModePatch(
  Map<String, dynamic> rawConfig, {
  required WorkMode workMode,
  String? staticCountry,
}) {
  switch (workMode) {
    case WorkMode.standard:
    case WorkMode.gaming:
      return Map<String, dynamic>.from(rawConfig);
    case WorkMode.smart:
      return _injectGroup(
        rawConfig,
        workModeSmartGroupName,
        () => <String, dynamic>{
          'name': workModeSmartGroupName,
          'type': 'smart',
          'include-all': true,
          'collectdata': false,
        },
      );
    case WorkMode.country:
      if (staticCountry == null || staticCountry.isEmpty) {
        return Map<String, dynamic>.from(rawConfig);
      }
      final nodes = _countryNodes(rawConfig, staticCountry);
      if (nodes.isEmpty) {
        return Map<String, dynamic>.from(rawConfig);
      }
      return _injectGroup(
        rawConfig,
        workModeCountryGroupName(staticCountry),
        () => <String, dynamic>{
          'name': workModeCountryGroupName(staticCountry),
          'type': 'fallback',
          'url': 'https://cp.cloudflare.com/generate_204',
          'interval': 180,
          'lazy': true,
          'proxies': List<String>.from(nodes),
        },
      );
  }
}

/// Whether the `Страна <flag>` group will be PRESENT in [applyWorkModePatch]'s
/// output for the given [workMode]/[staticCountry] over [rawConfig] — i.e. it is
/// already defined, or it is injectable because the country has ≥1 matching
/// subscription node.
///
/// Returns false for non-country modes, a null/empty country, or a country with
/// no matching nodes and no pre-existing group. When this is false but the
/// profile's `selectedMap[GLOBAL]` points at that group, the Mihomo core does
/// NOT error: its GLOBAL selector silently falls back to its first proxy (see
/// `Selector.selectedProxy` → `proxies[0]`). This lets the config-build path log
/// the dangling-group case without re-parsing.
bool countryGroupWillInject(
  Map<String, dynamic> rawConfig, {
  required WorkMode workMode,
  String? staticCountry,
}) {
  if (workMode != WorkMode.country) return false;
  if (staticCountry == null || staticCountry.isEmpty) return false;
  final groupName = workModeCountryGroupName(staticCountry);
  final groups = rawConfig['proxy-groups'];
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == groupName) return true;
    }
  }
  return _countryNodes(rawConfig, staticCountry).isNotEmpty;
}

/// Returns the subscription node names (top-level `proxies[*].name`) that belong
/// to the country keyed by flag-emoji [flag], in subscription order.
List<String> _countryNodes(Map<String, dynamic> rawConfig, String flag) {
  final proxies = rawConfig['proxies'];
  if (proxies is! List) return const <String>[];
  final names = <String>[];
  for (final p in proxies) {
    if (p is Map && p['name'] != null) {
      names.add(p['name'].toString());
    }
  }
  return groupNodesByCountry(names)[flag] ?? const <String>[];
}

/// Returns a shallow copy of [rawConfig] whose `proxy-groups` list has the group
/// produced by [buildGroup] appended — unless a group named [groupName] already
/// exists, in which case the config is returned unchanged (a shallow copy).
///
/// Only the `proxy-groups` list is reallocated (copy + append); every existing
/// group entry is preserved by reference, so existing groups/rules/proxies stay
/// deep-equal to the input.
Map<String, dynamic> _injectGroup(
  Map<String, dynamic> rawConfig,
  String groupName,
  Map<String, dynamic> Function() buildGroup,
) {
  final result = Map<String, dynamic>.from(rawConfig);
  final groups = rawConfig['proxy-groups'];
  final newGroups = <dynamic>[];
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == groupName) {
        // Already present — idempotent no-op.
        return result;
      }
      newGroups.add(g);
    }
  }
  newGroups.add(buildGroup());
  result['proxy-groups'] = newGroups;
  return result;
}
