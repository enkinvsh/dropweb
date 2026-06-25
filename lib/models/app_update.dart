import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/app_update.freezed.dart';

/// Lifecycle of the in-app updater (sideloaded Android). Drives the update
/// state machine and the Lumina update UI. See
/// docs/plans/2026-06-25-auto-update.md.
enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  readyToInstall,
  error,
}

/// A resolved, newer-than-installed update for the android-arm64 platform,
/// produced by `resolveAndroidUpdate` from the fetched update.json manifest.
@freezed
class AppUpdateInfo with _$AppUpdateInfo {
  const factory AppUpdateInfo({
    /// Marketing version WITHOUT a leading `v`, e.g. `0.8.2`.
    required String version,

    /// Release tag, e.g. `v0.8.2` — used to build the GitHub fallback URL.
    required String tag,

    /// Release notes (bullets), already split per line.
    @Default(<String>[]) List<String> notes,

    /// Primary download URL: Yandex Cloud (RU-reliable).
    required String primaryUrl,

    /// Fallback download URL: the GitHub release asset (computed from
    /// `repository` + [tag]). Null when no asset name is known for the platform.
    String? fallbackUrl,

    /// Lowercase hex sha256 of the APK. CORRUPTION check ONLY — it shares the
    /// manifest's trust root, so it is NOT a security control. The real gate is
    /// the native fail-closed signing-cert pin (verifyApkSignature, Task 4.4).
    String? sha256,

    /// Manifest `mandatory` flag. Soft-forced only: the UI nags persistently
    /// but never blocks app use.
    @Default(false) bool mandatory,

    /// Manifest `minSupported` version, if present.
    String? minSupported,
  }) = _AppUpdateInfo;
}


/// Reactive state for the in-app updater, surfaced by `appUpdateProvider` and
/// rendered by the Lumina update banner/sheet.
@freezed
class AppUpdateState with _$AppUpdateState {
  const factory AppUpdateState({
    @Default(AppUpdateStatus.idle) AppUpdateStatus status,
    AppUpdateInfo? info,

    /// Download progress 0.0..1.0 (only meaningful while [status] is downloading).
    @Default(0.0) double progress,

    /// Human-facing error key/message for the error state.
    String? error,

    /// User dismissed the soft banner this run (mandatory updates ignore this).
    @Default(false) bool dismissed,
  }) = _AppUpdateState;
}
