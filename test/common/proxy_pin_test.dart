import 'package:dropweb/common/proxy_pin.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Group buildGroup({
    required String name,
    required GroupType type,
    String? now,
    String fixed = '',
  }) =>
      Group(type: type, name: name, now: now, fixed: fixed);

  group('staleSelectedGroupNames', () {
    test(
        'reports a computed group whose pinned member the core has already '
        'dropped', () {
      // Given — the pinned 🌀 Cascade died, so the core cleared its own pin
      // (fixed: "") and now routes ▶️ YouTube through ⚡ Fastest.
      final groups = [
        buildGroup(
          name: '▶️ YouTube',
          type: GroupType.Fallback,
          now: '⚡ Fastest',
        ),
      ];

      // When
      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: const {'▶️ YouTube': '🌀 Cascade'},
      );

      // Then
      expect(stale, {'▶️ YouTube'});
    });

    test('keeps a pin the core still honors', () {
      final groups = [
        buildGroup(
          name: '▶️ YouTube',
          type: GroupType.Fallback,
          now: '🌀 Cascade',
          fixed: '🌀 Cascade',
        ),
      ];

      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: const {'▶️ YouTube': '🌀 Cascade'},
      );

      expect(stale, isEmpty);
    });

    test('reports a url-test group the same way as a fallback group', () {
      final groups = [
        buildGroup(
          name: '⚡ Fastest',
          type: GroupType.URLTest,
          now: '🇳🇱 Нидерланды',
        ),
      ];

      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: const {'⚡ Fastest': '🇩🇪 Германия'},
      );

      expect(stale, {'⚡ Fastest'});
    });

    test(
        'never touches a selector group, where the saved pin IS the routing '
        'decision', () {
      // A selector reports no `fixed` at all — its `now` is the user's pick.
      final groups = [
        buildGroup(
          name: 'GLOBAL',
          type: GroupType.Selector,
          now: '🇩🇪 Германия',
        ),
      ];

      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: const {'GLOBAL': '🇳🇱 Нидерланды'},
      );

      expect(stale, isEmpty);
    });

    test('never touches a work-mode key the app itself owns', () {
      // «Умный» / «Страна <flag>» pins express the selected work mode, not a
      // manual pick: dropping them would silently unwire the mode.
      final groups = [
        buildGroup(name: '🌍 VPN', type: GroupType.Fallback, now: '⚡ Fastest'),
        buildGroup(
          name: '▶️ YouTube',
          type: GroupType.Fallback,
          now: '⚡ Fastest',
        ),
      ];

      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: {
          '🌍 VPN': workModeSmartGroupName,
          '▶️ YouTube': workModeCountryGroupName('🇩🇪'),
        },
      );

      expect(stale, isEmpty);
    });

    test('ignores a group that is absent from the core snapshot', () {
      final stale = staleSelectedGroupNames(
        groups: const [],
        selectedMap: const {'▶️ YouTube': '🌀 Cascade'},
      );

      expect(stale, isEmpty);
    });

    test('ignores an empty saved pin', () {
      final groups = [
        buildGroup(
          name: '▶️ YouTube',
          type: GroupType.Fallback,
          now: '⚡ Fastest',
        ),
      ];

      final stale = staleSelectedGroupNames(
        groups: groups,
        selectedMap: const {'▶️ YouTube': ''},
      );

      expect(stale, isEmpty);
    });
  });

  group('isWorkModeOwnedSelection', () {
    test('claims the smart work-mode group', () {
      expect(isWorkModeOwnedSelection(workModeSmartGroupName), isTrue);
    });

    test('claims any country work-mode group', () {
      expect(isWorkModeOwnedSelection(workModeCountryGroupName('🇩🇪')), isTrue);
    });

    test('leaves a manual node pick alone', () {
      expect(isWorkModeOwnedSelection('🌀 Cascade'), isFalse);
      expect(isWorkModeOwnedSelection('🇩🇪 Германия'), isFalse);
    });
  });
}
