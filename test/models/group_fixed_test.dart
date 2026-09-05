import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group.fromJson `fixed`', () {
    test("carries the core's live manual pin", () {
      // Given — mihomo marshals a computed group's honored pin as `fixed`
      // (adapter/outboundgroup/{fallback,urltest,smart}.go).
      final group = Group.fromJson(const {
        'type': 'Fallback',
        'name': '▶️ YouTube',
        'now': '🌀 Cascade',
        'fixed': '🌀 Cascade',
        'all': <Map<String, Object?>>[],
      });

      expect(group.fixed, '🌀 Cascade');
    });

    test('is empty once the core drops a dead pin', () {
      final group = Group.fromJson(const {
        'type': 'Fallback',
        'name': '▶️ YouTube',
        'now': '⚡ Fastest',
        'fixed': '',
        'all': <Map<String, Object?>>[],
      });

      expect(group.fixed, isEmpty);
    });

    test('defaults to empty for a selector, which never reports `fixed`', () {
      final group = Group.fromJson(const {
        'type': 'Selector',
        'name': 'GLOBAL',
        'now': '🇩🇪 Германия',
        'all': <Map<String, Object?>>[],
      });

      expect(group.fixed, isEmpty);
    });
  });
}
