import 'package:dropweb/models/models.dart';

/// Owns the single mutable `Config` mirror that backs `globalState.config`.
///
/// ## Why this exists (dual source of truth, bounded)
/// The app intentionally keeps TWO views of `Config`:
///   * the 12 Riverpod slice providers (lib/providers/config.dart), which are
///     the source of truth for the UI isolate (`ProviderScope`); and
///   * this flat, ref-less mirror, read by code that has no Riverpod `ref`
///     (the domain layer in lib/state.dart and, crucially, the **service
///     isolate** in lib/main.dart, which constructs no `ProviderScope`).
///
/// This repository does NOT remove that duality — it concentrates the mirror
/// behind one object so the write path is single and documented, instead of
/// 12 inlined `globalState.config = globalState.config.copyWith(...)` sites.
///
/// ## The two writers (both legitimate)
///   1. **Provider slices** mirror their state forward via [syncSlice], called
///      from each provider's `onUpdate` (lib/providers/config.dart). This is
///      the hot path: every settings change flows through here.
///   2. **The service isolate** mutates the mirror directly through the
///      `globalState.config` setter (lib/main.dart, the `updateForegroundServer`
///      / `updateMode` IPC handlers). It has no `ProviderScope` by design, so
///      it cannot go through the providers — it writes the mirror straight.
///
/// ## Drift-lock
/// The forward seed (mirror → 12 providers, via each provider `build()` reading
/// `globalState.config.*`) and the reverse aggregation (12 providers → mirror,
/// via `configState` in lib/providers/state.dart) are field-coverage locked by
/// test/common/config_roundtrip_test.dart. A new `Config` field that is not
/// wired into both halves fails that test.
class ConfigRepository {
  /// The mirror itself. Set exactly once at startup by `GlobalState.init()`
  /// (from persisted preferences) before any reader runs; reading before that
  /// throws `LateInitializationError`, preserving the previous
  /// `late Config config` semantics this repository replaced.
  ///
  /// Direct assignment to this field is the **service-isolate write path**
  /// (writer #2 above): `globalState.config = ...` delegates here. Provider
  /// slices must NOT assign it directly — they go through [syncSlice].
  late Config config;

  /// The single write path for the 12 provider slices mirroring their state
  /// forward. Each provider's `onUpdate` (lib/providers/config.dart) calls this
  /// with a `copyWith` that overwrites just its own slice, e.g.
  /// `syncSlice((c) => c.copyWith(appSetting: value))`.
  void syncSlice(Config Function(Config current) apply) {
    config = apply(config);
  }
}
