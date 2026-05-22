# Google Play Readiness Issues

Google Play is the first store track for this readiness pass. Apple review, entitlement, and copycat checks are out of scope until a separate Apple plan exists.

Approval cannot be guaranteed. This list tracks honest compliance, release hygiene, and controllable rejection risk before a Google Play submission candidate.

## Blockers

- Publish a Privacy Policy URL before Play Console submission, then link it from the app and store listing.
- Complete Google Play Data Safety from the final app behavior, including VPN operation, diagnostics, identifiers, logs, device data, and account or cabinet flows.
- Complete the VpnService declaration honestly, including what the VPN does, why it is needed, how the user controls it, and a reviewer demo video.
- Add in-app VPN disclosure and explicit consent before first VPN activation.
- Make release signing fail closed when keystore config is missing. Release builds must not fall back to debug signing.
- Prepare GPL and source disclosure for the exact submitted build, through a source archive URL or public repository tag. Preserve upstream attribution and license notices.
- Keep `.sisyphus/` planning artifacts out of commits and release archives.

## High Risk

- Review `QUERY_ALL_PACKAGES`. Remove it if possible, or narrowly justify it with a matching Play declaration and user-visible reason.
- Remove, disable, or make explicit opt-in any VK or cookie capture, storage, or transport before Play v1.
- Ensure diagnostics and log upload use HTTPS only, explicit consent, visible destination, and sanitized payloads.
- Remove raw URL logging from common logging paths so sensitive subscription or profile URLs are not written to logs.
- Constrain `FilesProvider` exported behavior and file path handling to the minimum required sharing surface.
- Clean up advanced and fork-fingerprint UX in the Play-facing path. Dropweb should lead consumer surfaces while GPL attribution remains truthful and accessible.

## Manual Owner Tasks

- Assign owners for policy artifacts, store listing, demo video, legal review, release signing, engineering, and reviewer evidence.
- Approve Google Play as the first track and record Apple as a later, separate track.
- Decide whether `clash://install-config` compatibility stays, moves behind advanced import, or is removed with migration notes.
- Decide whether cabinet and VK flows are needed for Play v1 or should be removed or deferred.
- Approve final consumer terminology before string changes.
- Generate and securely store the release keystore. Do not commit secrets.
- Prepare support contact, store listing copy, screenshots, icon, feature graphic if needed, and sensitive permission justifications.

## Evidence Package

- Privacy Policy URL.
- Data Safety answers that match the submitted app.
- VpnService declaration text.
- Demo video showing import or add connection, consent, connect, status, disconnect, and settings or privacy links.
- Reviewer notes that explain Dropweb as a consumer VPN client, not a stealth proxy, abuse tool, or deceptive clone.
- Signed artifact hash.
- Source archive URL or public repository tag for the exact submitted build.
- Screenshots that match store listing claims.
- Support contact and deletion or support process for any retained diagnostics data.

## Out of Scope

- Apple submission work, Apple entitlements, Apple copycat review, and Apple store metadata.
- Android package identity changes. Keep the current package name `app.dropweb` unless the owner explicitly accepts the signing, install, store identity, and path blast radius.
- Production app code changes in Phase 0.
- Hiding VPN behavior, detecting reviewers, misleading policy forms, or keeping hidden behavior as a workaround for policy concerns.
- Removing GPL license text, upstream attribution, or required source disclosure.

## Implementation Notes

### VPN disclosure and consent gate (Phase 1 blocker)

Status: implemented in the cleanup worktree.

Layered enforcement — UI surface + central controller boundary:

- **Central guard (`AppController.updateStatus`)** is the source of truth. On any `updateStatus(true)` call it checks `vpnConsent.isAccepted()` first; if consent is missing it logs a refusal and returns without touching the VPN engine, status-bar icon, or proxy credentials. This applies to every entry point — Quick Settings tile, desktop tray, hotkey, deep links, auto-run — so no non-UI path can start the VPN before the disclosure has been accepted. The controller intentionally does not surface UI itself.
- **Dashboard StartButton** is the user-facing surface that actually shows the disclosure dialog. On the first start it (1) runs the consent gate, (2) on Continue persists the versioned flag, (3) only then plays the power-on haptic and sound and dispatches the central `updateStatus(true)` call. On Cancel it returns without any feedback, so no power-on tone or confirm haptic leaks before consent. Disconnect retains its original immediate feedback.
- **Versioned flag** `vpn_disclosure_accepted_v1` is stored in `SharedPreferences`. Future disclosure copy changes can require a fresh consent by bumping the version suffix without affecting earlier history.

Disclosure copy stays honest and moderation-safe: it names Dropweb, names the Android VPN permission, says traffic is routed per the user's selected connection or subscription, states the user can disconnect at any time, and notes that optional diagnostics, account, and cabinet features are disclosed separately. No "no logs", "anonymous", or "no tracking" claims.

Files involved:

- `lib/common/vpn_consent.dart` — versioned persistence helper (`isAccepted`, `markAccepted`, `reset`).
- `lib/controller.dart` (`AppController.updateStatus`) — central guard that refuses `isStart=true` until consent is persisted. Returns silently without UI from the controller.
- `lib/views/dashboard/widgets/start_button.dart` — runs the consent dialog before any feedback, marks consent on accept, then plays power-on cue and dispatches to the central controller path. Disconnect path unchanged.
- `lib/views/dashboard/widgets/vpn_disclosure_dialog.dart` — non-dismissible modal built on the existing `CommonDialog` flow.
- `arb/intl_en.arb`, `arb/intl_ru.arb`, `arb/intl_zh_CN.arb`, `arb/intl_ja.arb` and `lib/l10n/` — strings `vpnDisclosureTitle`, `vpnDisclosureBody`, `vpnDisclosureContinue`.

Verification:

