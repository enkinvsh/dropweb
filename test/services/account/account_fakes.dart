import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dropweb/services/account/account_biometrics.dart';
import 'package:dropweb/services/account/account_profiles.dart';
import 'package:dropweb/services/account/account_store.dart';

/// Ответ фейкового сервера: либо HTTP-ответ, либо исключение транспорта.
typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

ResponseBody jsonResponse(
  int status,
  Object body, {
  Map<String, List<String>> headers = const {},
}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );

/// Подменяет сеть Dio: тесты видят каждый запрос и решают, что ответить.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final requests = <RequestOptions>[];

  List<String> get paths => requests.map((r) => r.uri.toString()).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

class MemoryAccountStore implements AccountStorage {
  String? refreshToken;
  String? email;
  bool biometricEnabled = false;
  String? importedUrl;

  /// Базы бэкенда, к которому привязана сессия; null — сессия старого формата.
  List<String>? apiBases;
  final refreshWrites = <String>[];

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<bool> writeRefreshToken(String token) async {
    refreshWrites.add(token);
    refreshToken = token;
    return true;
  }

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<bool> writeEmail(String value) async {
    email = value;
    return true;
  }

  @override
  Future<bool> readBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> writeBiometricEnabled({required bool enabled}) async {
    biometricEnabled = enabled;
    return true;
  }

  @override
  Future<String?> readImportedUrl() async => importedUrl;

  @override
  Future<bool> writeImportedUrl(String url) async {
    importedUrl = url;
    return true;
  }

  @override
  Future<List<String>> readApiBases() async => apiBases ?? const [];

  @override
  Future<bool> writeApiBases(List<String> bases) async {
    apiBases = List.of(bases);
    return true;
  }

  @override
  Future<void> clear() async {
    apiBases = null;
    refreshToken = null;
    email = null;
    biometricEnabled = false;
    importedUrl = null;
  }
}

class FakeBiometrics implements AccountBiometrics {
  bool available = true;
  bool result = true;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}

class FakeProfiles implements AccountProfiles {
  /// id → url.
  final profiles = <String, String>{};
  String? currentId;
  final imports = <String>[];
  final deleted = <String>[];

  /// id → кабинет из заголовка `dropweb-cabinet` этого профиля.
  final cabinets = <String, Uri>{};

  /// Если false — импорт «молча» не создаёт профиль, как addProfileFormURL при ошибке.
  bool importSucceeds = true;

  @override
  Future<String?> findProfileIdByUrl(String url) async {
    for (final entry in profiles.entries) {
      if (entry.value == url) return entry.key;
    }
    return null;
  }

  @override
  Uri? cabinetUriOf(String id) => cabinets[id];

  @override
  Future<void> selectProfile(String id) async => currentId = id;

  @override
  Future<void> importProfile(String url) async {
    imports.add(url);
    if (!importSucceeds) return;
    final id = 'p${profiles.length + 1}';
    profiles[id] = url;
    currentId = id;
  }

  @override
  Future<void> deleteProfile(String id) async {
    deleted.add(id);
    profiles.remove(id);
  }
}
