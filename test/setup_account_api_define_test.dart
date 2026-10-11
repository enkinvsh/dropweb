import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Бэкенд аккаунта по умолчанию задаётся только при сборке: в исходниках
// адреса нет, setup.dart прокидывает переменную окружения во все пути сборки.
void main() {
  final source = File('setup.dart').readAsStringSync();

  test('setup.dart читает DROPWEB_ACCOUNT_API из окружения', () {
    expect(source, contains("Platform.environment['DROPWEB_ACCOUNT_API']"));
  });

  test('каждый путь с CORE_VERSION прокидывает и DROPWEB_ACCOUNT_API', () {
    final coreDefines =
        RegExp(r'dart-define=CORE_VERSION').allMatches(source).length;
    final accountDefines =
        RegExp(r'_accountApiArgs\("').allMatches(source).length;
    expect(coreDefines, greaterThan(0));
    expect(accountDefines, coreDefines);
  });

  test('в lib/ и setup.dart нет зашитого адреса бэкенда аккаунта', () {
    final constants = File('lib/common/constant.dart').readAsStringSync();
    expect(constants, contains("String.fromEnvironment('DROPWEB_ACCOUNT_API')"));
    expect(constants, isNot(contains('apigw')));
    expect(source, isNot(contains('apigw')));
  });
}