- Unit tests: `test/common/vpn_consent_test.dart` covers fresh-install default, persistence, reset, key isolation, version key shape, and the explicit central-guard predicate the controller relies on (false on fresh install → refuse; true after `markAccepted` → allow). Direct unit testing of `AppController.updateStatus` is not feasible — it is tightly coupled to `globalState`, Riverpod refs, platform plugins, and the running mihomo core — so the predicate test pins the underlying invariant the central guard depends on.
- Full suite: `flutter test` passes (163 tests, no regressions).
- Static analysis: `flutter_analyze` reports 0 errors, 0 warnings; infos stay at the project baseline (613).

Alternate start paths:

- Quick Settings tile (`lib/manager/tile_manager.dart`), desktop tray (`lib/common/tray.dart`), hotkey (`lib/manager/hotkey_manager.dart`), and any other code path that calls `globalState.appController.updateStatus(true)` is centrally blocked at the controller until consent has been recorded. Since none of these surfaces own dialog presentation, they simply produce no-op start attempts until the user accepts the disclosure inside the dashboard. The Android system VPN consent dialog continues to gate connection establishment at the OS level as a second line of defence.

Deferred (not in this task):

- Privacy Policy and Terms links inside the disclosure body — pending real URLs.
- Surfacing a user-visible notification on alternate-path refusal — current behaviour is a debug log line; explicit "open the app and accept the disclosure" hint can be added when surfacing notifications without depending on UI from the controller.

### Removed `QUERY_ALL_PACKAGES` (Phase 2A high-risk)

Status: implemented in the cleanup worktree.

Decision: **removed** the broad `android.permission.QUERY_ALL_PACKAGES` permission from `android/app/src/main/AndroidManifest.xml`. No Play sensitive-permission declaration is required, which collapses the highest reviewer-risk surface in the manifest.

Replacement: narrowed package visibility via the existing `<queries>` block. The block now declares three intents:

- `MAIN` + `LAUNCHER` — installed-app enumeration used by per-app VPN access control (`AppPlugin.getPackages` → `PackageManager.getInstalledPackages`). Under Android 11+ package-visibility rules this scopes the visible set to packages that publish a launcher entry matching the declared intent; the exact set is whatever `PackageManager` returns on the device, and the app does not assume more than that.
- `VIEW` + `BROWSABLE` + `scheme=https` — browser handoff for the existing `clash://`/`dropweb://` import deep-link flow.
- `VIEW` + `mimeType=text/plain` — config-file viewer handoff. `AppPlugin.openFile` now both (a) attaches `FLAG_GRANT_READ_URI_PERMISSION | FLAG_GRANT_WRITE_URI_PERMISSION` to the `ACTION_VIEW` intent via `intent.addFlags(flags)` so any resolving viewer (including one picked through the system chooser) receives the FileProvider URI grant automatically, and (b) iterates `queryIntentActivities` to issue explicit per-package `grantUriPermission` calls up-front against the candidates this `<queries>` entry makes visible.

Graceful degradation already in place in the affected paths:

- `lib/views/access.dart` shows the `NullStatus(label: noData)` empty state when the package list is empty, so the access-control list never renders as a broken UI.
- `AppPlugin.getPackageIcon` (which calls `PackageManager.getApplicationIcon`) and `AppPlugin.isChinaPackage` (which calls `PackageManager.getPackageInfo`) both wrap their package-manager lookups in `try { ... } catch (_: Exception)` and return safe defaults (default icon / `false`), so non-visible packages do not crash icon or filter requests.
- Connection-log icon lookups in `lib/views/connection/item.dart` fall back to `Container()` when the icon future returns `null`.

VPN core surface unchanged: `BIND_VPN_SERVICE`, `VpnService` intent filter, foreground-service declarations, and helper services are untouched. Consumer flow (import → connect → status → disconnect) does not depend on package visibility.

Advanced "App Access Control" UI is unchanged in this task and still reachable from settings. Hiding it behind an Advanced-mode toggle is tracked separately in the Phase 4 plan; if executed before Play submission, the empty-state copy will be the only user-visible behaviour when no launcher apps match the queries on a stock device.

Files involved:

- `android/app/src/main/AndroidManifest.xml` — `<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />` removed; `<queries>` block documented and extended with the `text/plain` view intent.

Verification:

- Static analysis: `flutter_analyze` reports 0 errors, 0 warnings (infos stay at the project baseline of 613).
- Full test suite: `flutter test` passes (163 tests, no regressions).
- No Dart code changes required — Dart bridge already accepts an empty package list and degrades to the no-data UI.

Reviewer evidence still needed at submission time:

- Note in the Play submission that `QUERY_ALL_PACKAGES` is NOT requested; per-app VPN routing uses scoped `<queries>` visibility against `MAIN` + `LAUNCHER` intents, with the visible set governed by Android package-visibility rules rather than any stronger guarantee.
- Confirm during the VpnService demo video that the App Access Control screen renders correctly with the narrowed visibility (or is hidden behind Advanced mode by then).
- Use only freshly rebuilt artifacts for submission evidence. Do not treat stale generated `build/` manifests (e.g. `android/app/build/intermediates/.../AndroidManifest.xml` from earlier builds) as proof of current behavior; clean rebuild before capturing the merged-manifest artifact that accompanies the submission.

### Raw URL logging redaction (Phase 2 high-risk)

Status: implemented in the cleanup worktree.

Decision: **two layered central chokepoints** — `commonPrint.log` and `FileLogger.log`. Subscription tokens, userinfo, query, and fragment are stripped before they reach `debugPrint`, `fileLogger.log`, the in-app log buffer, or the on-disk log file, regardless of which entry point the caller used. Scheme, host, port, and path are preserved so logs stay debuggable; `?...` becomes `?[REDACTED]`, `user:pass@` becomes `[REDACTED]@`, `#...` becomes `#[REDACTED]`. URLs whose query carries a percent-encoded subscription URL (`clash://install-config?url=...`, `dropweb://install-config?url=...`) are sanitized as a single unit, so the inner token never escapes.

