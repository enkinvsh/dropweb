/// Flag-emoji parsing and country grouping for subscription nodes.
///
/// Nodes in a subscription are named with a leading flag emoji (e.g.
/// "🇩🇪 Frankfurt 01"). A flag emoji is encoded as a pair of Unicode regional
/// indicator symbols (U+1F1E6..U+1F1FF). The flag emoji itself is the country
/// key — there is intentionally no country-name/ISO mapping here (the emoji IS
/// the key). A node without a recognizable flag is NOT lumped into a shared
/// «other» bucket: it becomes its own single-node group keyed by its node name.
///
/// This library is pure string/rune logic with no UI opinion: it answers «which
/// flag does this node carry» ([extractCountryFlag], [stripCountryFlag],
/// [countryCodeToFlag]) and «which nodes share a country key»
/// ([groupNodesByCountry], [resolveCountryKeyNodes]). Rendering the picker is
/// the UI layer's job — the country screen lists the router group's members
/// directly, so no row-model lives here.
library;

const int _regionalIndicatorStart = 0x1F1E6;
const int _regionalIndicatorEnd = 0x1F1FF;

bool _isRegionalIndicator(int rune) =>
    rune >= _regionalIndicatorStart && rune <= _regionalIndicatorEnd;

/// Converts a two-letter ISO 3166-1 alpha-2 [countryCode] (e.g. "DE") into its
/// flag emoji (🇩🇪) via the standard regional-indicator transform.
///
/// Returns null when [countryCode] is not exactly two ASCII letters (the core
/// returns "" for a GeoIP miss / private IP), so callers can simply omit the
/// flag badge instead of rendering garbage.
String? countryCodeToFlag(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code.length != 2) return null;
  final first = code.codeUnitAt(0);
  final second = code.codeUnitAt(1);
  const a = 0x41;
  const z = 0x5A;
  if (first < a || first > z || second < a || second > z) return null;
  return String.fromCharCode(first - a + _regionalIndicatorStart) +
      String.fromCharCode(second - a + _regionalIndicatorStart);
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
/// node). A key is therefore a flag emoji exactly when [extractCountryFlag]
/// returns non-null for it, and a node name otherwise. Input order is
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
