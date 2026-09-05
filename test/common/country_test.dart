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

    test(
        'a Hy2 node named with a leading flag buckets under that flag, '
        'not a flagless row (Страна auto-fix)', () {
      // The spec-built Hy2 proxy is now named "🇵🇱 Польша🎮" (leading PL flag)
      // instead of the old synthetic "🎮 pl.meybz.asia" (no leading flag → it
      // polluted «Страна» as a flagless 🏴 row). The flag must win the bucket.
      final result = groupNodesByCountry(['🇳🇱 Amsterdam 01', '🇵🇱 Польша🎮']);
      expect(result['🇵🇱'], ['🇵🇱 Польша🎮']);
      // No flagless bucket: neither the raw node name nor a "🎮" key exists.
      expect(result['🇵🇱 Польша🎮'], isNull);
      expect(result['🎮'], isNull);
      expect(result.keys.every((k) => extractCountryFlag(k) != null), isTrue);
    });

    test('each flagless node becomes its own single-node group keyed by name',
        () {
      final result = groupNodesByCountry(['Auto', '🇩🇪 Frankfurt 01', 'Direct']);
      expect(result['Auto'], ['Auto']);
      expect(result['Direct'], ['Direct']);
      expect(result[''], isNull);
      expect(result['🇩🇪'], ['🇩🇪 Frankfurt 01']);
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
}