`redactUrls(...)` is **structurally idempotent**: a URL substring is short-circuited only when it matches the sanitizer's own output shape exactly (anchored regex covering scheme, optional `[REDACTED]@` userinfo, host, optional port, optional path, optional `?[REDACTED]` query, optional `#[REDACTED]` fragment). A loose `contains('[REDACTED]')` shortcut would be a bypass — an attacker can trivially stuff the marker into a query value (`?note=[REDACTED]&token=secret`) to skip sanitization. The strict-shape check lets `commonPrint.log → FileLogger.log` re-passes stay a no-op without opening that hole.

Files involved:

- `lib/common/log_redaction.dart` — new module with `redactUrls(String)`; matches `http(s)://`, `clash://`, `dropweb://` substrings and rewrites credentials/query/fragment via `Uri` parsing. Idempotent on already-redacted input.
- `lib/common/print.dart` — `CommonPrint.log` redacts the payload before forwarding to `debugPrint`, `fileLogger`, and `addLog`. Protects the debug console and the in-app log buffer that `addLog` feeds.
- `lib/common/file_logger.dart` — `FileLogger.log` redacts every queued message before it touches `_writeQueue`, so any caller that bypasses `commonPrint.log` still has URL credentials/query/fragment stripped before reaching disk.
- `lib/manager/clash_manager.dart` (`_ClashContainerState.onLog`) — mihomo core log payloads carry outbound URLs from proxy/provider activity. The handler now computes `redactedPayload = redactUrls(log.payload)` once and feeds it to **all three consumers**: the in-app log viewer via `logsProvider.notifier.addLog(log.copyWith(payload: redactedPayload))`, the file logger, and the error notifier fallback. `ErrorMapper.mapError(...)` is still run against the raw payload so the existing localized-error pattern matching keeps working; the unmapped fallback uses the redacted payload, never the raw one, so a user-facing notifier cannot surface a token.
- `lib/common/secure_profile_store.dart` — defensively wraps every `debugPrint(...)` of a caught `flutter_secure_storage` exception in `redactUrls(...)`, so even if a platform exception message ever echoes the stored URL back, it never reaches console output.
- `lib/common/common.dart` — exports the new `log_redaction.dart`.

Existing safe paths preserved:

- `lib/common/request.dart:68` continues to log only the redirect URL **length** (`'Subscription redirect followed (length=${newUrl.length})'`). Not regressed to raw URL logging.
- `lib/common/request.dart:142` (`checkForUpdate failed: $e`) is bare `debugPrint`; the exception text is a Dio error string that does not include the request URL by default. Left untouched to keep the diff minimal.

Other direct `debugPrint` sites audited:

- `lib/views/profiles/receive_profile_dialog.dart`, `lib/views/dashboard/dashboard.dart`, `lib/main.dart`, `lib/manager/tray_manager.dart` — emit only error messages, lifecycle markers, or tile callbacks; no URL substrings reach them.

Verification:

- Targeted unit tests: `test/common/log_redaction_test.dart` — **13 tests, all pass**. Cases cover the pure helper (`https://...?token=...`, `https://user:pass@...`, `clash://install-config?url=...` encoded subscription, `dropweb://install-config?url=...`, `#access_token=...` fragment, multiple URLs in one line, non-sensitive helper-port URL preserved, plain text untouched), the bypass regression for an attacker-controlled `?note=[REDACTED]&token=secret` decoy, structural idempotency on already-redacted input for both `https://` and `clash://` forms, and the direct `commonPrint.log` chokepoint emitting a `debugPrint`-clean payload.
- Static analysis: `flutter_analyze` reports **0 errors, 0 warnings** on the entire project (infos remain at the baseline of 600).

Reviewer evidence still needed at submission time:

- Capture a snippet of the on-device log file (`logs/dropweb_*.log`) during a subscription import flow to confirm zero raw tokens or userinfo appear in clear text.

### Diagnostics and log upload removed (Phase 2 high-risk)

Status: resolved by removal in the cleanup worktree.

Decision: **the diagnostics / log-upload path was removed**, not retained behind HTTPS + consent + sanitization. Carrying a moderation-bound upload surface into Play v1 is not worth the data-safety form, demo-video, payload-sanitization, and reviewer-evidence cost when no operational use case demands remote diagnostics today. Local logging remains on-device only and the user can still export logs via an explicit save-file action.

What was removed (deleted with the ParazitX teardown):

- `lib/services/log_uploader.dart` — the HTTP log uploader. Gone; `lib/services/` now only contains `crypto_service.dart`, `deep_link_handler.dart`, and `subscription_notification_service.dart`.
- `lib/services/log_buffer.dart` — the upload-side ring buffer that fed `log_uploader`. Gone.
- Native ParazitX log channels under `android/app/src/main/kotlin/app/dropweb/` — no `parazitx/logs` `MethodChannel`/`EventChannel` is registered in `MainActivity.kt`, `AppPlugin.kt`, `VpnPlugin.kt`, `ServicePlugin.kt`, `TilePlugin.kt`, `DropwebApplication.kt`, or `FilesProvider.kt`. Grepping `parazitx|log_upload|sendLog|uploadLog|diagnostic` across `android/app/src/main` returns zero matches in app code (only Android-framework XML namespace URIs).
- `pubspec.yaml` and `lib/` carry no crash-reporter or telemetry SDK (no `sentry`, `firebase_crashlytics`, `bugsnag`, `datadog`, `rollbar`, `analytics`). The single `analytics` hit is a comment in `lib/common/vpn_consent.dart` stating the helper has none.

What is retained, and why it is not a diagnostics upload:

