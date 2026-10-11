import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setup.dart --store builds an AAB with the PLAY_BUILD switch', () {
    final source = File('setup.dart').readAsStringSync();

    expect(source, contains('"appbundle"'));
    expect(source, contains('"--dart-define=PLAY_BUILD=true"'));
  });

  test('store manifest overlay removes REQUEST_INSTALL_PACKAGES', () {
    final overlay =
        File('android/app/src/store/AndroidManifest.xml').readAsStringSync();

    expect(overlay, contains('REQUEST_INSTALL_PACKAGES'));
    expect(overlay, contains('tools:node="remove"'));
  });

  test('gradle applies the store overlay on the same PLAY_BUILD switch', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('PLAY_BUILD=true'));
    expect(gradle, contains('src/store/AndroidManifest.xml'));
  });

  test('store build is signed with the Play upload key, not the sideload key',
      () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(
      gradle,
      contains(
        'file(if (isStoreBuild) "upload-keystore.jks" else "keystore.jks")',
      ),
    );
  });

  test('store build ships only the ABIs the core is built for', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('abiFilters.addAll(listOf("arm64-v8a", "x86_64"))'));
  });
}
