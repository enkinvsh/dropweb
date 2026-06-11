import 'package:dropweb/common/doh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDohAnswer', () {
    test('extracts A records (type==1) in order', () {
      final json = <String, dynamic>{
        'Status': 0,
        'Answer': [
          {'name': 'de.meybz.asia', 'type': 1, 'data': '152.53.155.182'},
          {'name': 'de.meybz.asia', 'type': 1, 'data': '138.124.126.86'},
          {'name': 'de.meybz.asia', 'type': 1, 'data': '138.124.126.137'},
          {'name': 'de.meybz.asia', 'type': 1, 'data': '13.140.25.104'},
        ],
      };
      expect(parseDohAnswer(json), [
        '152.53.155.182',
        '138.124.126.86',
        '138.124.126.137',
        '13.140.25.104',
      ]);
    });

    test('ignores non-A records (AAAA type==28, CNAME type==5)', () {
      final json = <String, dynamic>{
        'Answer': [
          {'name': 'de.meybz.asia', 'type': 5, 'data': 'pool.example.'},
          {'name': 'de.meybz.asia', 'type': 1, 'data': '152.53.155.182'},
          {'name': 'de.meybz.asia', 'type': 28, 'data': '2a01:4f8::1'},
          {'name': 'de.meybz.asia', 'type': 1, 'data': '138.124.126.86'},
        ],
      };
      expect(parseDohAnswer(json), ['152.53.155.182', '138.124.126.86']);
    });

    test('dedupes repeated A records, preserving first-seen order', () {
      final json = <String, dynamic>{
        'Answer': [
          {'type': 1, 'data': '1.1.1.1'},
          {'type': 1, 'data': '2.2.2.2'},
          {'type': 1, 'data': '1.1.1.1'},
        ],
      };
      expect(parseDohAnswer(json), ['1.1.1.1', '2.2.2.2']);
    });

    test('returns [] for an empty Answer list', () {
      expect(parseDohAnswer(<String, dynamic>{'Answer': <dynamic>[]}), isEmpty);
    });

    test('returns [] when Answer is missing', () {
      expect(parseDohAnswer(<String, dynamic>{'Status': 0}), isEmpty);
    });

    test('returns [] when Answer is the wrong shape', () {
      expect(parseDohAnswer(<String, dynamic>{'Answer': 'oops'}), isEmpty);
    });

    test('skips A records whose data is not a valid IPv4', () {
      final json = <String, dynamic>{
        'Answer': [
          {'type': 1, 'data': 'not-an-ip'},
          {'type': 1, 'data': '152.53.155.182'},
          {'type': 1, 'data': ''},
        ],
      };
      expect(parseDohAnswer(json), ['152.53.155.182']);
    });

    test('skips records with a missing/non-string data field', () {
      final json = <String, dynamic>{
        'Answer': [
          {'type': 1},
          {'type': 1, 'data': 12345},
          {'type': 1, 'data': '152.53.155.182'},
        ],
      };
      expect(parseDohAnswer(json), ['152.53.155.182']);
    });
  });
}