- `logsProvider` (`lib/providers/generated/app.g.dart`, consumed by `lib/views/logs.dart` and `lib/controller.dart`) is an in-memory `FixedList<Log>` (cap 500) that backs the in-app log viewer. No network sink.
- `FileLogger` (`lib/common/file_logger.dart`) writes to a local on-disk log file. URL-redacted at the chokepoint (see Raw URL logging redaction section above). No network sink.
- `AppController.exportLogs()` (`lib/controller.dart:1869`) serializes `logsProvider` to UTF-8 and calls `picker.saveFile(...)` — user-initiated, system file-picker, fully local. No HTTP/Dio call, no remote destination.
- `lib/manager/clash_manager.dart` (`_ClashContainerState.onLog`) feeds mihomo core log payloads into `logsProvider`, `FileLogger`, and the error notifier — each consumer receives the URL-redacted payload. No network sink.

Outbound HTTP surfaces audited and confirmed non-diagnostic:

- `lib/common/request.dart` — only `http://$localhost:$helperPort/start|stop|ping` and `http://$defaultExternalController/...` calls (loopback helper + local mihomo controller). No log/diagnostic payload.
- `lib/pages/send_to_tv_page.dart` — user-explicit QR-scan flow that POSTs the **subscription URL the user is sharing** to a LAN TV `add-profile` endpoint. Not a diagnostics path; user initiates the scan and selects the target. Cabinet-adjacent, disclosed wherever cabinet/profile-sharing is disclosed.
- `lib/views/profiles/receive_profile_dialog.dart` — `router.post('/add-profile', ...)` is the inbound side of the same flow (this device acts as the LAN profile receiver), not outbound.

Acceptance grep evidence (run from `cleanup-code-garbage/`):

- `grep -R "log_uploader\|log_buffer\|LogBuffer\|sendLog\|uploadLog\|upload_log\|send_log" lib android/app/src/main test pubspec.yaml` → matches only `lib/views/logs.dart` and `lib/controller.dart` references to `logsProvider`, which is the in-memory in-app log buffer (not an upload). No `log_uploader`, `log_buffer`, `LogBuffer`, `sendLog`, `uploadLog`, `upload_log`, or `send_log` references remain in app code or tests.
- `grep -R "parazitx/logs\|parazitx" lib android/app/src/main test` → zero matches in app code, tests, or native code (matches only docs, plans, helper Rust source, and core `GeoSite.dat` strings, none of which are reachable from the running app).
- `grep -R "ParazitX\|Parazitx" lib android/app/src/main test` → zero matches in app code, tests, or native code (only docs and plans).
- `grep -R "sentry\|crashlytics\|bugsnag\|firebase_crashlytics\|datadog\|rollbar\|telemetry" pubspec.yaml lib` → zero matches (the only `analytics` hit is the "no network, no analytics" comment in `lib/common/vpn_consent.dart`).

No app-code changes were made by this verification task. Files inspected: `lib/services/`, `lib/views/logs.dart`, `lib/controller.dart`, `lib/manager/clash_manager.dart`, `lib/common/file_logger.dart`, `lib/common/request.dart`, `lib/pages/send_to_tv_page.dart`, `lib/views/profiles/receive_profile_dialog.dart`, `lib/providers/generated/app.g.dart`, `android/app/src/main/AndroidManifest.xml`, all Kotlin files under `android/app/src/main/kotlin/app/dropweb/`, `pubspec.yaml`, and `test/`. Because nothing in app code changed, `flutter_analyze` was not re-run for this task; the prior 0-errors / 0-warnings baseline from the Raw URL logging redaction section still holds.

Reviewer evidence still needed at submission time:

- Data Safety form: declare "No diagnostics data is collected or transmitted by the app." Local on-device logs only; the user can export them through the system file picker.
- VpnService declaration: do not list a diagnostics upload destination; there is none.
- The high-risk bullet "Ensure diagnostics and log upload use HTTPS only, explicit consent, visible destination, and sanitized payloads" is resolved because no diagnostics upload feature ships in Play v1. If a future feature reintroduces a remote diagnostics sink, the original four constraints (HTTPS-only, explicit consent, visible destination, sanitized payloads) must be reinstated before re-enabling it.

### `FilesProvider` SAF surface hardened (Phase 2 high-risk)

Status: implemented in the cleanup worktree.

Decision: **kept** the SAF `DocumentsProvider` so users can still browse exported configs and logs through the system documents UI, but the surface is now hardened to the minimum sharing footprint. Removing the provider entirely would silently break the "open in system file picker" UX without a corresponding moderation win, since the AndroidX `FileProvider` (`${applicationId}.fileProvider`) still serves the same files for the share/view intent in `AppPlugin.openFile`.

What changed in `android/app/src/main/kotlin/app/dropweb/FilesProvider.kt`:

