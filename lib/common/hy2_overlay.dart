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

import 'dart:convert';

import 'mihomo_yaml_splice.dart' show isRoutableProxy, mihomoBuiltinTargets;
import 'work_mode_patch.dart' show detectPrimaryRouter, interceptLeafNodes;

/// One Hy2 node as pushed by the panel via `dropweb-xnodes`. Pure data: the app
/// constructs the proxy verbatim from these fields and invents nothing.
class Hy2NodeSpec {
  const Hy2NodeSpec({
    required this.name,
    required this.server,
    required this.port,
    this.alpn = const <String>[],
    this.sni,
    this.skipCertVerify = false,
  });

  final String name;
  final String server;
  final int port;
  final List<String> alpn;
  final String? sni;
  final bool skipCertVerify;
}

/// Parses the `dropweb-xnodes` header into node specs. Accepts an optional
/// `base64:` prefix (the panel's convention for non-ASCII values, mirrored from
/// `Profile.serviceName`) wrapping a UTF-8 JSON array. Each entry needs a
/// non-empty `name` + `server` and an int-coercible `port`; `alpn` defaults to
/// `[]`, `sni` to null (→ `server` at build time), `skip-cert-verify` to false.
/// Duplicate names (first-seen wins) and malformed entries are skipped; a
/// null/empty/garbage payload yields `const []`. NEVER throws.
List<Hy2NodeSpec> parseHy2NodeSpecs(String? headerValue) {
  final raw = headerValue?.trim();
  if (raw == null || raw.isEmpty) return const <Hy2NodeSpec>[];

  var jsonText = raw;
  if (raw.startsWith('base64:')) {
    try {
      jsonText = utf8.decode(base64.decode(base64.normalize(raw.substring(7))));
    } catch (_) {
      return const <Hy2NodeSpec>[];
    }
  }

  dynamic decoded;
  try {
    decoded = json.decode(jsonText);
  } catch (_) {
    return const <Hy2NodeSpec>[];
  }
  if (decoded is! List) return const <Hy2NodeSpec>[];

  final specs = <Hy2NodeSpec>[];
  final seen = <String>{};
  for (final item in decoded) {
    if (item is! Map) continue;
    final name = item['name']?.toString();
    final server = item['server']?.toString();
    final port = item['port'] is int
        ? item['port'] as int
        : int.tryParse('${item['port']}');
    if (name == null ||
        name.isEmpty ||
        server == null ||
        server.isEmpty ||
        port == null) {
      continue;
    }
    if (!seen.add(name)) continue;
    final alpnRaw = item['alpn'];
    final alpn = alpnRaw is List
        ? alpnRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    specs.add(Hy2NodeSpec(
      name: name,
      server: server,
      port: port,
      alpn: alpn,
      sni: item['sni']?.toString() ?? server,
      skipCertVerify: item['skip-cert-verify'] == true,
    ));
  }
  return specs;
}

/// Subscription header carrying the rich Hy2 node specs (base64-wrapped JSON;
/// see [parseHy2NodeSpecs]). Canonical name; documented in `constant.dart` as
/// `kHy2NodesHeader`. Restated here (not imported) to keep this module pure /
/// Flutter-free — `constant.dart` pulls in `dart:ui` + Flutter. Keep in sync.
const _hy2NodesHeader = 'dropweb-xnodes';

/// Legacy header name, kept ONLY as a graceful fallback: its value is a CSV of
/// bare domains, which [parseHy2NodeSpecs] cannot turn into a spec (no port /
/// alpn), so a legacy-only subscription simply yields no Hy2 overlay. Retained
/// so a transient panel reversion degrades to "no overlay" rather than throwing.
const _legacyHy2NodesHeader = 'dropweb-game-nodes';

/// Builds ONE `hysteria2` proxy from a panel [spec], authed with [password]
/// (the user's vless uuid). Everything but `type` comes from the spec — the app
/// hardcodes nothing. `sni` falls back to `server` when the spec omits it; the
/// `alpn` list is copied so the result never aliases the spec's list.
Map<String, dynamic> buildHy2Proxy(Hy2NodeSpec spec, String password) =>
    <String, dynamic>{
      'name': spec.name,
      'type': 'hysteria2',
      'server': spec.server,
      'port': spec.port,
      'sni': spec.sni ?? spec.server,
      'password': password,
      'alpn': List<String>.from(spec.alpn),
      'skip-cert-verify': spec.skipCertVerify,
    };

/// Picks the Hy2-nodes header value: new [_hy2NodesHeader] first, legacy
/// [_legacyHy2NodesHeader] fallback. Pure — takes the already-collected,
/// lower-cased header map (see `Profile.providerHeaders`). Returns null when
/// neither header is present.
String? resolveHy2NodesHeader(Map<String, String> headers) =>
    headers[_hy2NodesHeader] ?? headers[_legacyHy2NodesHeader];

/// The USER's own vless `uuid` — the per-user Hy2 password — or `null` when no
/// such node exists. Transport-neutral: the all-modes overlay AND the gaming
/// hook both authenticate Hy2 with it.
///
/// Reuses [interceptLeafNodes] (the "user's real nodes, SOS pool excluded"
/// helper) to get the user's REAL leaf node names, then returns the `uuid` of
/// the FIRST `rawConfig['proxies']` entry that is both a member of that leaf set
/// AND `type == 'vless'`. Drawing it from the leaf set (not raw `proxies`)
/// structurally EXCLUDES the disconeko emergency pool (~57 external vless nodes
/// with FOREIGN uuids), so the overlay never injects a wrong Hy2 password.
String? extractUserVlessUuid(Map<String, dynamic> rawConfig) {
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

/// The complete header-gated Hy2 overlay, applied VERBATIM by every config
/// consumer (the build path `patchRawConfig` AND the «Страна» picker) so they
/// can never diverge — the single source of truth for "config + headers → config
/// with the panel's Hy2 nodes". Resolves the [Hy2NodeSpec]s from [headers] and
/// the user's vless uuid from [cfg]; injects via [injectHy2Overlay] only when
/// BOTH are present, otherwise returns [cfg] unchanged (no-op).
Map<String, dynamic> applyHy2Overlay(
  Map<String, dynamic> cfg,
  Map<String, String> headers,
) {
  final specs = parseHy2NodeSpecs(resolveHy2NodesHeader(headers));
  if (specs.isEmpty) return cfg;
  final password = extractUserVlessUuid(cfg);
  if (password == null) return cfg;
  return injectHy2Overlay(cfg, specs: specs, password: password);
}

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
///   * No-op (shallow copy) when [specs] is empty or [password] null/empty.
///   * Appends one [buildHy2Proxy] per spec to top-level `proxies`, skipping
///     names already present.
///   * Appends each injected name to the auto-select group
///     ([detectAutoSelectGroup]); when none is found the proxies are still
///     injected (available for manual pick) but nothing is bound — fail-open.
///   * Never mutates the input map / nested lists; only `proxies` and the one
///     target group list are reallocated (existing entries kept by reference).
Map<String, dynamic> injectHy2Overlay(
  Map<String, dynamic> rawConfig, {
  required List<Hy2NodeSpec> specs,
  required String? password,
}) {
  final result = Map<String, dynamic>.from(rawConfig);
  if (specs.isEmpty || password == null || password.isEmpty) return result;

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
  for (final spec in specs) {
    final proxy = buildHy2Proxy(spec, password);
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
