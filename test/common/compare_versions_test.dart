import 'package:dropweb/common/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('utils.compareVersions', () {
    test('equal stable versions', () {
      expect(utils.compareVersions('0.6.8', '0.6.8'), 0);
    });

    test('strips leading v / V prefix', () {
      expect(utils.compareVersions('v0.6.8', '0.6.8'), 0);
      expect(utils.compareVersions('V1.0.0', '1.0.0'), 0);
    });

    test('higher major / minor / patch beats lower', () {
      expect(utils.compareVersions('1.0.0', '0.9.9') > 0, isTrue);
      expect(utils.compareVersions('0.7.0', '0.6.9') > 0, isTrue);
      expect(utils.compareVersions('0.6.9', '0.6.8') > 0, isTrue);
    });

    test('fills missing minor / patch with 0', () {
      expect(utils.compareVersions('1', '1.0.0'), 0);
      expect(utils.compareVersions('1.2', '1.2.0'), 0);
      expect(utils.compareVersions('1.2', '1.1.99') > 0, isTrue);
    });

    test('stable release is higher than matching prerelease', () {
      expect(utils.compareVersions('0.6.8', '0.6.8-beta2') > 0, isTrue);
      expect(utils.compareVersions('0.6.8-beta2', '0.6.8') < 0, isTrue);
    });

    test('equal prerelease strings compare equal', () {
      expect(utils.compareVersions('0.6.8-beta2', '0.6.8-beta2'), 0);
    });

    test('compares prerelease identifiers lexicographically when same base',
        () {
      expect(utils.compareVersions('0.6.8-beta2', '0.6.8-beta1') > 0, isTrue);
      expect(utils.compareVersions('0.6.8-alpha', '0.6.8-beta') < 0, isTrue);
    });

    test('build metadata after + is ignored for ordering', () {
      expect(utils.compareVersions('1.2.3+build1', '1.2.3+build2'), 0);
      expect(utils.compareVersions('1.2.3+build1', '1.2.3'), 0);
      expect(utils.compareVersions('1.2.3+abc', '1.2.4') < 0, isTrue);
    });

    test('does not throw on malformed input', () {
      expect(() => utils.compareVersions('0-beta2', '0.6.8'), returnsNormally);
      expect(() => utils.compareVersions('', ''), returnsNormally);
      expect(() => utils.compareVersions('not-a-version', '1.0.0'),
          returnsNormally);
      expect(() => utils.compareVersions('0-beta2', '0.6.8-beta2'),
          returnsNormally);
    });

    test('v0.6.8 is greater than 0-beta2 (screenshot bug regression)', () {
      expect(utils.compareVersions('v0.6.8', '0-beta2') > 0, isTrue);
    });

    test('handles v-prefixed prerelease tag from GitHub', () {
      expect(utils.compareVersions('v0.6.9-beta1', '0.6.8') > 0, isTrue);
      expect(utils.compareVersions('v0.6.8-beta2', '0.6.8') < 0, isTrue);
    });

    test('does not strip v in the middle of a token', () {
      // Only leading v/V should be stripped; a 'v' inside a prerelease
      // identifier must stay intact (otherwise '0.6.8-rev2' would shift).
      expect(utils.compareVersions('0.6.8-rev2', '0.6.8-rev2'), 0);
    });
  });
}
