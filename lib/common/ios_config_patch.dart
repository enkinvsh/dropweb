/// iOS-only shaping of the parsed mihomo config. All functions are PURE:
/// they return new maps and never mutate their input.
///
/// Why: a Packet Tunnel extension may use 15 MB on iOS 13–14 and 50 MB on
/// iOS 15+ (measured on iPhone 8, see docs/plans/2026-10-08-ios-port-design.md).
library;

import 'work_mode_patch.dart' show detectPrimaryRouter;

/// iOS 13–14 run the lite profile. An unparsable version also gets lite:
/// lite works everywhere, the full profile does not.
bool iosNeedsLiteCore(String systemVersion) {
  final major = int.tryParse(systemVersion.split('.').first.trim());
  return major == null || major < 15;
}

const _iosListenerPorts = [
  'mixed-port',
  'port',
  'socks-port',
  'redir-port',
  'tproxy-port',
];

/// Inbound servers. The iOS core is built with `no_extra_protocols`, which
/// leaves most of their protocols out, and an extension serves only its TUN.
const _iosInboundServers = [
  'listeners',
  'tuic-server',
  'ss-config',
  'vmess-config',
  'tunnels',
];

/// Applied on every iOS version (RabbitHole does the same on iOS): no local
/// listeners, inbound servers or controller (the app talks to the extension through provider
/// messages), no process lookup (impossible inside NE), no keep-alive timers,
/// no cache-file writes. The TUN stack is always the user-space `mips` stack:
/// `system` cannot work inside NetworkExtension (the provider's own sockets
/// bypass its tunnel, so the kernel forwarder's replies never reach utun) and
/// the iOS core is built without gVisor to save memory.
Map<String, dynamic> applyIosBasePatch(Map<String, dynamic> rawConfig) {
  final config = Map<String, dynamic>.from(rawConfig);
  final tun = config['tun'];
  config['tun'] = <String, dynamic>{
    if (tun is Map) ...Map<String, dynamic>.from(tun),
    'stack': 'mips',
  };
  for (final key in _iosListenerPorts) {
    config[key] = 0;
  }
  _iosInboundServers.forEach(config.remove);
  config.remove('authentication');
  config['external-controller'] = '';
  config.remove('external-ui');
  config['find-process-mode'] = 'off';
  config['disable-keep-alive'] = true;
  config['profile'] = <String, dynamic>{
    'store-selected': false,
    'store-fake-ip': false,
  };
  return config;
}

const _autoGroupTypes = {'url-test', 'fallback', 'load-balance', 'smart'};
const _healthCheckKeys = [
  'url',
  'interval',
  'tolerance',
  'lazy',
  'timeout',
  'max-failed-times',
  'expected-status',
  'strategy',
  'uselightgbm',
  'collectdata',
  'policy-priority',
];
const iosLiteMinAutoInterval = 300;

/// iOS 13–14 only. Measured on iPhone 8: health-check machinery of many
/// auto groups costs ~1.5 MB of the 15 MB extension budget, smux sessions
/// (buffers plus two goroutines each) another ~1.4 MB, and every extra DNS
/// server ~1.3 MB at a burst of new connections.
Map<String, dynamic> applyIosLitePatch(Map<String, dynamic> rawConfig) {
  final config = Map<String, dynamic>.from(rawConfig);
  final proxies = config['proxies'];
  if (proxies is List) {
    config['proxies'] = [for (final p in proxies) _withoutSmux(p)];
  }
  if (config['dns'] is Map) {
    config['dns'] = _withOneServerPerList(config['dns'] as Map);
  }
  final groups = (config['proxy-groups'] as List?)?.cast<Map>() ?? const [];
  if (groups.isEmpty) return config;

  final routerName =
      detectPrimaryRouter(config) ?? groups.first['name'] as String?;
  final router = groups.where((g) => g['name'] == routerName).firstOrNull;
  final routerMembers =
      ((router?['proxies'] as List?) ?? const []).map((e) => '$e').toSet();

  config['proxy-groups'] = [
    for (final g in groups) _liteGroup(g, keepAuto: routerMembers),
  ];

  final providers = config['proxy-providers'];
  if (providers is Map) {
    config['proxy-providers'] = {
      for (final entry in providers.entries)
        entry.key: _withoutHealthCheck(entry.value),
    };
  }
  return config;
}

