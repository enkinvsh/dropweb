import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setup.dart invokes activated flutter_distributor without PATH reliance',
      () {
    final source = File('setup.dart').readAsStringSync();

    expect(
      source,
      contains(
        // `pub global run <package>:<script>` resolves bin/<script>.dart; the
        // package maps its executable via `executables: flutter_distributor:
        // main`, so the script name is `main`, not `flutter_distributor`.
        'dart pub global run flutter_distributor:main package',
      ),
      reason: 'pub global activate warns when ~/.pub-cache/bin is not in PATH; '
          'the build must use dart pub global run instead of a bare executable',
    );
    expect(
      source,
      isNot(contains('"flutter_distributor package --skip-clean')),
      reason: 'a bare flutter_distributor executable is not reproducible',
    );
  });
}
