import 'package:dropweb/enum/enum.dart';

import 'country.dart';
import 'mihomo_yaml_splice.dart' show mihomoBuiltinTargets;
import 'smart_pool_patch.dart' show detectPrimaryRouter;

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
///   * [WorkMode.smart] — ensures an additive `Умный` group (`type: smart`,
///     `collectdata: false`) whose `proxies` are the LEAF nodes of the detected
///     primary router (see [_smartLeafNodes]); NEVER `include-all` (that would
///     enumerate the disconeko emergency pool `patchSmartPool` appends to
///     top-level `proxies`, leaking SOS nodes into normal routing — D1). It also
///     APPENDS `Умный` as the last member of that primary router so the core's
///     forced selection actually binds (`fast()`/selector honor a forced
///     `selected` ONLY among a group's own members — D2). When no router is
///     found or the leaf list resolves empty, nothing is injected (smart
///     unavailable; mirrors the country-no-nodes behavior).
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
      final primary =
          detectPrimaryRouter(rawConfig['proxy-groups'], rawConfig['rules']);
      if (primary == null) {
        return Map<String, dynamic>.from(rawConfig);
      }
      final leaves = _smartLeafNodes(rawConfig, primary);
      if (leaves.isEmpty) {
        // Smart unavailable (router resolves to no top-level leaf nodes) — inject
        // nothing, mirroring the country-no-nodes path.
        return Map<String, dynamic>.from(rawConfig);
      }
      return _injectSmartGroup(rawConfig, primary, leaves);
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

/// Whether the `Умный` smart group will be PRESENT in [applyWorkModePatch]'s
/// `WorkMode.smart` output over [rawConfig] — i.e. it is already defined, or it
/// is injectable because the detected primary router resolves to ≥1 leaf node
/// (see [_smartLeafNodes]).
///
/// Mirror of [countryGroupWillInject] for smart mode: lets the UI gate Smart
/// availability and the controller decide whether to wire `selectedMap`, using
/// EXACTLY the same condition the patch uses to inject — so the binding never
/// points at a group that was never created.
bool smartGroupWillInject(Map<String, dynamic> rawConfig) {
  final groups = rawConfig['proxy-groups'];
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == workModeSmartGroupName) {
        return true;
      }
    }
  }
  final primary = detectPrimaryRouter(groups, rawConfig['rules']);
  if (primary == null) return false;
  return _smartLeafNodes(rawConfig, primary).isNotEmpty;
}

/// Resolves the LEAF proxy nodes routed through the [primaryRouter] group of
/// [rawConfig] — the explicit membership for the injected `Умный` smart group.
///
/// Rules:
///   * Start from the primary router's `proxies` members.
///   * Keep entries that name a TOP-LEVEL proxy (`rawConfig['proxies'][*].name`),
///     skipping mihomo builtins (DIRECT/REJECT/…).
///   * If a member is itself a proxy-group, resolve it ONE level deep and keep
///     only its top-level-proxy members (nested groups at that depth are
///     dropped). Total resolution depth is capped at 2.
///   * De-duplicates while preserving first-seen order.
///
/// SOS / emergency-pool nodes that `patchSmartPool` appends to top-level
/// `proxies` are NEVER router members, so they are structurally excluded — no
/// name-regex filter (which is unreliable: SOS names collide with panel country
/// names) is needed.
List<String> _smartLeafNodes(
  Map<String, dynamic> rawConfig,
  String primaryRouter,
) {
  final groups = rawConfig['proxy-groups'];
  if (groups is! List) return const <String>[];

  // Top-level proxy names (the only valid leaf targets).
  final proxyNames = <String>{};
  final proxies = rawConfig['proxies'];
  if (proxies is List) {
    for (final p in proxies) {
      if (p is Map && p['name'] != null) {
        proxyNames.add(p['name'].toString());
      }
    }
  }

  // Group name -> member list (plain strings).
  final groupMembers = <String, List<String>>{};
  for (final g in groups) {
    if (g is! Map) continue;
    final name = g['name']?.toString();
    if (name == null) continue;
    final members = <String>[];
    final ps = g['proxies'];
    if (ps is List) {
      for (final m in ps) {
        if (m != null) members.add(m.toString());
      }
    }
    groupMembers[name] = members;
  }

  final leaves = <String>[];
  final seen = <String>{};
  void addLeaf(String name) {
    if (mihomoBuiltinTargets.contains(name)) return;
    if (!proxyNames.contains(name)) return;
    if (seen.add(name)) leaves.add(name);
  }

  for (final member in groupMembers[primaryRouter] ?? const <String>[]) {
    if (mihomoBuiltinTargets.contains(member)) continue;
    if (proxyNames.contains(member)) {
      addLeaf(member);
    } else if (groupMembers.containsKey(member)) {
      // One level deep only — keep its top-level-proxy members, drop nested
      // groups (depth cap 2).
      for (final inner in groupMembers[member]!) {
        addLeaf(inner);
      }
    }
    // else: dangling name (no proxy, no group) — drop.
  }
  return leaves;
}

/// Returns a shallow copy of [rawConfig] with two additive smart-mode edits to
/// `proxy-groups`:
///   1. appends the `Умный` smart group (members == [leaves]) unless present;
///   2. appends `Умный` as the LAST member of the [primaryRouter] group
///      (non-destructive copy; idempotent; never reorders/removes existing
///      members).
///
/// Because [applyWorkModePatch] is workMode-gated and runs per-setup, the
/// Standard/Country/Gaming setups never carry the appended router member — so
/// the router's url-test never races `Умный` outside Smart mode. Every other
/// group is preserved by reference (deep-equal to the input).
Map<String, dynamic> _injectSmartGroup(
  Map<String, dynamic> rawConfig,
  String primaryRouter,
  List<String> leaves,
) {
  final result = Map<String, dynamic>.from(rawConfig);
  final groups = rawConfig['proxy-groups'];
  final newGroups = <dynamic>[];
  var smartPresent = false;
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == workModeSmartGroupName) {
        smartPresent = true;
        newGroups.add(g);
        continue;
      }
      if (g is Map && g['name']?.toString() == primaryRouter) {
        newGroups.add(_withAppendedMember(g, workModeSmartGroupName));
        continue;
      }
      newGroups.add(g);
    }
  }
  if (!smartPresent) {
    newGroups.add(<String, dynamic>{
      'name': workModeSmartGroupName,
      'type': 'smart',
      'collectdata': false,
      'proxies': List<String>.from(leaves),
    });
  }
  result['proxy-groups'] = newGroups;
  return result;
}

/// Returns [group] with [member] appended to its `proxies` list — unless it is
/// already present, in which case [group] is returned unchanged by reference
/// (idempotent). The copy is non-destructive: the original member list is never
/// mutated and existing members keep their order.
Map _withAppendedMember(Map group, String member) {
  final ps = group['proxies'];
  final members = <dynamic>[];
  if (ps is List) {
    for (final m in ps) {
      members.add(m);
    }
    if (members.any((m) => m?.toString() == member)) {
      return group; // already a member — idempotent no-op.
    }
  }
  members.add(member);
  final copy = Map<String, dynamic>.from(group.cast<String, dynamic>());
  copy['proxies'] = members;
  return copy;
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
