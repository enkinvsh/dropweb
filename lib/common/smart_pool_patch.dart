import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'mihomo_yaml_splice.dart';

/// Name of the smart auto-selecting group used for the emergency pool merge.
/// Mirrors the `🧠 Smart` group the raw-subscription synthesizer emits in
/// `share_link_profile`, which is proven to pick the best live foreign server
/// on device.
const _smartGroupName = disconekoSmartGroupName;

/// Public name of the disconeko emergency-pool smart group. It must stay a
/// real, NON-hidden top-level group so the Mihomo core health-checks it (and
/// `📶 First Available`, which references it, shows a delay). It is filtered
/// from the user-facing groups list purely in the UI layer (by this name) so it
/// is never a standalone selectable row — see `_RulesProxiesView`.
const disconekoSmartGroupName = '🧠 Smart';

/// Name of the `fallback` group that surfaces the emergency pool — mirrors the
/// `📶 First Available` group in the dropweb panel template. Offered as a
/// selectable (NON-default) option inside the primary router.
const _firstAvailableGroupName = '📶 First Available';

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

/// Merges an emergency pool of [sosProxies] into [mihomoYaml] by surfacing them
/// through the `📶 First Available` (`type: fallback`) proxy-group.
///
/// The function is PURE (no I/O). It performs only additive mutations:
/// - appends the (renamed) emergency proxies to top-level `proxies`;
/// - ensures a `🧠 Smart` smart group (`include-all: true`) exists;
/// - makes `🧠 Smart` the first member of `📶 First Available` when that group
///   already exists, OR creates a `📶 First Available` fallback group (holding
///   `🧠 Smart`) and appends it as a NON-default option to the primary router.
///
/// The primary router's own default is NEVER changed. The rest of the user's
/// YAML — comments, formatting, key order, all other groups and ALL rules — is
/// preserved byte-for-byte (text-splice appends + reliable `yaml_edit` edits).
///
/// Returns [mihomoYaml] unchanged when there is nothing to merge: no emergency
/// proxies, or no `📶 First Available` group AND no qualifying primary router
/// to anchor a freshly-created one.
///
/// Design rationale: `📶 First Available` is the panel template's opt-in
/// fallback group; routing the emergency pool through a `🧠 Smart`
/// (`include-all: true`) member lets it pick the best live server on device
/// without hijacking the user's default route.
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

  // Primary router = the group most rules target (single-sourced detection).
  final primary = detectPrimaryRouter(groups, rules);
  final hasSmart = groupMembers.containsKey(_smartGroupName);
  final hasFirstAvail = groupMembers.containsKey(_firstAvailableGroupName);

  // No-op guard: if there is no `📶 First Available` to target AND no
  // qualifying primary to anchor a new one, there is nowhere meaningful to
  // surface the pool — leave the profile byte-for-byte unchanged.
  if (!hasFirstAvail &&
      (primary == null || groupMembers[primary]!.isEmpty)) {
    return mihomoYaml;
  }

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
    // NOTE: intentionally NOT `hidden: true`. A config-level hidden flag makes
    // the core deprioritize the group and stops reporting its delay, which
    // broke the `📶 First Available` availability badge (and its selection
    // surfacing). The group stays a normal health-checked group; it's filtered
    // from the user-facing list purely in the UI (`_RulesProxiesView`) by name.
  };

  // Build the `📶 First Available` fallback group spec (used only when no such
  // group exists yet). Starts with `🧠 Smart` as its sole member.
  final firstAvailGroup = <String, Object>{
    'name': _firstAvailableGroupName,
    'type': 'fallback',
    'url': 'https://cp.cloudflare.com/generate_204',
    'interval': 180,
    'lazy': true,
    'proxies': <String>[_smartGroupName],
  };

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

  // (c) Append a NEW `📶 First Available` fallback group only if none exists.
  if (!hasFirstAvail) {
    result = appendToTopLevelBlock(
      result,
      'proxy-groups',
      emitListItemMap(firstAvailGroup, '  '),
    );
  }

  // (d) `yaml_edit` for the in-place edits that it handles reliably. Re-parse
  //     before each structural read so indices stay valid after prior edits.
  final editor = YamlEditor(result);

  if (hasSmart) {
    // Ensure the pre-existing `🧠 Smart` group has `include-all: true`.
    final reparsed = loadYaml(editor.toString());
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

  if (hasFirstAvail) {
    // Surface the pool by making `🧠 Smart` the FIRST member of the existing
    // `📶 First Available` group. Leave the primary router untouched.
    final reparsed = loadYaml(editor.toString());
    final faIndex = findGroupIndex(reparsed, _firstAvailableGroupName);
    if (faIndex != null) {
      final members =
          (reparsed as Map)['proxy-groups'][faIndex]['proxies'];
      if (members is List && members.isNotEmpty) {
        final firstIsSmart = members.first?.toString() == _smartGroupName;
        if (!firstIsSmart) {
          editor.insertIntoList(
            ['proxy-groups', faIndex, 'proxies'],
            0,
            _smartGroupName,
          );
        }
      } else {
        // proxies is null/empty (e.g. a `# LEAVE THIS LINE!` placeholder) —
        // replace it with a fresh single-member list.
        editor.update(
          ['proxy-groups', faIndex, 'proxies'],
          [_smartGroupName],
        );
      }
    }
  } else if (primary != null) {
    // The `📶 First Available` group was just created with `🧠 Smart` inside;
    // wire it into the primary router as an APPENDED (non-default) option.
    final reparsed = loadYaml(editor.toString());
    final primaryIndex = findGroupIndex(reparsed, primary);
    if (primaryIndex != null) {
      final members =
          (reparsed as Map)['proxy-groups'][primaryIndex]['proxies'];
      final alreadyListed = members is List &&
          members.any((m) => m?.toString() == _firstAvailableGroupName);
      if (!alreadyListed) {
        editor.appendToList(
          ['proxy-groups', primaryIndex, 'proxies'],
          _firstAvailableGroupName,
        );
      }
    }
  }

  return editor.toString();
}

