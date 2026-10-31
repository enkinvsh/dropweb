import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dropweb/common/common.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32_registry/win32_registry.dart';

class DeviceDetails {
  DeviceDetails({
    this.hwid,
    this.os,
    this.osVersion,
    this.model,
    this.appVersion,
  });
  final String? hwid;
  final String? os;
  final String? osVersion;
  final String? model;
  final String? appVersion;
}

class DeviceInfoService {
  factory DeviceInfoService() => testInstance ?? DeviceInfoService.custom();

  /// Конструктор с подменой платформенных зависимостей: в проде не нужен, им
  /// пользуются тесты, у которых на хосте нет ни Keychain, ни iOS.
  DeviceInfoService.custom({
    FlutterSecureStorage? iosKeychain,
    FlutterSecureStorage? legacyIosKeychain,
    bool? isIOS,
    Future<String?> Function()? iosVendorId,
  })  : _iosKeychain = iosKeychain ?? _thisDeviceKeychain,
        _legacyIosKeychain = legacyIosKeychain ?? _legacyKeychain,
        _isIOS = isIOS,
        _iosVendorId = iosVendorId;

  /// Шов для тестов: подменяет сервис, который создаёт `DeviceInfoService()`
  /// (например, в `Profile.update`). В проде всегда `null`.
  @visibleForTesting
  static DeviceInfoService? testInstance;

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static const String _hwidStorageKey = 'app_persistent_hwid';
  static const MethodChannel _channel =
      MethodChannel('app.dropweb/device_id');

  // HWID на iOS живёт в Keychain: в отличие от SharedPreferences он переживает
  // переустановку приложения, а одного identifierForVendor для этого мало.
  //
  // Класс `first_unlock_this_device` (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
  // не переезжает на другой телефон. Прежний `first_unlock` ехал вместе с
  // зашифрованной копией и с «Быстрым началом»: два айфона слали один HWID, и
  // панель считала их одним устройством.
  static const FlutterSecureStorage _thisDeviceKeychain = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Читает записи, сделанные до перехода на `this_device`. Плагин кладёт
  /// kSecAttrAccessible в каждый запрос (FlutterSecureStorage.swift:215-220),
  /// поэтому только читатель со старым классом видит старую запись.
  static const FlutterSecureStorage _legacyKeychain = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final FlutterSecureStorage _iosKeychain;
  final FlutterSecureStorage _legacyIosKeychain;
  final bool? _isIOS;
  final Future<String?> Function()? _iosVendorId;

  bool get _onIos => _isIOS ?? Platform.isIOS;

  String _generateCompact16CharId(String fullId) {
    final bytes = utf8.encode(fullId);
    final hash = sha256.convert(bytes);
    final hashHex = hash.toString();
    return hashHex.substring(0, 16).toUpperCase();
  }

  Future<String?> _getAndroidId() async {
    try {
      final String? androidId = await _channel.invokeMethod('getAndroidId');
      if (androidId != null && androidId.isNotEmpty) {
        return androidId;
      }
      return null;
    } catch (e) {
      commonPrint.log("Failed to get Android ID: $e");
      return null;
    }
  }

