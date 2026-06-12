/// Country grouping for subscription nodes.
///
/// Nodes in a subscription are named with a leading flag emoji (e.g.
/// "🇩🇪 Frankfurt 01"). A flag emoji is encoded as a pair of Unicode regional
/// indicator symbols (U+1F1E6..U+1F1FF). The flag emoji itself is the country
/// key — there is intentionally no country-name/ISO mapping here (the emoji IS
/// the key). Nodes without a recognizable flag are bucketed under the pirate
/// flag [kNoFlagCountryKey], a first-class selectable «country» the UI labels
/// «Другое».
///
/// The parsing logic is ported verbatim from the original private helpers in
/// `change_server_button.dart` so behavior stays pixel-identical.
library;

/// Display flag for nodes without a country flag — the single 🏴 waving black
/// flag (U+1F3F4, one codepoint, present in the bundled Twemoji font; the
/// pirate 🏴‍☠️ ZWJ ligature is NOT — it renders as two glyphs).
///
/// Flagless nodes are NOT lumped into one bucket: each gets its own key (its
/// node name, see [groupNodesByCountry]) and renders as an individual
/// selectable row «🏴 node name», last in the picker.
const String kNoFlagDisplayFlag = '🏴';

/// Whether [key] from [groupNodesByCountry] is a real flag-emoji country key
/// (regional-indicator pair) as opposed to a flagless node-name key.
bool isCountryFlagKey(String key) => extractCountryFlag(key) != null;

const int _regionalIndicatorStart = 0x1F1E6;
const int _regionalIndicatorEnd = 0x1F1FF;

bool _isRegionalIndicator(int rune) =>
    rune >= _regionalIndicatorStart && rune <= _regionalIndicatorEnd;

/// Human-readable display name for a country bucket.
///
/// Subscription node names carry the localized country name after the flag
/// (e.g. "🇩🇪 Германия" → "Германия"), so the first node's flag-stripped name
/// is used. Falls back to the ISO letters encoded in the flag's regional
/// indicators (🇩🇪 → "DE") when every node name is flag-only.
String countryDisplayName(String flag, List<String> nodeNames) {
  for (final name in nodeNames) {
    final stripped = stripCountryFlag(name).trim();
    if (stripped.isNotEmpty) return stripped;
  }
  return flag.runes
      .where(_isRegionalIndicator)
      .map((r) => String.fromCharCode(r - _regionalIndicatorStart + 0x41))
      .join();
}

/// Returns the first flag emoji found in [text], or null if there is none.
///
/// A flag is the first adjacent pair of regional indicator symbols.
String? extractCountryFlag(String text) {
  final runes = text.runes.toList();

  for (var i = 0; i < runes.length - 1; i++) {
    final first = runes[i];
    final second = runes[i + 1];

    if (_isRegionalIndicator(first) && _isRegionalIndicator(second)) {
      return String.fromCharCodes([first, second]);
    }
  }

  return null;
}

/// Returns [text] with every flag emoji (regional indicator pair) removed and
/// the result trimmed.
String stripCountryFlag(String text) {
  final runes = text.runes.toList();
  final result = <int>[];

  var i = 0;
  while (i < runes.length) {
    final current = runes[i];

    if (_isRegionalIndicator(current) && i + 1 < runes.length) {
      final next = runes[i + 1];

      if (_isRegionalIndicator(next)) {
        i += 2;
        continue;
      }
    }

    result.add(current);
    i++;
  }

  return String.fromCharCodes(result).trim();
}

/// Groups [nodeNames] by their leading country flag emoji.
///
/// The key is the flag emoji as returned by [extractCountryFlag]. A node
/// without a recognizable flag becomes ITS OWN single-node group keyed by the
/// full node name (so the picker can offer the actual server, not an opaque
/// «Other» bucket; the stored work-mode key resolves back to exactly that
/// node). Distinguish key kinds via [isCountryFlagKey]. Input order is
/// preserved both for the keys and within each group. No nodes are filtered
/// out — special-node filtering is the caller's responsibility.
Map<String, List<String>> groupNodesByCountry(Iterable<String> nodeNames) {
  final groups = <String, List<String>>{};

  for (final name in nodeNames) {
    final key = extractCountryFlag(name) ?? name;
    (groups[key] ??= <String>[]).add(name);
  }

  return groups;
}

/// Resolves a stored work-mode country key to its node pool.
///
/// Three key kinds are accepted:
///  * a flag-emoji key — all nodes carrying that flag (the country pool);
///  * an exact node name of a FLAGGED node — that single node (the picker
///    offers same-flag servers individually, so the stored key may be a
///    node name even though the node has a flag);
///  * a flagless node name — that single node (its own group key already).
///
/// Unknown keys resolve to an empty list. mihomo requires unique proxy
/// names, so a node-name key is unambiguous.
List<String> resolveCountryKeyNodes(Iterable<String> nodeNames, String key) {
  final direct = groupNodesByCountry(nodeNames)[key];
  if (direct != null) return direct;
  return nodeNames.contains(key) ? <String>[key] : const <String>[];
}

/// One selectable row of the country picker.
class CountryPickerEntry {
  const CountryPickerEntry({
    required this.key,
    required this.flag,
    required this.label,
    required this.flagged,
    required this.proxyName,
  });

  /// Work-mode key stored on apply: a flag emoji (single-server country),
  /// or an exact node name (expanded same-flag server / flagless node).
  final String key;

  /// Flag rendered before [label] (🏴 for flagless nodes).
  final String flag;

  /// Human-readable row text (flag-stripped node name or ISO fallback).
  final String label;

  /// True for rows backed by a flag-carrying node; false for flagless rows
  /// (which the picker gates behind a successful delay test).
  final bool flagged;

  /// The node whose health the availability badge probes.
  final String proxyName;
}

/// Flattens [groups] (from [groupNodesByCountry]) into picker rows.
///
/// Servers must NOT collapse: a flag group with more than one node expands
/// into one row PER server («🇩🇪 Германия-1», «🇩🇪 Германия-2»), each keyed by
/// its node name. Only a single-node flag group renders as a classic country
/// row keyed by the flag itself. Flagless node groups keep their existing
/// individual-row behavior and are emitted AFTER all flagged rows. Input
/// order is preserved.
List<CountryPickerEntry> countryPickerEntries(
  Map<String, List<String>> groups,
) {
  final flagged = <CountryPickerEntry>[];
  final flagless = <CountryPickerEntry>[];

  groups.forEach((key, nodes) {
    if (!isCountryFlagKey(key)) {
      flagless.add(CountryPickerEntry(
        key: key,
        flag: kNoFlagDisplayFlag,
        label: key,
        flagged: false,
        proxyName: key,
      ));
      return;
    }
    if (nodes.length == 1) {
      flagged.add(CountryPickerEntry(
        key: key,
        flag: key,
        label: countryDisplayName(key, nodes),
        flagged: true,
        proxyName: nodes.single,
      ));
      return;
    }
    for (final node in nodes) {
      final stripped = stripCountryFlag(node);
      flagged.add(CountryPickerEntry(
        key: node,
        flag: key,
        label: stripped.isNotEmpty ? stripped : countryDisplayName(key, const []),
        flagged: true,
        proxyName: node,
      ));
    }
  });

  return [...flagged, ...flagless];
}
