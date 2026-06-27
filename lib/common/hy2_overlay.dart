// lib/common/hy2_overlay.dart
//
// Header-gated Hysteria2 overlay. PURE, additive, idempotent — no I/O, no
// Flutter, no dart:io. Injects hysteria2 proxies (built from the panel-pushed
// pool domains + the user's vless uuid) into the parsed Mihomo config and binds
// them into the EXISTING auto-select group, so general VPN traffic transparently
// uses Hy2 when alive and falls back to Reality (url-test) when UDP is blocked.
//
// Transport ≠ work mode: this is a header-gated capability that applies in every
// WorkMode, NOT a new mode. When the header is absent the wiring no-ops.

import 'mihomo_yaml_splice.dart' show isRoutableProxy, mihomoBuiltinTargets;
import 'work_mode_patch.dart' show detectPrimaryRouter;

/// Hy2 inbound shape deployed by the webpanel Hysteria patch (UDP/443, alpn h3,
/// real LE cert). Protocol constants of OUR deployment, not policy — changing
/// them is a coordinated infra change. Kept here (not a remote descriptor) per
/// the "no engine" decision: the overlay runs in EVERY work mode, where the
/// gaming `game.yml` descriptor (and its header) may be absent, so there is no
/// always-available remote source to read these from.
const kHy2Port = 443;
const kHy2Alpn = <String>['h3'];
const kHy2SkipCertVerify = false;

/// Name marker for injected Hy2 proxies. `🎮 ` is historical (live `game.yml`
/// convention) AND intentionally NOT in `⚡ Fastest`'s exclude-filter
/// (`🇪🇺|🚀|cascade…`) so an explicit member is never stripped. Shared with
/// gaming so name-based dedup keeps a single Hy2 proxy per domain.
const kHy2ProxyPrefix = '🎮 ';

/// Subscription header carrying the comma-separated Hy2 pool domains. Canonical
/// name; documented in `constant.dart` as `kHy2NodesHeader`. Restated here (not
/// imported) to keep this module pure / Flutter-free — `constant.dart` pulls in
/// `dart:ui` + Flutter. Keep the two in sync.
const _hy2NodesHeader = 'dropweb-xnodes';

/// Legacy header name, kept as a fallback during the dual-header rollout.
/// Mirrors `constant.dart`'s `kGamingNodesHeader` (same purity caveat as above).
const _legacyHy2NodesHeader = 'dropweb-game-nodes';

/// Builds ONE `hysteria2` proxy for [domain], authed with [password] (the user's
/// vless uuid). `server == sni == [domain]` (the regional POOL domain, SAN'd in
/// the LE cert, so `skip-cert-verify: false` is valid). The `alpn` list is copied
/// so the result never aliases [kHy2Alpn].
Map<String, dynamic> buildHy2Proxy({
  required String domain,
  required String password,
}) =>
    <String, dynamic>{
      'name': '$kHy2ProxyPrefix$domain',
      'type': 'hysteria2',
      'server': domain,
      'port': kHy2Port,
      'sni': domain,
      'password': password,
      'alpn': List<String>.from(kHy2Alpn),
      'skip-cert-verify': kHy2SkipCertVerify,
    };

/// Picks the Hy2-nodes header value: new [_hy2NodesHeader] first, legacy
/// [_legacyHy2NodesHeader] fallback. Pure — takes the already-collected,
/// lower-cased header map (see `Profile.providerHeaders`). Returns null when
/// neither header is present.
String? resolveHy2NodesHeader(Map<String, String> headers) =>
    headers[_hy2NodesHeader] ?? headers[_legacyHy2NodesHeader];

