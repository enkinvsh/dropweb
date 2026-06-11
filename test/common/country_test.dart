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

  group('isIpv4', () {
    test('accepts a well-formed dotted-quad address', () {
      expect(isIpv4('152.53.155.182'), isTrue);
      expect(isIpv4('1.2.3.4'), isTrue);
      expect(isIpv4('255.255.255.255'), isTrue);
      expect(isIpv4('0.0.0.0'), isTrue);
    });

    test('rejects a domain host', () {
      expect(isIpv4('de.meybz.asia'), isFalse);
    });

    test('rejects octet out of range', () {
      expect(isIpv4('1.2.3.999'), isFalse);
      expect(isIpv4('256.1.1.1'), isFalse);
    });

    test('rejects wrong segment count', () {
      expect(isIpv4('1.2.3'), isFalse);
      expect(isIpv4('1.2.3.4.5'), isFalse);
    });

    test('rejects empty / non-numeric segments', () {
      expect(isIpv4(''), isFalse);
      expect(isIpv4('1.2.3.'), isFalse);
      expect(isIpv4('a.b.c.d'), isFalse);
    });
  });

  group('maskServerAddress', () {
    test('masks last two octets of an IPv4 address', () {
      expect(maskServerAddress('45.135.20.7'), '45.135.•.•');
      expect(maskServerAddress('192.168.1.1'), '192.168.•.•');
    });

    test('returns a host/domain unchanged', () {
      expect(maskServerAddress('de.meybz.asia'), 'de.meybz.asia');
    });

    test('returns a malformed address unchanged', () {
      expect(maskServerAddress('1.2.3'), '1.2.3');
      expect(maskServerAddress('1.2.3.999'), '1.2.3.999');
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

    test('puts nodes without a recognizable flag under the empty-string key', () {
      final result = groupNodesByCountry(['Auto', '🇩🇪 Frankfurt 01', 'Direct']);
      expect(result[''], ['Auto', 'Direct']);
      expect(result['🇩🇪'], ['🇩🇪 Frankfurt 01']);
    });

    test('returns an empty map for empty input', () {
      expect(groupNodesByCountry(<String>[]), <String, List<String>>{});
    });
  });
}
