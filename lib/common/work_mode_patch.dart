import 'package:dropweb/enum/enum.dart';

import 'country.dart';
import 'mihomo_yaml_splice.dart' show mihomoBuiltinTargets, ruleTarget;

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
///     (`type: fallback`) whose members are exactly the [interceptLeafNodes]
///     of [staticCountry] (the flag-emoji key, grouped via [groupNodesByCountry]
///     over the rule-group leaves — NOT the raw `proxies`, which carry the SOS
///     pool). When [staticCountry] is null/unknown or has no such nodes, nothing
///     is injected (the caller is expected to have revalidated first).
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
      // Bind «Умный» ONLY into the primary router (the catch-all MATCH target,
      // e.g. 🌍 VPN) — NOT into every rule-referenced group. Per-service groups
      // (YouTube / Discord / …) keep the panel template's own routing; only the
      // general «everything else» traffic is smart auto-selected.
      final primaryRouter = detectPrimaryRouter(rawConfig);
      if (primaryRouter == null) {
        return Map<String, dynamic>.from(rawConfig);
      }
      final leaves = _smartLeafNodes(rawConfig, primaryRouter);
      if (leaves.isEmpty) {
        // Smart unavailable (the primary router resolves to no top-level leaf
        // node) — inject nothing, mirroring the country-no-nodes path.
        return Map<String, dynamic>.from(rawConfig);
      }
      return _injectSmartGroup(rawConfig, [primaryRouter], leaves);
    case WorkMode.country:
      if (staticCountry == null || staticCountry.isEmpty) {
        return Map<String, dynamic>.from(rawConfig);
      }
      final nodes = _countryNodes(rawConfig, staticCountry);
      if (nodes.isEmpty) {
        return Map<String, dynamic>.from(rawConfig);
      }
      // Ensure the country fallback group (in-country failover safety net).
      // selectedMap[GLOBAL] is pointed at this group elsewhere (controller).
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
/// is injectable because the primary router ([detectPrimaryRouter]) resolves to
/// ≥1 leaf node (see [_smartLeafNodes]).
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
  final primaryRouter = detectPrimaryRouter(rawConfig);
  if (primaryRouter == null) return false;
  return _smartLeafNodes(rawConfig, primaryRouter).isNotEmpty;
}

/// Group names the `Умный` work mode must NEVER intercept: the emergency-pool
/// surface (`patchSmartPool`'s `🧠 Smart` smart group and its `📶 First
/// Available` fallback wrapper) and the injected `Умный` group itself. These
/// are excluded BY CONSTRUCTION (the SOS chain is never rule-referenced) — this
/// set is a belt-and-suspenders hard-exclude so a future template that DOES
/// rule-reference them still cannot leak SOS nodes into normal routing.
const _smartHardExcludedGroups = <String>{
  '🧠 Smart',
  '📶 First Available',
  workModeSmartGroupName,
};

/// Proxy-group `type`s the `Умный` work mode is allowed to intercept. A `smart`
/// group already rotates its own members, so it is never re-pointed;
/// relay/load-balance are out of scope per design (ИТЕРАЦИЯ 2).
const _smartInterceptableTypes = <String>{'select', 'url-test', 'fallback'};

/// Resolves the rules list from [rawConfig], accepting BOTH the parsed-config
/// key `rules` (used by `getProfileConfig` consumers and tests) AND `rule` (the
/// key the config-build path `patchRawConfig` has renamed it to by the time
/// [applyWorkModePatch] runs). Without this, smart-mode detection silently
/// no-ops in the real build path (where only `rule` is present).
Object? _resolveRules(Map<String, dynamic> rawConfig) =>
    rawConfig['rules'] ?? rawConfig['rule'];

