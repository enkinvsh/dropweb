import 'package:dropweb/common/archive_safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // POSIX-style absolute root mirrors the runtime `homeDirPath` used by
  // AppController.recoveryData. `safeArchivePath` must reject any archive
  // entry name (attacker-controlled, from the ZIP) that resolves outside it.
  const root = '/home/user/dropweb/profiles';

  group('safeArchivePath — rejects path-traversal entries (Zip-Slip)', () {
    test('rejects a parent-relative entry (../evil)', () {
      expect(safeArchivePath(root, '../evil'), isNull);
    });

    test('rejects an absolute entry (/abs/path)', () {
      expect(safeArchivePath(root, '/abs/path'), isNull);
    });

    test('rejects a deep escape after a benign prefix (a/../../b)', () {
      expect(safeArchivePath(root, 'a/../../b'), isNull);
    });

    test('rejects a bare parent reference (..)', () {
      expect(safeArchivePath(root, '..'), isNull);
    });

    test('rejects an empty entry name', () {
      expect(safeArchivePath(root, ''), isNull);
    });

    test('rejects an entry resolving to the root itself (.)', () {
      expect(safeArchivePath(root, '.'), isNull);
    });
  });

  group('safeArchivePath — accepts safe entries within root', () {
    test('accepts a top-level file (profile.yaml)', () {
      final result = safeArchivePath(root, 'profile.yaml');
      expect(result, isNotNull);
      expect(p.isWithin(root, result!), isTrue);
      expect(p.normalize(result), p.normalize(p.join(root, 'profile.yaml')));
    });

    test('accepts a nested file (sub/profile.yaml)', () {
      final result = safeArchivePath(root, 'sub/profile.yaml');
      expect(result, isNotNull);
      expect(p.isWithin(root, result!), isTrue);
      expect(
        p.normalize(result),
        p.normalize(p.join(root, 'sub', 'profile.yaml')),
      );
    });

    test('normalizes a benign in-root traversal (a/b/../profile.yaml)', () {
      final result = safeArchivePath(root, 'a/b/../profile.yaml');
      expect(result, isNotNull);
      expect(p.isWithin(root, result!), isTrue);
      expect(
        p.normalize(result),
        p.normalize(p.join(root, 'a', 'profile.yaml')),
      );
    });
  });
}