  Future<String?> _getWindowsMachineGuid() async {
    try {
      const keyPath = r'SOFTWARE\Microsoft\Cryptography';
      const valueName = 'MachineGuid';

      final key = Registry.openPath(RegistryHive.localMachine, path: keyPath);
      final data = key.getValue(valueName);
      key.close();

      return data?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getPlatformDeviceId() async {
    try {
      if (Platform.isWindows) {
        final machineGuid = await _getWindowsMachineGuid();
        if (machineGuid != null && machineGuid.isNotEmpty) {
          return machineGuid;
        }

        final info = await _deviceInfoPlugin.windowsInfo;
        final fallback =
            '${info.computerName}-${info.deviceId}-${info.productId}';
        return fallback;
      } else if (Platform.isAndroid) {
        // Try to get ANDROID_ID first (unique per device, persists across app reinstalls)
        final androidId = await _getAndroidId();
        if (androidId != null && androidId.isNotEmpty) {
          return androidId;
        }

        // Fallback to device info if ANDROID_ID is not available
        final info = await _deviceInfoPlugin.androidInfo;
        final combined =
            '${info.brand}-${info.device}-${info.hardware}-${info.id}';
        return combined;
      } else if (Platform.isLinux) {
        final info = await _deviceInfoPlugin.linuxInfo;
        final combined = info.machineId ?? '${info.id}-${info.name}';
        return combined;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfoPlugin.macOsInfo;
        final combined =
            info.systemGUID ?? '${info.model}-${info.computerName}';
        return combined;
      } else if (Platform.isIOS) {
        return await _getIosVendorId();
      }
      return null;
    } catch (e) {
      commonPrint.log("Failed to get platform device ID: $e");
      return null;
    }
  }

  Future<String?> _getIosVendorId() async {
    final override = _iosVendorId;
    if (override != null) return override();
    try {
      final info = await _deviceInfoPlugin.iosInfo;
      return info.identifierForVendor;
    } catch (e) {
      commonPrint.log("Failed to get identifierForVendor: $e");
      return null;
    }
  }

  /// HWID этого устройства (создаёт и сохраняет, если ещё нет). `null`, если
  /// идентификатор устройства получить не удалось.
  Future<String?> getPersistentHwid() async {
    try {
      if (_onIos) return await _getOrCreateIosHwid();

      final prefs = await SharedPreferences.getInstance();
      final storedHwid = prefs.getString(_hwidStorageKey);
      if (storedHwid != null && storedHwid.isNotEmpty) {
        return storedHwid;
      }

      final deviceId = await _getPlatformDeviceId();

      if (deviceId == null || deviceId.isEmpty) {
        commonPrint.log("ERROR: Device ID is null or empty");
        return null;
      }

      // Hash every platform's stable device ID to a compact 16-char value.
      // The raw system identifier (e.g. ANDROID_ID) is never persisted or sent.
      final newHwid = _generateCompact16CharId(deviceId);
      await prefs.setString(_hwidStorageKey, newHwid);
      return newHwid;
    } catch (e) {
      commonPrint.log("ERROR getting HWID: $e");
      return null;
    }
  }

  /// HWID iOS: запись `this_device` в Keychain, при её отсутствии — миграция
  /// старой записи `first_unlock`.
  ///
  /// Старая запись могла приехать с другого телефона (восстановление из
  /// зашифрованной копии, «Быстрое начало»), поэтому верить ей можно только
  /// когда она равна хэшу identifierForVendor ЭТОГО установленного приложения.
  /// Не равна — значит, это значение чужого телефона или остаток до
  /// переустановки (idfv после неё другой): отбрасываем и берём хэш текущего
  /// idfv. Для новой записи правило «равна хэшу idfv» не применяется: она
  /// пережила переустановку на этом же телефоне и должна остаться как есть.
  ///
  /// Порядок «удалить старую → записать новую» не случаен: `write` плагина при
  /// другом классе доступности не находит запись (containsKey фильтрует по
  /// kSecAttrAccessible), идёт в SecItemAdd и получает errSecDuplicateItem
  /// (FlutterSecureStorage.swift:557-573), а `delete` класс не учитывает
  /// (FlutterSecureStorage.swift:705) и снимает запись любого класса. Сбой
  /// между шагами безопасен: следующий запуск не найдёт ни одной записи и
  /// выведет то же значение из idfv.
  Future<String?> _getOrCreateIosHwid() async {
    final stored = await _iosKeychain.read(key: _hwidStorageKey);
    if (stored != null && stored.isNotEmpty) return stored;

    final legacy = await _legacyIosKeychain.read(key: _hwidStorageKey);
    final hasLegacy = legacy != null && legacy.isNotEmpty;

    final deviceId = await _getIosVendorId();
    final current = (deviceId == null || deviceId.isEmpty)
        ? null
        : _generateCompact16CharId(deviceId);

    if (hasLegacy) {
      await _iosKeychain.delete(key: _hwidStorageKey);
      // Значение в журнал не пишем.
      commonPrint.log(
        '[hwid] keychain migrated: ${legacy == current ? 'kept' : 'regenerated'}',
      );
    }

    if (current == null) {
      commonPrint.log("ERROR: Device ID is null or empty");
      return null;
    }

    await _iosKeychain.write(key: _hwidStorageKey, value: current);
    return current;
  }

  Future<DeviceDetails> getDeviceDetails() async {
    String? hwid, os, osVersion, model;
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;

    try {
      hwid = await getPersistentHwid();

      if (Platform.isWindows) {
        final info = await _deviceInfoPlugin.windowsInfo;
        os = 'Windows';
        osVersion = info.displayVersion;
        model = info.productName;
      } else if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        os = 'Android';
        osVersion = info.version.release;
        model = '${info.manufacturer} ${info.model}';
      } else if (Platform.isLinux) {
        final info = await _deviceInfoPlugin.linuxInfo;
        os = 'Linux';
        osVersion = info.versionId;
        model = info.name;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfoPlugin.macOsInfo;
        os = 'macOS';
        osVersion = info.osRelease;
        model = info.model;
      } else if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        os = 'iOS';
        osVersion = info.systemVersion;
        model = info.utsname.machine;
      }
    } catch (e) {
      // Silently handle errors in device info retrieval
    }

    return DeviceDetails(
      hwid: hwid,
      os: os,
      osVersion: osVersion,
      model: model,
      appVersion: appVersion,
    );
  }
}
