import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  Request() {
    _dio = Dio(
      BaseOptions(
        headers: {
          "User-Agent": browserUa,
        },
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) {
        client.userAgent = globalState.ua;
        return DropwebHttpOverrides.handleFindProxy(uri);
      };
      return client;
    });
  }
  late final Dio _dio;
  late final Dio _clashDio;
  String? userAgent;

  /// SECURITY: cap on subscription payload size — prevents OOM from rogue providers.
  static const int _maxProfileBytes = 50 * 1024 * 1024; // 50 MiB

  Future<Response<Uint8List>> getFileResponseForUrl(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    final requestHeaders = headers ?? {};
    requestHeaders['User-Agent'] = globalState.ua;

    final firstResponse = await _dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: requestHeaders,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    Response<Uint8List> response = firstResponse;
    if (firstResponse.isRedirect == true) {
      final newUrl = firstResponse.headers.value('location');
      if (newUrl == null) {
        throw Exception('Redirect detected, but no location header was found.');
      }

      // SECURITY: don't log redirect URLs — subscription tokens leak through them.
      if (kDebugMode) {
        debugPrint('Subscription redirect followed (length=${newUrl.length})');
      }
      response = await _dio.get<Uint8List>(
        newUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: requestHeaders,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    }

    final contentLengthHeader = response.headers.value('content-length');
    final contentLength = int.tryParse(contentLengthHeader ?? '');
    if (contentLength != null && contentLength > _maxProfileBytes) {
      throw Exception(
        'Subscription too large: $contentLength bytes (max $_maxProfileBytes)',
      );
    }
    final actualLength = response.data?.length ?? 0;
    if (actualLength > _maxProfileBytes) {
      throw Exception(
        'Subscription too large: $actualLength bytes (max $_maxProfileBytes)',
      );
    }
    return response;
  }

  Future<Response> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
    final contentLengthHeader = response.headers.value('content-length');
    final contentLength = int.tryParse(contentLengthHeader ?? '');
    if (contentLength != null && contentLength > _maxProfileBytes) {
      throw Exception(
        'Subscription too large: $contentLength bytes (max $_maxProfileBytes)',
      );
    }
    final actualLength = (response.data as String?)?.length ?? 0;
    if (actualLength > _maxProfileBytes) {
      throw Exception(
        'Subscription too large: $actualLength bytes (max $_maxProfileBytes)',
      );
    }
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  /// Update check against our own update server (dropweb.org/update.json,
  /// backed by YC Object Storage) instead of the GitHub API. РФ-reliable and
  /// independent of GitHub. The manifest is adapted to the shape
  /// [Controller.checkUpdateResultHandle] expects (tag_name / body / html_url),
  /// so downstream handling is unchanged. Absent manifest (404) => no update.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        "https://dropweb.org/update.json",
        options: Options(
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode != 200) return null;
      final raw = response.data;
      final manifest = raw is Map<String, dynamic>
          ? raw
          : (raw is String
              ? json.decode(raw) as Map<String, dynamic>
              : <String, dynamic>{});
      final remoteVersion = (manifest['version']?.toString() ?? '').trim();
      if (remoteVersion.isEmpty) return null;
      final localVersion = globalState.packageInfo.version;
      if (utils.compareVersions(remoteVersion, localVersion) <= 0) return null;

      final notes = manifest['notes'] is List
          ? (manifest['notes'] as List).map((e) => e.toString()).toList()
          : const <String>[];
      var downloadUrl = 'https://dropweb.org/downloads';
      final platforms = manifest['platforms'];
      if (platforms is Map) {
        final entry = platforms[_platformKey()];
        if (entry is Map &&
            entry['url'] is String &&
            (entry['url'] as String).isNotEmpty) {
          downloadUrl = entry['url'] as String;
        }
      }
      return <String, dynamic>{
        'tag_name':
            remoteVersion.startsWith('v') ? remoteVersion : 'v$remoteVersion',
        'body': notes.map((n) => '- $n').join('\n'),
        'html_url': downloadUrl,
      };
    } catch (e) {
      debugPrint('checkForUpdate failed: $e');
      return null;
    }
  }

  String _platformKey() {
    if (Platform.isAndroid) return 'android-arm64';
    if (Platform.isWindows) return 'windows-amd64';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux-amd64';
    return 'android-arm64';
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    "https://ipwho.is/": IpInfo.fromIpwhoIsJson,
    "https://api.ip.sb/geoip/": IpInfo.fromIpSbJson,
    "https://ipapi.co/json/": IpInfo.fromIpApiCoJson,
    "https://ipinfo.io/json/": IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    // Dedicated Dio with per-request timeouts so a hung geo endpoint can never
    // stall the check indefinitely (the previous bare Dio() had no timeouts).
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );
    try {
      // Try each source sequentially, stopping at the first success. This avoids
      // firing all four geo APIs through the proxy on every check.
      for (final source in _ipInfoSources.entries) {
        try {
          final res = await dio.get<Map<String, dynamic>>(
            source.key,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.json,
            ),
          );
          final data = res.data;
          if (res.statusCode == HttpStatus.ok && data != null) {
            return Result.success(source.value(data));
          }
        } on DioException catch (e) {
          // Honor caller cancellation; do NOT cancel the token ourselves.
          if (e.type == DioExceptionType.cancel) {
            return Result.error("cancelled");
          }
          // Timeout / network error — fall through and try the next source.
        } catch (_) {
          // Malformed payload — fall through and try the next source.
        }
      }
      return Result.success(null);
    } finally {
      dio.close();
    }
  }

  Future<bool> pingHelper() async {
    try {
      final response = await _dio
          .get(
            "http://$localhost:$helperPort/ping",
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      // CONFLICT CHECK (by identity, not by a hardcoded process name): only
      // hand our start request to the helper on the fixed port 47896 if it is
      // verifiably OURS. pingHelper() compares the helper's reported core hash
      // against our coreSHA256. If a foreign clash-lineage helper (e.g.
      // FlClashX) or a stale instance squats the port, this returns false and
      // we bail — the caller (ClashService.reStart) then spawns our own core
      // directly. We never drive someone else's helper.
      if (!await pingHelper()) {
        commonPrint.log(
            "[helper] $helperPort is not our verified helper — skipping helper, will spawn core directly");
        return false;
      }
      final homeDirPath = await appPath.homeDirPath;
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/start",
            data: json.encode({
              "path": appPath.corePath,
              "arg": arg,
              "home_dir": homeDirPath,
            }),
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/stop",
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));

      if (response.statusCode != HttpStatus.ok) return false;
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCoreVersion() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            "http://$defaultExternalController/version",
            options: Options(
              responseType: ResponseType.json,
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != HttpStatus.ok) return null;
      return response.data;
    } catch (_) {
      return null;
    }
  }
}

final request = Request();