- **Document IDs are now opaque, relative, and rooted at `Context.filesDir`.** Previously every cursor row exposed the absolute filesystem path via `Document.COLUMN_DOCUMENT_ID = file.absolutePath`, and `queryDocument` / `queryChildDocuments` / `openDocument` resolved caller-supplied IDs through `File(documentId)` with no sandboxing. A SAF client with `MANAGE_DOCUMENTS` (i.e. the system documents UI, or any future bound caller) could therefore request arbitrary absolute paths. The provider now uses a synthetic root id `"root"` and child IDs of the form `"configs"`, `"configs/foo.yaml"`, `"logs/dropweb_2026-05-21.log"` — strings that carry no filesystem-path semantics on their own.
- **Central `resolveFile(documentId)` gate.** Every caller-supplied id passes through one validator that (1) rejects empty / `ROOT_DOCUMENT_ID` / absolute / `..`-bearing strings up-front, (2) canonicalises `filesDir` and the candidate via `File.canonicalFile`, and (3) requires the canonical candidate path to equal one of the allowed-subdir roots or to start with `<root>/`. Symlink-escape attempts that survive the textual check are rejected at the canonical comparison. `queryDocument`, `queryChildDocuments`, and `openDocument` all funnel through this single gate; there is no remaining `File(documentId)` call site that bypasses it.
- **Allowed-subdirs set narrowed to `configs/` and `logs/`.** Kept intentionally in sync with the existing narrow `res/xml/file_paths.xml`, so the AndroidX `FileProvider` (used by `AppPlugin.openFile`) and the SAF `DocumentsProvider` cannot drift apart. `cache/shared/` is reachable via the AndroidX `FileProvider` for ad-hoc share intents but is deliberately not exposed through the SAF root — that surface only needs the long-lived user-visible exports.
- **Surface is now read-only.** `Document.FLAG_SUPPORTS_WRITE` and `Document.FLAG_SUPPORTS_DELETE` are no longer advertised (cursor rows now carry `COLUMN_FLAGS = 0`), and `openDocument` refuses any mode other than `"r"` by throwing `FileNotFoundException`. Previously `openDocument` accepted any mode via `ParcelFileDescriptor.parseMode(mode)`, which would have honoured write/append/truncate against arbitrary absolute paths. There is no current product feature that needs external write or delete through SAF; cabinet/profile import uses Dart `picker.saveFile(...)` directly, which is in-process and not affected.
- **Root listing limited to `configs/` and `logs/`.** Previously `queryChildDocuments("/")` returned `context.filesDir.listFiles()` — i.e. every directory in the app's private files dir, including any third-party plugin subfolder. The new root listing iterates only the allowed-subdirs set and includes a child row only when the directory actually exists, so empty installs render an empty list rather than leaking the structure of `filesDir`.
- **`includeFile` no longer leaks absolute paths.** The cursor now emits the opaque relative id passed in by the caller chain instead of `file.absolutePath`, so even read-only listings do not expose `/data/data/app.dropweb/files/...` strings to other apps.

Manifest and `file_paths.xml` were left unchanged because they already meet the constraint:

- `android/app/src/main/AndroidManifest.xml` keeps the SAF provider declared with `android:exported="true"`, `android:grantUriPermissions="true"`, `android:permission="android.permission.MANAGE_DOCUMENTS"`, `android:process=":background"`. Only the system holds `MANAGE_DOCUMENTS`, so only the system documents UI can bind to it; this is a permission-gated export, not a public surface.
- The AndroidX `FileProvider` declaration (`${applicationId}.fileProvider`) stays `android:exported="false"` with `android:grantUriPermissions="true"`, and `AppPlugin.openFile` continues to use it for `FileProvider.getUriForFile(...)` and explicit per-package `grantUriPermission` calls before `startActivity`. No code change was required for the `openFile` path.
- `android/app/src/main/res/xml/file_paths.xml` continues to expose only `files-path configs/`, `files-path logs/`, and `cache-path shared/`. Not broadened.

Files involved:

- `android/app/src/main/kotlin/app/dropweb/FilesProvider.kt` — replaced; see above.
- `android/app/src/main/AndroidManifest.xml` — unchanged.
- `android/app/src/main/res/xml/file_paths.xml` — unchanged.

Verification:

- Static analysis: `flutter_analyze` reports **0 errors, 0 warnings** on the entire project (infos remain at the baseline of 600).
- Release build evidence: parent ran `dart run setup.dart android --arch arm64` after the Kotlin hardening change. Gradle `assembleRelease` ended `BUILD SUCCESSFUL`, `build/app/outputs/flutter-apk/app-release.apk` was built, and `dist/dropweb.apk` was packaged.

Reviewer evidence still needed at submission time:

- During the VpnService demo capture, open the system documents UI / file picker and confirm the dropweb root is reachable but exposes only the `configs/` and `logs/` subdirectories, with no write or delete affordance.
- Confirm in the Play submission notes that the SAF surface is `MANAGE_DOCUMENTS`-gated (system-only callers), read-only, sandboxed to `Context.filesDir/configs` and `Context.filesDir/logs`, and validates every caller-supplied document id against canonical paths so external traversal/symlink escape is rejected.

### Android permissions and foreground-service declarations (Phase 2 high-risk)

Status: implemented in the cleanup worktree.

Decision: trim `AndroidManifest.xml` to permissions that are actually used by code or required by the declared foreground-service types, and clean up a stray `<property>` element whose semantics did not match the FGS type it was attached to. Removing unused sensitive permissions narrows the Data Safety surface, removes attack-surface lint at submission time, and pre-empts policy questions about permissions with no in-app justification.

What changed in `android/app/src/main/AndroidManifest.xml`:

- **`CHANGE_NETWORK_STATE` — removed.** Project-wide grep finds zero call sites for `setMobileDataEnabled`, `setWifiEnabled`, `ConnectivityManager.setNetworkPreference`, or any other API that requires this permission. `VpnPlugin` only observes network state through `ConnectivityManager.registerNetworkCallback(...)` (gated by `ACCESS_NETWORK_STATE`) and mutates only the tunnel's own underlying networks via `VpnService.setUnderlyingNetworks(...)`, which does not require `CHANGE_NETWORK_STATE`.
- **`RECEIVE_BOOT_COMPLETED` — removed.** No `<receiver>` declares the `android.intent.action.BOOT_COMPLETED` intent filter and no Kotlin handler implements boot-time reconnect. The only `autoStart` surface in the codebase (`lib/common/tray.dart`) is a desktop tray menu item for Windows / macOS / Linux launch agents, not Android boot. If always-on / boot reconnect is added later this permission must be reintroduced together with a real receiver and a Data Safety entry.
- **`WAKE_LOCK` — removed.** No `PowerManager.newWakeLock`, `acquireWakeLock`, or `PARTIAL_WAKE_LOCK` reference exists anywhere in the Kotlin sources. The lone historical mention is a `CHANGELOG.md` entry about the removed ParazitX service. The VPN tunnel itself is kept alive by `FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED` and the persistent ongoing notification, not by an explicit wake lock. If a future change needs to keep CPU awake during doze the permission must be reinstated together with the matching `PowerManager` acquisition.
- **`PROPERTY_SPECIAL_USE_FGS_SUBTYPE` removed from `DropwebService`.** That property is only meaningful for `foregroundServiceType="specialUse"`; on a `dataSync` service it was silently ignored and misled readers into thinking the service had a Play-reviewed special-use subtype. `DropwebService` keeps `foregroundServiceType="dataSync"`; the value reflected the actual binding (mihomo HTTP/SOCKS relay in non-VPN mode) without claiming special-use review.

