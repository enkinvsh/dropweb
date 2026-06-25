import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/update_resolver.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/services/android_app_updater.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/app_update.g.dart';

/// In-app updater state machine (sideloaded Android only). Inert on the Play
/// build (kIsPlayBuild). keepAlive so an in-flight download survives navigation
/// between the dashboard banner and the update sheet.
@Riverpod(keepAlive: true)
class AppUpdate extends _$AppUpdate {
  CancelToken? _cancelToken;

  @override
  AppUpdateState build() => const AppUpdateState();

  /// Checks dropweb.org/update.json for a newer build. [manual] bypasses the
  /// once/day cadence + the autoCheckUpdate setting; the Play gate is ALWAYS
  /// honoured. Tunnel-aware: routes via the proxy when the core is running.
  Future<void> check({bool manual = false}) async {
    if (!Platform.isAndroid || kIsPlayBuild) return;
    final setting = ref.read(appSettingProvider);
    if (!manual && !setting.autoCheckUpdate) return;
    final now = DateTime.now();
    if (!shouldRunScheduledCheck(
      manual: manual,
      lastCheck: DateTime.fromMillisecondsSinceEpoch(setting.lastUpdateCheckMs),
      now: now,
    )) {
      return;
    }
    if (state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading) {
      return;
    }

    state = state.copyWith(status: AppUpdateStatus.checking, error: null);
    final viaProxy = ref.read(runTimeProvider) != null;
    // Tunnel up: try via the active node first (ТСПУ may block dropweb.org/YC),
    // fall back to direct. Tunnel down: direct only.
    final manifest = await request.fetchUpdateManifest(viaProxy: viaProxy) ??
        (viaProxy ? await request.fetchUpdateManifest() : null);
    ref.read(appSettingProvider.notifier).updateState(
          (s) => s.copyWith(lastUpdateCheckMs: now.millisecondsSinceEpoch),
        );
    if (manifest == null) {
      state = state.copyWith(status: AppUpdateStatus.upToDate);
      return;
    }
    final info = resolveAndroidUpdate(
      manifest: manifest,
      localVersion: globalState.packageInfo.version,
    );
    state = info == null
        ? state.copyWith(status: AppUpdateStatus.upToDate, info: null)
        : state.copyWith(
            status: AppUpdateStatus.available,
            info: info,
            dismissed: false,
          );
  }

  /// Downloads the APK then verifies it. Source order: YC primary (direct, then
  /// via tunnel) → GitHub fallback (via tunnel when up, else direct).
  Future<void> download() async {
    final info = state.info;
    if (info == null || state.status == AppUpdateStatus.downloading) return;

    final savePath = await _stagedApkPath(info.version);
    _deleteQuietly(File(savePath));

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0,
      error: null,
    );
    _cancelToken = CancelToken();
    final isStart = ref.read(runTimeProvider) != null;

    var ok = false;
    try {
      for (final url in downloadSourcesInOrder(
        primaryUrl: info.primaryUrl,
        fallbackUrl: info.fallbackUrl,
      )) {
        final isPrimary = url == info.primaryUrl;
        final modes = isPrimary
            ? <bool>[false, if (isStart) true]
            : <bool>[if (isStart) true else false];
        for (final viaProxy in modes) {
          ok = await request.downloadUpdateApk(
            url: url,
            savePath: savePath,
            viaProxy: viaProxy,
            cancelToken: _cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 0) state = state.copyWith(progress: received / total);
            },
          );
          if (ok) break;
        }
        if (ok) break;
      }
    } on DioException catch (_) {
      // User cancel — re-arm the available state so the sheet can retry.
      state = state.copyWith(status: AppUpdateStatus.available, progress: 0);
      return;
    }

    if (!ok) {
      state =
          state.copyWith(status: AppUpdateStatus.error, error: 'updateFailed');
      return;
    }
    await _verify(savePath, info);
  }

  Future<void> _verify(String path, AppUpdateInfo info) async {
    state = state.copyWith(status: AppUpdateStatus.verifying);
    final file = File(path);
    // (1) Corruption guard — sha256 from the manifest is NOT a security control.
    if (info.sha256 != null) {
      final actual = await streamFileSha256(file);
      if (!sha256Matches(expected: info.sha256, actual: actual)) {
        _deleteQuietly(file);
        state = state.copyWith(
            status: AppUpdateStatus.error, error: 'updateFailed');
        return;
      }
    }
    // (2) MANDATORY fail-closed signing-cert pin — the REAL integrity gate.
    final signed = await app?.verifyApkSignature(path) ?? false;
    if (!signed) {
      _deleteQuietly(file);
      state =
          state.copyWith(status: AppUpdateStatus.error, error: 'updateFailed');
      return;
    }
    state = state.copyWith(status: AppUpdateStatus.readyToInstall, progress: 1);
  }

  /// Launches the system installer. If unknown-sources isn't granted, routes to
  /// settings and returns (the UI re-arms install on resume).
  Future<void> install() async {
    final info = state.info;
    if (info == null || state.status != AppUpdateStatus.readyToInstall) return;
    if (!(await app?.canInstallUnknownApps() ?? false)) {
      await app?.openUnknownSourcesSettings();
      return;
    }
    await app?.installApk(await _stagedApkPath(info.version));
  }

  void cancel() => _cancelToken?.cancel();

  void dismiss() => state = state.copyWith(dismissed: true);

  void reset() {
    _cancelToken?.cancel();
    state = const AppUpdateState();
  }

  Future<String> _stagedApkPath(String version) async {
    final cacheDir = await getApplicationCacheDirectory();
    final dir = Directory(p.join(cacheDir.path, kUpdateCacheDirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return p.join(dir.path, 'dropweb-$version.apk');
  }

  void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      debugPrint('updater: apk cleanup failed: $e');
    }
  }
}
