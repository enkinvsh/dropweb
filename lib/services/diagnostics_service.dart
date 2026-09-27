import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/diagnostics.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Result of [DiagnosticsService.writeAll].
class DiagnosticsWriteResult {
  const DiagnosticsWriteResult({
    required this.directory,
    required this.diagPath,
    required this.text,
    required this.isExternal,
  });

  final String directory;
  final String diagPath;
  final String text;

  /// False when the Android app-specific external dir was unavailable and the
  /// files went to the (non adb-pullable) app support dir instead.
  final bool isExternal;
}

/// IO + provider glue around the pure `lib/common/diagnostics.dart`. Shared
/// by the developer screen and the adb remote so both produce the same dump.
class DiagnosticsService {
  DiagnosticsService._();

  static const String diagDirName = 'diag';
  static const String latestDiag = 'diag-latest.txt';
  static const String latestConfig = 'config-latest.json';
  static const String latestHeaders = 'headers-latest.txt';

  static String appVersion() {
    try {
      final info = globalState.packageInfo;
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      // packageInfo is `late` and set in initApp; unreadable only very early.
      return 'unknown';
    }
  }

  /// Primary router (catch-all MATCH target) of the current profile, the same
  /// group the «Страна» screen and `applyWorkMode` treat as primary.
  static Future<String?> primaryRouter(ProviderContainer c) async {
    final profile = c.read(currentProfileProvider);
    if (profile == null) return null;
    try {
      return detectPrimaryRouter(
        await globalState.getProfileConfig(profile.id),
      );
    } catch (e) {
      commonPrint.log('[diagnostics] primary router lookup failed: $e');
      return null;
    }
  }

  /// One-line-JSON-able status: shared by `status` and the diag header.
  static Future<Map<String, Object?>> statusMap(ProviderContainer c) async {
    final profile = c.read(currentProfileProvider);
    final setting = c.read(appSettingProvider);
    final patch = c.read(patchClashConfigProvider);
    final groups = c.read(currentGroupsStateProvider).value;
    return {
      'running': c.read(runTimeProvider) != null,
      'workMode': profile?.workMode.name,
      'staticCountry': profile?.staticCountry,
      'fullTunnel': profile?.fullTunnel,
      'profile': profile == null ? null : redactUrls(profile.serviceName),
      'lastUpdateDate': profile?.lastUpdateDate?.toIso8601String(),
      'router': await primaryRouter(c),
      'developerMode': setting.developerMode,
      'openLogs': setting.openLogs,
      'logLevel': patch.logLevel.name,
      'coreLogLevel': coreLogLevel(
        openLogs: setting.openLogs,
        requested: patch.logLevel,
      ).name,
      'version': appVersion(),
      'isPlayBuild': kIsPlayBuild,
      'isDebug': kDebugMode,
      'groups': {for (final g in groups) g.name: g.now},
    };
  }

  static int? delayOf(ProviderContainer c, Group group, String proxyName) =>
      c.read(getDelayProvider(proxyName: proxyName, testUrl: group.testUrl));

  static List<DiagnosticsGroup> collectGroups(ProviderContainer c) => [
        for (final g in c.read(groupsProvider))
          DiagnosticsGroup(
            name: g.name,
            type: g.type.name,
            now: g.now,
            members: [
              for (final p in g.all)
                DiagnosticsMember(name: p.name, delay: delayOf(c, g, p.name)),
            ],
          ),
      ];

  static String formatLog(Log log) =>
      '${log.dateTime} [${log.logLevel.name.toUpperCase()}] ${log.payload}';

  static Future<String> buildReport(ProviderContainer c) async {
    final profile = c.read(currentProfileProvider);
    int? sdk;
    if (Platform.isAndroid) {
      try {
        sdk = await system.version;
      } catch (e) {
        commonPrint.log('[diagnostics] sdk lookup failed: $e');
      }
    }
    return buildDiagnosticsText(
      now: DateTime.now(),
      appVersion: appVersion(),
      isPlayBuild: kIsPlayBuild,
      isDebug: kDebugMode,
      androidSdk: sdk,
      status: await statusMap(c),
      groups: collectGroups(c),
      headers: profile?.providerHeaders ?? const {},
      profileUrl: profile?.url,
      lastSetupAt: globalState.lastSetupAt,
      effectiveConfig: globalState.lastSetupConfig,
      logLines: c.read(logsProvider).list.map(formatLog).toList(),
    );
  }

  /// Redacted pretty JSON of the last config sent to the core; null before
  /// the first setup.
  static String? redactedConfigJson() {
    final config = globalState.lastSetupConfig;
    if (config == null) return null;
    return JsonEncoder.withIndent('  ', (o) => o.toString())
        .convert(redactConfigForDiagnostics(config));
  }

  static Map<String, String> redactedHeaders(ProviderContainer c) =>
      redactHeadersForDiagnostics(
        c.read(currentProfileProvider)?.providerHeaders ?? const {},
      );

  static String redactedHeadersText(ProviderContainer c) =>
      redactedHeaders(c).entries.map((e) => '${e.key}: ${e.value}').join('\n');

  static Future<(Directory, bool)> _dir() async {
    Directory? base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    }
    final isExternal = base != null;
    base ??= await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$diagDirName');
    await dir.create(recursive: true);
    return (dir, isExternal);
  }

  static Future<void> _write(Directory dir, String name, String text) =>
      File('${dir.path}/$name').writeAsString(text, flush: true);

  /// Writes `diag-<ts>.txt` + `diag-latest.txt`, `config-latest.json` and
  /// `headers-latest.txt`, keeping at most 5 timestamped diag files.
  static Future<DiagnosticsWriteResult> writeAll(ProviderContainer c) async {
    final (dir, isExternal) = await _dir();
    final text = await buildReport(c);
    final stamped = 'diag-${diagnosticsTimestamp(DateTime.now())}.txt';
    await _write(dir, stamped, text);
    await _write(dir, latestDiag, text);
    await _write(dir, latestConfig, redactedConfigJson() ?? '{}');
    await _write(dir, latestHeaders, redactedHeadersText(c));
    final names = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    for (final name in diagFilesToPrune(names)) {
      await File('${dir.path}/$name').delete();
    }
    return DiagnosticsWriteResult(
      directory: dir.path,
      diagPath: '${dir.path}/$stamped',
      text: text,
      isExternal: isExternal,
    );
  }

  /// Writes only `config-latest.json` / `headers-latest.txt` (remote
  /// `config` / `headers`). Returns (path, content, isExternal).
  static Future<(String, String, bool)> writeConfig() async {
    final (dir, isExternal) = await _dir();
    final text = redactedConfigJson() ?? '{}';
    await _write(dir, latestConfig, text);
    return ('${dir.path}/$latestConfig', text, isExternal);
  }

  static Future<(String, String, bool)> writeHeaders(
      ProviderContainer c) async {
    final (dir, isExternal) = await _dir();
    final text = redactedHeadersText(c);
    await _write(dir, latestHeaders, text);
    return ('${dir.path}/$latestHeaders', text, isExternal);
  }
}
