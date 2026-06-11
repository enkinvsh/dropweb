/// Country grouping for subscription nodes.
///
/// Nodes in a subscription are named with a leading flag emoji (e.g.
/// "🇩🇪 Frankfurt 01"). A flag emoji is encoded as a pair of Unicode regional
/// indicator symbols (U+1F1E6..U+1F1FF). The flag emoji itself is the country
/// key — there is intentionally no country-name/ISO mapping here (the emoji IS
/// the key; the UI labels the no-flag bucket «Другое»).
///
/// The parsing logic is ported verbatim from the original private helpers in
/// `change_server_button.dart` so behavior stays pixel-identical.
library;

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
/// The key is the flag emoji as returned by [extractCountryFlag]. Nodes without
/// a recognizable flag are collected under the empty-string key `''` (the UI
/// labels this bucket «Другое»). Input order is preserved both for the keys and
/// within each group. No nodes are filtered out — special-node filtering is the
/// caller's responsibility.
Map<String, List<String>> groupNodesByCountry(Iterable<String> nodeNames) {
  final groups = <String, List<String>>{};

  for (final name in nodeNames) {
    final key = extractCountryFlag(name) ?? '';
    (groups[key] ??= <String>[]).add(name);
  }

  return groups;
}
