// Pure injector for the «Игровой» (gaming) work mode.
//
// Builds the Hysteria2 proxies + the `🎮 Gaming` proxy-group and ADDITIVELY
// folds them into a parsed Mihomo config. Stays Flutter-free and dart:io-free
// (only `package:dropweb/common/...` pure imports) so it is trivially
// unit-testable and easy to audit.
//
// On 2.7.4 the panel's Mihomo subscription carries ZERO hysteria nodes
// (Remnawave does not render Hy2 for clash.meta), so the app injects them. The
// node domains arrive via the panel-only `dropweb-game-nodes` header (see
// [parseGameNodeDomains]); the routing shape (group + rules) arrives via the
// pinned `game.yml` descriptor. The Hy2 password is the user's own vless uuid
// (proven e2e: Hy2 `auth == vlessUuid`).
//
// This module is PURE — no I/O, no providers, no build-path wiring. The fetch /
// build-path glue (Фаза 6) consumes these functions; this file is the pure core
// only.

import 'game_descriptor.dart';
import 'work_mode_patch.dart' show interceptLeafNodes;

/// Splits the `dropweb-game-nodes` header value into an ordered, de-duplicated
/// list of Hy2 node domains.
///
/// Each comma-separated entry is trimmed; empty entries are dropped; duplicates
/// are removed preserving first-seen order. A null/empty/whitespace-only header
/// yields `const []`.
List<String> parseGameNodeDomains(String? headerValue) {
  if (headerValue == null) return const <String>[];
  final domains = <String>[];
  final seen = <String>{};
  for (final part in headerValue.split(',')) {
    final domain = part.trim();
    if (domain.isEmpty) continue;
    if (seen.add(domain)) domains.add(domain);
  }
  return domains;
}

/// Returns the USER's vless `uuid` to use as the Hy2 password, or `null` when
/// there is no such node.
///
/// Reuses [interceptLeafNodes] — the codebase's "user's real nodes, SOS pool
/// excluded" helper — to get the user's REAL leaf node names, then returns the
/// `uuid` of the FIRST `rawConfig['proxies']` entry that is both a member of
/// that leaf set AND `type == 'vless'`.
///
/// Drawing the uuid from the leaf set (not raw `proxies`) is load-bearing: it
/// structurally EXCLUDES the disconeko emergency pool (~57 external vless nodes
/// baked into top-level `proxies` with FOREIGN uuids), so gaming never injects a
/// wrong Hy2 password.
String? extractGamingUuid(Map<String, dynamic> rawConfig) {
  final leaves = interceptLeafNodes(rawConfig).toSet();
  if (leaves.isEmpty) return null;
  final proxies = rawConfig['proxies'];
  if (proxies is! List) return null;
  for (final p in proxies) {
    if (p is! Map) continue;
    final name = p['name']?.toString();
    if (name == null || !leaves.contains(name)) continue;
    if (p['type']?.toString() != 'vless') continue;
    return p['uuid']?.toString();
  }
  return null;
}

/// Builds ONE `hysteria2` proxy map for the gaming [domain], authenticating with
/// [password] and shaped by [template] (port / alpn / skip-cert-verify).
///
/// The `name` follows the live `game.yml` convention `"🎮 " + domain`, and both
/// `server` and `sni` are the [domain] itself. `alpn` is copied so the returned
/// map never aliases the template's list.
Map<String, dynamic> buildGamingHysteriaProxy({
  required String domain,
  required String password,
  required GameHysteriaTemplate template,
}) =>
    <String, dynamic>{
      'name': '🎮 $domain',
      'type': 'hysteria2',
      'server': domain,
      'port': template.port,
      'sni': domain,
      'password': password,
      'alpn': List<String>.from(template.alpn),
      'skip-cert-verify': template.skipCertVerify,
    };

/// Additively injects the gaming Hy2 proxies + the `🎮 Gaming` group into
/// [rawConfig]. PURE, IDEMPOTENT, ADDITIVE.
///
///   * No-op (returns a shallow copy) when [nodeDomains] is empty or [password]
///     is null/empty — gaming cannot work without nodes and a credential.
///   * Otherwise appends one [buildGamingHysteriaProxy] per domain to `proxies`
///     and appends a group (named [descriptor].group.name, of
///     [descriptor].group.type, with the injected Hy2 names as members, plus
///     `url`/`interval`/`tolerance` when non-null on the descriptor group) to
///     `proxy-groups`.
///   * IDEMPOTENT: any Hy2 proxy whose name already exists is skipped; the group
///     is skipped entirely when one with that name already exists (mirrors
///     `work_mode_patch.dart`'s skip-by-name pattern).
///   * The input map and its nested lists/maps are NEVER mutated — a new
///     top-level map is returned, and only the `proxies` / `proxy-groups` lists
///     that gain an entry are reallocated (existing entries kept by reference).
Map<String, dynamic> injectGamingProxies(
  Map<String, dynamic> rawConfig, {
  required GameDescriptor descriptor,
  required List<String> nodeDomains,
  required String? password,
}) {
  final result = Map<String, dynamic>.from(rawConfig);
  if (nodeDomains.isEmpty || password == null || password.isEmpty) {
    return result;
  }

  // Append one Hy2 proxy per domain, skipping names already present (idempotent).
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
  final injectedNames = <String>[];
  final injectedSeen = <String>{};
  for (final domain in nodeDomains) {
    final proxy = buildGamingHysteriaProxy(
      domain: domain,
      password: password,
      template: descriptor.hysteriaTemplate,
    );
    final name = proxy['name'] as String;
    if (existingProxyNames.contains(name)) continue;
    if (!injectedSeen.add(name)) continue;
    newProxies.add(proxy);
    injectedNames.add(name);
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
      'proxies': List<String>.from(injectedNames),
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