/// Resolves the auto-select group general VPN traffic actually flows through:
/// the `url-test`/`smart`/`fallback` group reached from the `MATCH` target
/// ([detectPrimaryRouter]). If the primary router is itself such a group with
/// routable leaves, it is returned; if it is a `fallback`/`select` wrapper, the
/// FIRST member group (declaration order) that is selectable AND carries ≥1
/// routable top-level proxy is returned. Returns null when none qualifies (the
/// overlay then injects proxies but binds nothing — fail-open). NAME-AGNOSTIC.
String? detectAutoSelectGroup(Map<String, dynamic> rawConfig) {
  final primary = detectPrimaryRouter(rawConfig);
  if (primary == null) return null;

  final groups = rawConfig['proxy-groups'];
  if (groups is! List) return null;

  // name -> type and name -> member-names.
  final type = <String, String?>{};
  final members = <String, List<String>>{};
  for (final g in groups) {
    if (g is! Map) continue;
    final n = g['name']?.toString();
    if (n == null) continue;
    type[n] = g['type']?.toString();
    final ms = <String>[];
    final ps = g['proxies'];
    if (ps is List) {
      for (final m in ps) {
        if (m != null) ms.add(m.toString());
      }
    }
    members[n] = ms;
  }

  // Routable top-level proxy names (shared structural sentinel filter).
  final routable = <String>{};
  final proxies = rawConfig['proxies'];
  if (proxies is List) {
    for (final p in proxies) {
      if (p is Map && p['name'] != null && isRoutableProxy(p)) {
        routable.add(p['name'].toString());
      }
    }
  }

  const selectable = <String>{'url-test', 'smart', 'fallback'};
  bool hasRoutableLeaf(String name) => (members[name] ?? const []).any(
      (m) => !mihomoBuiltinTargets.contains(m) && routable.contains(m));

  // Primary itself is a selectable group with routable leaves?
  if (selectable.contains(type[primary]) && hasRoutableLeaf(primary)) {
    return primary;
  }
  // Else the first selectable member-group of the primary with routable leaves.
  for (final m in members[primary] ?? const <String>[]) {
    if (selectable.contains(type[m]) && hasRoutableLeaf(m)) return m;
  }
  return null;
}

/// Header-gated Hy2 overlay. PURE / ADDITIVE / IDEMPOTENT.
///   * No-op (shallow copy) when [domains] is empty or [password] null/empty.
///   * Appends one [buildHy2Proxy] per domain to top-level `proxies`, skipping
///     names already present.
///   * Appends each injected name to the auto-select group
///     ([detectAutoSelectGroup]); when none is found the proxies are still
///     injected (available for manual pick) but nothing is bound — fail-open.
///   * Never mutates the input map / nested lists; only `proxies` and the one
///     target group list are reallocated (existing entries kept by reference).
Map<String, dynamic> injectHy2Overlay(
  Map<String, dynamic> rawConfig, {
  required List<String> domains,
  required String? password,
}) {
  final result = Map<String, dynamic>.from(rawConfig);
  if (domains.isEmpty || password == null || password.isEmpty) return result;

  // 1. Append Hy2 proxies (idempotent by name).
  final existing = <String>{};
  final newProxies = <dynamic>[];
  final src = rawConfig['proxies'];
  if (src is List) {
    for (final p in src) {
      newProxies.add(p);
      if (p is Map && p['name'] != null) existing.add(p['name'].toString());
    }
  }
  final injected = <String>[];
  for (final d in domains) {
    final proxy = buildHy2Proxy(domain: d, password: password);
    final name = proxy['name'] as String;
    if (existing.contains(name) || injected.contains(name)) continue;
    newProxies.add(proxy);
    injected.add(name);
  }
  result['proxies'] = newProxies;
  if (injected.isEmpty) return result;

  // 2. Bind into the auto-select group (idempotent, non-destructive copy).
  final target = detectAutoSelectGroup(result);
  if (target == null) return result; // fail-open: injected but unbound.

  final groups = rawConfig['proxy-groups'];
  final newGroups = <dynamic>[];
  if (groups is List) {
    for (final g in groups) {
      if (g is Map && g['name']?.toString() == target) {
        final ms = <dynamic>[];
        final ps = g['proxies'];
        final present = <String>{};
        if (ps is List) {
          for (final m in ps) {
            ms.add(m);
            if (m != null) present.add(m.toString());
          }
        }
        for (final n in injected) {
          if (!present.contains(n)) ms.add(n);
        }
        final copy = Map<String, dynamic>.from(g.cast<String, dynamic>());
        copy['proxies'] = ms;
        newGroups.add(copy);
      } else {
        newGroups.add(g);
      }
    }
  }
  result['proxy-groups'] = newGroups;
  return result;
}