/// The ordered set of proxy-groups the `Умный` work mode intercepts: EVERY
/// group that is directly rule-referenced AND can actually route proxied
/// traffic, smart-rotating all of them rather than only the primary router
/// (ИТЕРАЦИЯ 2). Returned in `proxy-groups` declaration order for determinism.
///
/// A group QUALIFIES iff:
///   * it is NOT in [_smartHardExcludedGroups] (the SOS chain / `Умный` itself);
///   * it is the TARGET of ≥1 rule (resolved via [ruleTarget]; builtin targets
///     like DIRECT/REJECT are ignored);
///   * its `type` is one of [_smartInterceptableTypes];
///   * it carries ≥1 member that is not a mihomo builtin (so it can route).
///
/// The SOS chain (`🧠 Smart` / `📶 First Available`) is excluded both because
/// it is never rule-referenced and via the explicit hard-exclude. Groups that
/// are only reachable as a MEMBER of another group (e.g. `🌀 Cascade`) are NOT
/// intercepted, but their leaf nodes still flow into the Country candidate pool
/// via [interceptLeafNodes]'s one-level resolution.
List<String> smartInterceptGroups(Map<String, dynamic> rawConfig) {
  final groups = rawConfig['proxy-groups'];
  final rules = _resolveRules(rawConfig);
  if (groups is! List || rules is! List) return const <String>[];

  final groupType = <String, String?>{};
  final groupMembers = <String, List<String>>{};
  final order = <String>[];
  for (final g in groups) {
    if (g is! Map) continue;
    final name = g['name']?.toString();
    if (name == null) continue;
    order.add(name);
    groupType[name] = g['type']?.toString();
    final members = <String>[];
    final ps = g['proxies'];
    if (ps is List) {
      for (final m in ps) {
        if (m != null) members.add(m.toString());
      }
    }
    groupMembers[name] = members;
  }

  // Group names that ≥1 rule directly targets (non-builtin, names a group).
  final referenced = <String>{};
  for (final rule in rules) {
    final target = ruleTarget(rule?.toString() ?? '');
    if (target == null) continue;
    if (mihomoBuiltinTargets.contains(target)) continue;
    if (!groupMembers.containsKey(target)) continue;
    referenced.add(target);
  }

  bool qualifies(String name) {
    if (_smartHardExcludedGroups.contains(name)) return false;
    if (!referenced.contains(name)) return false;
    if (!_smartInterceptableTypes.contains(groupType[name])) return false;
    final members = groupMembers[name] ?? const <String>[];
    return members.any((m) => !mihomoBuiltinTargets.contains(m));
  }

  return [
    for (final name in order)
      if (qualifies(name)) name
  ];
}

/// The PRIMARY router group the `Умный` work mode binds into: the catch-all
/// `MATCH` rule's target — the group all otherwise-unmatched traffic flows to,
/// i.e. the semantic "VPN" router — provided it is a qualifying intercept group
/// ([smartInterceptGroups]). NAME-AGNOSTIC: works whether the panel template
/// calls that group `🌍 VPN`, `PROXY`, `节点选择`, etc., because every
/// well-formed Mihomo config ends in a `MATCH` catch-all.
///
/// Falls back to the FIRST qualifying rule-referenced routable group (in
/// `proxy-groups` declaration order) when there is no `MATCH` rule, or it
/// targets a builtin / a non-intercept group. Returns null when nothing
/// qualifies (smart unavailable — mirrors the country-no-nodes path).
String? detectPrimaryRouter(Map<String, dynamic> rawConfig) {
  final qualifying = smartInterceptGroups(rawConfig);
  if (qualifying.isEmpty) return null;
  final qualifyingSet = qualifying.toSet();
  final rules = _resolveRules(rawConfig);
  if (rules is List) {
    for (final rule in rules) {
      final text = rule?.toString() ?? '';
      final fields = text.split(',');
      if (fields.isEmpty || fields.first.trim() != 'MATCH') continue;
      final target = ruleTarget(text);
      if (target != null && qualifyingSet.contains(target)) {
        return target;
      }
    }
  }
  return qualifying.first;
}

/// The de-duplicated UNION of the leaf nodes routed through EVERY
/// rule-referenced intercept group of [rawConfig] (see [smartInterceptGroups] /
/// [_smartLeafNodes]), in first-seen order.
///
/// This is the structurally-SOS-free candidate set Country mode draws from
/// (the node pool `groupNodesByCountry` buckets per flag). Smart mode no longer
/// uses this union — it sources its `Умный` membership from the primary router
/// alone (see [detectPrimaryRouter] / [_smartLeafNodes]).
///
/// disconeko / emergency-pool nodes that `patchSmartPool` appends to top-level
/// `proxies` are NEVER members of a rule-referenced group, so they are excluded
/// here by construction — closing the leak in which Country mode would otherwise
/// source candidates from the raw `proxies` list (which includes the SOS pool).
/// No name/flag regex is used (SOS names collide with real country names).
List<String> interceptLeafNodes(Map<String, dynamic> rawConfig) =>
    _unionLeafNodes(rawConfig, smartInterceptGroups(rawConfig));

/// The de-duplicated UNION of the leaf nodes resolved for each of the
/// already-computed [interceptGroups], in first-seen order. Internal helper for
/// callers that have the group list in hand (avoids recomputing it).
List<String> _unionLeafNodes(
  Map<String, dynamic> rawConfig,
  List<String> interceptGroups,
) {
  final leaves = <String>[];
  final seen = <String>{};
  for (final group in interceptGroups) {
    for (final leaf in _smartLeafNodes(rawConfig, group)) {
      if (seen.add(leaf)) leaves.add(leaf);
    }
  }
  return leaves;
}

