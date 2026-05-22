/// Whether the Settings → Access Control / per-app proxy entry should be
/// exposed in the UI.
///
/// Access Control is an advanced Android surface: it enumerates installed
/// packages and lets the user pin per-app split-tunnel rules. For the Google
/// Play target we hide it by default and only re-expose it once the existing
/// developer/advanced mode is unlocked (5 rapid taps on the Settings nav,
/// see `lib/views/developer.dart`). This mirrors the gating already applied
/// to `_ConfigItem` and `_SettingItem` in `lib/views/tools.dart`.
///
/// The actual `AccessView` implementation, per-app VPN plumbing, and Android
/// package-visibility declarations are untouched — only the Settings entry
/// point is gated.
///
/// Access Control only ever existed on Android, so non-Android callers
/// always get `false` regardless of the developer-mode flag.
bool shouldShowAccessControl({
  required bool isAndroid,
  required bool developerMode,
}) {
  if (!isAndroid) return false;
  return developerMode;
}