/// Detects the "primary router" proxy-group from a parsed Mihomo config's
/// [proxyGroups] and [rules] lists: the qualifying group the most rules target
/// (tie → earliest in `proxy-groups` order). Returns `null` when none qualifies.
///
/// A group QUALIFIES only if it carries at least one member that is NOT a
/// built-in target (`DIRECT`/`REJECT`/...), i.e. it can actually route proxied
/// traffic. This is the single source of truth for "which group is the user's
/// main route" — shared by [patchSmartPool] and the work-mode engine so the two
/// never diverge.
String? detectPrimaryRouter(Object? proxyGroups, Object? rules) {
  if (proxyGroups is! List || rules is! List) return null;

  final groupMembers = <String, List<String>>{};
  final groupOrder = <String>[];
  for (final g in proxyGroups) {
    if (g is! Map) continue;
    final name = g['name']?.toString();
    if (name == null) continue;
    groupOrder.add(name);
    final members = <String>[];
    final ps = g['proxies'];
    if (ps is List) {
      for (final m in ps) {
        if (m != null) members.add(m.toString());
      }
    }
    groupMembers[name] = members;
  }

  bool isQualifyingGroup(String name) {
    final members = groupMembers[name];
    if (members == null) return false;
    return members.any((m) => !mihomoBuiltinTargets.contains(m));
  }

  final ruleCounts = <String, int>{};
  for (final rule in rules) {
    final target = ruleTarget(rule?.toString() ?? '');
    if (target == null) continue;
    if (mihomoBuiltinTargets.contains(target)) continue;
    if (!groupMembers.containsKey(target)) continue;
    if (!isQualifyingGroup(target)) continue;
    ruleCounts[target] = (ruleCounts[target] ?? 0) + 1;
  }

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
  return primary;
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