Map<String, dynamic> _liteGroup(Map group, {required Set<String> keepAuto}) {
  final copy = Map<String, dynamic>.from(group);
  if (!_autoGroupTypes.contains(copy['type'])) return copy;
  if (keepAuto.contains(copy['name'])) {
    final interval = int.tryParse('${copy['interval']}') ?? 0;
    copy['interval'] =
        interval < iosLiteMinAutoInterval ? iosLiteMinAutoInterval : interval;
    copy['lazy'] = true;
    return copy;
  }
  copy['type'] = 'select';
  for (final key in _healthCheckKeys) {
    copy.remove(key);
  }
  return copy;
}

dynamic _withoutSmux(dynamic proxy) {
  if (proxy is! Map || proxy['smux'] is! Map) return proxy;
  return {
    ...Map<String, dynamic>.from(proxy),
    'smux': {
      ...Map<String, dynamic>.from(proxy['smux'] as Map),
      'enabled': false
    },
  };
}

const _dnsServerLists = [
  'nameserver',
  'fallback',
  'default-nameserver',
  'proxy-server-nameserver',
  'direct-nameserver',
];
const _dnsServerPolicies = [
  'nameserver-policy',
  'proxy-server-nameserver-policy'
];

/// mihomo sends each query to every server of a list at once, and each
/// encrypted server keeps its own connection, through the proxy when DNS
/// respects rules.
Map<String, dynamic> _withOneServerPerList(Map dns) {
  final copy = Map<String, dynamic>.from(dns);
  for (final key in _dnsServerLists) {
    if (copy.containsKey(key)) copy[key] = _firstServer(copy[key]);
  }
  for (final key in _dnsServerPolicies) {
    final policy = copy[key];
    if (policy is! Map) continue;
    copy[key] = {
      for (final entry in policy.entries) entry.key: _firstServer(entry.value),
    };
  }
  return copy;
}

dynamic _firstServer(dynamic servers) =>
    servers is List && servers.length > 1 ? [servers.first] : servers;

dynamic _withoutHealthCheck(dynamic provider) {
  if (provider is! Map) return provider;
  final copy = Map<String, dynamic>.from(provider);
  final hc = copy['health-check'];
  if (hc is Map) {
    copy['health-check'] = {...Map<String, dynamic>.from(hc), 'enable': false};
  }
  return copy;
}

typedef IosExtensionConfig = ({
  Map<String, dynamic> config,
  List<String> stillRemote,
});

const _remoteOnlyKeys = ['url', 'interval', 'proxy', 'header', 'size-limit'];

/// The extension must never fetch: the first provider download peaked at
/// 33.9 MB on iPhone 8. The app's own core downloads providers into the shared
/// App Group paths; here they are re-declared as local files.
IosExtensionConfig toIosExtensionConfig(
  Map<String, dynamic> rawConfig, {
  required bool Function(String path) fileExists,
}) {
  final config = Map<String, dynamic>.from(rawConfig);
  final stillRemote = <String>[];
  for (final section in ['proxy-providers', 'rule-providers']) {
    final providers = config[section];
    if (providers is! Map) continue;
    config[section] = {
      for (final entry in providers.entries)
        entry.key: _asLocalFile(entry, fileExists, stillRemote),
    };
  }
  return (config: config, stillRemote: stillRemote);
}

dynamic _asLocalFile(
  MapEntry entry,
  bool Function(String) fileExists,
  List<String> stillRemote,
) {
  final provider = entry.value;
  if (provider is! Map || provider['type'] != 'http') return provider;
  final path = provider['path'];
  if (path is! String || !fileExists(path)) {
    stillRemote.add('${entry.key}');
    return provider;
  }
  final copy = Map<String, dynamic>.from(provider)..['type'] = 'file';
  for (final key in _remoteOnlyKeys) {
    copy.remove(key);
  }
  return copy;
}
