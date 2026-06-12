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

  group('resolveCountryKeyNodes', () {
    const nodes = [
      '🇩🇪 Германия-1',
      '🇩🇪 Германия-2',
      '🇳🇱 Нидерланды',
      'balancer-host',
    ];

    test('flag key resolves to all same-flag nodes', () {
      expect(
        resolveCountryKeyNodes(nodes, '🇩🇪'),
        ['🇩🇪 Германия-1', '🇩🇪 Германия-2'],
      );
    });

    test('flagged node NAME resolves to exactly that node', () {
      expect(
        resolveCountryKeyNodes(nodes, '🇩🇪 Германия-2'),
        ['🇩🇪 Германия-2'],
      );
    });

    test('flagless node name resolves to itself (group key)', () {
      expect(resolveCountryKeyNodes(nodes, 'balancer-host'), ['balancer-host']);
    });

    test('unknown key resolves to empty', () {
      expect(resolveCountryKeyNodes(nodes, '🇫🇷'), isEmpty);
      expect(resolveCountryKeyNodes(nodes, 'nope'), isEmpty);
    });
  });

  group('countryPickerEntries', () {
    test('single-node flag group stays one country row keyed by flag', () {
      final entries = countryPickerEntries(
        groupNodesByCountry(['🇳🇱 Нидерланды']),
      );
      expect(entries, hasLength(1));
      expect(entries.single.key, '🇳🇱');
      expect(entries.single.flagged, isTrue);
      expect(entries.single.label, 'Нидерланды');
      expect(entries.single.proxyName, '🇳🇱 Нидерланды');
    });

    test('multi-node flag group expands to one row per server', () {
      final entries = countryPickerEntries(
        groupNodesByCountry(['🇩🇪 Германия-1', '🇩🇪 Германия-2']),
      );
      expect(entries, hasLength(2));
      expect(entries[0].key, '🇩🇪 Германия-1');
      expect(entries[0].flagged, isTrue);
      expect(entries[0].flag, '🇩🇪');
      expect(entries[0].label, 'Германия-1');
      expect(entries[0].proxyName, '🇩🇪 Германия-1');
      expect(entries[1].key, '🇩🇪 Германия-2');
      expect(entries[1].label, 'Германия-2');
    });

    test('expanded row with flag-only name falls back to ISO label', () {
      final entries = countryPickerEntries(
        groupNodesByCountry(['🇩🇪', '🇩🇪 Берлин']),
      );
      expect(entries[0].label, 'DE');
      expect(entries[1].label, 'Берлин');
    });

    test('flagless nodes stay individual unflagged rows after flagged ones',
        () {
      final entries = countryPickerEntries(
        groupNodesByCountry(
          ['balancer-host', '🇩🇪 Германия-1', '🇩🇪 Германия-2'],
        ),
      );
      expect(entries, hasLength(3));
      expect(entries[0].flagged, isTrue);
      expect(entries[1].flagged, isTrue);
      expect(entries[2].flagged, isFalse);
      expect(entries[2].key, 'balancer-host');
      expect(entries[2].label, 'balancer-host');
    });

    test('config order is preserved within and across flag groups', () {
      final entries = countryPickerEntries(
        groupNodesByCountry([
          '🇳🇱 Нидерланды',
          '🇩🇪 Германия-1',
          '🇩🇪 Германия-2',
        ]),
      );
      expect(entries.map((e) => e.key).toList(), [
        '🇳🇱',
        '🇩🇪 Германия-1',
        '🇩🇪 Германия-2',
      ]);
    });
  });
}