/// Whether [proxy] (a top-level `proxies[]` entry) is a structurally routable
/// node, as opposed to a non-routable SENTINEL that Remnawave/xray-style panels
/// inject for expiry / device-limit / HWID-lock / bot-link states (e.g. a
/// 🇸🇴 «Подписка истекла» placeholder or a flagless «Докупите устройства»).
///
/// The check is provider-AGNOSTIC and structural — no name/flag regex: a real
/// proxy never points at `0.0.0.0`/loopback, a port ≤ 1, or the all-zero
/// VLESS/VMess UUID. Dropping these here keeps dead "countries" out of BOTH the
/// country picker candidate set and the injected Smart group, before any
/// liveness probe runs.
bool _isRoutableProxy(Map proxy) {
  final server = proxy['server']?.toString().trim() ?? '';
  if (server.isEmpty ||
      server == '0.0.0.0' ||
      server == '::' ||
      server == '127.0.0.1' ||
      server == '::1') {
    return false;
  }
  final rawPort = proxy['port'];
  final port =
      rawPort is int ? rawPort : int.tryParse(rawPort?.toString() ?? '');
  if (port != null && port <= 1) return false;
  final uuid = proxy['uuid']?.toString();
  if (uuid == '00000000-0000-0000-0000-000000000000') return false;
  return true;
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

  // Top-level proxy names (the only valid leaf targets), STRUCTURALLY ROUTABLE
  // ones only: non-routable sentinels (0.0.0.0 / port ≤ 1 / all-zero uuid the
  // panel injects for expiry / device-limit / HWID-lock) are dropped here so
  // they never reach the country picker NOR the Smart group (see
  // [_isRoutableProxy]). Decoy/meta crutches that LOOK valid are NOT name-matched
  // here — they share identical crypto with real nodes and can only be told
  // apart by an actual liveness probe (done non-blocking in the picker).
  final proxyNames = <String>{};
  final proxies = rawConfig['proxies'];
  if (proxies is List) {
    for (final p in proxies) {
      if (p is Map && p['name'] != null && _isRoutableProxy(p)) {
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
///   2. appends `Умный` as the LAST member of EACH group in [interceptGroups]
///      (non-destructive copy; idempotent; never reorders/removes existing
///      members).
///
/// Because [applyWorkModePatch] is workMode-gated and runs per-setup, the
/// Standard/Country/Gaming setups never carry the appended router member — so
/// the routers' url-test never race `Умный` outside Smart mode. Every group
/// NOT in [interceptGroups] is preserved by reference (deep-equal to the input).
Map<String, dynamic> _injectSmartGroup(
  Map<String, dynamic> rawConfig,
  List<String> interceptGroups,
  List<String> leaves,
) {
  final interceptSet = interceptGroups.toSet();
  final result = Map<String, dynamic>.from(rawConfig);
  final groups = rawConfig['proxy-groups'];
  final newGroups = <dynamic>[];
  var smartPresent = false;
  if (groups is List) {
    for (final g in groups) {
      final name = g is Map ? g['name']?.toString() : null;
      if (name == workModeSmartGroupName) {
        smartPresent = true;
        newGroups.add(g);
        continue;
      }
      if (name != null && interceptSet.contains(name)) {
        newGroups.add(_withAppendedMember(g as Map, workModeSmartGroupName));
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

/// Returns the candidate node names that belong to the country keyed by
/// flag-emoji [flag], in rule-group order.
///
/// Candidates are drawn from [interceptLeafNodes] — the nodes actually routed
/// through the rule-referenced groups — NOT from the raw top-level `proxies`
/// list. This is the structural fix for the disconeko leak: `patchSmartPool`
/// bakes ~57 SOS emergency nodes (with real country flags like 🇷🇺/🇬🇧) into
/// top-level `proxies`, so a raw-`proxies` source would let Country mode route
/// all traffic through the emergency pool. Those SOS nodes are never members of
/// a rule-referenced group, so this excludes them by construction.
/// [flag] may also be an exact node name (the picker offers same-flag servers
/// individually) — [resolveCountryKeyNodes] handles both key kinds.
List<String> _countryNodes(Map<String, dynamic> rawConfig, String flag) =>
    resolveCountryKeyNodes(interceptLeafNodes(rawConfig), flag);

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
