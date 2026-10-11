import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Бэкенд аккаунта по умолчанию задаётся только при сборке: в исходниках
// адреса нет, setup.dart прокидывает переменную окружения во все пути сборки.
void main() {
  final source = File('setup.dart').readAsStringSync();

  test('setup.dart читает DROPWEB_ACCOUNT_API из окружения', () {
    expect(source, contains("Platform.environment['DROPWEB_ACCOUNT_API']"));
  });

  test('каждый путь с CORE_VERSION, кроме магазинного, прокидывает и '
      'DROPWEB_ACCOUNT_API', () {
    final coreDefines =
        RegExp(r'dart-define=CORE_VERSION').allMatches(source).length;
    // В магазинной сборке аккаунта нет — адрес бэкенда в её бинарник не кладём.
    final storeDefines =
        RegExp(r'"--dart-define=PLAY_BUILD=true"').allMatches(source).length;
    final accountDefines =
        RegExp(r'_accountApiArgs\("').allMatches(source).length;
    expect(coreDefines, greaterThan(0));
    expect(storeDefines, 1);
    expect(accountDefines, coreDefines - storeDefines);
  });

  test('магазинная сборка не получает DROPWEB_ACCOUNT_API', () {
    final store = source.indexOf('"--dart-define=PLAY_BUILD=true"');
    final callEnd = source.indexOf('],', store);
    final callStart = source.lastIndexOf('Build.exec(', store);
    expect(
      source.substring(callStart, callEnd),
      isNot(contains('_accountApiArgs')),
    );
  });

  test('в lib/ и setup.dart нет зашитого адреса бэкенда аккаунта', () {
    final constants = File('lib/common/constant.dart').readAsStringSync();
    expect(constants, contains("String.fromEnvironment('DROPWEB_ACCOUNT_API')"));
    expect(constants, isNot(contains('apigw')));
    expect(source, isNot(contains('apigw')));
  });
}
