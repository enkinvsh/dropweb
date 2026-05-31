import 'package:yaml/yaml.dart';

/// Smart converter for URL subscriptions whose HTTP body is a raw, newline-
/// separated list of share links (`vless://`, `trojan://`) instead of a full
/// Mihomo/Clash YAML config.
///
/// [convertShareLinkSubscriptionToMihomo] is intentionally narrow:
/// - Returns `null` for normal Mihomo YAML or any plain text that does not
///   contain a supported share-link line. Existing import paths then continue
///   to treat the body as a YAML profile (their original behavior).
/// - Returns a minimal, self-contained Mihomo YAML string when at least one
///   `vless://` or `trojan://` line can be parsed successfully. The generated
///   YAML still flows through `clashCore.validateConfig` upstream.
///
/// The emitter purposefully produces only the minimum sections needed by
/// Mihomo: `mixed-port`, `mode`, `proxies`, `proxy-groups`, `rules`. There
/// is no `🌀 Cascade`, no `📶 First Available`, no `rule-providers`, no DNS
/// or TUN block — server-side panel skeleton is not reconstructed here.
String? convertShareLinkSubscriptionToMihomo(String content) {
  final proxies = _parseShareLinkProxies(content);
  if (proxies.isEmpty) return null;
  return _emitMihomoYaml(proxies);
}

/// Extracts proxy maps from a subscription body for downstream merging.
///
/// Two input shapes are supported, in priority order:
/// 1. A raw, newline-separated list of `vless://` / `trojan://` share links
///    (same parsing + name-dedup path used by
///    [convertShareLinkSubscriptionToMihomo]).
/// 2. A Mihomo/Clash YAML document with a top-level `proxies:` list.
///
/// Each returned map carries the full proxy fields including a `name` key.
/// Returns `[]` when neither shape yields a usable proxy.
List<Map<String, Object>> parseSubscriptionToProxies(String content) {
  final shareLinkProxies = _parseShareLinkProxies(content);
  if (shareLinkProxies.isNotEmpty) {
    return [
      for (final p in shareLinkProxies)
        <String, Object>{'name': p.name, ...p.data},
    ];
  }

  final Object? doc;
  try {
    doc = loadYaml(content);
  } catch (_) {
    return const [];
  }
  if (doc is! Map) return const [];
  final rawProxies = doc['proxies'];
  if (rawProxies is! List) return const [];

  final result = <Map<String, Object>>[];
  for (final entry in rawProxies) {
    if (entry is! Map) continue;
    final map = _yamlMapToObjectMap(entry);
    if (map['name'] is! String) continue;
    result.add(map);
  }
  return result;
}

/// Shared share-link parsing path: scans [content] for supported share-link
/// lines, parses each, and applies name deduplication. Returns `[]` when no
/// share-link line is present (caller decides the fallback behavior).
List<_ProxyEntry> _parseShareLinkProxies(String content) {
  final candidates = <String>[];
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    if (line.startsWith('vless://') || line.startsWith('trojan://')) {
      candidates.add(line);
    }
  }
  if (candidates.isEmpty) return [];

  final proxies = <_ProxyEntry>[];
  final nameCounts = <String, int>{};

  for (final line in candidates) {
    final entry = _parseShareLink(line);
    if (entry == null) continue;
    final base = entry.name;
    if (nameCounts.containsKey(base)) {
      final next = nameCounts[base]! + 1;
      nameCounts[base] = next;
      entry.name = '$base #$next';
    } else {
      nameCounts[base] = 1;
    }
    proxies.add(entry);
  }

  return proxies;
}

/// Recursively converts a parsed YAML node into plain Dart `Object` values,
/// so the result is a `Map<String, Object>` free of `YamlMap`/`YamlList`.
Map<String, Object> _yamlMapToObjectMap(Map source) {
  final result = <String, Object>{};
  source.forEach((key, value) {
    final converted = _yamlNodeToObject(value);
    if (converted != null) {
      result[key.toString()] = converted;
    }
  });
  return result;
}

Object? _yamlNodeToObject(Object? node) {
  if (node == null) return null;
  if (node is Map) return _yamlMapToObjectMap(node);
  if (node is List) {
    return [
      for (final item in node)
        if (_yamlNodeToObject(item) case final v?) v,
    ];
  }
  return node;
}

class _ProxyEntry {
  _ProxyEntry({
    required this.name,
    required this.data,
  });

  String name;
  // Ordered fields (excluding 'name', which is emitted first separately).
  final Map<String, Object> data;
}

