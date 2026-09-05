import 'package:dropweb/common/setup_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Baseline inputs reused across cases. Note: `selectedMap` is intentionally
  // NOT an input to computeSetupHash — proxy selection is applied separately
  // via changeProxy and must not invalidate the full-setup cache.
  final mtime = DateTime.fromMicrosecondsSinceEpoch(1700000000000000);
  Map<String, dynamic> baseArgs() => {
        'profileId': 'profile-a',
        'profileFileLastModified': mtime,
        'profileFileLength': 4096,
        'patchConfigJson': <String, dynamic>{
          'port': 7890,
          'mode': 'rule',
          'tun': {'enable': true, 'stack': 'system'},
        },
        'overrideDataJson': <String, dynamic>{
          'enable': false,
          'rule': {'type': 'added'},
        },
        'appFlagsJson': <String, dynamic>{
          'overrideNetworkSettings': false,
          'routeMode': 'config',
          'overrideDns': false,
          'scriptId': null,
        },
      };

  String hashOf(Map<String, dynamic> a) => computeSetupHash(
        profileId: a['profileId'] as String,
        profileFileLastModified: a['profileFileLastModified'] as DateTime?,
        profileFileLength: a['profileFileLength'] as int,
        patchConfigJson: a['patchConfigJson'] as Map<String, dynamic>,
        overrideDataJson: a['overrideDataJson'] as Map<String, dynamic>,
        appFlagsJson: a['appFlagsJson'] as Map<String, dynamic>,
      );

  group('computeSetupHash', () {
    test('(a) identical inputs produce identical hash', () {
      expect(hashOf(baseArgs()), equals(hashOf(baseArgs())));
    });

    test('(b) changed profile mtime produces different hash', () {
      final a = baseArgs();
      final b = baseArgs()
        ..['profileFileLastModified'] =
            DateTime.fromMicrosecondsSinceEpoch(1700000000000001);
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('(b2) changed profile file length produces different hash', () {
      final a = baseArgs();
      final b = baseArgs()..['profileFileLength'] = 8192;
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('(c) changed patchConfigJson value produces different hash', () {
      final a = baseArgs();
      final b = baseArgs();
      (b['patchConfigJson'] as Map<String, dynamic>)['port'] = 7891;
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('(c2) changed appFlagsJson value produces different hash', () {
      final a = baseArgs();
      final b = baseArgs();
      (b['appFlagsJson'] as Map<String, dynamic>)['overrideNetworkSettings'] =
          true;
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('(c3) changed overrideDataJson value produces different hash', () {
      final a = baseArgs();
      final b = baseArgs();
      (b['overrideDataJson'] as Map<String, dynamic>)['enable'] = true;
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('(d) key-order-insensitive: same entries, different insertion order '
        'produce the SAME hash (recursive canonicalization)', () {
      final a = computeSetupHash(
        profileId: 'p',
        profileFileLastModified: mtime,
        profileFileLength: 10,
        patchConfigJson: {
          'port': 7890,
          'tun': {'enable': true, 'stack': 'system'},
        },
        overrideDataJson: {'enable': false},
        appFlagsJson: {'overrideNetworkSettings': false, 'routeMode': 'config'},
      );
      final b = computeSetupHash(
        profileId: 'p',
        profileFileLastModified: mtime,
        profileFileLength: 10,
        // Top-level keys reversed AND nested-map keys reversed.
        patchConfigJson: {
          'tun': {'stack': 'system', 'enable': true},
          'port': 7890,
        },
        overrideDataJson: {'enable': false},
        appFlagsJson: {'routeMode': 'config', 'overrideNetworkSettings': false},
      );
      expect(a, equals(b));
    });

    test('(e) selectedMap is NOT an input: it is not present in the function '
        'signature, so proxy selection changes cannot affect the hash', () {
      // This is enforced structurally — computeSetupHash has no selectedMap
      // parameter. Two calls that differ ONLY in proxy selection state (which
      // lives outside these inputs) yield the same hash because that state is
      // never passed in.
      expect(hashOf(baseArgs()), equals(hashOf(baseArgs())));
    });

    test('null profileFileLastModified is handled deterministically', () {
      final a = baseArgs()..['profileFileLastModified'] = null;
      expect(hashOf(a), equals(hashOf(a)));
      // null differs from a concrete mtime.
      expect(hashOf(a), isNot(equals(hashOf(baseArgs()))));
    });

    test('different profileId produces different hash', () {
      final a = baseArgs();
      final b = baseArgs()..['profileId'] = 'profile-b';
      expect(hashOf(a), isNot(equals(hashOf(b))));
    });

    test('hash is a 32-char hex md5 string', () {
      final h = hashOf(baseArgs());
      expect(h, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });
}
