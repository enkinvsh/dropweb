# AGENTS.md — dropweb

Multi-platform consumer VPN client (Android primary; Windows, macOS) built on the mihomo/Clash **Go core**, with a **Flutter/Dart** UI talking to the core over **FFI**. Package/applicationId `app.dropweb`. GPL-3.0. Repo: `enkinvsh/dropweb`. Version `0.8.1+2026062605`.

## Context layer — query this BEFORE reading whole files
This repo is wired for fast, low-token retrieval. When opencode runs from this directory, three layers activate automatically — use them first, read full files only when they are insufficient:

- **Serena (symbol layer, active via project-from-cwd):** `get_symbols_overview`, `find_symbol`, `find_referencing_symbols` instead of reading entire files. Start at Serena memory `mem:core` (graph root → `tech_stack`, `conventions`, `suggested_commands`, `task_completion`).
- **code-graph (whole-repo discovery):** `project_map` (architecture), `semantic_code_search` ("where is X" by concept, before you know symbol names), `get_call_graph`, `impact_analysis` (blast radius before a change), `module_overview`, `find_references`. Index in `.code-graph/index.db`, incremental on save. Go = full relations, Dart = calls/imports/implements.
- **Memory MCP (cross-session facts):** `recall "dropweb"`. Key facts: `dropweb_core_state` (core rebase/version), `dropweb_build_machine` (local toolchain), `dropweb_release_workflow` (CI/tags).

## Repo map
- `lib/` — Flutter app (216 Dart files, ~82K LOC). Entry: `main.dart`, `application.dart`, `controller.dart`, `state.dart`. Barrel imports `package:dropweb/...`. Riverpod `Consumer*` widgets.
  - `clash/` FFI bridge to Go core (ffigen `ClashFFI` -> `lib/clash/generated/clash_ffi.dart`)
  - `common/` shared utils (largest) - `models/` Freezed/json - `providers/` Riverpod - `manager/` runtime managers
  - `views/` screens - `pages/` - `widgets/` - `services/` - `l10n/` (generated) - `enum/` - `utils/`
- `core/` — Go mihomo core: `Clash.Meta` submodule (`enkinvsh/xHomo`, branch `dropweb-core-rebuild`) + Go/Dart bridge (`lib.go`, `hub.go`, `action.go`, `android_bride.go`, `main.go`, `dart-bridge/`, `tun/`, `state/`, `platform/`).
- `android/` native shell (see invariants) - `plugins/` local Flutter plugins (`proxy`, `window_ext`) - `arb/` l10n sources -> `lib/l10n` - `setup.dart` + `Makefile` build entry - `assets/` - `build/`,`dist/` gitignored artifacts.

## Stack
Flutter/Dart SDK `>=3.5.0 <4.0.0`. Riverpod (`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`) + Freezed + `json_serializable` + `build_runner`. FFI to Go core. Forked deps pinned to a ref: `re_editor`, `flutter_js` (both `enkinvsh`).

## Build & verify
- Deps: `flutter pub get`
- Codegen (after annotation/ARB changes): `dart run build_runner build --delete-conflicting-outputs`
- Static check: `dart analyze` (or `flutter_analyze` MCP) — report exact error/warning counts
- Core-only fast build (~30s, no keystore): `make android_arm64_core`  (= `dart run setup.dart android --arch arm64 --out core`)
- Full Android arm64: `make android_arm64`  (needs `ANDROID_NDK`)
- Debug APK: `fvm flutter build apk --debug --target-platform android-arm64`
- Build env: full builds need fvm Flutter **3.41.6** (brew 3.44 breaks gradle AGP), JDK **17** (NOT 26), NDK **28.2.13676358**, `ANDROID_HOME` set. Details: `recall "dropweb_build_machine"`.

