// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dropweb/clash/core.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/share_link_profile.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/utils/device_info_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'clash_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

typedef _FetchedSubscription = ({
  Response<Uint8List> response,
  Uint8List bytes,
  String url,
});

/// Provider headers store builds ([System.isStoreBuild]: Google Play, iOS)
/// drop at ingestion: payment and account-cabinet links. The store app is a
/// neutral bring-your-own-config client — it must not steer users to a
/// provider's checkout or cabinet, whatever panel the user imports. Provider
/// support and device removal stay. Sideload builds keep every header.
const storeStrippedProviderHeaders = {
  'dropweb-renew-url',
  'dropweb-topup-url',
  'dropweb-cabinet',
};

Map<String, String> storeSafeProviderHeaders(
  Map<String, String> headers, {
  bool? isStoreBuild,
}) {
  if (!(isStoreBuild ?? system.isStoreBuild)) return headers;
  return {
    for (final entry in headers.entries)
      if (!storeStrippedProviderHeaders.contains(entry.key))
        entry.key: entry.value,
  };
}

/// Ссылки внутри текста `announce` кликабельны только вне магазинов. Текст
/// объявления провайдера остаётся виден, но тап по нему не уводит на оплату,
/// канал или бота: вычистить такие ссылки из чужого свободного текста на
/// импорте нельзя, а гейт на тапе закрывает их независимо от панели.
bool announceLinksTappable({bool? isStoreBuild}) =>
    !(isStoreBuild ?? system.isStoreBuild);

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final map = <String, int?>{};
    // Tolerate trailing ';', empty segments and malformed pairs: skip them
    // instead of throwing (a RangeError here used to abort the whole update).
    for (final segment in info.split(";")) {
      final eq = segment.indexOf("=");
      if (eq <= 0) continue;
      final key = segment.substring(0, eq).trim();
      if (key.isEmpty) continue;
      map[key] = int.tryParse(segment.substring(eq + 1).trim());
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
    @Default({}) Map<String, String> providerHeaders,
    String? fallbackUrl,
    // Зеркала той же подписки (`dropweb-sub-mirrors`) и её стабильный id
    // (`dropweb-sub-id`). Оба несут токен: на диск попадают только через
    // защищённое хранилище, как [url] / [fallbackUrl].
    @Default([]) List<String> mirrorUrls,
    String? subId,
    @JsonKey(unknownEnumValue: WorkMode.standard)
    @Default(WorkMode.standard)
    WorkMode workMode,
    String? staticCountry,
    // Send everything the provider's rules do not name through the VPN
    // (`applyFullTunnel`). Independent of [workMode].
    @Default(false) bool fullTunnel,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) =>
      Profile(
        label: label,
        url: url,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autoUpdateDuration: defaultUpdateDuration,
      );
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  /// Human-facing subscription/service name, mirroring the dashboard card
  /// resolution (MetainfoWidget.pickTitle): the Remnawave `profile-title`
  /// header wins, then the `dropweb-servicename` header, then the stored
  /// `label`, then the raw `id`. Both branding headers may arrive base64
  /// (optionally `base64:`-prefixed), so they are decoded here. Never empty.
  String get serviceName {
    String? decode(String? value) {
      if (value == null || value.isEmpty) return null;
      return decodeMaybeBase64(value);
    }

    for (final candidate in [
      decode(providerHeaders['profile-title']),
      decode(providerHeaders['dropweb-servicename']),
    ]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    final trimmedLabel = label?.trim();
    return (trimmedLabel != null && trimmedLabel.isNotEmpty)
        ? trimmedLabel
        : id;
  }

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    final profilePath = await appPath.getProfilePath(id);
    return File(profilePath).exists();
  }

  Future<File> getFile() async {
    final path = await appPath.getProfilePath(id);
    final file = File(path);
    final isExists = await file.exists();
    if (!isExists) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<int> get profileLastModified async {
    final file = await getFile();
    return (await file.lastModified()).microsecondsSinceEpoch;
  }

  Future<Profile> update({bool shouldSendHeaders = true}) async {
    final headers = <String, dynamic>{};

    if (shouldSendHeaders) {
      final deviceInfoService = DeviceInfoService();
      final details = await deviceInfoService.getDeviceDetails();

      if (details.hwid != null) headers['x-hwid'] = details.hwid;
      if (details.os != null) headers['x-device-os'] = details.os;
      if (details.osVersion != null) headers['x-ver-os'] = details.osVersion;
      if (details.model != null) headers['x-device-model'] = details.model;
    }

    // Resolve URL on demand — `this.url` is empty post-migration.
    final primaryUrl = await preferences.getProfileUrl(this);
    if (primaryUrl == null || primaryUrl.isEmpty) {
      throw Exception(
        'Profile ${id} has no subscription URL in secure storage',
      );
    }
    final fallback = await preferences.getProfileFallbackUrl(this);
    final mirrors = await preferences.getProfileMirrors(this);
    final preferred = await preferences.getProfilePreferredUrl(this);
    final candidates = subscriptionCandidates(
      preferred: preferred,
      primary: primaryUrl,
      mirrors: mirrors,
      fallback: fallback,
    );

    // Перебор фронтов одной подписки: падение одного (шлюз, домен) не должно
    // оставлять приложение без обновлений, пока остальные живы. Если упали
    // все — и известные адреса, и адреса из маяка, — наружу уходит ошибка
    // ПЕРВОГО кандидата: на неё рассчитан существующий UX ошибок.
    final known = await _fetchFirstAccepted(
      candidates,
      headers,
      logLabel: 'candidate',
    );
    var fetched = known.fetched;
    final viaBeacon = fetched == null;
    if (fetched == null) {
      try {
        fetched = await _fetchViaBeacon(
          tried: candidates.toSet(),
          headers: headers,
        );
      } catch (e) {
        // Маяк — последний шанс, а не новый источник ошибок для UX.
        commonPrint.log('subscription beacon stage failed: ${e.runtimeType}');
      }
    }
    if (fetched == null) {
      Error.throwWithStackTrace(known.firstError!, known.firstStackTrace!);
    }
    final response = fetched.response;
    final bytesToSave = fetched.bytes;
    final succeededUrl = fetched.url;
    await _rememberWorkingCandidate(
      succeededUrl: succeededUrl,
      primaryUrl: primaryUrl,
      preferredUrl: preferred,
    );

    // `headers.value()` THROWS when a header is repeated (e.g. a panel
    // custom header duplicating `profile-title`); take the first value.
    String? header(String name) => response.headers[name]?.first;

    final disposition = header("content-disposition");
    final userinfo = header('subscription-userinfo');

    final providerHeaders = <String, String>{};

    final headersToCollect = [
      'announce',
      'support-url',
      'profile-update-interval',
      'x-hwid-limit',
      // Standard Remnawave subscription headers — profile title and the
      // subscription page URL, collected as harmless metadata.
      'profile-title',
      'profile-web-page-url',
    ];

    for (final headerName in headersToCollect) {
      final value = header(headerName);
      if (value != null && value.isNotEmpty) {
        providerHeaders[headerName] = value;
      }
    }

    // Subscription providers (Remnawave panel templates) return dropweb-*
    // HTTP headers to customize the dashboard layout, theme, service name,
    // logo, and behavior. Legacy flclashx-* headers from FlClashX-targeted
    // panels are intentionally NOT accepted — dropweb is a distinct product
    // and must not share a customization protocol surface with FlClashX
    // (see .sisyphus/plans/2026-04-20-flclashx-hard-decouple.md for the
    // decision record).
    response.headers.forEach((name, values) {
      if (name.toLowerCase().startsWith('dropweb-') && values.isNotEmpty) {
        providerHeaders[name.toLowerCase()] = values.first;
      }
    });

    Duration? durationFromHeader;
    final updateIntervalHeader = providerHeaders['profile-update-interval'];
    if (updateIntervalHeader != null) {
      final hours = int.tryParse(updateIntervalHeader);
      if (hours != null && hours > 0) {
        durationFromHeader = Duration(hours: hours);
      }
    }

    // Адреса и id подписки несут токен: в разобранном виде они уходят в поля
    // профиля (на диск — только через защищённое хранилище), а в
    // providerHeaders, который пишется в plaintext Config, их нет. Читаются
    // без гейта `dropweb-custom`: это устойчивость, а не кастомизация.
    final newFallbackUrl = header('fallback-url');
    final mirrorsHeader = header('dropweb-sub-mirrors');
    final newMirrors =
        mirrorsHeader == null ? null : parseSubscriptionMirrors(mirrorsHeader);
    final newSubId = parseSubscriptionSubId(header('dropweb-sub-id'));
    // Маяк — параметр провайдера, а не кастомизация: тоже без гейта
    // `dropweb-custom` и без вырезания в магазинных сборках.
    final beaconUrlsHeader = header('dropweb-sub-beacon');
    final beaconKeysHeader = header('dropweb-sub-beacon-key');
    providerHeaders.removeWhere((name, _) => isStoredOutsideConfigHeader(name));

    final freshMirrors = newMirrors?.isNotEmpty ?? false;
    final List<String> nextMirrors;
    if (viaBeacon) {
      // Адрес из маяка становится известным: следующее обновление начнётся с
      // него (preferred), не дожидаясь мёртвых фронтов и самого маяка. База —
      // зеркала из хранилища: после миграции поле профиля может быть пустым,
      // и запись одного адреса затёрла бы сохранённый список.
      nextMirrors = _withLeadingMirror(
        freshMirrors ? newMirrors! : mirrors,
        succeededUrl,
      );
    } else {
      nextMirrors = freshMirrors ? newMirrors! : mirrorUrls;
    }

    final saved = await copyWith(
      label: label ?? utils.getFileNameForDisposition(disposition) ?? id,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      autoUpdateDuration: durationFromHeader ?? autoUpdateDuration,
      providerHeaders: storeSafeProviderHeaders(providerHeaders),
      fallbackUrl:
          (newFallbackUrl?.isNotEmpty ?? false) ? newFallbackUrl : fallbackUrl,
      mirrorUrls: nextMirrors,
      subId: newSubId ?? subId,
    ).saveFile(bytesToSave);
    await _storeBeaconHeaders(
      urlsHeader: beaconUrlsHeader,
      keysHeader: beaconKeysHeader,
    );
    return saved;
  }

  /// Первый адрес из [urls], давший пригодную подписку. Ошибки по адресам
  /// только считаются: в URL лежит токен подписки.
  Future<
      ({
        _FetchedSubscription? fetched,
        Object? firstError,
        StackTrace? firstStackTrace,
      })> _fetchFirstAccepted(
    List<String> urls,
    Map<String, dynamic> headers, {
    required String logLabel,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        final response = await request.getFileResponseForUrl(
          url,
          headers: headers.isNotEmpty ? Map.of(headers) : null,
        );
        final bytes = _acceptedSubscriptionBytes(response.data);
        return (
          fetched: (response: response, bytes: bytes, url: url),
          firstError: firstError,
          firstStackTrace: firstStackTrace,
        );
      } catch (e, st) {
        if (firstError == null) {
          firstError = e;
          firstStackTrace = st;
        }
        // SECURITY: только номер и тип ошибки — в URL лежит токен подписки.
        commonPrint.log(
          'subscription $logLabel ${i + 1}/${urls.length} failed: '
          '${e.runtimeType}',
        );
      }
    }
    return (
      fetched: null,
      firstError: firstError,
      firstStackTrace: firstStackTrace,
    );
  }

  /// Этап маяка: все известные адреса мертвы, новый фронт берётся из
  /// подписанного провайдером списка. Без sub-id персональный адрес не
  /// собрать — тогда этап пропускается целиком, маяк даже не запрашивается.
  Future<_FetchedSubscription?> _fetchViaBeacon({
    required Set<String> tried,
    required Map<String, dynamic> headers,
  }) async {
    final subId = await preferences.getProfileSubId(this);
    if (subId == null || subId.isEmpty) return null;
    final beaconUrls = await preferences.getProfileBeaconUrls(id);
    final keys = await preferences.getProfileBeaconKeys(id);
    if (beaconUrls.isEmpty || keys.isEmpty) return null;
    final cached = await preferences.getProfileBeaconState(id);

    final resolution = await resolveBeacon(
      beaconUrls: beaconUrls,
      keys: keys,
      cached: cached,
      // SECURITY: никаких заголовков — хостинг маяка чужой и не должен
      // узнать ни устройство, ни подписку; он видит только IP и User-Agent.
      fetch: (url) async {
        final response = await request.getFileResponseForUrl(
          url,
          maxBytes: kMaxBeaconDocumentBytes,
        );
        final data = response.data;
        if (data == null) throw const BeaconRejected('empty');
        return data;
      },
      onFailure: (i, n, e) => commonPrint.log(
        i < n
            ? 'subscription beacon ${i + 1}/$n failed: ${e.runtimeType}'
            : 'subscription beacon cache rejected: ${e.runtimeType}',
      ),
    );
    if (resolution == null) return null;
    if (resolution.state != cached) {
      try {
        final ok = await preferences.setProfileBeaconState(
          id,
          resolution.state,
        );
        if (!ok) commonPrint.log('subscription beacon state not stored');
      } catch (e) {
        commonPrint.log(
          'subscription beacon state not stored: ${e.runtimeType}',
        );
      }
    }

    final urls = beaconSubscriptionUrls(resolution.payload.mirrors, subId)
        .where((url) => !tried.contains(url))
        .take(kMaxBeaconAttempts)
        .toList();
    if (urls.isEmpty) return null;
    final attempt = await _fetchFirstAccepted(
      urls,
      headers,
      logLabel: 'beacon candidate',
    );
    return attempt.fetched;
  }

  /// Правило то же, что у остальных заголовков подписки: есть валидное
  /// значение — заменяем, нет — оставляем прежнее. Сбой хранилища не валит
  /// уже успешное обновление.
  Future<void> _storeBeaconHeaders({
    required String? urlsHeader,
    required String? keysHeader,
  }) async {
    try {
      final urls = parseSubscriptionBeaconUrls(urlsHeader);
      if (urls.isNotEmpty) {
        if (!await preferences.setProfileBeaconUrls(id, urls)) {
          commonPrint.log('subscription beacon urls not stored');
        }
      }
      final keys = parseSubscriptionBeaconKeys(keysHeader);
      if (keys.isNotEmpty) {
        if (!await preferences.setProfileBeaconKeys(id, keys)) {
          commonPrint.log('subscription beacon keys not stored');
        }
      }
    } catch (e) {
      commonPrint.log('subscription beacon not stored: ${e.runtimeType}');
    }
  }

  static List<String> _withLeadingMirror(List<String> mirrors, String url) {
    final normalized = normalizeProfileUrl(url);
    if (mirrors.map(normalizeProfileUrl).contains(normalized)) return mirrors;
    return [normalized, ...mirrors].take(kMaxSubscriptionMirrors).toList();
  }

  /// Тело ответа, пригодное к сохранению, или исключение — тогда кандидат
  /// считается упавшим и пробуется следующий (captive-портал или страница
  /// ошибки одного фронта не должны ни перезаписать профиль, ни остановить
  /// перебор).
  Uint8List _acceptedSubscriptionBytes(Uint8List? responseData) {
    if (responseData == null) {
      throw Exception("Failed to get profile data from response.");
    }
    // Some providers return a raw, newline-separated list of share links
    // (e.g. `vless://...`, `trojan://...`) instead of a Mihomo/Clash YAML
    // document. Detect that case here and rewrite the bytes to a minimal,
    // self-contained Mihomo YAML before they hit `saveFile`. Returns `null`
    // for normal YAML, in which case `responseData` flows through unchanged.
    final decoded = utf8.decode(responseData, allowMalformed: true);
    final converted = convertShareLinkSubscriptionToMihomo(decoded);

    // Guard the stored profile: a blank body or a document without any
    // proxy source (an HTML/JSON error page, `proxies: []`) would pass the
    // core's syntax-only validation and overwrite the working config, after
    // which every connection silently routes DIRECT. Reject it the same way a
    // fetch failure is rejected so the existing file stays untouched.
    final rejectReason = subscriptionBodyRejectReason(converted ?? decoded);
    if (rejectReason != null) {
      throw Exception('Invalid subscription response: $rejectReason');
    }
    return converted == null
        ? responseData
        : Uint8List.fromList(utf8.encode(converted));
  }

  /// Запоминает сработавший не основной адрес, чтобы следующее обновление
  /// начиналось с него, а не ждало таймаутов мёртвого фронта. Основной адрес
  /// успех зеркала не меняет. Ошибка хранилища только логируется: память о
  /// зеркале — оптимизация, а не условие успешного обновления.
  Future<void> _rememberWorkingCandidate({
    required String succeededUrl,
    required String primaryUrl,
    required String? preferredUrl,
  }) async {
    final isPrimary =
        normalizeProfileUrl(succeededUrl) == normalizeProfileUrl(primaryUrl);
    final next = isPrimary ? null : succeededUrl;
    if (next == preferredUrl) return;
    try {
      final ok = await preferences.setProfilePreferredUrl(id, next);
      if (!ok) commonPrint.log('subscription preferred candidate not stored');
    } catch (e) {
      commonPrint.log(
        'subscription preferred candidate not stored: ${e.runtimeType}',
      );
    }
  }

  Future<Profile> saveFile(Uint8List bytes) async {
    final message = await clashCore.validateConfig(utf8.decode(bytes));
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    // Atomic write: stage into a sibling temp file then rename over the target.
    // A kill mid-write would otherwise leave the stored profile truncated/corrupt.
    // File.rename is atomic on the same filesystem (macOS/Linux/Android); on
    // Windows a rename onto an existing target can throw, so fall back to
    // delete-then-rename.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    }
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<Profile> saveFileWithString(String value) async {
    final message = await clashCore.validateConfig(value);
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    // Atomic write: stage into a sibling temp file then rename over the target.
    // A kill mid-write would otherwise leave the stored profile truncated/corrupt.
    // File.rename is atomic on the same filesystem (macOS/Linux/Android); on
    // Windows a rename onto an existing target can throw, so fall back to
    // delete-then-rename.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    }
    return copyWith(lastUpdateDate: DateTime.now());
  }
}