Retained permissions and the user-visible reason for each:

- **`INTERNET`** — core network access for the mihomo proxy/tunnel engine.
- **`FOREGROUND_SERVICE`** — required umbrella permission for any `startForeground(...)` call on Android 9+.
- **`POST_NOTIFICATIONS`** — runtime-requested in `AppPlugin.requestNotificationPermission` so the persistent VPN status notification is visible on Android 13+. The notification carries a Stop action and a content intent back into the app; it is the user-visible kill switch for the VPN.
- **`ACCESS_NETWORK_STATE`** — read-only network observation in `VpnPlugin.registerNetworkCallback`, `ConnectivityManager.resolveDns`, and `NetworkRequest` with `NET_CAPABILITY_NOT_VPN` / `NET_CAPABILITY_INTERNET` / `NET_CAPABILITY_NOT_RESTRICTED`. Used to refresh DNS and the VPN's underlying network when Wi-Fi / cellular switches, so the tunnel does not stall after a connectivity change.
- **`FOREGROUND_SERVICE_DATA_SYNC`** — matches `DropwebService` `foregroundServiceType="dataSync"` for the non-VPN proxy mode (mihomo HTTP/SOCKS relay between local apps and remote servers).
- **`FOREGROUND_SERVICE_SYSTEM_EXEMPTED`** — matches `DropwebVpnService` `foregroundServiceType="systemExempted"`. Per Android documentation, an app whose service extends `VpnService` and is the device's active VPN qualifies for the `systemExempted` FGS type, which avoids the Android 14+ cumulative 6 h `dataSync` timeout (`ForegroundServiceDidNotStopInTimeException`) that would otherwise kill long-running VPN sessions. The runtime FGS type is selected in `BaseServiceInterface.startForeground` by `if (this is VpnService) FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED else FOREGROUND_SERVICE_TYPE_DATA_SYNC`, so the manifest and code agree.

Service-bind permissions (declared as `android:permission=` on the component, not as `<uses-permission>`) kept unchanged:

- **`BIND_VPN_SERVICE`** on `DropwebVpnService` — required by Android so only the system can bind the VPN service. Paired with the `android.net.VpnService` intent filter.
- **`BIND_QUICK_SETTINGS_TILE`** on `DropwebTileService` — required by Android so only the system Quick Settings host can bind the tile service.
- **`BIND_APPWIDGET`** on `DropwebWidgetProvider` — required by Android so only the system AppWidget service can deliver widget updates.
- **`MANAGE_DOCUMENTS`** on `FilesProvider` — system-only callers; covered by the SAF hardening note above.

Forbidden / previously-removed permissions confirmed absent in this pass: `QUERY_ALL_PACKAGES`, `USE_FULL_SCREEN_INTENT`, `SYSTEM_ALERT_WINDOW`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_*`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `PACKAGE_USAGE_STATS`.

Files involved:

- `android/app/src/main/AndroidManifest.xml` — three `<uses-permission>` lines removed (`CHANGE_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`); stray `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE">` element removed from `DropwebService`; retained-permission comments updated to point at concrete call sites.

Verification:

- Static analysis: parent ran `flutter_analyze`; it returned 0 errors / 0 warnings / 600 infos.
- Manifest XML validation: parent ran `xmllint --noout android/app/src/main/AndroidManifest.xml`; it completed with no output/errors.
- Release-path build: parent ran `dart run setup.dart android --arch arm64`; Gradle `assembleRelease` ended `BUILD SUCCESSFUL in 2m 9s`, `build/app/outputs/flutter-apk/app-release.apk` was built, and `dist/dropweb.apk` was packaged.
- Grep acceptance: `CHANGE_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, and `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` no longer appear as `<uses-permission>` / `<property>` declarations in the manifest (only as comment text explaining why they are absent).
- Retained `<uses-permission>` set is exactly: `INTERNET`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`.
- Service-bind permissions on components unchanged: `BIND_VPN_SERVICE`, `BIND_QUICK_SETTINGS_TILE`, `BIND_APPWIDGET`, `MANAGE_DOCUMENTS`.

Reviewer evidence still needed at submission time:

- Play Console **VpnService declaration** form: declare Dropweb as a consumer VPN client running an embedded mihomo core, with user-controlled start / stop through the dashboard, the Quick Settings tile, the home-screen widget, and the persistent notification's Stop action. Provide the demo video already required by the Phase 1 disclosure work.
- Play Console **Foreground Services** declaration: declare both FGS types in use.
  - `systemExempted` for `DropwebVpnService` — justify with "Android documents `systemExempted` as the correct FGS type for an app whose service extends `VpnService` and is the device's active VPN, replacing the Android 14+ `dataSync` 6 h cumulative timeout that would otherwise kill long-running VPN sessions."
  - `dataSync` for `DropwebService` — justify with "Non-VPN proxy mode: the embedded mihomo core relays user traffic between local apps and remote proxy servers over the network. The service stops when the user toggles the dashboard off."
- Data Safety form: confirm that no permission in the retained set implies background data collection. `ACCESS_NETWORK_STATE` is read-only network observation for reconnect handling; `POST_NOTIFICATIONS` is the user-visible VPN status notification; the FGS permissions only enable the matching foreground-service types. Diagnostics upload is not present (see the diagnostics removal note above).
- If always-on VPN, boot reconnect, or CPU wake-lock behavior is added later, the corresponding permission (`RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`) must be reintroduced together with a real receiver / `PowerManager` acquisition, and the Data Safety / FGS declarations updated to match.

