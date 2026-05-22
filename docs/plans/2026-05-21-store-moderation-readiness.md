# Dropweb Store Moderation Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare Dropweb for a Google Play submission candidate by reducing controllable rejection risk and making the product clearly distinct from its FlClashX origins.

**Architecture:** Treat Google Play readiness as the first release track. Fix policy blockers, privacy/security issues, fork fingerprints, consumer UX, release metadata, and reviewer evidence in gated phases. Apple is explicitly deferred to a later separate track because it needs organization, entitlement, and copycat review checks.

**Tech Stack:** Flutter/Dart, Android/Kotlin, Gradle, ARB localization, Google Play Console artifacts, GPL source disclosure.

---

## Non-guarantee and ethical boundary

100% moderation approval cannot be guaranteed. The goal is approval-readiness hardening, meaning honest compliance and reduced controllable rejection risk.

This plan separates legitimate compliance and product differentiation from prohibited moderation evasion. Do not hide VPN behavior from reviewers, detect reviewers, mislead policy forms, remove required GPL attribution, or make privacy claims that the code and network behavior don't support.

## Priority labels

- **BLOCKER:** Must be complete before any Google Play submission candidate.
- **HIGH:** Strong rejection or user-trust risk, should be complete before closed testing.
- **MEDIUM:** Important polish or risk reduction, can follow blockers but before production launch.
- **LOW:** Cleanup that improves maintainability or presentation, not a submission blocker.

## Phase 0. Branch/release hygiene before touching moderation work

### Code tasks

- [ ] **BLOCKER:** Work in the cleanup worktree only: `/Users/oen/.config/superpowers/worktrees/dropweb-app/cleanup-code-garbage`.
- [ ] **BLOCKER:** Confirm `.sisyphus/` planning artifacts are not staged or included in release packaging.
- [ ] **BLOCKER:** Create a release-readiness issue list from this plan before editing app code.
- [ ] **HIGH:** Keep Android package `app.dropweb` unchanged unless the owner explicitly accepts the signing, installs, store identity, and path blast radius.
- [ ] **HIGH:** Do not rename core internals such as `lib/common/constant.dart` `coreName` casually. Treat core-facing names as compatibility-sensitive until tested.

### Manual owner tasks

- [ ] **BLOCKER:** Choose Google Play as the first store track. Record Apple as a separate later track.
- [ ] **BLOCKER:** Assign owners for policy artifacts, store listing, demo video, legal review, release signing, and engineering.
- [ ] **HIGH:** Decide whether Android `clash://install-config` compatibility remains, is hidden behind advanced import, or is removed with migration notes.

### Acceptance gate

- [ ] No production code was changed before owners and scope were confirmed.
- [ ] `.sisyphus/` is excluded from commits and release archives.
- [ ] Google Play first is documented, Apple is not part of the immediate implementation scope.

## Phase 1. Google Play compliance blockers

### Code tasks

- [ ] **BLOCKER:** Add an in-app VPN disclosure and consent screen before first VPN start. Exact files to inspect and likely modify: `lib/views/dashboard/`, `lib/pages/`, `lib/providers/`, `lib/services/`, and Android VPN service calls under `android/app/src/main/kotlin/app/dropweb/`.
- [ ] **BLOCKER:** Add links to Privacy Policy, Terms, support, and open-source notices in About or Settings. Exact file: `lib/views/about.dart`.
- [ ] **HIGH:** Review Android permissions and service declarations. Exact file: `android/app/src/main/AndroidManifest.xml`.
- [ ] **HIGH:** Add explicit user-facing explanations for VPN connection, local VPN routing, diagnostics, and any optional account/cabinet integrations.

### Manual owner tasks

- [ ] **BLOCKER:** Publish a Privacy Policy URL before Play Console submission.
- [ ] **BLOCKER:** Complete Google Play Data Safety based on real behavior, including VPN, diagnostics, identifiers, logs, device data, and account/cabinet flows.
- [ ] **BLOCKER:** Complete Google Play VpnService declaration honestly. Include what the VPN does, why it is needed, and how the user controls it.
- [ ] **BLOCKER:** Prepare a short demo video for the VpnService declaration showing import/add connection, consent, connect, status, disconnect, and settings/privacy links.
- [ ] **HIGH:** Prepare reviewer notes that explain Dropweb as a consumer VPN client, not a stealth proxy, device abuse tool, or deceptive clone.
- [ ] **HIGH:** Map each sensitive permission to a user-visible feature and policy reason.

