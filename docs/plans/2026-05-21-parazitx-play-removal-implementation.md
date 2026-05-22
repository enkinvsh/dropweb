# ParazitX Play Removal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Physically remove the ParazitX / VK Calls module from the Play-facing Dropweb app while preserving normal Dropweb VPN, mihomo subscription import, connect, status, disconnect, and the browser-only cabinet flow.

**Architecture:** Delete the ParazitX feature surface, Dart managers, plugin channels, Android service, relay controller, native relay binaries, and ParazitX-only tests. Keep the ordinary mihomo pipeline untouched. Cabinet stays browser-only via the dashboard SVG/button affordance calling `openCabinetBrowser(Uri)`, with no native cabinet restoration.

**Tech Stack:** Flutter, Dart, Riverpod, Kotlin Android, mihomo via `setup.dart`, Flutter test, `flutter_analyze`.

---

## Decision

ParazitX is removed physically from Play-facing app code, not hidden behind a feature flag. The Google Play build should not ship dormant VK login, VK cookie capture, ParazitX relay binaries, ParazitX Android services, ParazitX method channels, ParazitX UI, or ParazitX tests.

## Safety / Preservation

- Current branch/worktree: `cleanup-code-garbage` at `/Users/oen/.config/superpowers/worktrees/dropweb-app/cleanup-code-garbage`.
- Separate preservation branch exists: `wip/parazitx-quarantine-2026-05-17`.
- Do not delete git history or the `wip/parazitx-quarantine-2026-05-17` branch.
- Do not remove GPL or upstream attribution.
- Do not delete docs history in this implementation. Existing historical docs, changelog entries, and old plans may retain ParazitX references unless a later docs cleanup decision says otherwise.
- Do not touch Android package identity. Current package identity is `app.dropweb`; leave it unchanged.
- Do not restore native cabinet. Cabinet remains `SVG/кнопка → openCabinetBrowser(Uri)`.

## Known ParazitX / VK Areas Found During Planning

Inspect these before editing because they were present in this worktree:

**Dart app code**
- `lib/state.dart`, imports `services/parazitx_mihomo_orchestrator.dart` and calls `ParazitXMihomoOrchestrator.applyToConfig(...)` inside `GlobalState.patchRawConfig`.
- `lib/services/parazitx_manager.dart`, main activation, VK cookies, captcha, manifest, relay, log upload orchestration.
- `lib/services/parazitx_manifest.dart`, manifest model and node selection.
- `lib/services/parazitx_mihomo_orchestrator.dart`, mihomo bridge injection and DIRECT rules.
- `lib/services/mihomo_dialer_proxy_patcher.dart`, ParazitX bridge proxy patcher.
- `lib/services/vk_auth_service.dart`, VK cookie storage and cleanup.
- `lib/services/log_buffer.dart`, ParazitX log buffer with cookie sanitization.
- `lib/services/log_uploader.dart`, ParazitX log uploader.
- `lib/plugins/parazitx_vpn_plugin.dart`, Dart method channel `app.dropweb/parazitx_vpn`.
- `lib/plugins/vk_tunnel_plugin.dart`, Dart event channel `app.dropweb/vktunnel/status`.
- `lib/common/vk_cookie_consent.dart`, VK disclosure consent persistence.
- `lib/views/parazitx_page.dart`, standalone VK Calls page.
- `lib/views/parazitx/footer_diagnostics.dart`.
- `lib/views/parazitx/hero_state_card.dart`.
- `lib/views/parazitx/primary_cta.dart`.
- `lib/views/parazitx/vk_calls_state.dart`.
- `lib/views/parazitx/vk_calls_status_view.dart`.
- `lib/views/vk_login_screen.dart`, in-app VK login WebView.
- `lib/views/vk_cookie_disclosure_dialog.dart`.
- `lib/views/captcha_screen.dart`.
- `lib/views/application_setting.dart`, contains `ParazitXSectionItem`, `ParazitXSectionLayout`, `SendParazitXLogsItem`, and imports ParazitX services/views.
- `lib/views/tools.dart`, imports `parazitx_page.dart`, adds `_ParazitXItem` to Android settings list, and opens `ParazitXPage`.
- `lib/services/deep_link_handler.dart`, imports `parazitx_page.dart` and handles route `parazitx`.
- `lib/l10n/l10n.dart` and generated `lib/l10n/intl/messages_*.dart`, contain VK disclosure and ParazitX labels.

