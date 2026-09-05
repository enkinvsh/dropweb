import 'dart:io';

import 'package:dropweb/common/package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  PackageInfo info(String version) => PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: version,
        buildNumber: '1',
        buildSignature: '',
      );

  group('PackageInfo.ua', () {
    test('keeps the clash-verge token required for gateway format negotiation',
        () {
      expect(info('0.8.1').ua, contains('clash-verge/v0.8.1'));
    });

    test('still advertises the dropweb identity and platform', () {
      final ua = info('0.8.1').ua;
      expect(ua, contains('dropweb/v0.8.1'));
      expect(ua, contains('Platform/${Platform.operatingSystem}'));
    });
  });
}
