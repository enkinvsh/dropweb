// Pure injector for the «Игровой» (gaming) work mode.
//
// Builds the Hysteria2 proxies + the `🎮 Gaming` proxy-group and ADDITIVELY
// folds them into a parsed Mihomo config. Stays Flutter-free and dart:io-free
// (only `package:dropweb/common/...` pure imports) so it is trivially
// unit-testable and easy to audit.
//
// On 2.7.4 the panel's Mihomo subscription carries ZERO hysteria nodes
// (Remnawave does not render Hy2 for clash.meta), so the app injects them. The
// node specs (name + server + port + alpn) arrive via the panel-pushed
// `dropweb-xnodes` header (see [parseHy2NodeSpecs] in `hy2_overlay.dart`); the
// routing shape (group + rules) arrives via the pinned `game.yml` descriptor.
// The Hy2 password is the user's own vless uuid (proven e2e: Hy2
// `auth == vlessUuid`). Nodes are built via the shared [buildHy2Proxy] so the
// `🎮 Gaming` group and the all-modes overlay reference ONE proxy per node.
//
// This module is PURE — no I/O, no providers, no build-path wiring. The fetch /
// build-path glue (Фаза 6) consumes these functions; this file is the pure core
// only.

import 'game_descriptor.dart';
import 'hy2_overlay.dart' show Hy2NodeSpec, buildHy2Proxy;

/// Additively injects the gaming Hy2 proxies + the `🎮 Gaming` group into
/// [rawConfig]. PURE, IDEMPOTENT, ADDITIVE.
///
///   * No-op (returns a shallow copy) when [specs] is empty or [password] is
///     null/empty — gaming cannot work without nodes and a credential.
///   * Otherwise appends one [buildHy2Proxy] per spec to `proxies` (skipping any
///     name already present) and appends a group (named [descriptor].group.name,
///     of [descriptor].group.type, plus `url`/`interval`/`tolerance` when
///     non-null) to `proxy-groups`. The group references EVERY spec node — even
///     one whose proxy already existed (e.g. injected by the all-modes overlay,
///     which runs FIRST in the build path) — so both groups share ONE proxy.
///   * IDEMPOTENT: a Hy2 proxy whose name already exists is not re-added; the
///     group is skipped entirely when one with that name already exists (mirrors
///     `work_mode_patch.dart`'s skip-by-name pattern).
///   * The input map and its nested lists/maps are NEVER mutated — a new
///     top-level map is returned, and only the `proxies` / `proxy-groups` lists
///     that gain an entry are reallocated (existing entries kept by reference).
Map<String, dynamic> injectGamingProxies(
  Map<String, dynamic> rawConfig, {
  required GameDescriptor descriptor,
  required List<Hy2NodeSpec> specs,
  required String? password,
}) {
  final result = Map<String, dynamic>.from(rawConfig);
  if (specs.isEmpty || password == null || password.isEmpty) {
    return result;
  }

  // Append one Hy2 proxy per spec, skipping names already present (idempotent).
  final proxies = rawConfig['proxies'];
  final newProxies = <dynamic>[];
  final existingProxyNames = <String>{};
  if (proxies is List) {
    for (final p in proxies) {
      newProxies.add(p);
      if (p is Map && p['name'] != null) {
        existingProxyNames.add(p['name'].toString());
      }
    }
  }
  // Membership tracks ALL spec names (deduped, order-preserving). The proxy LIST
  // only grows for names not already present — the overlay may have injected
  // them first, but the group must still reference that shared proxy.
  final memberNames = <String>[];
  final memberSeen = <String>{};
  for (final spec in specs) {
    final name = spec.name;
    if (!memberSeen.add(name)) continue;
    memberNames.add(name);
    if (!existingProxyNames.contains(name)) {
      newProxies.add(buildHy2Proxy(spec, password));
    }
  }
  result['proxies'] = newProxies;

  // Append the gaming group unless one of that name already exists (idempotent).
  final groupName = descriptor.group.name;
  final groups = rawConfig['proxy-groups'];
  final newGroups = <dynamic>[];
  var groupPresent = false;
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == groupName) {
        groupPresent = true;
      }
      newGroups.add(g);
    }
  }
  if (!groupPresent) {
    final group = <String, dynamic>{
      'name': groupName,
      'type': descriptor.group.type,
      'proxies': List<String>.from(memberNames),
    };
    if (descriptor.group.url != null) group['url'] = descriptor.group.url;
    if (descriptor.group.interval != null) {
      group['interval'] = descriptor.group.interval;
    }
    if (descriptor.group.tolerance != null) {
      group['tolerance'] = descriptor.group.tolerance;
    }
    newGroups.add(group);
  }
  result['proxy-groups'] = newGroups;

  return result;
}

/// Applies the gaming routing shape (rule-providers + rules) from [descriptor]
/// onto [rawConfig]. PURE, ADDITIVE for providers, AUTHORITATIVE for rules.
///
///   * Rule-providers (additive merge): ensures a `rule-providers` map exists in
///     the result (a copy of the existing one, else a fresh `{}`); for each
///     entry in [descriptor].ruleProviders it is added under its key ONLY IF
///     that key is absent — a panel-defined provider is NEVER overwritten. No
///     `path` field is set (that is the build path's I/O concern).
///   * Rules (replace): sets `result['rule']` to a fresh copy of
///     [descriptor].rules and REMOVES any `result['rules']` key. The build path
///     renames `rules`→`rule` before this hook, so `rule` is the canonical key
///     the core reads; clearing `rules` avoids an ambiguous duplicate.
///   * The input map and its nested maps/lists are NEVER mutated — a new
///     top-level map is returned and the merged `rule-providers` map is freshly
///     allocated (existing provider entries kept by reference).
Map<String, dynamic> applyGamingPatch(
  Map<String, dynamic> rawConfig,
  GameDescriptor descriptor,
) {
  final result = Map<String, dynamic>.from(rawConfig);

  // Rule-providers: additive merge, never overwriting an existing key.
  final existing = rawConfig['rule-providers'];
  final providers = <String, dynamic>{
    if (existing is Map)
      for (final entry in existing.entries) entry.key.toString(): entry.value,
  };
  descriptor.ruleProviders.forEach((key, value) {
    providers.putIfAbsent(key, () => value);
  });
  result['rule-providers'] = providers;

  // Rules: replace via the canonical singular `rule` key, drop legacy `rules`.
  result['rule'] = List<String>.from(descriptor.rules);
  result.remove('rules');

  return result;
}