**Android app code**
- `android/app/src/main/kotlin/app/dropweb/MainActivity.kt`, registers ParazitX status/log event channels, `app.dropweb/parazitx_vpn`, `app.dropweb/parazitx_notifications`, and route `parazitx`.
- `android/app/src/main/kotlin/app/dropweb/services/ParazitXVpnService.kt`, ParazitX VpnService and controller.
- `android/app/src/main/kotlin/app/dropweb/ParazitXRelayController.kt`, relay process lifecycle and binary lookup.
- `android/app/src/main/kotlin/app/dropweb/services/DropwebTileService.kt`, listens to ParazitX broadcasts and lets the tile stop ParazitX.
- `android/app/src/main/AndroidManifest.xml`, declares `.services.ParazitXVpnService` in process `:parazitx`.
- `android/app/src/main/jniLibs/arm64-v8a/libparazitx-relay.so`.
- `android/app/src/main/jniLibs/armeabi-v7a/libparazitx-relay.so`.

**Tests**
- `test/services/parazitx_manifest_test.dart`.
- `test/services/parazitx_mihomo_orchestrator_test.dart`.
- `test/services/mihomo_dialer_proxy_patcher_test.dart`.
- `test/views/parazitx/vk_calls_status_view_test.dart`.
- `test/views/parazitx/primary_cta_test.dart`.

**Docs/history to keep unless a later decision says otherwise**
- `docs/parazitx/operator-guide.md`.
- `docs/parazitx/relay-build.md`.
- `docs/plans/2026-05-02-parazitx-mihomo-outbound.md`.
- `docs/plans/2026-04-30-vk-calls-ux-redesign.md`.
- `CHANGELOG.md` historical entries.

## Task 1: Discovery Snapshot

**Files:**
- Inspect: whole worktree under `/Users/oen/.config/superpowers/worktrees/dropweb-app/cleanup-code-garbage`.
- Do not modify app code in this task.

**Step 1: Confirm branch and preservation branch**

Run:

```bash
GIT_MASTER=1 git status --short --branch
GIT_MASTER=1 git branch --list 'wip/parazitx-quarantine-2026-05-17'
```

Expected:
- Current branch is `cleanup-code-garbage`.
- Local branch `wip/parazitx-quarantine-2026-05-17` is listed.

**Step 2: Capture current ParazitX/VK references**

Run:

```bash
grep -RInE 'ParazitX|parazitx|VK|\bvk\b|VkTunnel|vk_tunnel|captcha|relay|log uploader|log_buffer|send logs|commonPrint' lib test android docs CHANGELOG.md
```

Expected: references exist in the files listed above. Save the output in the executor notes, not in the plan.

**Step 3: Capture matching files**

Run:

```bash
find lib test android docs -iname '*parazitx*' -o -iname '*vk*' -o -iname '*captcha*'
```

Expected: matching files include ParazitX services, VK views/plugins, ParazitX tests, Android service/controller, relay binaries, and historical docs.

## Task 2: Tests-First Guardrails For Preserved Behavior

**Files:**
- Inspect: `test/`.
- Modify or create only if equivalent tests are missing: `test/providers/profile_cabinet_test.dart`, `test/views/dashboard/metainfo_widget_test.dart`, or the nearest existing cabinet/profile test file.
- Do not add ParazitX tests.

**Step 1: Find existing cabinet tests**

Run:

```bash
grep -RInE 'openCabinetBrowser|profileHasCabinetMarker|resolveCabinet|dropweb-cabinet|cabinet' test lib/views/dashboard lib/providers
```