## Hard invariants (do not violate)
- `minSdk = 24` hardcoded in `android/app/build.gradle.kts` (flutter_secure_storage 10.x + core). Do NOT revert to `flutter.minSdkVersion`.
- `jniLibs.useLegacyPackaging = true` — relay `.so` must extract to disk for `ProcessBuilder` under SELinux.
- 16KB page alignment is solved at NDK/Go link (`-Wl,-z,max-page-size=16384`), NOT by packaging flags.
- Force `androidx.datastore:* = 1.1.7` (resolutionStrategy); 1.2.0 ships a non-16KB-aligned `.so` -> Google Play rejection.
- No R8 `-assumenosideeffects android.util.Log` — caused release-only splash hang.
- Fail-closed release signing: missing keystore/creds -> release tasks abort (no debug-key fallback). Debug uses `applicationIdSuffix .debug`.
- Generated code (`*.g.dart`, `*.freezed.dart`, `lib/l10n/`) is regenerated, never hand-edited.

## Design system (UI work — read before touching any widget)
**Design authority: `DESIGN.md`** at repo root, read by design-cockpit and the design-workflow skill every session, in any agent. Summary below.

Dark-only, atomic, token-based. The product language is intentional "Lumina" dark glass + accent glow + orbs. Do NOT introduce a new visual system, light/system mode, or ad-hoc styling.

Token sources (hardcoded hex lives ONLY here):
- `lib/common/lumina.dart` (`Lumina`, static const): surfaces `void_`/`surface1..5`; glass (`glass()`, `glassCircle()`, `glassBlur`/`heavyBlur`, opacity consts); glow (`glowPrimary/Secondary/Accent`, `glowShadow()`); shadows; radii (`radiusMd 16`/`radiusLg 24`/`radiusXl 32`/`radiusXxl 48`); motion (`luminaCurve`, `luminaDuration` 400ms).
- `lib/common/color.dart`: opacity via `.opacity80..opacity0` extensions (NOT `withOpacity`); `lighten/darken`, `blendDarken/blendLighten(context)`; scheme-variant filters; `ColorScheme.toPureBlack`.
- `lib/common/theme.dart` (`CommonTheme`): context-cached derived colors.
- Semantic colors via `context.colorScheme.*` (Material 3). Dynamic accent/orb/preset themes via `themeSettingProvider` (presets Emerald/Frost/Amethyst/Magma/Amber/Crimson/Stealth).

Atomic layer: compose from `package:dropweb/widgets/widgets.dart` (card, chip, container, input, sheet, side_sheet, dialog, popup, scaffold, list, grid, super_grid, tab, icon, text, palette, color_scheme_box, notification, null_status, effect, mesh_background, charts...). Reuse these; do NOT rebuild buttons/cards/inputs/sheets from raw Container/Material.

Hard rules (anti-slop):
- No `Color(0xFF...)` outside `lumina.dart` — use `Lumina.*` / `context.colorScheme.*` / opacity extensions.
- No inline `TextStyle(...)` for ad-hoc size/color — use `Theme.of(context).textTheme.*` + text atoms. Fonts via `FontFamily` enum (Onest / JetBrainsMono / Twemoji), never literal family strings.
- Radii from `Lumina.radius*`; spacing on the existing 8-scale (16/24/64) already in use.
- Glass is intentional but ONLY via `Lumina.glass*`/`glassBlur`; never raw `BackdropFilter` with arbitrary sigma. Blur is GPU-quadratic and deliberately capped (4/8) for mid-range Android (Skia, no Impeller) — do not raise it.
- Dark-only: no light/system-mode branches. Signature motion via `Lumina.luminaCurve`/`luminaDuration`.

Visual QA (Flutter, not browser): verify with `flutter_screenshot` (flutter-dev MCP) on device, NOT design-cockpit browser capture. Cover states default/pressed/disabled/loading/empty/error. For non-trivial UI, route to the `visual-engineering` category with the `design-workflow` skill and produce a project-native Design Brief first.

## Update-after-work ritual
1. `dart analyze` clean (or name pre-existing failures).
2. code-graph reindexes incrementally on save; force with `npx -y @sdsrs/code-graph incremental-index`.
3. Update Serena memories ONLY for stable, non-obvious invariants (dense bullets, no task notes).
4. `save_fact` / `remember` durable cross-session facts to Memory MCP.
5. `git status` — `.serena/` and `.code-graph/` are gitignored (local-only); commit only real source changes.
