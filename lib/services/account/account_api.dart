import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dropweb/services/account/account_api_exception.dart';
import 'package:dropweb/services/account/account_models.dart';
import 'package:dropweb/services/account/account_pow.dart';

/// REST-клиент API кабинета провайдера для входа в аккаунт из приложения.
///
/// Свой Dio, а не общий `request`: трафик самого приложения на Android идёт
/// мимо VPN-туннеля, а этому клиенту нужны свои таймауты и перебор баз.
class AccountApi {
  AccountApi({
    required List<String> Function() baseUrls,
    required String Function() userAgent,
    Dio? dio,
  })  : _baseUrls = baseUrls,
        _userAgent = userAgent,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final List<String> Function() _baseUrls;
  final String Function() _userAgent;
  final Dio _dio;

  /// Последняя база, ответившая хоть чем-то (в т.ч. HTTP-ошибкой). Живёт до
  /// перезапуска процесса, чтобы не тратить 15 с на мёртвый адрес каждый раз.
  String? _lastWorkingBase;

  String? get activeBaseUrl => _lastWorkingBase;

  /// Кандидаты без дублей; последняя рабочая база — первой.
  List<String> candidateBases() {
    final seen = <String>{};
    final result = <String>[];
    void add(String raw) {
      var base = raw.trim();
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      if (base.isNotEmpty && seen.add(base)) result.add(base);
    }

    final configured = _baseUrls();
    final last = _lastWorkingBase;
    if (last != null && configured.any((b) => _sameBase(b, last))) add(last);
    configured.forEach(add);
    return result;
  }

  static bool _sameBase(String a, String b) {
    String strip(String s) => s.trim().replaceAll(RegExp(r'/+$'), '');
    return strip(a) == strip(b);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final bases = candidateBases();
    if (bases.isEmpty) {
      throw const AccountApiException(
        AccountApiErrorKind.network,
        message: 'no account API base configured',
      );
    }
    DioException? lastTransport;
    for (final base in bases) {
      try {
        final response = await _dio.request<Object?>(
          '$base$path',
          data: body,
          options: Options(
            method: method,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            headers: {
              'User-Agent': _userAgent(),
              'Accept': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
          ),
        );
        _lastWorkingBase = base;
        return _asMap(response.data);
      } on DioException catch (e) {
        final response = e.response;
        if (response != null) {
          // Сервер ответил — база рабочая, ошибка содержательная, дальше не идём.
          _lastWorkingBase = base;
          throw AccountApiException.fromResponse(
            response.statusCode ?? 0,
            _decode(response.data),
            retryAfterHeader: response.headers.value('retry-after'),
          );
        }
        if (!AccountApiException.isFailoverTransport(e)) {
          throw AccountApiException.fromTransport(e);
        }
        lastTransport = e;
      }
    }
    throw AccountApiException.fromTransport(lastTransport!);
  }

  static Object? _decode(Object? data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } on FormatException {
        return data;
      }
    }
    return data;
  }

  static Map<String, dynamic> _asMap(Object? data) {
    final decoded = _decode(data);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw AccountApiException(
      AccountApiErrorKind.server,
      message: 'unexpected response body: ${decoded.runtimeType}',
    );
  }

  /// Конструкторы моделей бросают TypeError на неожиданном JSON — это ошибка
  /// сервера, а не падение приложения.
  static T _parse<T>(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(json);
    } on TypeError catch (e) {
      throw AccountApiException(
        AccountApiErrorKind.server,
        message: 'malformed response: $e',
      );
    }
  }

  Future<bool> emailAuthEnabled() async {
    final json = await _send('GET', '/cabinet/branding/email-auth');
    return json['enabled'] == true;
  }

  Future<PowChallenge> fetchChallenge() async {
    final json = await _send('GET', '/cabinet/auth/email/challenge');
    return _parse(json, PowChallenge.fromJson);
  }

  /// challenge → решение PoW в изоляте → запрос кода на почту.
  Future<CodeRequestResult> requestCode({
    required String email,
    required String language,
  }) async {
    final challenge = await fetchChallenge();
    final PowSolution solution;
    try {
      solution = await solvePowInIsolate(challenge);
    } on PowUnsolvableException catch (e) {
      throw AccountApiException(
        AccountApiErrorKind.captchaFailed,
        code: 'pow_unsolvable',
        message: e.message,
      );
    }
    final json = await _send(
      'POST',
      '/cabinet/auth/email/code/request',
      body: {'email': email, 'language': language, 'pow': solution.toJson()},
    );
    return _parse(json, CodeRequestResult.fromJson);
  }

  Future<AccountTokens> verifyCode({
    required String email,
    required String code,
    required String language,
  }) async {
    final json = await _send(
      'POST',
      '/cabinet/auth/email/code/verify',
      body: {'email': email, 'code': code, 'language': language},
    );
    return _parse(json, AccountTokens.fromJson);
  }

  Future<AccountTokens> refresh(String refreshToken) async {
    final json = await _send(
      'POST',
      '/cabinet/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    return _parse(json, AccountTokens.fromJson);
  }

  Future<void> logout(String refreshToken) async {
    await _send(
      'POST',
      '/cabinet/auth/logout',
      body: {'refresh_token': refreshToken},
    );
  }

  Future<AccountSubscription> subscription(String accessToken) async {
    final json = await _send(
      'GET',
      '/cabinet/subscription',
      accessToken: accessToken,
    );
    return _parse(json, AccountSubscription.fromJson);
  }

  Future<AccountHandoff> appHandoff(String accessToken) async {
    final json = await _send(
      'POST',
      '/cabinet/auth/app-handoff',
      accessToken: accessToken,
    );
    return _parse(json, AccountHandoff.fromJson);
  }
}