Expected: find existing coverage or identify the closest place to add small tests.

**Step 2: Add a focused test only if coverage is missing**

If there is no existing coverage, add tests for:
- `profileHasCabinetMarker(Profile?)` stays true for `dropweb-cabinet` truthy headers.
- Cabinet URLs still resolve to HTTPS or local development HTTP only.
- Dashboard cabinet affordance still calls the browser entry point through `openCabinetBrowser(Uri)`.

Do not create a native cabinet test. Do not add a WebView/native-cabinet path.

**Step 3: Run the focused tests**

Run the exact file added or modified, for example:

```bash
flutter test test/providers/profile_cabinet_test.dart
```

Expected: passes. If no tests were added because coverage already exists, run the existing cabinet test file instead.

## Task 3: Remove UI and Navigation Entry Points

**Files:**
- Modify: `lib/views/tools.dart`.
- Modify: `lib/views/application_setting.dart`.
- Modify: `lib/services/deep_link_handler.dart`.
- Delete: `lib/views/parazitx_page.dart`.
- Delete: `lib/views/parazitx/footer_diagnostics.dart`.
- Delete: `lib/views/parazitx/hero_state_card.dart`.
- Delete: `lib/views/parazitx/primary_cta.dart`.
- Delete: `lib/views/parazitx/vk_calls_state.dart`.
- Delete: `lib/views/parazitx/vk_calls_status_view.dart`.
- Delete: `lib/views/vk_login_screen.dart`.
- Delete: `lib/views/vk_cookie_disclosure_dialog.dart`.
- Delete: `lib/views/captcha_screen.dart`.

**Step 1: Remove Tools entry point**

In `lib/views/tools.dart`:
- Remove `import 'package:dropweb/views/parazitx_page.dart';`.
- Remove `if (Platform.isAndroid) const _ParazitXItem(),` from `_getSettingList`.
- Remove the `_ParazitXItem` class.

Keep `_TvItem`, `_AccessItem`, `_ConfigItem`, `_SettingItem`, and all ordinary settings behavior intact.

**Step 2: Remove settings activation section**

In `lib/views/application_setting.dart`:
- Remove imports for `log_buffer.dart`, `log_uploader.dart`, `parazitx_manager.dart`, `vk_auth_service.dart`, `captcha_screen.dart`, `parazitx/primary_cta.dart`, and `vk_login_screen.dart`.
- Remove `_UserCancelled`.
- Remove `_ParazitXState`.
- Remove `ParazitXSectionLayout`.
- Remove `ParazitXSectionItem` and `_ParazitXSectionItemState`.
- Remove `SendParazitXLogsItem` and its state class.
- Remove any references to these widgets from settings sections.

Do not remove `OpenLogsFolderItem` unless a compile error proves it was ParazitX-only. Ordinary app logs are still useful.

**Step 3: Remove deep link route**

In `lib/services/deep_link_handler.dart`:
- Remove `import 'package:dropweb/enum/enum.dart';` if it becomes unused.
- Remove `import 'package:dropweb/state.dart';` if it becomes unused.
- Remove `import 'package:dropweb/views/parazitx_page.dart';`.
- Remove route case `parazitx`.
- Remove `_openParazitX()`.
- Keep unknown-route logging and channel initialization intact.

**Step 4: Delete UI files**

Delete the listed `lib/views/parazitx*`, VK login, VK disclosure, and captcha files.

**Step 5: Analyze after UI removal**

Run:

```bash
flutter_analyze
```

Expected: 0 errors. Baseline warnings and infos are acceptable only if they existed before this work.

## Task 4: Remove Dart Services, Plugins, and Mihomo Injection

