import 'package:dropweb/common/country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractCountryFlag', () {
    test('extracts flag emoji from a node name', () {
      expect(extractCountryFlag('🇩🇪 Frankfurt 01'), '🇩🇪');
    });

    test('returns null when there is no flag', () {
      expect(extractCountryFlag('Frankfurt 01'), isNull);
    });

    test('returns the first flag when multiple are present', () {
      expect(extractCountryFlag('🇩🇪 → 🇳🇱 relay'), '🇩🇪');
    });

    test('returns null for empty input', () {
      expect(extractCountryFlag(''), isNull);
    });
  });

  group('stripCountryFlag', () {
    test('removes the flag and trims surrounding whitespace', () {
      expect(stripCountryFlag('🇩🇪 Frankfurt 01'), 'Frankfurt 01');
    });

    test('returns the text unchanged (trimmed) when there is no flag', () {
      expect(stripCountryFlag('  Frankfurt 01  '), 'Frankfurt 01');
    });

    test('removes all flags present', () {
      expect(stripCountryFlag('🇩🇪🇳🇱 relay'), 'relay');
    });
  });

  group('countryDisplayName', () {
    test('uses first node name with flag stripped', () {
      expect(
        countryDisplayName('🇩🇪', ['🇩🇪 Германия', '🇩🇪 Германия 2']),
        'Германия',
      );
    });

    test('skips flag-only node names, uses next informative one', () {
      expect(countryDisplayName('🇳🇱', ['🇳🇱', '🇳🇱 Нидерланды']), 'Нидерланды');
    });

    test('falls back to ISO letters when all names are flag-only', () {
      expect(countryDisplayName('🇩🇪', ['🇩🇪']), 'DE');
      expect(countryDisplayName('🇳🇱', []), 'NL');
    });
  });

  group('groupNodesByCountry', () {
    test('groups a single flagged node under its flag', () {
      final result = groupNodesByCountry(['🇩🇪 Frankfurt 01']);
      expect(result, {
        '🇩🇪': ['🇩🇪 Frankfurt 01'],
      });
    });

    test('groups multiple countries and preserves input order', () {
      final result = groupNodesByCountry([
        '🇩🇪 Frankfurt 01',
        '🇳🇱 Amsterdam 01',
        '🇩🇪 Frankfurt 02',
        '🇳🇱 Amsterdam 02',
      ]);
      expect(result.keys.toList(), ['🇩🇪', '🇳🇱']);
      expect(result['🇩🇪'], ['🇩🇪 Frankfurt 01', '🇩🇪 Frankfurt 02']);
      expect(result['🇳🇱'], ['🇳🇱 Amsterdam 01', '🇳🇱 Amsterdam 02']);
    });

    test('each flagless node becomes its own single-node group keyed by name',
        () {
      final result = groupNodesByCountry(['Auto', '🇩🇪 Frankfurt 01', 'Direct']);
      expect(result['Auto'], ['Auto']);
      expect(result['Direct'], ['Direct']);
      expect(result[''], isNull);
      expect(result['🇩🇪'], ['🇩🇪 Frankfurt 01']);
    });

    test('isCountryFlagKey separates flag keys from node-name keys', () {
      expect(isCountryFlagKey('🇩🇪'), isTrue);
      expect(isCountryFlagKey('Auto'), isFalse);
      // The display flag for flagless rows is the single black flag — one
      // codepoint, NOT a regional-indicator pair, so not a flag key itself.
      expect(kNoFlagDisplayFlag, '🏴');
      expect(isCountryFlagKey(kNoFlagDisplayFlag), isFalse);
    });

    test('returns an empty map for empty input', () {
      expect(groupNodesByCountry(<String>[]), <String, List<String>>{});
    });
  });
}