### Acceptance gate

- [ ] Privacy Policy URL, Data Safety draft, VpnService declaration draft, reviewer notes, and demo script exist.
- [ ] App has clear VPN disclosure and consent before VPN activation.
- [ ] No review evasion, hidden behavior, or misleading policy language is present.

## Phase 2. Privacy/security code blockers

### Code tasks

- [ ] **BLOCKER:** Remove or narrowly justify `QUERY_ALL_PACKAGES`. Exact file: `android/app/src/main/AndroidManifest.xml`. If retained, prove it is essential and prepare a Play declaration.
- [ ] **BLOCKER:** Remove, disable, or make explicit opt-in any VK cookie capture, storage, or transport. Exact files to inspect: embedded VK/captcha/cabinet flows under `lib/`, related services/providers, and any WebView/cookie handling code found during implementation.
- [ ] **BLOCKER:** Ensure diagnostics upload uses HTTPS only, explicit consent, visible destination, and sanitized payloads. Exact areas from audit: ParazitX log sending, diagnostic upload path, `log_buffer` handling.
- [ ] **HIGH:** Remove raw URL logging from `commonPrint` paths. Exact files to inspect: `lib/common/`, `lib/utils/`, and logging helpers.
- [ ] **HIGH:** Constrain `FilesProvider` exported behavior and file path handling. Exact Android files to inspect: `android/app/src/main/AndroidManifest.xml`, Android XML provider paths, and Kotlin file sharing handlers under `android/app/src/main/kotlin/app/dropweb/`.
- [ ] **MEDIUM:** Recheck `USE_FULL_SCREEN_INTENT` and remove it if no policy-safe, user-visible alarm/call use exists. Exact file: `android/app/src/main/AndroidManifest.xml`.
- [ ] **MEDIUM:** Recheck foreground service types, especially `systemExempted`, and align with real VPN behavior. Exact file: `android/app/src/main/AndroidManifest.xml`.
- [ ] **MEDIUM:** Make device headers and HWID behavior opt-in, or remove default-on behavior. Exact files from audit: `lib/models/profile.dart` `Profile.update()`, `lib/controller.dart`.
- [ ] **MEDIUM:** Review SendToTv local HTTP subscription URL sharing. Gate it behind advanced settings or remove from Play builds if not essential.

### Manual owner tasks

- [ ] **BLOCKER:** Update Privacy Policy and Data Safety after code changes, not before.
- [ ] **HIGH:** Document retained diagnostics fields, retention period, destination, and deletion/support process.
- [ ] **HIGH:** Decide whether cabinet/VK flows are needed for Play v1 or should be removed/deferred.

### Acceptance gate

- [ ] No high-risk personal data collection remains without clear purpose, consent, and disclosure.
- [ ] Diagnostics cannot send raw sensitive logs or HTTP payloads.
- [ ] Sensitive Android permissions are removed or justified with matching user-visible features.
- [ ] `flutter_analyze` reports 0 errors after code changes.

## Phase 3. Fork fingerprint and product copy cleanup

### Code tasks

- [ ] **HIGH:** Rewrite `lib/views/about.dart` so Dropweb is the main product. Move FlClashX, pluralplay, and chen08209 attribution into Open-source notices instead of making them the lead identity.
- [ ] **HIGH:** Rewrite `README.md` and `README_EN.md` opening sections to position Dropweb as a consumer VPN client while preserving GPL license and upstream attribution.
- [ ] **HIGH:** Replace user-facing Clash/ClashMeta copy in ARB files where it describes consumer features. Exact files: `arb/intl_en.arb`, `arb/intl_ru.arb`, `arb/intl_zh_CN.arb`, `arb/intl_ja.arb`.
- [ ] **HIGH:** Regenerate localization outputs after ARB edits. Exact generated area: `lib/l10n/`.
- [ ] **HIGH:** Rework macOS, Windows, and Linux schemes, keywords, and metadata that expose `flclash`, `clashx`, `clash`, or `clashmeta`, unless needed for compatibility and hidden from consumer copy.
- [ ] **MEDIUM:** Decide Android `clash://install-config` treatment and implement the chosen compatibility path.
- [ ] **LOW:** Leave technical references such as `pubspec.yaml` mihomo core, `.gitmodules` `core/Clash.Meta/xHomo`, and `lib/common/constant.dart` `coreName` alone unless a compatibility-safe migration is planned.