**Files:**
- Modify: `lib/state.dart`.
- Delete: `lib/services/parazitx_manager.dart`.
- Delete: `lib/services/parazitx_manifest.dart`.
- Delete: `lib/services/parazitx_mihomo_orchestrator.dart`.
- Delete: `lib/services/mihomo_dialer_proxy_patcher.dart`.
- Delete: `lib/services/vk_auth_service.dart`.
- Delete: `lib/services/log_uploader.dart`.
- Delete: `lib/common/vk_cookie_consent.dart`.
- Delete: `lib/plugins/parazitx_vpn_plugin.dart`.
- Delete: `lib/plugins/vk_tunnel_plugin.dart`.
- Inspect before deleting: `lib/services/log_buffer.dart`.

**Step 1: Remove mihomo ParazitX bridge injection**

In `lib/state.dart`:
- Remove `import 'services/parazitx_mihomo_orchestrator.dart';`.
- Remove the full comment and call to `ParazitXMihomoOrchestrator.applyToConfig(...)` inside `GlobalState.patchRawConfig`.
- Keep all ordinary `patchRawConfig` behavior intact: rule override handling, `rawConfig['rule'] = rules`, profile config loading, and mihomo update flow.

**Step 2: Delete ParazitX service and plugin files**

Delete the service and plugin files listed above.

**Step 3: Decide `log_buffer.dart` by reference, not by name**

Run:

```bash
grep -RIn "LogBuffer" lib test
```

If only deleted ParazitX files used it, delete `lib/services/log_buffer.dart`. If ordinary Dropweb logging still uses it, keep it and remove only ParazitX-specific comments or sanitizers if they cause stale Play-facing copy.

**Step 4: Analyze after service removal**

Run:

```bash
flutter_analyze
```

Expected: 0 errors.

## Task 5: Remove Android Service, Channels, Relay Binary, and Tile Coupling

**Files:**
- Modify: `android/app/src/main/kotlin/app/dropweb/MainActivity.kt`.
- Modify: `android/app/src/main/kotlin/app/dropweb/services/DropwebTileService.kt`.
- Modify: `android/app/src/main/AndroidManifest.xml`.
- Delete: `android/app/src/main/kotlin/app/dropweb/services/ParazitXVpnService.kt`.
- Delete: `android/app/src/main/kotlin/app/dropweb/ParazitXRelayController.kt`.
- Delete: `android/app/src/main/jniLibs/arm64-v8a/libparazitx-relay.so`.
- Delete: `android/app/src/main/jniLibs/armeabi-v7a/libparazitx-relay.so`.

**Step 1: Remove ParazitX channels from MainActivity**

In `MainActivity.kt`, remove:
- EventChannel `app.dropweb/vktunnel/status`.
- EventChannel `app.dropweb/parazitx/logs`.
- MethodChannel `app.dropweb/parazitx_vpn`.
- MethodChannel `app.dropweb/parazitx_notifications`.
- Companion constants `ROUTE_PARAZITX` and any `EXTRA_ROUTE` use if no other route uses it.
- Imports that only support those removed blocks.

Keep:
- `AppPlugin` registration.
- `ServicePlugin`, `TilePlugin`, and `VpnPlugin` registration.
- `GlobalState.syncStatus()`.
- App theme logic.

**Step 2: Simplify DropwebTileService to mihomo only**

In `DropwebTileService.kt`:
- Remove `BroadcastReceiver`, `Intent`, and `IntentFilter` imports if only used for ParazitX.
- Remove `lastParazitxStatus`.
- Remove `parazitxReceiver` and `parazitxReceiverRegistered`.
- Remove `parazitxActive` and `parazitxConnecting`.
- In `refreshTile()`, compute tile state only from `GlobalState.runState.value` and `GlobalState.hasActiveProfile()`.
- In `onStartListening()`, keep `GlobalState.syncStatus()` and `GlobalState.runState.observeForever(mihomoObserver)`. Remove `ParazitXVpnController.queryStatus(...)`.
- In `onStopListening()` and `onDestroy()`, remove ParazitX receiver unregister logic.
- In `onClick()`, use the ordinary mihomo behavior: inactive starts, active stops, unavailable does nothing, unknown toggles.

