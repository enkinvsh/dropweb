import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'mihomo_yaml_splice.dart';

/// Name of the smart auto-selecting group used for the emergency pool merge.
/// Mirrors the `🧠 Smart` group the raw-subscription synthesizer emits in
/// `share_link_profile`, which is proven to pick the best live foreign server
/// on device.
const _smartGroupName = '🧠 Smart';

/// Matches a regional-indicator flag pair (two code points in U+1F1E6–U+1F1FF)
/// followed by the country word(s) up to the first ` |` field separator.
///
/// Example: `0099 | 🇷🇺 Russia | 🏳️ SNI-VK | VLESS | TG: @x` captures
/// `🇷🇺` (group 1) + `Russia` (group 2). Provider / SNI / protocol / TG text
/// after the next `|` is discarded.
final _flagCountryRe = RegExp(
  r'([\u{1F1E6}-\u{1F1FF}][\u{1F1E6}-\u{1F1FF}])\s*([^|]*)',
  unicode: true,
);

/// Merges an emergency pool of [sosProxies] into [mihomoYaml] by exposing them
/// through a `🧠 Smart` smart group that becomes the default of the primary
/// router.
///
/// The function is PURE (no I/O). It performs only additive mutations plus a
/// single index-0 insert into the primary router group, preserving the rest of
/// the user's YAML — comments, formatting, key order, all other groups and ALL
/// rules — byte-for-byte (text-splice appends + a reliable `yaml_edit` insert).
///
/// Returns [mihomoYaml] unchanged when there is nothing to merge: no qualifying
/// router group, an empty primary group, or no emergency proxies.
///
/// Design rationale: a `smart` group with `include-all: true` considers ALL
/// top-level proxies — the subscription's own nodes plus the merged emergency
/// pool — and routes traffic through the best live one. This delivers the same
/// proven "smart" UX as loading a raw subscription directly, instead of the
/// slow fallback-chain probing the previous `🆘 SOS` design used.
String patchSmartPool(String mihomoYaml, List<Map<String, Object>> sosProxies) {
  if (sosProxies.isEmpty) return mihomoYaml;

  final Object? parsed;
  try {
    parsed = loadYaml(mihomoYaml);
  } catch (_) {
    return mihomoYaml;
  }
  if (parsed is! Map) return mihomoYaml;

  final groups = parsed['proxy-groups'];
  if (groups is! List || groups.isEmpty) return mihomoYaml;

  final rules = parsed['rules'];
  if (rules is! List) return mihomoYaml;

  // Existing top-level proxy names (for dedup of derived display names).
  final existingProxyNames = <String>{};
  final topProxies = parsed['proxies'];
  if (topProxies is List) {
    for (final p in topProxies) {
      if (p is Map && p['name'] != null) {
        existingProxyNames.add(p['name'].toString());
      }
    }
  }

  // Map of proxy-group name -> its member list (as plain strings).
  final groupMembers = <String, List<String>>{};
  final groupTypes = <String, String>{};
  final groupOrder = <String>[];
  for (final g in groups) {
    if (g is! Map) continue;
    final name = g['name']?.toString();
    if (name == null) continue;
    groupOrder.add(name);
    groupTypes[name] = g['type']?.toString() ?? '';
    final members = <String>[];
    final ps = g['proxies'];
    if (ps is List) {
      for (final m in ps) {
        if (m != null) members.add(m.toString());
      }
    }
    groupMembers[name] = members;
  }

  // A group qualifies as a router target only if it has at least one member
  // that is NOT a built-in target (i.e. it can actually carry proxied traffic).
  bool isQualifyingGroup(String name) {
    final members = groupMembers[name];
    if (members == null) return false;
    return members.any((m) => !mihomoBuiltinTargets.contains(m));
  }

  // Count how many rules target each qualifying proxy-group.
  final ruleCounts = <String, int>{};
  for (final rule in rules) {
    final target = ruleTarget(rule?.toString() ?? '');
    if (target == null) continue;
    if (mihomoBuiltinTargets.contains(target)) continue;
    if (!groupMembers.containsKey(target)) continue;
    if (!isQualifyingGroup(target)) continue;
    ruleCounts[target] = (ruleCounts[target] ?? 0) + 1;
  }

  if (ruleCounts.isEmpty) return mihomoYaml;

  // Primary = highest rule-count; tie → earliest in proxy-groups order.
  String? primary;
  var primaryCount = -1;
  for (final name in groupOrder) {
    final count = ruleCounts[name];
    if (count == null) continue;
    if (count > primaryCount) {
      primaryCount = count;
      primary = name;
    }
  }
  if (primary == null) return mihomoYaml;

  final primaryMembers = groupMembers[primary]!;
  if (primaryMembers.isEmpty) return mihomoYaml;

  // Derive a human display name for each emergency proxy: country flag emoji +
  // country word taken from the ORIGINAL label, stripping provider / SNI /
  // protocol / TG noise. Dedup collisions (against each other AND existing
  // top-level names) with a numeric suffix. Fall back to `🌐 Node N` when no
  // flag/country can be parsed.
  final usedNames = <String>{...existingProxyNames};
  final renamedSos = <Map<String, Object>>[];
  final smartMembers = <String>[];
  var nodeIndex = 0;
  for (final proxy in sosProxies) {
    nodeIndex++;
    final base = _deriveDisplayName(proxy['name']?.toString() ?? '', nodeIndex);
    final unique = _uniqueName(base, usedNames);
    usedNames.add(unique);
    smartMembers.add(unique);
    renamedSos.add(<String, Object>{...proxy, 'name': unique});
  }

  // Build the `🧠 Smart` group spec (used only when no such group exists yet).
  final smartGroup = <String, Object>{
    'name': _smartGroupName,
    'type': 'smart',
    'uselightgbm': false,
    'include-all': true,
  };

  final hasSmart = groupMembers.containsKey(_smartGroupName);

  // Mutations are applied as deterministic text splices rather than via
  // `yaml_edit.appendToList`. yaml_edit mis-indents a complex map appended to a
  // list whose final item carries an empty/comment-only nested block (the
  // mihomo `proxies:\n  # LEAVE THIS LINE!` placeholder), so we render the new
  // blocks to correctly-indented YAML text and insert them at the end of each
  // top-level section. Everything else stays byte-for-byte intact.
  var result = mihomoYaml;

  // (a) Append the (renamed) emergency proxies to top-level `proxies`.
  final proxyEntries = StringBuffer();
  for (final p in renamedSos) {
    proxyEntries.write(emitListItemMap(p, '  '));
  }
  result = appendToTopLevelBlock(result, 'proxies', proxyEntries.toString());

  // (b) Append the `🧠 Smart` smart group only if one does not already exist.
  if (!hasSmart) {
    result = appendToTopLevelBlock(
      result,
      'proxy-groups',
      emitListItemMap(smartGroup, '  '),
    );
  }

  // (c) `yaml_edit` for the in-place edits that it handles reliably:
  //     - add `include-all: true` to a pre-existing `🧠 Smart` group, and
  //     - prepend `🧠 Smart` at index 0 of the primary router's members.
  final editor = YamlEditor(result);
  final reparsed = loadYaml(result);

  if (hasSmart) {
    final smartIndex = findGroupIndex(reparsed, _smartGroupName);
    if (smartIndex != null) {
      final existing = (reparsed as Map)['proxy-groups'][smartIndex];
      final alreadyIncludesAll =
          existing is Map && existing['include-all'] == true;
      if (!alreadyIncludesAll) {
        editor.update(
          ['proxy-groups', smartIndex, 'include-all'],
          true,
        );
      }
    }
  }

  final primaryIndex = findGroupIndex(loadYaml(editor.toString()), primary);
  if (primaryIndex != null) {
    final updated = loadYaml(editor.toString());
    final members = (updated as Map)['proxy-groups'][primaryIndex]['proxies'];
    final firstIsSmart = members is List &&
        members.isNotEmpty &&
        members.first?.toString() == _smartGroupName;
    if (!firstIsSmart) {
      editor.insertIntoList(
        ['proxy-groups', primaryIndex, 'proxies'],
        0,
        _smartGroupName,
      );
    }
  }
  return editor.toString();
}

/// Derives the display name for an emergency proxy from its [original] label.
/// Returns flag emoji + country word (e.g. `🇷🇺 Russia`), or `🌐 Node [index]`
/// when no regional-indicator flag + country can be parsed.
String _deriveDisplayName(String original, int index) {
  final match = _flagCountryRe.firstMatch(original);
  if (match != null) {
    final flag = match.group(1)!;
    final country = match.group(2)!.trim();
    if (country.isNotEmpty) return '$flag $country';
  }
  return '🌐 Node $index';
}

/// Returns [base] if unused, else appends ` 2`, ` 3`, ... until unique within
/// [used]. Does not mutate [used].
String _uniqueName(String base, Set<String> used) {
  if (!used.contains(base)) return base;
  var n = 2;
  var candidate = '$base $n';
  while (used.contains(candidate)) {
    n++;
    candidate = '$base $n';
  }
  return candidate;
}