### Manual owner tasks

- [ ] **BLOCKER:** Prepare GPL/source disclosure for the exact submitted build, including source archive URL or public repository tag.
- [ ] **HIGH:** Prepare dependency/open-source notices for the app and store listing.
- [ ] **HIGH:** Approve product positioning language before engineering rewrites copy.

### Acceptance gate

- [ ] Store-facing and first-run surfaces identify the app as Dropweb, not FlClashX.
- [ ] GPL and upstream attribution remain available and truthful.
- [ ] Copy cleanup is differentiation, not concealment of license or origin.

## Phase 4. Consumer UX differentiation

### Code tasks

- [ ] **BLOCKER:** Preserve the minimum consumer path: import/add connection, connect/disconnect, status/subscription, support/cabinet.
- [ ] **HIGH:** Remove the hidden File Transfer easter egg from Play-facing builds.
- [ ] **HIGH:** Remove public Android in-app GitHub update check for Play builds. Updates should come through Play.
- [ ] **HIGH:** Remove normal ParazitX log sending or turn it into explicit, opt-in diagnostics with policy-safe copy.
- [ ] **HIGH:** Hide advanced surfaces behind an Advanced mode: Proxies/server lab, Config, DNS, Network, Logs, Resources/GeoData, Developer, Access Control/per-app proxy.
- [ ] **HIGH:** Rename consumer-facing labels: Profiles/Profile to Subscription or Connection, Proxies to Servers or Routes, Rules to Routing, TUN to VPN mode, Logcat to Diagnostics, Core to Engine, GeoData to Routing data, External Controller to Remote control.
- [ ] **HIGH:** Add profile labels to connection key and QR import flows so users understand what they added.
- [ ] **MEDIUM:** Replace raw proxy selector with a consumer region/server picker. Keep expert proxy controls only in Advanced mode.
- [ ] **MEDIUM:** Rewrite ParazitX copy to truthful consumer language if retained.

### Manual owner tasks

- [ ] **HIGH:** Approve the final consumer terminology list before string implementation.
- [ ] **HIGH:** Decide which advanced features stay in Play v1 and which are deferred.
- [ ] **MEDIUM:** Prepare support/cabinet instructions for reviewers and testers.

### Acceptance gate

- [ ] A non-technical reviewer can complete import, connect, verify status, disconnect, and find privacy/support links.
- [ ] Advanced proxy/client internals no longer dominate first-run or main navigation.
- [ ] Removed features are not replaced with hidden behavior.

## Phase 5. Release/signing/store asset package

### Code tasks

- [ ] **BLOCKER:** Prevent release signing from falling back to debug signing when keystore config is missing. Exact files to inspect: Android Gradle files under `android/`, signing config docs, `key.properties`, `local.properties` references.
- [ ] **HIGH:** Align version and minimum Android metadata. Exact files from audit: `pubspec.yaml`, `tool/release/latest.example.json`, Android Gradle files.
- [ ] **HIGH:** Add About links for privacy, terms, support, and source disclosure. Exact file: `lib/views/about.dart`.
- [ ] **MEDIUM:** Make app name consistency pass across Android manifest/resources, store copy, screenshots, and in-app surfaces.

### Manual owner tasks

- [ ] **BLOCKER:** Generate and securely store the release keystore. Do not commit secrets.
- [ ] **BLOCKER:** Produce a release source archive or public tag matching the submitted binary for GPL compliance.
- [ ] **BLOCKER:** Prepare store listing copy, short description, full description, screenshots, icon, feature graphic if needed, and support contact.
- [ ] **HIGH:** Prepare sensitive permission justifications and Data Safety evidence docs.
- [ ] **HIGH:** Update signing documentation so it consistently says where keystore data lives and how release builds fail closed.

### Acceptance gate

- [ ] Release build cannot silently use debug signing.
- [ ] Store assets and policy forms match app behavior and screenshots.
- [ ] GPL/source disclosure points to the exact submitted source state.

## Phase 6. Internal/closed testing and reviewer evidence

### Code tasks