**Step 3: Remove manifest service declaration**

In `AndroidManifest.xml`, remove only the `.services.ParazitXVpnService` `<service>` block at lines around 200 to 209. Keep `.services.DropwebVpnService`, `.services.DropwebService`, permissions, package identity, and foreground service declarations needed by ordinary VPN.

**Step 4: Delete native ParazitX files and relay binaries**

Delete the listed Kotlin files and `.so` relay binaries. Do not touch `libclash/`, `core/`, ordinary Dropweb service code, or Android package identity `app.dropweb`.

**Step 5: Build syntax check through analyze**

Run:

```bash
flutter_analyze
```

Expected: 0 errors. Kotlin compile errors may only appear during the full Android build in Task 8, so do not stop after analyze if Android files changed.

## Task 6: Localization and Copy Cleanup

**Files:**
- Modify: `lib/l10n/l10n.dart`.
- Modify: `lib/l10n/intl/messages_en.dart`.
- Modify: `lib/l10n/intl/messages_ru.dart`.
- Modify: `lib/l10n/intl/messages_ja.dart`.
- Modify: `lib/l10n/intl/messages_zh_CN.dart`.
- Inspect: `arb/` if present in this worktree.

**Step 1: Remove ParazitX and VK Calls strings from app localization**

Remove strings used only by deleted ParazitX/VK flows, including:
- `parazitx` label if it exists.
- VK cookie disclosure title/body.
- VK Calls stability mode copy.
- Captcha copy used only by `CaptchaScreen`.
- Send logs copy used only by `SendParazitXLogsItem`.

Do not remove generic app log strings, VPN strings, subscription strings, or cabinet strings.

**Step 2: Regenerate localization if this project expects generated files**

If `flutter gen-l10n` is configured and generated files are normally regenerated, run:

```bash
flutter gen-l10n
```

Expected: generated localization files no longer contain app-facing VK disclosure or ParazitX labels.

If this project maintains generated files manually, edit the generated files consistently and document that choice in executor notes.

**Step 3: Analyze after localization cleanup**

Run:

```bash
flutter_analyze
```

Expected: 0 errors.

## Task 7: Remove ParazitX Tests and Add Negative Acceptance Checks

**Files:**
- Delete: `test/services/parazitx_manifest_test.dart`.
- Delete: `test/services/parazitx_mihomo_orchestrator_test.dart`.
- Delete: `test/services/mihomo_dialer_proxy_patcher_test.dart`.
- Delete: `test/views/parazitx/vk_calls_status_view_test.dart`.
- Delete: `test/views/parazitx/primary_cta_test.dart`.
- Modify only if needed: existing cabinet or VPN tests.

**Step 1: Delete tests for deleted code**

Delete the ParazitX and bridge patcher test files listed above. These tests should not be kept as skipped tests because skipped Play-facing tests still imply shipped dormant behavior.

**Step 2: Run app-code reference acceptance checks**

Run:

```bash
grep -RInE 'ParazitX|parazitx|VkTunnel|vk_tunnel|vktunnel|app\.dropweb/parazitx|app\.dropweb/vktunnel|libparazitx|dropweb-parazitx|__dropweb_parazitx_vk_bridge' lib test android pubspec.yaml || true
```

Expected: no output.

Run:

```bash
grep -RInE 'VK Звонки|VK Calls|vkCookie|vk_cookie|captcha|CAPTCHA|send ParazitX logs|log uploader|log_uploader' lib test android pubspec.yaml || true
```

Expected: no ParazitX/VK tunnel output. Generic Windows constants like `VK_LBUTTON` in desktop tray code are allowed only outside Android Play-facing tunnel code. If a match is ordinary non-ParazitX code, document it in executor notes.

**Step 3: Confirm docs/history are the only retained ParazitX references**

Run:

```bash
grep -RInE 'ParazitX|parazitx|VK Calls|VK Звонки|libparazitx|dropweb-parazitx' docs CHANGELOG.md || true
```