_ProxyEntry? _parseShareLink(String line) {
  final Uri uri;
  try {
    uri = Uri.parse(line);
  } catch (_) {
    return null;
  }
  if (uri.scheme.isEmpty) return null;
  if (uri.host.isEmpty) return null;
  if (uri.port == 0) return null;
  if (uri.userInfo.isEmpty) return null;

  final params = uri.queryParameters;
  final name = _decodeName(uri.fragment).isNotEmpty
      ? _decodeName(uri.fragment)
      : '${uri.scheme} ${uri.host}:${uri.port}';

  final network = _normalizeNetwork(params['type']);

  final data = <String, Object>{
    'type': uri.scheme,
    'server': uri.host,
    'port': uri.port,
  };

  if (uri.scheme == 'vless') {
    data['uuid'] = _decode(uri.userInfo);
    data['network'] = network;
    final flow = params['flow'];
    if (flow != null && flow.isNotEmpty) {
      data['flow'] = flow;
    }
    final security = params['security'];
    if (security == 'tls' || security == 'reality') {
      data['tls'] = true;
    }
    final sni = params['sni'];
    if (sni != null && sni.isNotEmpty) {
      data['servername'] = sni;
    }
    final fp = params['fp'];
    if (fp != null && fp.isNotEmpty) {
      data['client-fingerprint'] = fp;
    }
    if (security == 'reality') {
      final pbk = params['pbk'];
      if (pbk != null && pbk.isNotEmpty) {
        data['reality-opts'] = <String, Object>{
          'public-key': pbk,
          'short-id': params['sid'] ?? '',
        };
      }
    }
    return _ProxyEntry(name: name, data: data);
  }

  if (uri.scheme == 'trojan') {
    data['password'] = _decode(uri.userInfo);
    data['network'] = network;
    final sni = params['sni'];
    if (sni != null && sni.isNotEmpty) {
      data['sni'] = sni;
    }
    final fp = params['fp'];
    if (fp != null && fp.isNotEmpty) {
      data['client-fingerprint'] = fp;
    }
    final security = params['security'];
    if (security == 'reality') {
      final pbk = params['pbk'];
      if (pbk != null && pbk.isNotEmpty) {
        data['reality-opts'] = <String, Object>{
          'public-key': pbk,
          'short-id': params['sid'] ?? '',
        };
      }
    }
    return _ProxyEntry(name: name, data: data);
  }

  return null;
}

String _decodeName(String fragment) {
  if (fragment.isEmpty) return '';
  try {
    return Uri.decodeComponent(fragment).trim();
  } catch (_) {
    return fragment.trim();
  }
}

String _decode(String s) {
  try {
    return Uri.decodeComponent(s);
  } catch (_) {
    return s;
  }
}

String _normalizeNetwork(String? type) {
  if (type == null || type.isEmpty) return 'tcp';
  // Xray uses `raw`; Mihomo equivalent is `tcp`.
  if (type == 'raw') return 'tcp';
  return type;
}

String _emitMihomoYaml(List<_ProxyEntry> proxies) {
  const vpnGroup = '🌍 VPN';
  const fastestGroup = '⚡ Fastest';
  const smartGroup = '🧠 Smart';

  final buf = StringBuffer()
    ..writeln('mixed-port: 7890')
    ..writeln('mode: rule')
    ..writeln('proxies:');
  for (final p in proxies) {
    buf.writeln('  - name: ${_yamlScalar(p.name)}');
    _writeFields(buf, p.data, '    ');
  }

  buf
    ..writeln('proxy-groups:')
    ..writeln('  - name: ${_yamlScalar(vpnGroup)}')
    ..writeln('    type: select')
    ..writeln('    proxies:')
    ..writeln('      - ${_yamlScalar(smartGroup)}')
    ..writeln('      - ${_yamlScalar(fastestGroup)}');
  for (final p in proxies) {
    buf.writeln('      - ${_yamlScalar(p.name)}');
  }
  buf
    ..writeln('      - DIRECT')
    ..writeln('  - name: ${_yamlScalar(fastestGroup)}')
    ..writeln('    type: url-test')
    ..writeln('    url: ${_yamlScalar('http://www.gstatic.com/generate_204')}')
    ..writeln('    interval: 300')
    ..writeln('    tolerance: 50')
    ..writeln('    proxies:');
  for (final p in proxies) {
    buf.writeln('      - ${_yamlScalar(p.name)}');
  }
  buf
    ..writeln('  - name: ${_yamlScalar(smartGroup)}')
    ..writeln('    type: smart')
    ..writeln('    uselightgbm: false')
    ..writeln('    proxies:');
  for (final p in proxies) {
    buf.writeln('      - ${_yamlScalar(p.name)}');
  }
  buf
    ..writeln('rules:')
    ..writeln('  - ${_yamlScalar('MATCH,$vpnGroup')}');

  return buf.toString();
}

void _writeFields(StringBuffer buf, Map<String, Object> map, String indent) {
  map.forEach((key, value) {
    if (value is Map<String, Object>) {
      buf.writeln('$indent$key:');
      _writeFields(buf, value, '$indent  ');
    } else if (value is bool) {
      buf.writeln('$indent$key: $value');
    } else if (value is int) {
      buf.writeln('$indent$key: $value');
    } else {
      buf.writeln('$indent$key: ${_yamlScalar(value.toString())}');
    }
  });
}

/// Render [s] as a YAML block scalar. Uses bare form when the value is safe
/// in a plain scalar context, otherwise single-quotes and escapes the inner
/// quotes. Conservative: any character that can change YAML semantics
/// (`#`, `:`, leading/trailing spaces, YAML indicator at start) forces
/// quoting.
String _yamlScalar(String s) {
  if (s.isEmpty) return "''";
  if (_needsQuoting(s)) {
    return "'${s.replaceAll("'", "''")}'";
  }
  return s;
}

bool _needsQuoting(String s) {
  if (s != s.trim()) return true;
  if (s.contains('#')) return true;
  if (s.contains(': ')) return true;
  if (s.contains(' #')) return true;
  if (s.contains('\n') || s.contains('\t') || s.contains('\r')) return true;
  const reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};
  if (reserved.contains(s.toLowerCase())) return true;
  const indicators = {
    '?', ':', '-', ',', '[', ']', '{', '}', '&', '*',
    '!', '|', '>', "'", '"', '%', '@', '`',
  };
  if (indicators.contains(s[0])) return true;
  if (RegExp(r'^-?\d').hasMatch(s) && double.tryParse(s) != null) return true;
  return false;
}