- [ ] **BLOCKER:** Run `flutter_analyze` after implementation tasks and fix all errors. Existing warnings/infos can be triaged separately if they are baseline.
- [ ] **HIGH:** Build through the project release path, not raw `flutter build apk`. Use `dart run setup.dart android --arch arm64` or the `flutter_build` MCP when implementation starts.
- [ ] **HIGH:** Install and test the signed candidate on Pixel 10 arm64.
- [ ] **HIGH:** Verify no Play-facing flow depends on GitHub update checks, hidden easter eggs, or undeclared data collection.

### Manual owner tasks

- [ ] **BLOCKER:** Run internal testing with a clean install and a reviewer-like account/config.
- [ ] **BLOCKER:** Capture demo video evidence for VPN declaration.
- [ ] **HIGH:** Capture screenshots that match store listing claims.
- [ ] **HIGH:** Prepare reviewer notes with test account or test subscription instructions if needed.
- [ ] **HIGH:** Archive final evidence: Privacy Policy URL, Data Safety answers, VpnService declaration, demo video, screenshots, signed artifact hash, source archive URL, and support contact.

### Acceptance gate

- [ ] Clean install test passes: import/add connection, consent, connect, status, disconnect, privacy/support/source links.
- [ ] Reviewer notes are accurate and complete.
- [ ] Evidence package is ready before submitting to Google Play review.

## Phase 7. Apple later track

### Code tasks

- [ ] **LOW:** Do not start Apple implementation in this Google Play readiness pass.
- [ ] **LOW:** Keep Apple-specific code changes out of the immediate Play branch unless they are harmless shared cleanup.

### Manual owner tasks

- [ ] **HIGH:** After Google Play readiness, check Apple organization developer account needs, VPN entitlement requirements, and App Review 5.4 expectations.
- [ ] **HIGH:** Audit Apple copycat risk under App Review 4.1, minimum functionality under 4.2, spam under 4.3, and accurate metadata under 2.3.
- [ ] **MEDIUM:** Decide whether Apple needs a separate UX, entitlement, and legal plan.

### Acceptance gate

- [ ] Apple remains a separate track with no immediate implementation dependency.
- [ ] Google Play candidate is not delayed by Apple entitlement or organization work.

## Do Not Do

- [ ] Do not hide VPN behavior from users or reviewers.
- [ ] Do not detect reviewers, stores, devices, networks, or accounts to change behavior for moderation.
- [ ] Do not delete GPL license, upstream attribution, or required source disclosure. Move and de-emphasize consumer placement where appropriate, but keep it truthful and accessible.
- [ ] Do not make misleading privacy claims. Policy text must match real code, network calls, logs, diagnostics, and retention.
- [ ] Do not casually rename Android package `app.dropweb` or core compatibility identifiers without owner approval and migration/signing analysis.
- [ ] Do not keep hidden features as a workaround for policy concerns. Remove them, disclose them, or place legitimate expert tools behind Advanced mode.

## Definition of Done for Google Play submission candidate

- [ ] **BLOCKER:** Privacy Policy URL is published and linked in app/store listing.
- [ ] **BLOCKER:** Data Safety answers match the final app behavior.
- [ ] **BLOCKER:** VpnService declaration is complete with honest demo video and reviewer notes.
- [ ] **BLOCKER:** In-app VPN disclosure and consent appear before first VPN activation.
- [ ] **BLOCKER:** Release signing fails closed when keystore config is missing.
- [ ] **BLOCKER:** GPL/source disclosure points to the exact submitted source archive or tag.
- [ ] **BLOCKER:** `.sisyphus/` artifacts are not committed or packaged.
- [ ] **HIGH:** High-risk privacy/security issues from Phase 2 are fixed or explicitly removed from Play v1.
- [ ] **HIGH:** Store-facing copy, README lead, About page, screenshots, and main UX identify Dropweb as the product while preserving attribution.
- [ ] **HIGH:** Consumer path works on a clean install: import/add connection, consent, connect, status/subscription, disconnect, support/privacy/source links.
- [ ] **HIGH:** Advanced internals are hidden from the main consumer path or renamed with clear consumer language.
- [ ] **HIGH:** `flutter_analyze` reports 0 errors after implementation.
- [ ] **HIGH:** Signed internal/closed test candidate is installed and tested on Pixel 10 arm64.
- [ ] **MEDIUM:** Version, minimum Android, app name, support contact, screenshots, and store metadata are consistent.
- [ ] **LOW:** Apple follow-up plan is filed separately and not mixed into this Play submission candidate.