Expected: references may remain only in historical docs, old plans, and changelog. Do not delete them in this implementation.

## Task 8: Full Verification

**Files:**
- Whole worktree.

**Step 1: Run analyzer**

Run:

```bash
flutter_analyze
```

Expected: 0 errors. Baseline warnings and infos are acceptable only if they existed before this removal.

**Step 2: Run full Flutter test suite**

Run:

```bash
flutter test
```

Expected: all remaining tests pass. No skipped ParazitX tests should remain.

**Step 3: Build Play-facing Android arm64 APK through project entry point**

Run:

```bash
dart run setup.dart android --arch arm64
```

Expected: build succeeds and writes the arm64 APK under `dist/`.

Env hints:
- Use the cleanup worktree as cwd: `/Users/oen/.config/superpowers/worktrees/dropweb-app/cleanup-code-garbage`.
- Build arm64 only for Pixel 10 iteration.
- If Android or Flutter cache state is corrupted, use the project Flutter workflow: `flutter_clean(deep=True)`, then `flutter_pub(action='get')`, then retry the same `dart run setup.dart android --arch arm64` command.
- Do not replace this with a universal APK build.

**Step 4: Final app-code acceptance greps**

Run:

```bash
grep -RInE 'ParazitX|parazitx|VkTunnel|vk_tunnel|vktunnel|app\.dropweb/parazitx|app\.dropweb/vktunnel|libparazitx|dropweb-parazitx|__dropweb_parazitx_vk_bridge' lib test android pubspec.yaml || true
```

Expected: no output.

Run:

```bash
grep -RInE 'VK Звонки|VK Calls|vkCookie|vk_cookie|captcha|CAPTCHA|send logs|log uploader|log_uploader' lib test android pubspec.yaml || true
```

Expected: no ParazitX/VK tunnel output. Any non-tunnel false positives must be explicitly justified in executor notes.

Run:

```bash
grep -RInE 'openCabinetBrowser|dropweb-cabinet|profileHasCabinetMarker|defaultCabinetUrl' lib test
```

Expected: browser-only cabinet references still exist. No native cabinet code was restored.

## Task 9: Documentation Note For The Removal

**Files:**
- Create: `docs/parazitx/README.md` if the directory remains and no README exists.
- Or modify: an existing cleanup note if the repository already has one.

**Step 1: Add a short removal note**

Write a concise note stating:
- ParazitX was physically removed from the Play-facing app code.
- The preserved branch is `wip/parazitx-quarantine-2026-05-17`.
- Historical docs remain for context only and do not describe shipped Play-facing behavior.
- Cabinet remains browser-only through `openCabinetBrowser(Uri)`.

Do not delete old docs in this task.

**Step 2: Run docs grep**

Run:

```bash
grep -RInE 'wip/parazitx-quarantine-2026-05-17|physically removed|openCabinetBrowser' docs/parazitx docs/plans/2026-05-21-parazitx-play-removal-implementation.md
```

Expected: the removal note and this plan both document preservation and browser-only cabinet.

## Non-Goals

- No feature flag for ParazitX.
- No hidden dormant ParazitX service.
- No native cabinet restoration.
- No Android package rename.
- No deletion of GPL/upstream attribution.
- No deletion of git branch `wip/parazitx-quarantine-2026-05-17`.
- No cleanup of historical docs beyond adding a clear removal note.

## Final Definition of Done

- `flutter_analyze` reports 0 errors.
- `flutter test` passes.
- `dart run setup.dart android --arch arm64` passes.
- Grep acceptance checks show no ParazitX/VK tunnel references in `lib/`, `test/`, `android/`, or `pubspec.yaml`.
- Historical references remain only in docs/history where intentionally retained.
- Normal Dropweb VPN/mihomo import, connect, status, and disconnect flow is preserved.
- Browser-only cabinet remains `SVG/кнопка → openCabinetBrowser(Uri)`.
- Android package identity remains `app.dropweb`.
