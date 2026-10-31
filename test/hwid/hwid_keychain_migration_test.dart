import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dropweb/utils/device_info_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Транзитивная зависимость flutter_secure_storage: подмена платформы Keychain
// возможна только через её интерфейс, а добавлять зависимость ради теста нельзя.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';

const _hwidKey = 'app_persistent_hwid';
const _thisDevice = 'first_unlock_this_device';
const _legacy = 'first_unlock';

/// Хэш idfv ровно по правилу приложения (sha256, 16 символов верхним регистром).
String _hwidOf(String idfv) =>
    sha256.convert(utf8.encode(idfv)).toString().substring(0, 16).toUpperCase();

/// Keychain iOS в том виде, в каком его видит плагин flutter_secure_storage_darwin
/// (FlutterSecureStorage.swift): kSecAttrAccessible входит в каждый запрос
/// чтения, поэтому читатель видит только записи своего класса доступности;
/// запись поверх записи ДРУГОГО класса не находит её, идёт в SecItemAdd и
/// получает errSecDuplicateItem; удаление класс не учитывает.
class _PluginLikeKeychain extends FlutterSecureStoragePlatform {
  /// ключ → (класс доступности, значение)
  final Map<String, ({String accessibility, String value})> items = {};

  /// Сколько ближайших записей уронить (сбой между «удалить» и «записать»).
  int failNextWrites = 0;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      items[key]?.accessibility == options['accessibility'];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      items.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      items.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final item = items[key];
    return item?.accessibility == options['accessibility'] ? item?.value : null;
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      {
        for (final e in items.entries)
          if (e.value.accessibility == options['accessibility'])
            e.key: e.value.value,
      };

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (failNextWrites > 0) {
      failNextWrites--;
      throw PlatformException(code: 'Unexpected security result code');
    }
    final accessibility = options['accessibility']!;
    final existing = items[key];
    if (existing != null && existing.accessibility != accessibility) {
      throw PlatformException(
        code: 'Unexpected security result code',
        message: 'errSecDuplicateItem',
      );
    }
    items[key] = (accessibility: accessibility, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();

  late _PluginLikeKeychain keychain;
  late List<String> logs;
  late DebugPrintCallback savedDebugPrint;

  DeviceInfoService service({String? idfv = 'IDFV-OF-THIS-INSTALL'}) =>
      DeviceInfoService.custom(
        iosKeychain: const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        legacyIosKeychain: const FlutterSecureStorage(
          iOptions:
              IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        ),
        isIOS: true,
        iosVendorId: () async => idfv,
      );

  setUp(() {
    keychain = _PluginLikeKeychain();
    FlutterSecureStoragePlatform.instance = keychain;
    // Плагин выбирает набор опций по платформе: на хосте подменяем её на iOS.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    logs = [];
    savedDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    debugPrint = savedDebugPrint;
  });

  test(
      'старая запись равна хэшу idfv: значение сохраняется, но переезжает в '
      'this-device, старая удаляется', () async {
    final own = _hwidOf('IDFV-OF-THIS-INSTALL');
    keychain.items[_hwidKey] = (accessibility: _legacy, value: own);

    final hwid = await service().getPersistentHwid();

    expect(hwid, own);
    expect(keychain.items[_hwidKey]?.accessibility, _thisDevice);
    expect(keychain.items[_hwidKey]?.value, own);
    expect(logs.where((l) => l.contains('[hwid] keychain migrated: kept')),
        hasLength(1));
  });

  test(
      'старая запись не равна хэшу idfv (приехала с другого телефона): '
      'HWID выводится заново', () async {
    final foreign = _hwidOf('IDFV-OF-ANOTHER-PHONE');
    keychain.items[_hwidKey] = (accessibility: _legacy, value: foreign);

    final hwid = await service().getPersistentHwid();

    expect(hwid, _hwidOf('IDFV-OF-THIS-INSTALL'));
    expect(hwid, isNot(foreign));
    expect(keychain.items[_hwidKey]?.accessibility, _thisDevice);
    expect(keychain.items[_hwidKey]?.value, hwid);
    expect(
        logs.where((l) => l.contains('[hwid] keychain migrated: regenerated')),
        hasLength(1));
  });

  test('значение HWID в журнал не попадает', () async {
    final foreign = _hwidOf('IDFV-OF-ANOTHER-PHONE');
    keychain.items[_hwidKey] = (accessibility: _legacy, value: foreign);

    final hwid = await service().getPersistentHwid();

    expect(
        logs.where((l) => l.contains(foreign) || l.contains(hwid!)), isEmpty);
  });

  test('чистая установка: пишется запись this-device, миграции нет', () async {
    final hwid = await service().getPersistentHwid();

    expect(hwid, _hwidOf('IDFV-OF-THIS-INSTALL'));
    expect(keychain.items[_hwidKey]?.accessibility, _thisDevice);
    expect(logs.where((l) => l.contains('keychain migrated')), isEmpty);
  });

  test(
      'запись this-device переживает переустановку: при новом idfv '
      'возвращается как есть, а не пересчитывается', () async {
    final first =
        await service(idfv: 'IDFV-BEFORE-REINSTALL').getPersistentHwid();

    final afterReinstall =
        await service(idfv: 'IDFV-AFTER-REINSTALL').getPersistentHwid();

    expect(afterReinstall, first);
    expect(afterReinstall, isNot(_hwidOf('IDFV-AFTER-REINSTALL')));
    expect(logs.where((l) => l.contains('keychain migrated')), isEmpty);
  });

  test(
      'сбой записи после удаления старой: следующий запуск приходит к тому '
      'же результату', () async {
    keychain.items[_hwidKey] =
        (accessibility: _legacy, value: _hwidOf('IDFV-OF-ANOTHER-PHONE'));
    keychain.failNextWrites = 1;

    expect(await service().getPersistentHwid(), isNull);
    expect(keychain.items, isEmpty);

    expect(
        await service().getPersistentHwid(), _hwidOf('IDFV-OF-THIS-INSTALL'));
    expect(keychain.items[_hwidKey]?.accessibility, _thisDevice);
  });

  test(
      'старая запись есть, а idfv недоступен: чужое значение отбрасывается, '
      'новое не создаётся', () async {
    keychain.items[_hwidKey] =
        (accessibility: _legacy, value: _hwidOf('IDFV-OF-ANOTHER-PHONE'));

    expect(await service(idfv: null).getPersistentHwid(), isNull);
    expect(keychain.items, isEmpty);
  });
}