### Release signing fail-closed (Phase 5 blocker)

Status: implemented in the cleanup worktree.

Decision: the release variant in `android/app/build.gradle.kts` no longer falls back to the debug signing key when the production keystore is missing. Instead, the signing config is attached only when every required input is present, and a Gradle task-graph guard aborts any release packaging task up-front with an actionable message when the production config is absent. Releases without the production keystore are no longer produced at all — they cannot accidentally be signed by debug, and they cannot accidentally be shipped unsigned.

What the build now requires for a real release build:

- `android/app/keystore.jks` (the production keystore file). The check uses `File.isFile`, so a directory of the same name does not satisfy it.
- The following keys in `android/local.properties` (same file Android already uses for SDK / NDK paths), each value **present and non-blank** (empty / whitespace-only values are treated as missing):
  - `storePassword=<store password>`
  - `keyAlias=<key alias>`
  - `keyPassword=<key password>`

When all four inputs are present (`mStoreFile.isFile` AND all three property values pass `!isNullOrBlank()`), `isRelease == true` and `signingConfigs.release` is created with those credentials. Otherwise `isRelease == false`, no release signing config is created, and the release build type does not assign `signingConfig` at all (no debug fallback). Blank-credential cases fail at the task-graph guard with the same actionable message as a fully-missing config, instead of failing mid-build with a cryptic apksigner error.

The guard is `gradle.taskGraph.whenReady { ... }`. It scans the resolved task graph for any of these task entry points under `:app:` — `assembleRelease`, `bundleRelease`, `installRelease`, `packageRelease`, `packageReleaseBundle`, `signReleaseApk`, `signReleaseBundle` — and, if any are scheduled while `isRelease == false`, throws `GradleException` with a message that names the required non-secret inputs (paths and property keys, not values). The guard ignores debug tasks, `tasks`, `help`, `dependencies`, IDE sync, `flutter analyze` / `dart analyze`, and unit-test paths, so day-to-day development is unaffected by the absence of a production keystore.

Files involved:

- `android/app/build.gradle.kts` — release build type no longer assigns `signingConfig = signingConfigs.getByName("debug")` when `isRelease` is false; `signingConfig` is only set when `isRelease` is true. New `gradle.taskGraph.whenReady` guard at the top level of the file aborts release packaging tasks when `isRelease` is false, naming the required inputs in the error message.
- `docs/release/direct-apk.md` — keystore and secret hygiene section corrected to reference the actual signing inputs (`android/app/keystore.jks` + `storePassword` / `keyAlias` / `keyPassword` in `android/local.properties`), and the hard-gate language updated to reflect the new fail-closed behavior (release tasks abort instead of silently signing with debug).
- `tool/release/build_direct_apk.sh` — operator preconditions header updated to reference the actual signing inputs and the new fail-closed behavior. No script logic changes; the script remains a thin wrapper around `dart run setup.dart android --arch arm64`.

Verification (run from `cleanup-code-garbage/`):

- Static analysis: `flutter_analyze` reports **0 errors, 0 warnings**, infos stay at the project baseline (600). No new infos introduced by this change.
- Fail-closed evidence with no production keystore present (current worktree state — `android/app/keystore.jks` does not exist, no signing keys in `android/local.properties`):
  - `JAVA_HOME=<jdk17> ./gradlew :app:assembleRelease --no-daemon` (run from `android/`) **aborts at the task-graph guard** with `FAILURE: Build failed with an exception.` and the message `Release signing configuration is missing. Refusing to run: :app:packageRelease, :app:assembleRelease`. The follow-up text names the required non-secret inputs (`Production keystore at: android/app/keystore.jks` and `storePassword` / `keyAlias` / `keyPassword` keys in `android/local.properties`). No APK is produced and the debug key is not consulted. `BUILD FAILED in 15s`.
  - `JAVA_HOME=<jdk17> ./gradlew :app:bundleRelease --no-daemon` aborts at the same guard with `Refusing to run: :app:packageReleaseBundle, :app:signReleaseBundle, :app:bundleRelease` — the guard correctly catches the bundle path (including the standalone `signReleaseBundle` task).
- Non-release tasks unaffected by the absence of a production keystore:
  - `JAVA_HOME=<jdk17> ./gradlew :app:help --no-daemon` completes with `BUILD SUCCESSFUL`.
  - `JAVA_HOME=<jdk17> ./gradlew :app:assembleDebug --dry-run --no-daemon` completes with `BUILD SUCCESSFUL` — the debug task graph is resolved without the guard firing. Debug builds remain runnable without the production keystore present; the guard only matches the release entry-point set above.
- JDK note: the guard itself is JDK-version-agnostic; the `JAVA_HOME` override above is only used because Gradle 8.11.1 + Kotlin DSL on this host's default JDK (`openjdk 25.0.2`) fails to parse the JVM version string before it ever reaches the app build script. Project Java/Kotlin target is 17 (`JavaVersion.VERSION_17` in `android/app/build.gradle.kts`); operators should already have JDK 17 on `JAVA_HOME` for any normal Android build.

When the production keystore is later provisioned (operator step — keep secrets out of git and CI logs), `isRelease` becomes true automatically and the release variant uses `signingConfigs.release`. No further Gradle changes are needed at that point.

Reviewer evidence still needed at submission time:

- During the final pre-submission build, capture the certificate SHA-256 of the signed release APK / AAB (`apksigner verify --print-certs <artifact>` → `Signer #1 certificate SHA-256 digest`) and confirm it matches the production fingerprint recorded in `docs/release/direct-apk.md` (or its equivalent for the Play track). Any release artifact whose certificate SHA-256 does not match must be treated as a regression and not submitted.

### Android GitHub update checks hidden and blocked for Play

Status: implemented in the cleanup worktree.

Decision: Android Play builds no longer expose or run the GitHub-driven app update path. Google Play updates must go through Play, so the manual About-page check, Android auto-check setting, and Android automatic check path are all gated off. Desktop keeps the existing behavior.

What changed:

- `lib/views/about.dart` uses `shouldShowCheckForUpdate({required bool isAndroid}) => !isAndroid` and hides the manual "Check for updates" row on Android.
- `lib/controller.dart` uses `shouldRunAutoUpdateCheck({required bool isAndroid, required bool autoCheckUpdate})` so Android returns `false` even if the persisted setting was enabled earlier or changed by subscription headers.
- `lib/views/application_setting.dart` hides `AutoCheckUpdateItem()` on Android so the Play-facing UI does not show a no-op update preference.

What stays in scope for normal app operation:

- Subscription/profile updates, GeoData, rule-provider updates, and mihomo core behavior are unchanged.
- `request.checkForUpdate()` stays available for non-Android platforms.

Verification:

- Targeted update-check tests: `flutter test test/views/about_check_update_test.dart test/common/should_run_auto_update_check_test.dart test/common/should_handle_update_result_test.dart` passed 10/10.
- Later full-suite checks in this readiness pass passed 102/102 and then 104/104 after the Send to TV gate landed.
- Static analysis in the same pass reported 0 errors / 0 warnings.
- Pixel 10 UI check confirmed the Android About page no longer shows `Проверить обновления`.

Reviewer evidence still needed at submission time:

- Reviewer notes should not describe any Android in-app updater. App updates for the Play artifact are through Google Play only.

### Hidden File Transfer easter egg removed

Status: implemented in the cleanup worktree.

Decision: removed the hidden Dashboard rapid-tap "File Transfer" game from the Play-facing app. A hidden route with contributor-card dragging, fake kernel-panic styling, and a forced-exit ending is unnecessary in a VPN client and would be hard to explain to reviewers.

What changed:

- `lib/views/about.dart` no longer contains `_FileTransferGame`, `_KinvshGlitchScreen`, `startFileTransferGame`, or the supporting painter / draggable classes.
- `lib/pages/home.dart` no longer tracks Dashboard easter-egg tap counts and no longer launches the hidden route from navigation taps.
- About-page product information, GPL-3.0 attribution, upstream FlClashX link, mihomo link, project link, gratitude sheet, and visible author-credit affordances remain intact.

Verification:

- Grep acceptance in the implementation pass found no remaining app-code references for `File Transfer`, `_eggTap`, `FileTransferGame`, `startFileTransferGame`, or the hidden-game helper classes.
- Existing update-check test coverage still passed after removal.
- Static analysis in the same pass reported 0 errors / 0 warnings.
- Pixel 10 UI check confirmed rapid Dashboard taps no longer open File Transfer.

Reviewer evidence still needed at submission time:

- No reviewer-facing claim is needed for this removed easter egg. Keep GPL and upstream attribution visible and truthful, as already required above.

### Android Send to TV / LAN subscription-sharing visibility gate

Status: implemented in the cleanup worktree.

Decision: Android Play builds no longer expose the Send to TV / LAN subscription-sharing entry points. The flow shares the selected subscription URL over local HTTP to a QR-scanned LAN endpoint, which is not essential for Play v1 and adds policy explanation cost. Non-Android surfaces keep the existing user-explicit flow.

What changed:

- `lib/common/send_to_tv_visibility.dart` adds `shouldShowSendToTv({required bool isAndroid}) => !isAndroid`.
- `lib/views/tools.dart` no longer exposes the Android settings entry for `Подключить ТВ`.
- `lib/views/profiles/profiles.dart` gates the per-profile popup `sendToTv` action with `shouldShowSendToTv(isAndroid: Platform.isAndroid)`, so Android hides `Отправить на ТВ` while iOS keeps it.

What stays in place:

- `lib/pages/send_to_tv_page.dart` is retained for non-Android callers.
- `lib/views/profiles/receive_profile_dialog.dart` and its inbound LAN `add-profile` route are unchanged.
- Profile import/update, QR scanning for normal profile import, VPN consent, and VPN connect/disconnect behavior are unchanged.

Verification:

- TDD helper test `test/common/should_show_send_to_tv_test.dart` was written red first, failed on the missing helper, then passed after implementation.
- Targeted Play-gate tests passed 8/8 for Send to TV plus existing Android update-check gates.
- Later full-suite checks in this readiness pass passed 102/102 and then 104/104 after the Send to TV gate landed.
- Static analysis in the same pass reported 0 errors / 0 warnings.
- Pixel 10 UI checks confirmed no `Подключить ТВ` in Settings and no `Отправить на ТВ` in the Android profile popup.

Reviewer evidence still needed at submission time:

- Data Safety and reviewer notes can state that Android Play v1 does not expose the Send to TV / LAN subscription-sharing flow.

### HWID and device headers retained by owner decision

Status: intentionally retained in current app behavior.

Decision: the owner explicitly rejected removing HWID/device headers or defaulting them off in this pass. The existing `sendDeviceHeaders`, `x-hwid`, and `DeviceInfoService` behavior is retained. Do not document this as removed, disabled, or deferred behind a default-off switch.

Policy consequence:

- Privacy Policy, Data Safety, and reviewer notes must document and justify any retained HWID/device-header behavior if it is present in the submitted artifact.
- This remains an owner/release blocker for final policy writing. It is not solved by the Play-facing removals above.

Verification:

- Implementation tasks for the update-check removal, File Transfer removal, and Send to TV Android visibility gate explicitly left HWID/device-header code untouched.
- Current code still contains the relevant identifiers (`sendDeviceHeaders`, `x-hwid`, `DeviceInfoService`) by owner decision.

Reviewer evidence still needed at submission time:

- Explain when device headers are sent, what fields are included, why they are needed, whether they identify a device across subscriptions or accounts, how users are informed, and how this maps to Data Safety. Do not claim Google Play approval is guaranteed.
