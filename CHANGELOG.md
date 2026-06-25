## v0.8.3

- feat(update): in-app auto-update for sideloaded Android

- True in-app updater for the non-Play Android build: fetches the manifest
- (tunnel-aware via the proxy when the core is running, direct otherwise),
- downloads the APK (YC primary -> GitHub fallback), verifies it (sha256
- corruption check + MANDATORY fail-closed signing-cert pin), and launches the
- system installer. Gated behind kIsPlayBuild so the Play AAB stays inert.

- - Lumina update sheet + existing Settings entry with available-indicator
- - startup auto-check (default ON) + manual check; once/24h cadence
- - native installApk/canInstallUnknownApps/verifyApkSignature + Dart wrappers
- - CI build.yaml emits per-platform sha256 into update.json
- - ru/en l10n; bump 0.8.3+2026062612

- Validated end-to-end on Pixel 10: 0.8.1 -> 0.8.2 self-update via download +
- sha256 + fail-closed pin + system install.

## v0.8.2-pre.10

- fix(ui): connect button can't vanish / brick the UI on a stalled boot start

- StartButton: stop collapsing to SizedBox.shrink on !isInit; show the existing dimmed/disabled pending affordance instead, so the power glyph stays visible until core init completes (matches canonical FlClash, which gates only on hasProfile). The old gate left only the glass lens (empty circle) when init stalled.

- controller.init(): guard _initCore() and _initStatus() (25s timeout) so a throwing/hung boot auto-start can no longer abort init() before initProvider=true — the root cause of the 'empty circle, dead until force-kill' report.

- clash/interface: bound startListener() with a 10s timeout (was the 30s safeFuture default) so the start path fails fast.

## v0.8.2-pre.9

- fix(windows): clean install removes orphaned binaries/services/autostart from prior builds

- Inno copied new files but never removed orphans, so every past (incl. FlClash-branded) build's binaries/services/autostart piled up in the install dir and fought over the global helper port / TUN / system proxy.

- Tier 1 (safe, preserves user data): [InstallDelete] {app}\* empties the install dir before [Files] copy; expand process kill-list to FlClash/Koala lineage; CurStepChanged(ssInstall) stops service + kills processes + CleanLineageLeftovers (delete stale services/Run-key/scheduled-tasks gated to those whose path is inside our {app}, so a separately installed real FlClashX is never touched).

- Tier 2 (opt-in): prompt to delete legacy-identity data (%APPDATA%\com.follow\clashx); current dropweb\dropweb profiles/settings preserved. Skipped on silent installs.

## v0.8.2-pre.8

- ci: free disk space on the android job to stop the no-space build flake

- The android matrix entry has no --arch, so it builds a UNIVERSAL APK (arm64 + armeabi-v7a + x86_64) plus the embedded Go core - 3x the native .so payload. On a cold Gradle cache that exhausts the ~14 GB ubuntu runner mid :app:mergeReleaseNativeLibs ('No space left on device'), which is what failed the v0.8.2-pre.7 build (it only passed on a warm-cache re-run). Reclaim ~15-20 GB from preinstalled toolchains we never use (.NET, GHC/ghcup, Swift, CodeQL, docker images) BEFORE the build, while deliberately keeping the Android SDK/NDK, Go and Flutter the build needs.

## v0.8.2-pre.7

- ci(windows): add clean-install integration test (no FlClashX)

- Baseline counterpart to windows-conflict-test: on a pristine windows-latest runner (no FlClashX) install the latest dropweb pre-release and assert it (1) installs with the full footprint, (2) its helper binds its OWN port 47896 — the clean-box proof of the 3ad5cd4 fix, mirroring the conflict test that proves it FAILS to bind when FlClashX squats 47890, and (3) boots without leaving a loadingRun started-but-never-done (the e374d08 stuck-dashboard regression), asserted from the app boot log since headless CI can't see the UI. Fails on positive evidence of the stuck-UI bug; warns (not fails) if the app simply doesn't init in headless CI, so it catches regressions without flaking. Boot logs upload as an artifact for inspection.

- ci: fail the build when dist/ is empty so a no-artifact build can't pass green

- setup.dart can exit 0 yet produce no artifact (e.g. an MSVC hard-error in a plugin, a missing packaging tool), and upload-artifact happily uploads nothing — the exact 'green job, empty dist' failure that shipped empty windows pre-releases. Assert dist/ is non-empty right after Setup so a broken build fails loudly instead of masquerading as a successful release.

- fix(ui): widen the loadingRun backstop to 5 min so it can't fire mid-setup

- The 60s loadingRun net was SHORTER than the core ops it wraps: setupConfig/updateConfig are bounded at 120s each (clash/interface.dart), and a composite applyProfile (wait-for-geo-lock + setupConfig + group/provider refresh) can legitimately run past a minute. So the 60s net fired SPURIOUSLY mid-setup — showing an error while the inner core call kept running underneath (risking a double-apply). Every async path reachable from loadingRun is already bounded at the source (invoke/safeFuture 30s default, helper HTTP .timeout(), bounded geo-lock actions), so this is a pure catastrophic backstop now: 5 min exceeds any legitimate composite duration and only trips on a genuine wedge.

## v0.8.2-pre.6

- fix(ui): bound loadingRun with a 60s timeout so a hung op can't freeze the screen

- Clean-Windows logs (no FlClashX) showed the core+helper handshake working, yet the dashboard was stuck behind the top progress bar with the add button unusable. loadingRun() awaited its future with NO timeout, so a future that never returns left _loading=true forever (spinning bar) and the screen unusable. Bound it to 60s — a hang now surfaces an error and recovers. Also: skip the 20s updateGroups poll when no profile is selected (it only logged 'unknown error' against an empty core), and log [loadingRun] start/done/timeout so the next capture names the exact stuck operation.

## v0.8.2-pre.5

- fix(macos): auto-open the status-bar popover on launch

- macOS build is a menu-bar app; applicationDidFinishLaunching closes the main window, so after install/launch nothing is visible until the user clicks the tray icon. Open the popover once on launch, deferred + NSApp.activate so the transient popover is not auto-dismissed.

- fix(windows): move dropweb helper service to its own port 47896 (was 47890, shared with FlClashX)

- FlClashX's Windows helper also binds 127.0.0.1:47890 (verified in pluralplay/FlClashX constant.dart + hub.rs). The CI integration test proved the runtime clash on a real x64 runner: with both helpers on 47890, whichever starts last takes the port and the other's service goes Stopped. Moving dropweb's helper to 47896 (hub.rs LISTEN_PORT + constant.dart helperPort) lets both coexist; pairs with the identity-checked helper-conflict resolution already in 31a4963.

- ci(windows): add runtime job — FlClashX running first, then install dropweb

- Installs FlClashX, registers+starts its helper service (binds 47890) and launches the app, THEN installs dropweb and starts its helper. With pre.4 (both helpers on 47890) this isolates the runtime helper-port clash: dropweb's helper is expected to fail to bind while FlClashX holds 47890. Informational (does not fail the build).

- ci(windows): fix conflict test — registry-based inspection, no slow full-recurse

- Get-ChildItem -Recurse over all of Program Files hung the baseline step on the loaded windows-latest runner. Switch to targeted dir checks + authoritative registry InstallLocation; verdict reads dropweb's uninstall key InstallLocation and flags if it sits inside the FlClashX folder.

- ci(windows): add FlClashX coexistence integration test

- Native x64 GitHub Actions job (public repo = free runners) that installs FlClashX + current dropweb on a clean windows-latest runner and inspects install paths, uninstall registry keys ({728B} vs {6997}), helper services and ports after each step. Proves whether the two apps' installers/footprints actually collide (the 'FlClashX installer detects dropweb' report) on real x64 Windows — no local ARM VM needed. Fails if current dropweb lands in FlClashX's install folder.

## v0.8.2-pre.4

- fix(app): robust launch + FlClashX conflict resolution; declutter settings & onboarding

- - clash/interface: timeout init/isInit/setState so a stalled core handshake cannot hang AppController.init() and brick the UI
- - controller: surface the window/macOS popover before _initCore() — fixes the desktop app starting hidden in the tray
- - common/windows + request: identity-checked helper-port 47890 conflict resolution (do not drive a foreign helper; free a stale/foreign holder by detected PID); core-bridge diagnostics; fix isStarting leak on the helper path
- - onboarding: remove the dead first-run tap-to-add hint + onboarding_state.dart
- - settings: lift check-for-updates + support-project into Settings/Other; drop the More grouping in About
- - tools: hide the Windows-only loopback entry from the desktop UI

## v0.8.2

- fix(modes): temporarily remove the Smart («Умный») mode card

- Hide «Умный» from the work-mode list for now (to be reintroduced later); the WorkMode.smart code path (work_mode_patch / detectPrimaryRouter / controller) stays intact. Also drops the now-unused _ModeCard.enabled param it was the only caller of.

- fix(theme): apply the current profile's theme on startup

- The subscription theme was only (re)applied on a profile switch/update, so a fresh launch kept the last-applied theme — possibly a DIFFERENT provider's colors — until the user switched or updated a profile. init() now calls applyCurrentProfileThemeOnStartup(), mirroring handleChangeProfile's reset-then-apply (a profile without a dropweb-theme header reverts to the dropweb default).

- fix(profiles): remove the traffic usage bar from profile cards

- Same as the dashboard card: drop the LinearProgressIndicator (and its progress/color computation) under the «Трафик used / total» line in each profile card; keep the textual usage.

- fix(dashboard): remove the traffic usage bar from the subscription card

- Drop the LinearProgressIndicator (and its progress/color computation) under the «Трафик used / total» line on the dashboard subscription card; keep the textual usage. Cleaner card, no thin bar bisecting the logo.

## v0.8.2-pre.3

- fix(ci): unblock windows build — silence MSVC experimental-coroutine deprecation

- GitHub's windows-latest runner moved to VS18 / MSVC 14.51, which turns the <experimental/coroutine> deprecation into hard error C2338 (STL1011). flutter_inappwebview_windows still includes that header, so the whole windows C++ build failed to compile and dist/ ended up empty (job green, no .exe/.zip). Define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS dir-wide (like the UNICODE defines) so it reaches the plugin subprojects.

## v0.8.2-pre.2

- fix(ci): restore windows/EnableLoopback.exe so the windows build produces artifacts

- An over-broad *.exe ignore rule plus the untrack chore (d4ca6be) dropped windows/EnableLoopback.exe — a bundled Windows runtime tool that windows/CMakeLists.txt installs into the app bundle and tools.dart invokes at runtime. On a fresh CI checkout it was absent, so the windows job went green but produced no .exe/.zip. Re-track it with a !windows/EnableLoopback.exe negation.

## v0.8.2-pre.1

- chore(release): 0.8.2+2026062611

- fix(ci): build a real universal APK and publish it as android-universal

- The android job only emitted split-per-abi APKs, so the update.json android-universal slot aliased the arm64 APK (uninstallable on 32-bit/x86). setup.dart now also builds a single all-ABI universal APK (dist/dropweb-universal.apk) when no --arch is given, and the YC publish step uploads it and points android-universal at it.

- feat(modes): bind Smart to the primary MATCH router only + Smart chevron

- Add detectPrimaryRouter() (the catch-all MATCH target, name-agnostic) and bind the additive 'Умный' group + selectedMap into that one router instead of every rule-referenced group, so per-service groups keep the template's own routing. Also give the Умный card the same «Серверы и группы» chevron as Стандарт.

- fix(ui): notification card uses the 26 system radius

- The MessageManager snackbar card was hardcoded to Radius.circular(12); switch it to Lumina.radiusLg (26) so it matches every other card and drops a hardcoded-radius design-lint violation.

- fix(modes): stop the "restart VPN" tip firing on a profile switch

- syncNetworkSettingsFromProvider writes the provider's tun.stack back into patchClashConfigProvider on every setup, churning vpnStateProvider — so switching profile (egress applies live) wrongly raised the restart tip. Guard it with globalState.suppressVpnTip around setupClashConfig; manual TUN/vpnProps changes still warn via _updateClashConfig.

- feat(profiles): show the service name + logo on profile cards

- Reuse SubscriptionCardLogo (now header-parametrized) and a new Profile.serviceName getter (profile-title -> dropweb-servicename -> label) so each profile card shows the branded name + accent bleed-off logo instead of the raw user_xxx label, with the user id kept as a muted secondary line.

- feat(modes): country picker — liveness-filtered list + canonical load UX

- Filter xray "crutch" nodes (АВТО/auto-selectors, balancer pseudo-hosts, DPI
- decoys, expiry/HWID sentinels) generically — they have no static fingerprint
- (ss-vs-vless, decoy-vs-real share identical crypto, flags reused), so liveness
- is the only provider-agnostic signal. No name/flag hardcode.

- - work_mode_patch: structural sentinel prefilter (_isRoutableProxy) drops
-   0.0.0.0 / port<=1 / all-zero-uuid placeholders from the picker AND Smart group
- - picker shows only probe-confirmed-alive nodes (n/a in mihomo = unusable)

- Canonical load UX (no incremental reflow / jerk):
- - skeleton -> crossfade -> settled stable list; _lastAlive cache so a re-ping
-   never flickers; staggered fade+slide row reveal; Lumina shimmer badges
- - probe awaits full completion (cold REALITY/gRPC handshakes captured on first
-   open) + waits for core groups after a profile switch
- - auto-ping on open + pull-to-refresh

- feat(dashboard): provider logo on the sub card — accent-keyed corner bleed, feathered, fades in

- feat(connect): living glass button — aurora core + holo rim on theme orbs

- Connected look is driven by the theme orb trio (accent + orbColorPrimary +
- orbColorSecondary): an aurora mesh core + iridescent holo rim, so it follows
- presets and custom orbs. Dark orbs are normalised (near-black -> accent,
- merely-dark -> HSL lightness floor) to stay readable on the dark glass.

- Glyph gets a Fresnel 'rim внутри' (ShaderMask + SweepGradient over HugeIcon).

- States: dormant / connecting (fast spin + halo pulse + iris bloom) / connected
- (one settle spin, then freeze). No perpetual repaint while connected (controllers
- stop -> battery/thermal-safe on mid-range); reduced-motion respected.

- chore(repo): untrack tool/ (local-only dev/release scripts)

- chore(repo): add ignore patterns for untracked AI/tooling/tests

- chore(repo): untrack local-only AI/tooling, tool experiments, and tests

- Move AGENTS.md, DESIGN.md, dev-only tool/ experiments, and test/ out of
- git tracking (kept on disk) and add them to .gitignore so they stop
- showing up. Also drop already-ignored .vscode/settings.json and
- EnableLoopback.exe from the index.

- docs(readme): bake the logo lockup (mark + wordmark) as the title

- GitHub strips the CSS the site uses to flex-center the mark, so an inline image always sat off-baseline. Render the db mark + Onest wordmark into one image (same layout as the site), theme-aware via <picture> (white on dark, dark on light). Verified on both themes.

- docs(readme): plain title, remove the inline logo mark

- The pixel db mark clashed with the smooth wordmark and sat off inline. The header banner already carries the logo; keep the title as plain text.

- docs(readme): vertically center and size the title logo mark

- Was baseline-aligned and small (looked off). Set the db mark to height=36 align=middle so it centers with the dropweb wordmark; verified against a GitHub-accurate h1 render.

- docs(readme): restore header banner, add db logo mark beside title

- Keep header.png as the hero banner. Add a theme-aware db mark next to the title via <picture>: logo-mark.png (white) on dark, logo.png (tile) as the light-theme fallback.

- docs(readme): use logo as header, drop platforms/build sections

- Replace the retro banner with the centered db logo (assets/images/logo.png, copied from dropweb-site). Remove the redundant Platforms & download and Build from source sections and their now-unused icons.

- docs(readme): correct upstream attribution to FlClashX (fork of FlClash)

- docs(readme): rewrite RU/EN README, add icon set and screenshots

- Differentiators, comparison, efficiency, provider customization, privacy and open-source attribution; neutral, store-review-safe businesslike tone. Hugeicons (MIT) section icons under docs/icons. Replace screenshots with current connected/modes/menu (EXIF stripped).

## v0.8.1-pre.11

- chore(core): bump Clash.Meta — resolve firefox/safari to newest custom spec

- Pin xHomo dropweb-core-alpha-refresh acdf427->d4bdb09: the firefox/safari
- uTLS aliases now resolve to the newest custom ClientHello spec (FF148 /
- Safari 26.3) instead of the older built-in. Already exercised on-device in
- this wave's QA build.

- chore(release): bump build to 2026062610 for v0.8.1-pre.11

- style(windows): rounded app and tray icons

- All Windows .ico assets were fully opaque squares. Corners now rounded
- with the system radius — 26 anchored at the 256px canvas, scaled
- proportionally per mip frame (16..256), 8x supersampled edges. Covers the
- window/taskbar/installer icon and both tray states; art untouched.

- fix(announce): emoji-safe text runs on Windows

- buildEmojiSpans extracted from EmojiText (single owner of the emoji regex)
- and applied to the announcement's non-URL runs — flag emojis no longer drop
- on Windows while URL spans keep their tap recognizers.

- feat(connections): cached icons, GeoIP destination flags, per-connection traffic

- FlClashX pre.17 parity for the (currently unrouted) connections screen:
- - static future caches for package icons (fixes flicker on the 1s poll) and
-   per-IP country codes, FFI getCountryCode lookups serialized via a promise
-   queue so polling can't flood the bridge
- - destination rendered as a Twemoji flag badge (countryCodeToFlag helper in
-   country.dart), up/down traffic via TrafficValue in the metadata line
- Screen stays out of navigation by owner decision — dormant code.

- country.dart carries the one shared regional-indicator transform the view
- depends on; they land together.

- feat(tv): /status polling, Ethernet fallback, visible handoff errors

- - GET /status returns waiting|received (read-only, never leaks the nonce;
-   POST nonce checks untouched)
- - Android TV on Ethernet: getWifiIP() returned null and the dialog silently
-   popped — now falls back to NetworkInterface.list (prefers non-link-local)
-   and renders an error state instead of vanishing (also for a busy :8899)
- - phone polls /status after a failed POST to distinguish 'TV already got
-   it' from 'unreachable'

- fix(ui): lifecycle and resource guards

- - ThemeManager: ref.watch for textScale — changing text scale now applies
-   without a remount
- - MessageManager: mounted guards around delayed notifier mutations (toast
-   queued across dispose threw on a disposed ValueNotifier)
- - super_grid: TickerCanceled guard on the drag-end animation
- - tray_manager (Windows): calloc.free in finally — FFI throw leaked the
-   native UTF-16 string

- fix(ffi): free the getRunTime C string

- The only sync FFI handler without freeCString — leaked a Go-allocated
- string every second while connected.

- fix(dns): macOS DNS — space-safe service names, origin persist, op queue

- - getMacOSDefaultServiceName stripped via split(' ')[1]: names with spaces
-   ('Thunderbolt Ethernet', 'USB 10/100/1000 LAN') were truncated and the
-   networksetup calls hit the wrong service. Now only the leading '(N) '
-   index is stripped
- - the TRUE pre-injection DNS is persisted (macos_origin_dns): a crash while
-   connected no longer bakes 1.1.1.1 in forever — the next inject trusts the
-   persisted origin over the poisoned live read, restore clears the key, and
-   AppStateManager restores at launch (no-op in a clean state)
- - every set/restore chains onto a _dnsOp promise queue: rapid VPN toggles
-   can no longer run parallel networksetup invocations and capture the
-   injected DNS as the origin

- fix(net): sequential ip-check with timeouts

- checkIp fired all 4 geo sources in parallel through bare Dio() instances
- with no timeouts — 3 of 4 completers never completed and a hung request
- hung forever. Now a sequential loop (FlClashX parity) with 5s connect / 3s
- receive timeouts, stops at first success, honors the caller's CancelToken.

- fix(profiles): auto-update survives exceptions, atomic writes, sync dispose

- - the 20-min auto-update timer chain re-arms even when a run throws
-   (one secure-storage hiccup silently killed periodic updates until app
-   restart); getProfileUrl moved inside the per-profile try
- - saveFile/saveFileWithString stage into a .tmp sibling and rename over the
-   target — a kill mid-write no longer corrupts the stored profile
- - ApplicationState.dispose is synchronous again (Flutter calls dispose
-   synchronously; everything after the first await ran on a torn-down tree);
-   async exit work is kicked off unawaited, handleExit already covers
-   savePreferences + core shutdown
- - geo download write section enqueues onto the controller's geo-file lock;
-   the HEAD metadata fetch stays outside the lock

- fix(vpn): tri-state connect transitions, icon rollback, forced Android re-setup

- - handleStart returns bool? (null = transition already in flight) and
-   handleStop returns bool (false = stop ignored): updateStatus no longer
-   tears down traffic/runtime/providers for a stop that never happened and
-   no longer shows a false 'VPN Start Failed' toast on a double-tap
- - status-bar icon is set only after the transition succeeds, and rolled
-   back to disconnected on a failed start
- - Android connect always forces a full profile re-setup (FlClashX parity:
-   the long-lived mihomo executor degrades across stop/start) and the setup
-   hash is dropped on disconnect so the forced apply is a REAL re-setup,
-   while repeated applies during a live session stay cached
- - withGeoFileLock: a single promise chain serializes _applyProfile's
-   config/geo reads against the geo updater's on-disk writes (sharing
-   violations on Windows, corrupt geodata)

- Files must land together: the handleStart/handleStop signature change in
- state.dart and its consumer in controller.dart do not compile apart.

- fix(core): answer unsupported action methods instead of hanging the invoke

- handleAction's default branch ignored nextHandle's boolean — an unhandled
- method sent no reply, so the Dart Completer sat on the 30s safeFuture floor
- and then resolved to a silent default value. Now replies
- ActionResult{Code:-1, "unsupported method: X"} immediately on all three
- nextHandle variants (android / other-cgo / server).

- fix(android): crash-safe socket-address parse on the JNI resolver thread

- parseInetSocketAddress used URL("https://$address") — bare IPv6 or a
- missing port threw on a JNI callback thread and crashed the process.
- Manual host:port split with bracket stripping, any failure falls back to
- the wildcard:0 address which getConnectionOwnerUid tolerates (-1 uid).

- fix(android): syncStatus is enrichment-only — never clobbers tile runState

- runState stays the synchronous source of truth for the QS tile. The Dart
- getStatus() round-trip bails on an indeterminate reply (no service engine
- after process recreation) and never overwrites an in-flight PENDING —
- previously both got forced to STOP, flipping a live tile to inactive.

- fix(android): tear down Go core when the system destroys the VPN service

- onDestroy now routes through VpnPlugin.handleStop() (idempotent for the
- normal stop path): Core.stopTun + runState reconcile + receiver/job cleanup.
- Previously an LMK/system kill left Go core threads running on a dead TUN
- with runState stuck at START.

- fix(android): harden VpnPlugin — bind race, double-attach, fd leak, stop leaks

- - stop-during-bind race: startRequested flag — a stop() arriving while
-   bindService() is in flight is honored when onServiceConnected re-enters
-   handleStartService (VPN no longer starts after the user pressed stop)
- - double-engine attach: attachCount guards scope creation and
-   registerNetworkCallback (singleton is attached to both the main and the
-   service engine; second register threw IllegalArgumentException inside an
-   unhandled coroutine), unregister/teardown only on last detach
- - detached tun fd is closed (adoptFd) and runState rolled back to STOP when
-   Core.startTun throws
- - handleStop: clear uidPageNameMap, unbind the BIND_AUTO_CREATE connection
-   and null dropwebService (the binding kept the stopped service alive)
- - onServiceDisconnected stops the 1s foreground-params polling job
- - resolverProcess: getPackagesForUid()?.firstOrNull() — empty array crashed
-   the JNI callback thread

## v0.8.1-pre.10

- chore(release): bump build to 2026062609 for v0.8.1-pre.10

- fix(desktop): restore tray Старт/Стоп connect toggle

- The connect/disconnect tray entry was dropped in eea7283 along with the
- TUN/proxy/restart items. Bring back just the start/stop toggle (label
- tracks trayState.isStart, same updateStart() as the hotkey path); TUN,
- system-proxy, restart and copy-env stay removed.

- fix(desktop): Windows 'Unknown Hard Error' crash on exit

- Raw exit(0) tore down plugin DLLs (WinRT compositor, window_manager,
- tray) with the engine still live, raising the Windows 'Unknown Hard
- Error' dialog when WER is disabled; a 300ms watchdog fired exit(0)
- mid-cleanup (helper /stop alone allows 2000ms).

- - Window.close() on Windows: windowManager.destroy() (PostQuitMessage →
-   clean wWinMain return, engine shutdown joins raster thread) instead of
-   raw exit(0); Windows.forceExit() (TerminateProcess) as hard fallback.
- - handleExit(): _isExiting re-entrancy guard; hide window first; each
-   teardown step independently guarded so an early throw never skips core
-   shutdown (orphaned core); watchdog 300ms→5s and TerminateProcess on
-   Windows (re-posting WM_QUIT is a no-op when the loop is wedged).
- - Settings disclaimer is now read-only (single Закрыть button); only the
-   first-run flow keeps the accept/exit choice.

## v0.8.1-pre.9

- chore(release): bump build to 2026062608 for v0.8.1-pre.9

- feat(dashboard): remove liquid provider-logo lens + connect morph — clean power button

- Owner feedback: the morphing provider logo on the connect button reads as
- too crazy («сносим под корень»). Removed in full:
- - T21 connect morph (_morphController/_morph, optimistic isConnecting sync,
-   the logoT surge multiplier, and the glyph recede in start_button)
- - the entire pre-existing liquid logo subsystem: _logoImage/_flowController/
-   _logoFade load+drift machinery, the painter's layer-2.5 liquid CTA
-   treatment, _paintLiquidLogo + the value-noise/fbm/mesh-warp engine,
-   channel-isolating colour filters and all _liquid* constants
- The lens is now a clean glass power-button (body/veil/inset/specular/inner-
- edge/iris/Fresnel-rim/halo layers retained). The success haptic on connect
- is KEPT. Provider brand still shows on the subscription card.
- Net: -605 lines, 4 now-unused imports dropped. Easily revertible if a static
- logo is wanted later.

- feat(onboarding): drop the attention pulse — keep only the glass hint callout

- Owner feedback: the three expanding rings around the lens read as too busy.
- Removed _AttentionPulsePainter + its bounded-cycle controller; the first-run
- coach hint is now just the static glass callout (entrance fade/slide, reduce-
- motion snap preserved).

- i18n(zh): use 加速器 (accelerator) instead of VPN — China market convention

- In China 'VPN' is politically sensitive and avoided in consumer apps; the
- category norm is 加速器. All user-facing zh_CN strings switched to 加速器/系统设置.
- Only vpnDisclosureBody keeps the literal 'Android VPN 权限' reference — that
- is the honest name of the system VpnService permission being requested.

- feat(onboarding): first-run hint, clipboard subscription hand-off, import→connect invite

- refactor(controller): extract ProfileService behind facade

- Carve the profile-domain concern out of the 2208-line AppController into
- lib/services/profile_service.dart (ProfileService), constructed with the
- WidgetRef the same way AppController holds _ref — mirroring the prior
- AppUpdateService extraction.

- Moved verbatim (delegation only, zero logic change):
- - add/delete:        addProfile, deleteProfile
- - setters:           setProfile, setProfileAndAutoApply, setProfiles
- - subscription/theme headers: applySubscriptionSettings, applyAllHeaderSettings
-   (was _applyAllHeaderSettings), applyActiveProfileHeaders, resetSubscriptionTheme
-   (was _resetSubscriptionTheme) + service-private _applyProviderSettings,
-   _applyThemeColor, _applyDropwebTheme, _parseHexColorValue, _applyCustomViewSettings
- - geo metadata:      updateGeoFilesAfterProfileUpdate (was _updateGeoFiles...) +
-   service-private _getRemoteFileMetadata, _getMetadataKey, _getSavedMetadata,
-   _saveMetadata, _hasMetadataChanged
- - auto-update:       autoUpdateProfiles, updateProfiles, updateCurrentProfileSubscription
-   (was _updateCurrentProfileSubscription)

- AppController keeps thin delegating methods with identical signatures so all
- call sites stay untouched — public delegates for external callers
- (application.dart, profiles.dart, subscription.dart, card_menu.dart,
- add_profile.dart) and private delegate stubs for the staying internal callers
- (updateProfile, handleChangeProfile, addProfileFormURL, init).

- Stayed in the controller (depend on its private work-mode/config state or build
- raw dialogs against the stored context — out of the profile-data concern):
- updateProfile, setProfileWithRevalidationAndAutoApply (both call private
- _revalidateWorkMode), handleChangeProfile (_lastSetupHash),
- _showHwidLimitNotice + addProfileFormURL/File/QrCode (UI/Navigator/context).
- The service reaches the few public staying methods via globalState.appController
- (applyProfileDebounce, clearEffect, updateStatus, savePreferencesDebounce,
- updateProfile). No BuildContext is stored in the service.

- The pure helper shouldAutoUpdateProfile stays top-level in controller.dart (its
- test imports it there). Dropped its @visibleForTesting marker: ProfileService is
- now a legitimate cross-library production caller, so the annotation was
- inaccurate — same reasoning the prior commit applied to shouldRunAutoUpdateCheck
- / shouldHandleUpdateResult. Removed the now-unused http import from controller.

- dart analyze: 0 errors, 1 warning (pre-existing subscription.dart baseline).
- flutter test: 251 pass UNCHANGED. make android_arm64_core: exit 0.
- controller.dart 2208 -> 1692 LOC.

- chore: retire stale Skia claim in DESIGN.md; drop orphan zoom l10n key

- refactor: delete dead DAV backup remnants and orphaned recoveryStrategy field

- Completes T19's surface removal at the persisted-model layer:
- - DAVClient + webdav_client dep; AppDAVSetting slice + configState dav line
- - Config.dav + DAV freezed model + defaultDavFileName
- - AppSettingProps.recoveryStrategy + RecoveryStrategy enum + getBackupFileName
- - 17 orphaned backup/WebDAV arb keys × 4 locales (intl regen)
- - 13→12 slice-count comments (T18 enumeration sites)
- - NEW back-compat test: legacy persisted JSON with dav/recoveryStrategy keys
-   still deserializes (no disallowUnrecognizedKeys; compatibleFromJson safe)
- - round-trip fixture drops dav; drift-lock self-adjusts via toJson().keys

- perf(settings): disabled provider-managed switches render M3 disabled colors

- Follow-up to e349428: SwitchDelegate.onChanged nulled while the row is
- provider-managed, restoring visual parity with the removed Opacity(0.5)
- wrapper. AbsorbPointer already blocked interaction — zero behavior change.

- perf(settings): drop saveLayer Opacity wrappers — alpha via color tokens

- refactor(state): ConfigRepository owns the config mirror; round-trip test locks the field list

- style(l10n): short labels in all locales — Update/更新, Always-on/常時接続/始终开启 (match RU «Обновить»/«Всегда включен»)

- refactor(controller): extract UpdateService behind facade

- Carve the app-update concern out of the 2260-line AppController into
- lib/services/app_update_service.dart (AppUpdateService), constructed with
- the WidgetRef the same way AppController holds _ref.

- Moved verbatim:
- - autoCheckUpdate
- - checkUpdateResultHandle
- - _resolveReleaseUrl (private; only those two used it)

- AppController keeps thin delegating methods with identical signatures, so
- all call sites stay untouched:
- - lib/views/about.dart:36 globalState.appController.checkUpdateResultHandle(...)
- - AppController.init() autoCheckUpdate() (in-process)

- Notes:
- - No BuildContext stored in the service. The one direct context use
-   (context.textTheme) now reads globalState.navigatorKey.currentContext,
-   guarding null (showMessage routes through the same navigatorKey, so the
-   guard is behaviour-equivalent — no context, no dialog).
- - The pure policy helpers shouldRunAutoUpdateCheck / shouldHandleUpdateResult
-   stay top-level in controller.dart (their tests import them from there).
-   Dropped their @visibleForTesting marker: they now have a legitimate
-   cross-library production caller (the service), so the annotation was
-   inaccurate. shouldAutoUpdateProfile keeps its marker.
- - Removed now-unused url_launcher import from controller.dart.

- dart analyze: 0 errors, 1 warning (pre-existing subscription.dart baseline).
- flutter test: 248 pass — update tests (should_handle_update_result_test,
- should_run_auto_update_check_test, about_check_update_test) pass UNCHANGED.
- make android_arm64_core: builds (exit 0). controller.dart 2260 -> 2208 LOC.

- refactor: delete dead Backup&Recovery feature (unreachable FlClash legacy)

- BackupAndRecovery screen is FlClash legacy and unreachable: it was only
- referenced by its own definition and the views.dart barrel export — no
- navigation wires it (T17 evidence). Owner verdict: product is URL
- subscriptions only, no backup concept.

- Deleted (each verified to have no live caller outside the dead cluster):
- - lib/views/backup_and_recovery.dart (the unreachable screen)
- - AppController.backupData / recoveryData / _recovery (only the dead view
-   called them)
- - lib/common/archive.dart (ArchiveExt — only backupData used it)
- - lib/common/archive_safety.dart + test/common/recovery_zip_slip_test.dart
-   (T6 zip-slip helper; recoveryData was its ONLY caller — dead-code
-   precedent: CryptoService/T13)
- - RecoveryOption enum (only the dead cluster used it)
- - archive: ^4.0.7 pubspec dep (sole consumers were the deleted files)
- - scriptRestoreWarning l10n key (T9; orphaned by _recovery deletion) from
-   4 arb + regenerated lib/l10n

- Kept as follow-up (bigger blast radius, same rationale as DAV):
- - Config.recoveryStrategy field + RecoveryStrategy enum (persisted model
-   field; removal is a generated-code + ConfigRepository/T18 change)
- - DAV model/provider slices (appDAVSettingProvider, Config.dav) and
-   DAVClient (now unused but DAV-scoped)
- - other orphaned backup-related l10n keys (harmless unused strings)

- dart analyze: 0 errors. flutter test: 248 pass (257 baseline − 9 deleted
- zip-slip cases).

- feat(dashboard): liquid morph start↔lens, zero-lag state sync, connect haptics

- - New connect-morph controller on Lumina motion tokens: the provider
-   watermark idles as a 30% ghost and surges to full with the connect
-   transition; driven OPTIMISTICALLY from globalState.isConnecting (sub-frame
-   after the tap), settles on the real runTime flip, reverses on a failed
-   start. Reduce-motion snaps; controllers disposed; no always-on tickers.
- - Glyph layer counterpart: power glyph recedes (0.88 scale, 0.82 alpha)
-   while connected so the logo reads as the primary surface; recede/restore
-   rides the same Lumina duration/curve as the lens morph.
- - New DropwebHapticCue.success on the established connection (OFF→ON only):
-   CONTEXT_CLICK on Android R+, KEYBOARD_TAP fallback, mediumImpact Flutter
-   shim; contract test extended (4 pass).

- Device-verified on Pixel 10 (owner-confirmed morph quality).

- fix(modes): same-flag servers no longer collapse — each is its own picker row

- A flag group with >1 node now expands into one row per server
- («🇩🇪 Германия-1», «🇩🇪 Германия-2»), keyed by the exact node name; a
- single-server country keeps the classic flag-keyed row. New pure
- resolveCountryKeyNodes accepts all three key kinds (flag emoji, flagged
- node name, flagless node name) and backs both the work-mode pool builder
- and the post-update revalidation, so a stored node-name selection
- survives subscription refreshes and resets to Standard only when that
- exact server disappears. 9 new tests.

- fix(l10n): complete ja/zh translations (29 missing keys + 20 untranslated values), RU «Обновить», Always-on row re-localizes

- - intl_ja/zh_CN.arb: fill 29 keys that fell back to English at runtime and
-   20 values that were English text sitting in the locale files (mixed-language
-   UI on the card menu / settings screens); key order aligned to intl_en.arb
- - ru: updateSubscription «Обновить подписку» → «Обновить» (owner request)
- - AlwaysOnVpnItem: AppLocalizations.of(context) instead of the global getter —
-   const-instantiated row now registers a Localizations dependency and rebuilds
-   on language change (the T22 getter fixed values-on-rebuild; this fixes the
-   missing rebuild trigger)

- fix(l10n): appLocalizations global re-reads current locale — was frozen at startup

- The top-level `final appLocalizations = AppLocalizations.current;` is a lazy
- final: it evaluates once on first read and freezes that locale's instance
- forever. AppLocalizations.load() reassigns the static _current on every locale
- change, but the frozen final never re-reads it, so ~60 global consumers keep
- the STARTUP locale after a language switch (e.g. Toolbox Always-on row stays
- RU in a JA app). Commit 2078118 whack-a-moled this per-widget; this fixes the
- root.

- Change to a getter so every read resolves the current static. It is
- call-site-compatible with the final (all consumers use appLocalizations.X) and
- resolves a static field — zero allocation, no hot-path cost. Per-widget
- context lookups from 2078118 stay (harmless, context-correct).

- Verified on Pixel 10: RU->JA switch + re-enter Toolbox now shows 常時接続VPN;
- dashboard card unfreezes too. flutter test 248 pass, analyze 0 errors.

- style(settings): Always-on row is title-only — «Всегда включен»

- style: tokenize stray colors, drop dead light branches, conditional sheet blur

- perf(size): ship single geo format, drop redundant databases (-19.6MB assets / -10.4MB compressed APK)

- Drop geoip.metadb (9.2M) and ASN.mmdb (10.4M) from the bundled geo seed,
- keeping GeoIP.dat + GeoSite.dat.

- Proof the dropped files are redundant:
- - The seed copy (ClashCore.initGeo / Geodata.ensureGeoFilesIfNeeded) only
-   ever runs for profiles with geodata-mode == true, and in that mode mihomo
-   loads GeoIP.dat (not geoip.metadb). In geodata-mode == false the app seeds
-   nothing, so the bundled metadb is never load-bearing in any path.
- - The real dropweb subscription has geodata-mode unset (false) and 0
-   GEOIP/GEOSITE/ASN database rules (all geo matching via .mrs rule-providers).
- - ASN.mmdb is unused by default rules; the only Fatalln path
-   (getCountryCode -> mmdb.IPInstance) has no Dart callers.

- Graceful degradation preserved: if a profile needs metadb/ASN, the
- controller download path + manual geo-update UI + mihomo core auto-download
- (init.go) fetch them on demand; absence never crashes.

- Removed both files from the two copy lists only; filename constants and the
- on-demand download/update paths are unchanged.

- Device QA (Pixel 10, pm clear cold start): connects, tun0 up, subscription
- refresh fetches through tunnel, geo copy correctly skipped, no geo errors.

- Revert "feat: warn that backup export contains plaintext credentials"

- This reverts commit cd45a53794397c0c58556b5438e68c46b5aff560.

- feat: warn that backup export contains plaintext credentials

- fix(security): trust user CAs only in debug builds

- chore: log silently-swallowed VPN proxy-name and config-parse errors

- chore: remove dead CryptoService (hardcoded infra)

- fix(security): JS eval timeout; confirm scripts on restore

- fix(security): move AlwaysOnVpn entry to Toolbox — more discoverable placement

- feat(security): handle VPN revoke + surface Always-on/Lockdown guidance

- fix(security): nonce-validate Send-to-TV profile handoff

- fix(stability): FFI dispatch survives malformed core messages

- fix(security): reject path-traversal entries in backup restore

- fix: apply 50MiB cap to text fetches

- perf(battery): pause group polling while app is backgrounded

- docs(render): Impeller is production renderer; retire stale Skia/shader gotcha

- feat(stability): global error handlers route uncaught errors to file log

- fix(ffi): timeout returns error sentinel, not fake success

- fix(security): redact URL path in logs — subscription tokens live in paths

- feat(modes): country sheet scrolls; flagless nodes are individual 🏴 servers with liveness gate

- shrinkWrap ListView locked scrolling once content hit the 85% cap → SingleChildScrollView + min Column (hug-when-short preserved); flagless nodes each become their own selectable «🏴 name» row (single black flag — Twemoji lacks the pirate ZWJ ligature), sorted last, shown only after their delay test succeeds (xray balancer pseudo-hosts never surface); symmetric row insets; AnimatedSize + fade-in reveal on Lumina motion tokens.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(dashboard): raise liquid provider logo to optical lens center

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(l10n): page/dialog titles re-localize on language change

- titles were captured as plain String at push time; optional titleBuilder(context) re-resolves via AppLocalizations.of and registers a Localizations dependency.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(macos): expose autostart toggle, surface window on deep-link import

- AutoLaunchItem was gated by unrelated overrideProviderSettings; status_bar_icon channel gains showWindow (NSApp.activate + popover).

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(desktop): tray menu to Show/Autostart/Exit, announce card clears connect lens

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(errors): humanize user-facing errors, gate QR-from-image off Windows/Linux

- ErrorMapper covers Dio timeouts/connection/cert/HTTP-status/Format/MissingPlugin/Timeout; safeRun + loadingRun + addProfileFormURL fall back to localized generic message; mobile_scanner analyzeImage has no Windows/Linux impl so the QR entry is hidden there.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

## v0.8.1-pre.8

- chore(release): v0.8.1-pre.8 (bump build for in-place upgrade)

- feat(dashboard): liquid provider-logo connect lens + tuning lab

- Port zencab's ConnectGlassCTA/LiquidLogoLayer into _ConnectGlassPainter
- as layer 2.5: orb1->darkened-accent gradient base, top glass highlight,
- and the subscription provider logo (dropweb-logo header, gated by
- applySubscriptionLogo) stretched across the lens and liquid-warped.

- The SVG filter chain is reproduced on pure canvas (no fragment shaders -
- Impeller kills them silently): 32x32 static mesh via drawVertices with
- BACKWARD-warped texture coordinates (feDisplacementMap semantics),
- 2-octave fractal value noise sampled in the liquid_lab coordinate frame,
- animated only by base-frequency breathing + chroma pulse (seamless 19s
- loop). Chroma split renders as three channel-isolated passes; below
- chroma 0.05 a single-pass path draws luminosity directly WITHOUT
- saveLayer - Impeller rasterizes advanced-blend saveLayers at logical
- resolution (no DPR), which blurred the whole layer.

- Logo pipeline: 512px decode via CachedNetworkImageProvider/flutter_svg,
- fade-in via Lumina curve, reduced-motion freezes the field, fallback =
- stock dark lens. Idle dims the stack to 0.45 (lerped by irisT) and the
- iris wash fades out while the logo is active. Rim/glow/icon-shadow
- dials promoted to consts (_rimAlpha, haloAlpha, _iconShadow*).

- tool/liquid_lab.html: WYSIWYG tuning lab (WebGL, identical formulas,
- Copy-Dart-consts export, ?logo=&freeze= harness).

## v0.8.1-pre.7

- docs: add AGENTS.md + DESIGN.md context anchors; ignore .code-graph

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- l10n: drop the «Рекомендуем» line from the standard mode description

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- style(subscription): proxy selector rows as Lumina cards, radiusLg across sheet cards

- Drill-in selector rows were flat edge-to-edge bands; restyle them as
- rounded bordered cards mirroring the group cards, and align both the
- group cards and selector rows to Lumina.radiusLg (26) to match the
- mode cards.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(ui): bottom sheet fills edge-to-edge behind gesture nav

- Top-only SafeArea + useSafeArea:false so the sheet container reaches
- the screen bottom; the gesture-nav inset moves inside
- AdaptiveSheetScaffold as content padding.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(proxies): resolve smart group delay at the group itself, not the display label

- Block B made GroupType.Smart computed-selected, so _getProxyCardState
- recursed into the smart group and the localized «Авто» label leaked in
- as a proxy name — delay tests hit a nonexistent proxy and the
- First Available badge died. Split GroupExt into resolveSelectedName()
- (resolution-safe, '' for the unpinned-smart placeholder so the chain
- terminates at the group, which the core can URLTest directly) and
- getCurrentSelectedName() (display-only, keeps «Авто»).

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(disconeko): keep 🧠 Smart health-checked, hide from list in UI not config

- Root cause of 'smart doesn't select': 1aa3db8 set hidden:true on 🧠 Smart at the
- CONFIG level. A config hidden flag makes the mihomo core deprioritize the group
- and stop reporting its delay, so 📶 First Available (now = 🧠 Smart) lost its
- selection/availability badge that worked before today. (Before today the Dart
- GroupType had no 'smart' case, so 🧠 Smart wasn't parsed into the list at all,
- yet the core still health-checked it — hence the old working badge.)

- Fix: drop hidden from the config so the core health-checks 🧠 Smart again
- (First Available auto-selects + shows ms), and filter 🧠 Smart from the
- «Серверы и группы» list purely in the UI (_RulesProxiesView, by name via the new
- public disconekoSmartGroupName) so it's still never a standalone selectable row.
- NOTE: takes effect after the subscription is re-downloaded (patchSmartPool runs
- at download; the saved config still carries the old hidden flag until refresh).

- fix(modes): restore availability badge on First Available / smart pool

- The hidden:true on 🧠 Smart (1aa3db8) dropped it from currentGroupsState, so
- _pingAllProxies (which iterated the filtered groups) no longer delay-tested the
- disconeko smart pool — 📶 First Available (now = 🧠 Smart) lost its ms badge that
- worked before. Fix:
- - _pingAllProxies now reads the RAW groupsProvider (includes hidden groups), so
-   🧠 Smart and its members are delay-tested again → First Available shows a badge.
- - _RulesProxiesView is now stateful and fires _pingAllProxies once on open
-   (post-frame), so badges populate immediately like the old version (pull-to-
-   refresh still re-tests). 🧠 Smart stays hidden from the list (no standalone row).

- fix(ui): country picker sheet adapts to content height

- Was a fixed 70% SizedBox → empty space with only a few countries. Now a
- ConstrainedBox(maxHeight 70%) + shrinkWrap ListView: the sheet sizes to its
- content (short for 3 countries) and only scrolls when the list exceeds 70%.

- fix(modes): smart group shows «Авто», not «Smart - Select» placeholder

- A type:smart group has no single current node (it picks per destination), so the
- core's Now() returns the literal placeholder "Smart - Select". The UI rendered it
- verbatim with no node highlighted — reading as an empty manual selector awaiting a
- pick, though the group ALWAYS auto-selects at dial time. Map the placeholder to a
- localized «Авто» so smart presents as auto-mode. Display-only; routing/auto-select
- unchanged. (LightGBM uselightgbm stays off — see note: enabling it triggers a
- synchronous 90s GitHub model download at config-apply that would hang pre-VPN on
- RU/KZ; needs a bundled Model.bin or reachable lgbm-url mirror first.)

- fix(modes): recompute country/smart provider on profile update

- _modeProfileDataProvider (FutureProvider.autoDispose.family keyed by profileId)
- kept a stale result after a subscription update because the key didn't change —
- the cause of the transient 'страны пропали' after refresh. Watch the profile's
- lastUpdateDate + providerHeaders count so the provider re-evaluates getProfileConfig
- when the subscription actually changes.

- feat(modes): shorten mode descriptions, remove Gaming card

- - Стандарт: «Рекомендуем.\nВсё настроено за вас.» (two lines)
- - Умный: «Сам выбирает лучший.»
- - Страна: «Выберите страну.»
- - Removed the «Игровой» (Gaming) card entirely from the modes tab.
-   (workModeGaming/Desc/comingSoon l10n keys left orphaned per convention.)

- feat(ui): country picker as modal sheet, gate Standard deep until selected

- - Country picker now opens as a popup modal sheet (showSheet + AdaptiveSheetScaffold),
-   matching «Серверы и группы» — was a full-page showExtend push.
- - Standard's «Серверы и группы» chevron is gated: tappable only when Standard is
-   the active mode; otherwise rendered greyed + non-tappable (taps fall through to
-   the card, selecting Standard). _ModeCard.chevronDisabled + _ChevronAffordance.disabled.

- feat(disconeko): hide 🧠 Smart emergency-pool group from groups list

- The disconeko 🧠 Smart group surfaced as a standalone selectable row (with a
- drill-in node picker) in «Серверы и группы». Per product owner it must be
- emergency plumbing only — auto-selecting, never user-pickable, only a fallback
- member of 📶 First Available.

- Mihomo requires every group (incl. a fallback member) to be a named top-level
- proxy-groups entry — anonymous subgroups are impossible. So instead of removing
- it, mark it hidden: true (core honors hidden on smart groups; currentGroupsState
- filters hidden==false — same mechanism the panel uses for ♻️ DIRECT). The group
- stays referenceable by 📶 First Available (SOS isolation + smart ranking intact)
- but its card and drill-in vanish from the UI. Applied to both the injected spec
- and the pre-existing-group idempotent branch.

- feat(modes): remove strict node + DoH, country picker shows availability badge

- feat(ui): country strict-node shows resolved pool IPs

- Strict-node picker branches on country shape (ИТЕРАЦИЯ 3):
- - POOLED (exactly 1 leaf whose server is a domain) → DoH-resolve the pool
-   domain via an autoDispose.family provider (shared 60s cache, loading
-   spinner) and offer one row per real IP (flag + country name title, full
-   IP subtitle since the user wants the exact pin). DoH empty/fail → fall
-   back to pinning the pooled node itself with a subtle hint.
- - DISCRETE (>1 leaf, or a leaf with an IP server) → unchanged per-node-name
-   rows with masked-server subtitles.
- Extracted a shared _StrictRow widget. No auto-pop; strict-off → onApply(country, null).

- feat(modes): DoH pool unrolling — pin a fixed server IP in country strict mode

- The panel delivers ONE pooled node per country (e.g. 🇩🇪 Германия,
- server: de.meybz.asia). That domain's A record is a pool of several real
- server IPs; mihomo's tcp-concurrent races them, so the exit IP is
- non-deterministic — bad for an arbitrage user who needs a FIXED IP.

- - common/doh.dart: Cloudflare DoH JSON resolver (resolvePoolIps) with a
-   pure, unit-tested parser (parseDohAnswer) + a 60s per-host cache;
-   returns [] on timeout/error/empty so callers fall back.
- - common/country.dart: extract & export isIpv4(); maskServerAddress reuses it.
- - common/work_mode_patch.dart: countryStrictProxyName('Страна <flag> <ip>')
-   + staticStrictNode param. Country branch clones the pooled BASE leaf into
-   a variant proxy with server=<IP>, preserving Reality SNI (synthesize
-   servername=pool-domain only when both servername/sni absent; never clobber
-   an existing steal-domain). Additive + idempotent; built only from the
-   country's own leaf (no SOS-pool leak).
- - controller.dart: applyWorkMode pins selectedMap[GLOBAL] to the variant
-   name for an IPv4 pin; _revalidateWorkMode keeps an IP pin (not a member
-   name) instead of dropping it.
- - state.dart: thread profile.staticStrictNode into applyWorkModePatch.

- fix(ui): strict-node rows keep flag + masked server IP, country tap no auto-return

- - Strict-node list shows full node name WITH flag (was flag-stripped) +
-   masked server address subtitle (IPv4 first two octets, e.g. 45.135.•.•;
-   pooled domains shown as-is). nodeServers exposed via _modeProfileDataProvider.
- - maskServerAddress() in country.dart + tests.
- - Tapping a country selects it in place WITHOUT popping the screen, so the
-   user can then toggle Строгая нода and pick a node before returning.

- feat(ui): country names in picker, inline strict-node list

- - Country rows show localized names derived from node names
-   (stripCountryFlag of first informative node; ISO-letters fallback) —
-   new countryDisplayName() in country.dart with tests.
- - «Строгая нода» no longer opens a modal: the active country's nodes
-   render inline below the toggle, tap pins in place. _openStrictNodePicker
-   sheet removed.

- fix(modes): country candidates from rule-group leaves only, close disconeko leak in country mode

- fix(ui): country deep rows show node counts, uniform trailing

- feat(ui): case+deep mode cards, country picker deep screen

- feat(modes): smart intercepts all rule-referenced groups, fail-open revalidation

- - «Умный» now binds into EVERY rule-referenced group (select/url-test/
-   fallback, >=1 non-builtin member): member append + selectedMap, so
-   YouTube/Discord etc. smart-rotate too, not only the primary router.
- - Smart group rotates over the UNION of leaf nodes across intercepted
-   groups; SOS chain hard-excluded on top of structural exclusion.
- - CRITICAL: build path renames rules->rule (state.dart) before
-   applyWorkModePatch; detection now reads both keys (was silently
-   no-op in production).
- - selectedMap ownership by VALUE ('Умный'/'Страна *') on cleanup.
- - _revalidateWorkMode is fail-open: resets only on positive proof,
-   malformed/unexpected config shape preserves mode (fixes spurious
-   smart->standard reset after restart).

- fix(modes): smart group from router leaf nodes, bind as router member (close SOS leak, fix inert binding)

- fix(modes): harden country mode revalidation and apply rollback

- feat(l10n): strict node reset notice

- fix(modes): write derived mode back to provider, remove desktop mode switching surfaces

- fix(modes): updateProfile re-reads latest profile state, stop stale-snapshot reverts

- refactor(ui): profile tiles on flagship card language, kill hardcodes

- feat(ui): work modes tab

- feat(l10n): work mode strings

- feat(modes): wire work modes into config pipeline

- feat(modes): work mode patch engine

- feat(proxies): surface core smart groups in Dart layer

- feat(modes): country extraction utility

- feat(modes): WorkMode fields on Profile

- style(tokens): bump radiusLg 24->26

## v0.8.1-pre.6

- chore(release): v0.8.1-pre.6 (bump build for in-place upgrade)

- fix(core): extend panic recovery to hub callback goroutines

- fix(geo): fail loudly instead of exit(0) on geodata copy failure

- perf(start): lazy geodata asset copy

- perf(ui): bound image caches

- perf(core): default find-process-mode strict

- New installs and config resets now default to FindProcessMode.strict
- instead of always. With always, every connection resolved UID/package
- through the Kotlin VpnPlugin.resolverProcess callback, a measurable
- per-connection CPU/memory cost.

- mihomo strict mode still resolves the process when a rule actually
- requires it (PROCESS-NAME / PROCESS-PATH / app-based routing); it only
- skips resolution when no rule needs it.

- Existing users are unaffected: their persisted find-process-mode value
- is already serialized in saved config JSON, and the @Default only
- applies when the key is absent (fromJson). They keep their chosen value.

- Tradeoff: on profiles with no process-based rules, the Connections page
- may show fewer app names. Accepted.

- perf(core): bound Go heap with GOMEMLIMIT and tighter GC percent

- Apply debug.SetMemoryLimit(192 MiB) and debug.SetGCPercent(70) once at
- core init (handleInitClash, guarded by isInit so it runs once per process).

- Without a limit the default GOGC=100 lets the heap double before each GC
- cycle, inflating RSS on mid-range Android devices. 192 MiB is a soft limit
- for the Go runtime only (not total app RSS): as the heap approaches it the
- runtime GCs harder instead of OOM-ing. GOGC 70 trims the per-cycle growth
- target from 100% to 70%, keeping the working set tighter.

- hub.go is shared across platforms, so this applies to Android, Windows,
- macOS and Linux builds. That is intended: desktop also benefits, and a
- 192 MiB Go-heap soft limit is plenty for the core everywhere (typical core
- heap is <100 MiB).

- perf(config): skip full core setup when effective config hash unchanged

- perf(connect): drop 300ms debounce from start path

- fix(connect): gate tun ack on vpn service mode, not tun config flag

- feat(connect): honest connected state gated on TUN readiness ack

- feat(core): emit tun ready/error ack over message bus

- fix(core): recover panics in bridge action handler and goroutines

- perf(trace): instrument tap-to-traffic connect path

- docs: add client-fingerprint (uTLS) reference incl. firefox148/safari26

## v0.8.1-pre.5

- chore(release): v0.8.1-pre.5 (bump build for in-place upgrade)

- docs(headers): document dropweb-renew-url and dropweb-topup-url monetization headers

- chore(android): read signing creds from env with local.properties fallback

- Release signing credentials can now be supplied via DROPWEB_STORE_PASSWORD
- / DROPWEB_KEY_ALIAS / DROPWEB_KEY_PASSWORD instead of plaintext in
- local.properties. Non-breaking: falls back to local.properties when the
- env vars are unset, so existing local and CI builds are unchanged.

- chore: track core submodule on dropweb-core-alpha-refresh branch

- .gitmodules pointed core/Clash.Meta at 'main' (metacubex upstream), but
- the actual dropweb fork work lives on 'dropweb-core-alpha-refresh'. This
- fixes 'git submodule update --remote' pulling the wrong branch. SHA-based
- checkout (CI) was already correct.

- feat: port FlClashX improvements - monetization, VPN lifecycle, uTLS

- Batch of improvements adapted from pluralplay/FlClashX analysis,
- implemented in dropweb's own conventions:

- - monetization: header-driven renew/top-up buttons in the subscription
-   card, gated by expiry<3d / traffic<10%, via dropweb-renew-url and
-   dropweb-topup-url (our namespace; flclashx-* still rejected)
- - vpn(fd): leak-free Android TUN fd ownership on start failure + bounded
-   3s drain in TunHandler.close() to avoid stop/start deadlock
- - vpn(consent): queue VPN consent callbacks so concurrent starts cannot
-   strand a pending one
- - vpn(battery): Play-safe one-time battery-optimization prompt, shown
-   only after the first VPN start (never a cold-start nag)
- - tls: bump core submodule for Firefox 148 / Safari 26.3 fingerprints

- Verified: flutter analyze clean, go build + 11 core tests pass, debug APK
- built and a live tunnel established on-device.

## v0.8.1-pre.4

- chore(release): v0.8.1-pre.4 (bump build for in-place upgrade)

- fix: batch UI/profile/subscription fixes from on-device QA

- - profile switch now routes through handleChangeProfile() and resets the operator (subscription) theme to the dropweb default when the new profile has no dropweb-theme — fixes the previous operator's theme persisting after switching back
- - addProfile() always selects the freshly imported config (was skipped when a profile already existed)
- - three-dots 'Update' + new 'Обновить подписку' card-menu item no longer no-op: dropped the post-migration 'type == file' guard that silently skipped every URL subscription (url is '' in memory). Mirrors the pull-to-refresh fix
- - desktop window 375x600 -> 450x720 on Windows/Linux (macOS popover 5:8 proportions, roomier); native min/max synced in flutter_window.cpp (macOS popover untouched)
- - unavailable locations show an 'n/a' badge via utils.delayBadgeLabel (server card, group row, proxy selector, proxy card)
- - CommonDialog clips ink to its rounded corners (clipBehavior) — no more rectangular highlight behind the rounded card menu
- - removed the useless wifi fallback icon on server/location group cards
- - force Twemoji on server/group/proxy names for flag rendering
- - keep the clash-verge UA token (load-bearing: Remnawave selects Mihomo YAML vs base64/VLESS by User-Agent; a plain dropweb UA broke subscription import)
- - add updateSubscription l10n key (ru: 'Обновить подписку')
- - tests: package UA contract + utils.delayBadgeLabel

- fix(windows): use dropweb's own Inno AppId GUID (was inherited FlClashX 728B3532-...) — installer no longer detects/overwrites a FlClashX install; dropweb is now a distinct app

## v0.8.1-pre.3

- chore(release): v0.8.1-pre.3 (bump build above installed for in-place upgrade)

- feat(update): show 'Check for updates' on sideloaded Android (our RU channel) — gated off for Play via --dart-define=PLAY_BUILD=true; _platformKey resolves android-arm64; test updated + passing

- feat(update): in-app update check via our own server (dropweb.org/update.json, YC-backed) instead of GitHub API — РФ-reliable, graceful when absent (Phase 3)

- fix(android): drop redundant runtime portrait re-assert (manifest already locks it) — avoids fixed-orientation letterbox leaking a compat frame to the launcher on exit (flutter#184963). Candidate fix for home-screen layout break on Pixel/Android 15

- fix(profile): prevent subscription-URL loss on keystore write failure (verify-before-strip); profile menu = Обновить only (drop Редактировать/Переопределение); fixed 375x600 window on Windows + Linux like macOS popover

- ci: on stable release, publish binaries + update.json to YC (own РФ update server, no PAT)

- feat(privacy): hash ANDROID_ID like other platforms; never persist raw system id

- Fresh HWID generation now SHA-256-hashes the stable device id on every
- platform (Android included) instead of persisting/sending the raw ANDROID_ID.
- Existing installs keep their stored HWID (read-first in _getOrCreatePersistentHwid),
- so no forced re-hash and no x-hwid-limit churn. Makes Privacy §3.5 truthful.

## v0.8.1-pre.2

- chore: gitignore fvm local Flutter pin (.fvm/, .fvmrc)

- core: rebase onto mihomo Alpha v1.19.27-1 (all features + security)

- Rebase our 5 customizations (FlClashX Android patch-layer, Dropweb rebrand,
- sing-box converter, TLS ClientHello fragmentation, Smart/LightGBM group) onto
- fresh MetaCubeX Alpha HEAD 7031b756 (v1.19.27-1), superseding the pre.1
- cherry-pick. Security fixes now native; adds PASS-RULE, empty-fallback,
- path-in-bundle, age-secret-key, OpenVPN ping keepalive, allow-insecure listeners.
- Followed upstream removal of global-client-fingerprint (config parsing kept).
- xHomo @ dropweb-core-alpha-refresh (7cb57dc8). pubspec 0.8.1+2026060602.
- Verified: host build + android cross-compile + device boot (no crash, core inits).

## v0.8.1-pre.1

- chore(release): v0.8.1-pre.1 — canonical repo slug + version bump

- - pubspec 0.8.0+2026053101 -> 0.8.1+2026060601
- - pre_release_template.md: enkinvsh/dropweb-app -> enkinvsh/dropweb (canonical)
- - build.yaml: latest-release lookup uses ${{ github.repository }}

- core: backport mihomo v1.19.27 security fixes; bump core to 1.19.27

- Cherry-pick 5 upstream OOB/DoS fixes onto our Alpha core base (xHomo
- dropweb-core-rebuild @ 2590b929):
- - dns/doq readMsg out-of-bounds access (conflict-resolved)
- - quic sniffer OOB crash via single UDP packet
- - socks4 readUntilNull unbounded memory allocation
- - trojan WaitReadFrom panic via oversized UDP relay length
- - vless vision TLS filter OOB via crafted session_id length
- Set constant.Version placeholder 1.10.0 -> 1.19.27 (fixes core version
- shown in-app). Host go build (-tags with_gvisor) clean for submodule + wrapper.

- chore: stop tracking android/build artifacts

- Merge feat/core-alpha-rebase-smart: v0.8.0 — core MetaCubeX Alpha, TLS fragment, theming, subscription logo, Linux builds; scrub internal docs

- # Conflicts:
- #	CHANGELOG.md

- docs: document developer mode (5-tap unlock on the Settings title)

- Update changelog

## v0.8.0

- chore: drop internal parazitx/plans/release docs from public source

- Remove docs/parazitx, docs/plans, docs/release (internal planning + infra notes) from the tracked tree and gitignore them so they don't ship in the public GPL source. Sanitize the parazitx reference in .gitignore.

- ci(release): select latest stable Xcode on macOS

- macOS build failed compiling connectivity_plus 7.1.1 (NWPath.isUltraConstrained missing in the runner's default Xcode SDK). Pin latest-stable Xcode for the macos matrix entry so a newer macOS SDK is used.

- chore(release): 0.8.0; build Linux amd64 in the release matrix

- Bump version to 0.8.0+2026053101. Add a linux/ubuntu-24.04/amd64 entry to build.yaml so Linux is built and attached to GitHub releases (mirrors build-linux.yaml).

- docs: document dropweb-logo header

- Circular provider logo on the subscription card: accent ring synced to the connect button, theme-filter applied, gated by the 'Лого из подписки' toggle.

- feat(dashboard): subscription logo on the card with filter, accent ring, toggle

- Render the dropweb-logo header as a circular logo on the subscription card (replacing the menu icon; menu stays reachable via the swipe-up handle). Logo is color-filtered to follow the active scheme variant (imageColorFilter mirrors applyColorFilter), with a thin 0.5px accent ring that lights up in sync with the connect button. Gated by a new 'Лого из подписки' setting (applySubscriptionLogo, default on) placed above 'Тема из подписки'.

- feat(dashboard): card menu modal + bottom swipe-up handle

- Collapse cabinet/support/settings into a reusable CommonDialog menu (showCardMenu); open via the card icon or an accent up-arrow swipe handle pinned in the gap above the bottom edge (adaptive). CommonDialog skips empty titles.

- feat(theme): default to the Падение green theme

- Set defaultThemeProps + presetEmerald to accent #29FF76, orbs #009938/#2BFF7A, blur 4 (fidelity scheme); match first primary swatch.

- docs: add TLS Fragment reference; consolidate header docs

- - docs/tls-fragment.md: SNI-targeted TLS fragmentation (DPI bypass) — how it works, params (tls-fragment/-size/-delay), how to enable
- - subscription-headers.md: merge dropweb-cabinet section + summary row
- - remove duplicate remnawave-response-headers.md (single source of truth)

- feat(profile): surface disconeko pool via First Available, not VPN default

- Retarget patchSmartPool to inject the Smart emergency group into the
- "First Available" (fallback) proxy-group instead of prepending it as the
- default of the rule-count primary router. The primary router's default is
- now left untouched, so the emergency pool is opt-in. When the delivered
- config lacks a First Available group, one is created and appended to the
- primary router as a non-default option.

- Tests updated to the new contract; disconeko comment in profile.dart
- reworded accordingly.

- docs: add subscription headers reference; remove legacy dropweb-hex

- - docs/subscription-headers.md: operator reference for dropweb-custom gate, dropweb-theme contract (filter,hex,hex,hex,blur), 'Тема из подписки' toggle, dropweb-disconeko SOS pool
- - remove legacy dropweb-hex parser (_applyThemeColorFromHex) and its dispatch; dropweb-theme is now the sole theme contract

- feat(theme): operator-driven theming + user presets/filters/orbs/picker

- - 6 brand presets (one-tap accent+orb trio): Падение/Иней/Аметист/Багрянец/Янтарь/Стелс
- - per-orb colors (top/bottom) + blur slider (1-5, gradient sharpness)
- - 5 HSL scheme filters: Обычные(exact accent)/Яркие/Моно/Нейтральные/Выразительные, applied to accent+orbs preserving hue
- - flutter_colorpicker hue-wheel replaces buggy custom palette
- - connect button retuned per design tuner + icon outline
- - 'Тема из подписки' toggle (user master switch over operator theme)
- - operator contract: dropweb-theme (filter,hex,hex,hex,blur) + dropweb-hex CSV; applied on subscription update and profile switch

- feat(profile): merge disconeko emergency pool into a Smart group

- Subscriptions may carry a `dropweb-disconeko` header pointing to an emergency server pool. On profile update the client fetches it, names the nodes by country (flag + country word), and exposes them through a `🧠 Smart` group (type: smart, include-all) set as the primary router default — so traffic uses the best live server among the subscription's own nodes plus the emergency pool, matching the smart UX of loading a raw subscription directly.

- - common/smart_pool_patch: pure additive YAML patch (Smart group + nodes)
- - common/mihomo_yaml_splice: shared text-splice + router-detection helpers
- - common/share_link_profile: expose parseSubscriptionToProxies()
- - models/profile: best-effort disconeko fetch + patch, guarded by clashCore.validateConfig (reverts on rejection, never breaks the base profile)
- - deps: yaml, yaml_edit

- chore: bump Clash.Meta (Alpha rebase + Smart group + TLS fragmentation + sing-box converter)

- feat(profile): emit Smart group when building config from non-mihomo subscriptions

- feat(ui): add opt-in TLS Fragment toggle

- chore(core): rebase to MetaCubeX Alpha; adapt FFI bridge; fix codegen toolchain; bump NDK

- docs: trim public README

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

## v0.7.1

- fix(rebase): resolve release cleanup conflicts

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- docs: simplify public release materials

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- release(v0.7.1): prepare arm64 build

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(about): add Tribute support link

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(parazitx): remove Dart app surfaces

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(android): simplify Dropweb tile integration

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(android): remove ParazitX method channel hooks

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- chore(android): remove ParazitX service declarations

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(ci): install Linux libsecret build dependency

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

## v0.7.0

- Cleaned up the codebase for Google Play readiness and removed the legacy ParazitX module along with the unused native cabinet.
- Hardened privacy: tightened logging, locked down FileProvider exports, and added an explicit in-app VPN data-collection disclosure.
- Gated Play-facing UI surfaces and moved admin unlock controls out of the main flow.
- Fixed several profile import/edit bugs and the proxy selector sheet behavior.
- Switched the app to dark-only theming and removed desktop global hotkeys.
- Added a manual Linux build workflow (not part of the release matrix).

## v0.6.10

- Added raw share-link subscription import support.
- Fixed auto-update for migrated URL profiles.
- Polished mobile settings entry and subscription tab.
- Refined ambient background visuals.

## v0.6.9

- Added Android manual update checks with prerelease-safe update handling.
- Added Iris connect button bloom feedback.
- Added pixel-native haptics for key interactions.
- Added native Android SoundPool UI sounds with a reduced retained SFX set.

## v0.6.8

- release(v0.6.8): ship dashboard control hotfix

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(home): keep connect control on dashboard

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- Update changelog

## v0.6.7

- release(v0.6.7): ship Lumina cabinet UX

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- style(ui): clean secondary dashboard controls

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(dashboard): polish subscription card layout

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(home): add centered glass connect control

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(navigation): simplify profile-gated pages

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): keep cabinet access in subscription flow

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- docs(remnawave): document response headers

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): open header-gated cabinet tab

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): add browser entry page

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): resolve cabinet URLs from provider headers

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(cabinet): tighten native cabinet card spacing

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(cabinet): support OAuth post-auth bootstrap

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(cabinet): block Telegram deeplink handoff

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- build(release): add direct APK build helper

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- docs(release): document APK source availability

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- docs(cabinet): record bento layout decisions

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- chore(settings): clean tools view analyzer hints

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): add marker-gated cabinet tab

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): add native cabinet home

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): harden zencab WebView bridge

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(cabinet): persist native home data

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(onboarding): add subscription bento flow

- fix(cabinet): pin surface param, append UA marker, harden bridge args

- feat(cabinet): add zencab WebView shell

- Merge branch 'main' of https://github.com/enkinvsh/dropweb

- style(ui): update support link icon

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(ux): map YAML parse errors to human-readable messages in ErrorMapper

- fix(parazitx): plumb SOCKS5 credentials end-to-end so Mihomo can authenticate to relay bridge

- ParazitX's SOCKS5 listener requires RFC1929 user/password auth
- (`--socks-user`/`--socks-pass` CLI args). The Mihomo bridge proxy
- config in patchRawConfig had no auth. As soon as `__dropweb_parazitx_vk_bridge`
- was selected as GLOBAL on the device, every Mihomo CONNECT failed
- the SOCKS5 method-selection handshake and user traffic stopped.

- Generate creds in Dart with Random.secure() (16 hex / 32 hex). Pass
- them via existing MethodChannel + new EXTRA_SOCKS_USER/PASS Intent
- extras down to ParazitXRelayController.start(...) (with override
- parameters; lazy random fallback preserves standalone-mode behavior).
- Surface them on ParazitXBridgeInfo for the orchestrator to forward
- to MihomoDialerProxyPatcher. Redact in toString() and never log.

- Caught during device QA on Pixel 10: api.ipify.org through the bridge
- now returns 64.188.66.103 (pzx-001 egress) instead of failing.

- fix(android): VPN services use systemExempted FGS to avoid Android 14+ dataSync 6h timeout

- Android 14+ enforces a 6h cumulative timeout on `dataSync` foreground
- services and crashes them with ForegroundServiceDidNotStopInTime when
- the service does not stop on request. Sticky-restarted ParazitXVpnService
- hit this within 10s of a fresh launch on Pixel 10.

- VPN apps qualify for the `systemExempted` FGS type, which is the
- correct declaration for VpnService subclasses. DropwebService stays
- on `dataSync` since it is a true background-data service.

- Caught during device QA on Pixel 10 (API 36).

- feat(parazitx): wave-2 — Mihomo owns TUN, ParazitX is local SOCKS outbound

- Implements docs/plans/2026-05-02-parazitx-mihomo-outbound.md tasks 1-9.

- Mihomo's DropwebVpnService now owns TUN/DNS/fake-IP. ParazitXVpnService
- gains a `mihomo_outbound` mode that runs the relay subprocess only and
- exposes its local SOCKS5 listener as `__dropweb_parazitx_vk_bridge`
- appended to the GLOBAL proxy-group. ParazitXMihomoOrchestrator wires
- this into GlobalState.patchRawConfig and prepends DIRECT rules for VK
- signaling/Yandex/YC API Gateway endpoints to prevent self-loop while
- the Go relay still lacks VpnService.protect(fd).

- Tests: 31 new unit tests across patcher + orchestrator. Architecture:
- docs/plans/2026-05-02-parazitx-mihomo-outbound.md.

- Update changelog

## v0.6.6

- release(v0.6.6): ship libparazitx-relay.so in release APKs

- v0.6.5 was packaged without the relay binary because
- android/app/src/main/jniLibs/ was gitignored and setup.dart only
- produces libclash.so, so on every ParazitX activation the service
- crashed with 'libparazitx-relay.so missing in nativeLibraryDir'.
- The previous commit vendors the binary; v0.6.6 is the first release
- in which ParazitX actually starts on a clean install.

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(parazitx): vendor libparazitx-relay.so so release APKs ship the binary

- The CI build at v0.6.5 produced an APK without libparazitx-relay.so:
- clean checkout + jniLibs gitignored + setup.dart only producing
- libclash.so left lib/arm64-v8a/ without the relay binary, so on every
- ParazitX activation ParazitXRelayController.ensureBinary threw

-   java.lang.IllegalStateException:
-     libparazitx-relay.so missing in nativeLibraryDir=…/lib/arm64

- at ParazitXVpnService.onStartCommand:309 and the tunnel never opened.
- Same defect affected v0.6.4, v0.6.1, etc. — it just hadn't been
- exercised on a clean install before.

- Stop ignoring android/app/src/main/jniLibs/ and check the prebuilt
- relay binary in for both arm64-v8a and armeabi-v7a. Source build
- instructions stay in docs/parazitx/relay-build.md (manually rebuilt
- and copied in until setup.dart / CI grow a relay-build step).

- Sha256:
-   arm64-v8a/libparazitx-relay.so  8924be67260541… (10.7 MB, Apr 30)
-   armeabi-v7a/libparazitx-relay.so 91cff0f6bdf798… (15.5 MB, Apr 24)

- android/core/src/main/jniLibs/ stays ignored — that one is fully
- generated by setup.dart on every build.

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- docs(parazitx/operator-guide): YC relay is required for RU networks, fix Remnawave header docs

- The previous wording marked the Yandex API Gateway relay as 'optional,
- useful inside Russia'. That is misleading: ТСПУ whitelists drop direct
- HTTPS to node:3478, and `*.yandexcloud.net` is one of the few HTTPS
- zones that survive the filter. Without an https-session relay in front,
- nodes are unreachable for the actual target audience. Reframed as a
- hard requirement, with a banner near the top of the guide and an
- extended smoke test that verifies the relay path explicitly.

- Also corrected the Remnawave subscription section: ParazitX overrides
- are configured via Hosts custom response headers in the Remnawave admin
- UI, not in any `provider_headers:` YAML. Listed the recognised header
- names and the three deployment patterns (server-only, pin-all, private
- manifest) without suggesting a fictional config file format.

- No code or app behavior change.

- Update changelog

## v0.6.5

- release(v0.6.5): VK Звонки UX overhaul + theme HEX picker

- - Lumina-aligned VK Звонки screen with primary CTA, widened state
-   indication (idle/syncing/verification/connecting/protected/error),
-   Google Play- and RU-law-safe copy
- - HEX input on the custom theme color dialog with #RRGGBB / RRGGBB /
-   #RGB / RGB validation
- - Horizontal swipe between dashboard and tools on mobile
- - Pull-to-refresh on the Profiles tab now updates the current profile
-   regardless of ProfileType (post-migration url-stripping bug)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(subscription): pull-to-refresh updates current profile regardless of ProfileType

- After URL-encryption migration `Profile.url` is stripped to '' in
- memory and the real URL lives in the encrypted store, so the
- `url.isEmpty ? file : url` getter reports `ProfileType.file` for
- every URL subscription post-migration. The earlier "if file → return"
- guard therefore silently no-op'd every refresh on real users, which
- the user reported as a broken pull-to-refresh on the Profiles tab.

- Drop the `type` branch entirely. `Profile.update()` resolves the URL
- lazily from secure storage and throws if it genuinely doesn't exist —
- the same error path we already surface through `globalState.showMessage`.
- File-only profiles surface a clean error rather than swallowing the
- gesture.

- fix(subscription): pull-to-refresh works for file-type current profile

- When the current profile is local-file (no remote source), the early
- return left the RefreshIndicator briefly spinning with no visible
- effect — the user reported pulling on the Profiles tab and the UI
- just snapped back. Now we fall back to refreshing every other remote
- profile, and surface a short notifier when every profile is local
- instead of letting the gesture vanish silently.

- feat(home, subscription): horizontal swipe between dashboard and tools, smarter pull-to-refresh

- - Mobile only: `_HomePageView.PageView` switches from
-   `NeverScrollableScrollPhysics` to `PageScrollPhysics` so users can
-   swipe between dashboard and settings. `onPageChanged` syncs
-   `currentPageLabelProvider` via `globalState.appController.toPage`
-   in a post-frame callback, with a guard against the
-   swipe -> toPage -> animate -> onPageChanged feedback loop.
-   Desktop/tablet stay sidebar-driven; physics fall back to
-   `NeverScrollableScrollPhysics`.

- - `SubscriptionPage` pull-to-refresh now updates the currently open
-   profile when one exists, so swiping down on the profile screen
-   refreshes the active subscription instead of crawling through every
-   saved profile. Multi-profile fallback is preserved when there is no
-   current profile (first-time setup, just-deleted active, etc.).
-   File-type profiles short-circuit to avoid an infinite spinner; errors
-   reset `isUpdating` and surface through `globalState.showMessage`
-   exactly like the batch path.

- feat(theme): HEX input in custom palette dialog

- Add an opaque-only HEX input to the theme color picker:
- - accept #RRGGBB / RRGGBB / #RGB / RGB, case-insensitive, trimmed,
-   alpha forced to 0xFF
- - live two-way sync between the palette and the text field, guarded
-   against feedback loops mid-drag
- - confirm disabled while invalid; "Введите HEX цвет" inline error
- - newly added custom color is auto-selected as primaryColor so apply
-   reflects everywhere without a second tap on the swatch

- Pure parseHexColor helper is exported for testing and covered by 11
- unit cases.

- feat(vk-calls): Lumina-aligned VK Звонки screen with primary CTA

- Redesign the ParazitX page as a Google Play- and RU-law-safe "VK
- Звонки" screen: hero state card, full-width primary CTA, footer
- diagnostics, no settings switch row on the standalone page. Widen
- status indication into idle / syncing / verification / connecting /
- protected / error and override hero from ParazitXManager.isActive so
- it stays consistent with the CTA after hot restart. Drop the
- obstructive cookie banner from VkLoginScreen and the redundant
- "Параметры" panel. Sanitize visible copy: no internal/transport
- jargon, no bypass/whitelist wording.

- Surfaces use Lumina.glass / radii / curve and inherit theme colors.
- The standalone page renders ParazitXSectionItem in a new primaryCta
- layout while settings keep the switch tile, sharing all activation
- logic.

- Merge pull request #2 from enkinvsh/feat/parazitx

- feat(parazitx): manifest-driven discovery, configurable MTU, log uploader fallback
- docs(parazitx): relay build and self-hosted operator guide

- feat(parazitx): log uploader uses manifest signaling relays when subscription headers absent

- feat(parazitx): manifest-driven server and signaling-relay discovery without hardcoded endpoints

- feat(parazitx): make VpnService MTU configurable with safe default 1280

- feat(parazitx): manifest signaling_relays model with https-session and https-passthrough kinds

- chore: ignore .sisyphus orchestration scratch

- fix(parazitx): stabilize tunnel handoff overlay

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(parazitx): prefer canary backend during activation

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(parazitx): add canary manifest utilities

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- perf: localize magic rings repaint area

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- perf: move dashboard animation sync out of build

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- perf: avoid chart animation churn

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- perf: reduce navigation and proxy rebuilds

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- perf: narrow derived state watches

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- Update changelog

## v0.6.4

- release(v0.6.4): mobile-only parazitx build

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat: force mobile portrait layout

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix: anchor magic rings to connect button

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat: deep navigation + visual status feedback

- 1. Deep navigation from notification tap:
-    - Intent extra 'route' → EventChannel → Flutter navigation
-    - Handles cold start (onCreate) and warm start (onNewIntent)
-    - Tap notification → navigates to ParazitX page

- 2. Visual connection status (NordVPN-style):
-    - 4 user-visible states: idle/connecting/verifying/protected/error
-    - Animated crossfade (200ms) + color-coded dot
-    - Progress indicator during connection phases
-    - No technical jargon exposed to user

- fix: show notification directly from MainActivity (cross-process fix)

- Broadcasts from main process don't reach VpnService in :parazitx process
- due to RECEIVER_NOT_EXPORTED. Show notification directly via
- NotificationManager instead.

- feat: predictive captcha notification with background-aware timing

- - Add WidgetsBindingObserver to detect foreground/background state
- - Show notification after 2s in background (WebView throttled anyway)
- - Keep 10s delay in foreground (auto-solve usually works)
- - Restart auto-solve when app returns to foreground with pending captcha
- - Add fullScreenIntent for locked screen notifications (like incoming call)
- - Add USE_FULL_SCREEN_INTENT permission in AndroidManifest

- fix: use split routes universally for localhost VPN bypass

- excludeRoute() on API 33+ was tested but caused establish() to fail
- on Android 16 (SDK 36). Split tunneling with 8 CIDR routes works
- on all Android versions.

- Routes cover 0.0.0.0/0 minus 127.0.0.0/8, allowing WebView to reach
- localhost captcha proxy while VPN is active.

- fix: exclude localhost from VPN routing (Oracle-reviewed)

- - Remove useless WebView package exclusions (they run in-process)
- - Add applyAllowedRoutes() helper:
-   - API 33+: excludeRoute(IpPrefix) for 127.0.0.0/8
-   - API <33: 8 CIDR routes covering 0.0.0.0/0 minus 127.0.0.0/8
- - Add logging for establish() failures

- This allows WebView to reach localhost captcha proxy during VPN rotation.

- fix: remove Chrome from VPN exclusions - only WebView components should bypass

- fix: exclude WebView packages from VPN to fix rotation captcha

- WebView runs in separate process (com.google.android.webview) which
- was not excluded from VPN routing. During rotation, captcha WebView
- tried to reach localhost:PORT via VPN tunnel, causing ERR_CONNECTION_REFUSED.

- Now excludes: webview, chrome, trichromelibrary packages.

- feat: auto-solve VK captcha via headless WebView

- - Add HeadlessInAppWebView to click checkbox automatically
- - Multiple selectors with retry every 250ms for 10s
- - Listen to relay status for cleanup
- - 30s hard timeout as safety net
- - Manual CaptchaScreen preserved as fallback
- - Rotation interval back to 8 minutes

- feat: enable hybrid DC mode and increase rotation to 60 min

- - Switch tunnelMode from 'video' to 'dc' for higher bandwidth
- - Increase rotation interval from 10 to 60 minutes
- - DC mode: ~5 Mbps vs ~2-3 Mbps in pure video mode

- feat(tile): sync Quick Settings tile with ParazitX state

- - Listen to ParazitX cross-process broadcasts (BROADCAST_STATUS)
- - Show ACTIVE when TUNNEL_CONNECTED/TUNNEL_ACTIVE
- - Show UNAVAILABLE when connecting (READY, CONNECTING, CAPTCHA, etc.)
- - Fallback to mihomo state when ParazitX is off
- - Tap to stop ParazitX (start requires MainActivity for VK login)
- - Ignore taps during handshake to prevent teardown

- feat(parazitx): exponential backoff for auto-reconnect

- Replace fixed 2s debounce with exponential backoff:
- - Sequence: 2s → 4s → 8s → 16s → 32s → 60s (capped)
- - Reset to 2s on successful tunnel connection
- - Log current delay and attempt number for debugging

- Inspired by Lionheart reconnect patterns.

- fix(parazitx): fix auto-reconnect not triggering after tunnel loss

- The reconnect logic was checking if _currentJoinLink == null after
- _rotateCall(), but _currentJoinLink was never cleared on failure.
- This caused the fallback to full reactivate() to never trigger.

- Fix: Clear _currentJoinLink before rotation attempt, restore on failure.

- Also added logging for better debugging:
- - Auto-reconnect: attempting new session
- - Reconnect: rotation failed, trying full reactivate
- - Rotation successful, new call started

- feat: YC proxy fallback + toggle state fix

- - Add Yandex.Cloud proxy fallback for TSPU whitelist hours
- - parazitx_manager: try direct (3s), then YC proxy (30s)
- - log_uploader: same fallback logic for log uploads
- - application_setting: show 'Connecting...' when tunnel drops
-   instead of staying stuck on 'Active'

- feat: add WakeLock, remote logging, and captcha proxy fix

- - Add WAKE_LOCK permission and PARTIAL_WAKE_LOCK in ParazitXVpnService
-   to prevent Android from freezing the VPN process when screen is off
- - Add remote logging (log_buffer.dart, log_uploader.dart) for debugging
-   user issues - logs can be sent to callfactory /v1/logs endpoint
- - Update relay binary with captcha proxy fix (IP resolution skip)
- - Fix captcha modal closing on CAPTCHA status

- fix(parazitx): dismiss handoff modal when captcha required

- Handoff modal was blocking captcha input. Now closes modal on CAPTCHA status
- and only shows it after captcha solved or tunnel ready.

## v0.6.1

- refactor(parazitx): move relay to VpnService process

- Fixes Android freezing relay when app backgrounded.

- - ParazitXVpnService: now owns relay lifecycle, starts it in :parazitx process
- - MainActivity: removed vktunnel MethodChannel, uses BroadcastReceiver for status IPC
- - VkTunnelManager: deleted (no longer needed)
- - Dart: simplified to single start(joinLink) call

- Relay now inherits :parazitx cgroup (FGS protected), survives backgrounding.

- feat(parazitx): auto-reconnect on tunnel failure

- - Dart: add _reconnectAfterFailure() with 2s debounce when TunnelStatus.isFailure()
- - Kotlin: emit TUNNEL_LOST when relay process dies (finally block)

- feat(parazitx): server pool from subscription with 503 fallback

- - Remove hardcoded 31.57.105.213:8088
- - Read server list from dropweb-parazitx-servers header
- - Shuffle pool, try each server, fallback on 503/error
- - Port changed to 3478 (TURN mimicry)
- - deactivate() clears server cache for fresh load on next activate

- feat(parazitx): promote out of dev menu, capture input during handoff

- UI changes:
- - New ParazitX entry in main Settings list (under Connect TV), opens a
-   dedicated ParazitX page grouped under 'VK Звонки' header so future
-   transports (Sber Jazz, etc.) slot in next to it.
- - Removed the redundant 'ParazitX / Обход whitelist через VK' header
-   from the section — toggle and 'Logout from VK' stand on their own
-   inside the page.
- - Removed the entry from the developer menu.
- - l10n strings (en/ru): parazitx, parazitxDesc.

- Black-screen fix on resume:
- - ParazitXPage grabs input the moment the captcha is solved (not at
-   TUNNEL_CONNECTED): a non-dismissible modal with a spinner is shown
-   via showDialog(useRootNavigator: true) on the next frame, so the
-   user cannot tap the tab bar / back / list during the WebRTC
-   handshake + Android network handoff window.
- - Posting the dialog from addPostFrameCallback gives CaptchaScreen a
-   chance to actually pop first; both listen to the same status, but
-   if we showDialog in the same microtask Captcha's pop dismisses our
-   dialog with it.
- - After TUNNEL_CONNECTED we still wait 2s for the tun establish() and
-   Android route reshuffle to settle, then dismiss the modal,
-   popUntil-isFirst, and toPage(Dashboard). Same path the user takes
-   manually — and that path was the only one that didn't EGL-crash
-   Impeller on the next resume.
- - CaptchaScreen now closes on 'Captcha solved' (or any failure)
-   instead of waiting for TUNNEL_CONNECTED, so the modal can take over
-   immediately.

- fix(parazitx): tunnel handoff stable, captcha auto-closes

- Three race/lifecycle fixes that together make the toggle reach
- TUNNEL_CONNECTED and bring up the VpnService without a black screen
- on resume:

- - Shared broadcast bus for VkTunnelPlugin.statusStream. Native
-   EventChannel keeps a single StreamHandler, so a second listener
-   (CaptchaScreen) was silently stealing events from ParazitXManager.
-   ParazitXManager then never saw TUNNEL_CONNECTED and tun2socks
-   never started. Bus fans one native subscription out to many.

- - ParazitXManager now does a one-shot status poll right after
-   subscribing, in case librelay emitted TUNNEL_CONNECTED before the
-   Dart listener attached (fast path, cached anonymous token).
-   _startVpnLayer guards against double-start.

- - CaptchaScreen waits for TUNNEL_CONNECTED before closing (not for
-   the intermediate 'Captcha solved, retrying...'), then ParazitX
-   section pops back to the dashboard. Tearing down the InAppWebView
-   before VpnService triggers Android's network handoff avoids
-   EGL_BAD_ACCESS on the next resume.

- feat(parazitx): VK WebRTC tunnel as standalone VPN mode

- End-to-end working transport layer that tunnels traffic through a VK
- video call to bypass TSPU whitelist on LTE/MTS. Autonomous VPN mode,
- independent from mihomo (Android allows only one VpnService at a time).

- Tunnel pipeline:
-   librelay (vk-headless-joiner)        — SOCKS5 :1080, VK auth, WebRTC
-   ParazitXVpnService + Androidbind      — tun2socks forwards tun -> SOCKS5
-   keksx callfactory creator peer        — exits to internet

- Native components:
- - libparazitx-relay.so in jniLibs (Go binary from kulikov0/whitelist-bypass)
- - mobile.aar bundles gomobile androidbind.Androidbind tun2socks
- - ParazitXRelayController runs librelay via ProcessBuilder, stdin/stdout
-   protocol (AUTH:, RESOLVE:, STATUS:, CAPTCHA:)
- - ParazitXVpnService builds tun 172.19.0.1/30 with self-exclusion so
-   librelay's WebSocket reaches VK SFU via underlying network, then calls
-   Androidbind.startTun2Socks (non-blocking; spawns goroutines)

- Dart layer:
- - VkAuthService + VkLoginScreen capture VK session cookies via WebView
- - CryptoService encrypts cookies (ECDH X25519 + AES-256-GCM) before POST
-   to callfactory — server keypair is pre-shared
- - CaptchaScreen handles VK's anonymous-token captcha via local HTTP proxy
- - ParazitXManager drives activation: POST callfactory -> spawn librelay
-   -> wait TUNNEL_CONNECTED -> bring up ParazitXVpnService
- - Optimistic toggle with typed ActivateError for SnackBar feedback
- - Mihomo VPN is stopped before ParazitX starts via a confirmation dialog

- Known issue:
- - Black screen on Pixel 10 when backgrounding + resuming with ParazitX
-   active. EGL_BAD_ACCESS from libEGL / Impeller GLES. Investigation in
-   progress — likely needs upstream FlClash approach of separating the
-   VPN core into its own Android process.

- 2ip.ru verified: traffic exits through keksx (Helsinki) with tunnel up.

## v0.6.0-beta3

- release(v0.6.0-beta3): Win32 WM_SIZING hook — actually cap window width

- Beta2 was wrong. window_manager.setMaximumSize() doesn't work on frameless
- windows because the plugin's own WM_SIZING handler ignores maximum_size_.
- Beta2 hooked WM_GETMINMAXINFO only, which is skipped on some Windows 11
- borderless configurations.

- Beta3: hook WM_SIZING in windows/runner/flutter_window.cpp BEFORE
- Flutter's plugin handler. Mutate the proposed RECT on every drag tick
- based on which edge the user is dragging. This is the canonical Win32
- pattern and works regardless of plugin behavior.

- Kept WM_GETMINMAXINFO as fallback for fresh-start + programmatic moves.

## v0.6.0-beta2

- release(v0.6.0-beta2): hotfix Windows width cap + installer desktop icon

- Hotfix for v0.6.0-beta1 — both Windows-specific fixes from beta1 reported
- broken by test-group users:

- - Window width still resizable past 600px (window_manager.setMaximumSize
-   unreliable on frameless windows). Fixed via Win32 WM_GETMINMAXINFO
-   hook in windows/runner/flutter_window.cpp.
- - Installer hid the desktop-icon checkbox whenever it detected an upgrade.
-   Removed the 'Check: not IsUpgradeInstallation' clause so the checkbox
-   always appears.

## v0.6.0-beta1

- release(v0.6.0-beta1): decouple dropweb from FlClashX (Windows registry + headers)

- Fixes two user-reported Windows bugs:

- Bug #1: VPN connect button disappears when the window is resized wider.
-   Root cause: bottom nav bar + connect button only render in ViewMode.mobile
-   (<=600px). Desktop/laptop layouts have no connect button.
-   Fix: clamp window max width to 600px via window_manager.

- Bug #2: dropweb 'steals' FlClashX's subscriptions + widgets on Windows.
-   Root cause: two-layer entanglement.
-     (a) Protocol.register() unconditionally overwrote HKCU\\Software\\Classes
-         \\flclash and \\clashx, hijacking deep-link handlers that belong
-         to FlClashX.
-     (b) Subscription parser accepted HTTP response headers with flclashx-*
-         prefix - so any Remnawave panel serving FlClashX-targeted layouts
-         would apply them to dropweb too.
-   Fix: hard decouple both layers.
-     - flclash:// and clashx:// now registered with onlyIfMissing=true.
-     - One-time migration removes our existing claims on shared schemes.
-     - Remnawave header parser now accepts ONLY dropweb-* prefix.
-     - Uninstaller conditionally removes shared scheme handlers.

- BREAKING: Remnawave panel (cab.dropweb.space) and @dropwebpay_bot must be
- updated in the same release window to emit dropweb-* headers and
- dropweb:// links. Legacy flclashx-* is silently ignored.

- TG notifications disabled for this release (notify_telegram.py still
- posts as FlClashX - separate rebrand task).

- See .sisyphus/plans/2026-04-20-flclashx-hard-decouple.md for full plan.

## v0.5.2

- release(v0.5.2): macOS tray popover size + magic rings on resize

- - fix(macos): pin NSPopover preferredContentSize to 375×600. Without it
-   the Flutter view pushed the popover to grow vertically (observed at
-   ~1180 px on user's tray) — autoresizingMask alone wasn't enough.

- - fix(home): MagicRings stayed at a stale anchor after window resize on
-   desktop. Added WidgetsBindingObserver to _ConnectCircle so position
-   is re-reported via didChangeMetrics after the layout settles.

## v0.5.1

- release(v0.5.1): juicy easter-egg + drop-zone fix

- - feat(about): full game-feel pass on File Transfer easter egg
-   - wandering target (Lissajous, ×1.6 amp / ×1.8 freq on drag)
-   - SHRINKING target: drop zone collapses from full-height to a 220dp
-     square when a drag starts — surrounding space becomes miss zone
-   - anti-drag ping taunts cycling every 1.1s, with an escalating
-     dread set for kinvsh ('НЕТ', 'умоляю', 'это конец')
-   - success: animated progress, 14-particle confetti via CustomPainter,
-     zone pulse, '+1 shipped' float-up, medium haptic
-   - failure: shard burst via same painter + heavy haptic at drop point
-   - SURPRISE A (chen boomerang): first 'successful' chen08209 drop is
-     a fakeout — card returns, progress rolls back to 0, try again
-   - SURPRISE B (kinvsh ghost counter): '9 из 9' morphs through
-     '9 из 13 / 9 из ∞ / ? из ?' while kinvsh hovers the drop zone
-   - SURPRISE C (kinvsh glitch exit): 4 black/red flashes + fake
-     terminal stack trace before handleExit() — ~1.5s of drama

- - fix(game): AnimatedContainer crashed with 'Cannot interpolate between
-   finite and unbounded constraints' when animating width/height between
-   double.infinity and 220. Wrapped drop zone in LayoutBuilder and
-   animate between two resolved finite numbers, with fallback 360/480
-   for the first layout pass.

- fix(about+nav): repo URL, header tap zones, easter-egg moved to nav-bar

- - fix: repository constant was 'enkinvsh/dropweb-app' but the actual
-   GitHub repo is 'enkinvsh/dropweb' — broke About 'Проект' link, the
-   in-app update checker, and release page redirects.

- - perf(home): _ConnectCircle._scheduleTracking was an infinite
-   addPostFrameCallback running every frame on Dashboard
-   (findRenderObject + localToGlobal + ValueNotifier write each tick).
-   The button doesn't move while Dashboard is alive — report position
-   once in initState and again after didChangeDependencies for
-   orientation / insets shifts.

- - fix(home): dev-mode no longer activates accidentally. Counter for
-   '5 taps on Settings' now resets on any non-Tools nav-bar tap, so
-   Dashboard↔Tools bouncing can't unlock it.

- - feat(home): easter-egg game moved off the About page. 10 rapid
-   consecutive taps on the Dashboard nav-bar entry now launch the File
-   Transfer game. Tools/Dashboard counters are mutually exclusive
-   (tapping Tools resets egg counter and vice versa).

- - refactor(about): drop _EasterEggDetector wrapper from the header
-   since the trigger lives in the nav-bar now. Header keeps the 3D
-   flip and three discrete tap zones (avatar=flip, name=link,
-   subtitle=link).

- - fix(tools): bottom padding on the settings list was 20px while the
-   floating nav-bar takes ~80px + system insets, hiding the last item
-   once dev-mode unlocks extra entries. Now uses 96 + viewPadding.bottom.

## v0.5.0

- refine(about): simplify structure, hide kinvsh behind logo flip

- - feat: 3D flip on logo+name tap → swaps dropweb↔kinvsh with author avatar
- - refactor: Благодарность reduced to one menu item that opens credits sheet
-   (no parade of avatars on main About page); kinvsh excluded from the sheet
-   since he's already the flip-side of the logo
- - fix: restore missing assets/images/icon.png (removed in 61fe7c0 'remove
-   unused legacy brand assets' but still referenced by About + sidebar +
-   launcher config)
- - feat: easter-egg drag-and-drop game — 10 taps on header opens it,
-   move contributor cards one-by-one to shipped/, final kinvsh drop
-   closes the app via appController.handleExit() (can't ship yourself)
- - docs: changelog rewrite to match final v0.5.0 behaviour

- release(v0.5.0): fix Dashboard→Settings stutter, clean up About, hidden credits egg

- - perf(tools): move Keystore IPC out of _TvItem.build() into initState
-   via ref.listenManual. Eliminates 335ms frame spike during page
-   transitions (Pixel 10, debug: p99 335→15ms, slow frames 19%→6%).

- - refactor(about): drop three legacy contributors/thanks/gratitude
-   sections inherited from upstream forks. Public About now shows just
-   logo, version, core, description and links.

- - fix(about): remove in-app 'Check for updates' on Android (Play Store
-   policy forbids it). Retained for desktop builds.

- - fix(about): fix stale repo links — originalRepository now points to
-   pluralplay/FlClashX (our direct upstream, not chen08209/FlClash),
-   core points to MetaCubeX/mihomo (real VPN engine, not the fork).

- - feat(about): hidden credits via File Transfer Manager easter egg.
-   Ten taps on the logo reveal a credits roll disguised as a file
-   transfer: each 'file' is actually a contributor with avatar and role,
-   in order chen08209 → pluralplay → ... → enkinvsh. Transfer hangs
-   forever on the last one.

## v0.4.5

- release(v0.4.5): consolidate splash-hang fix, rebrand repo dropweb-app → dropweb

- Consolidates the real splash-hang fix (file_logger infinite microtask
- loop, see lib/common/file_logger.dart) into a single v0.4.5 release.
- All previous v0.4.5 → v0.4.18 tags/releases were red herrings chasing
- Impeller, Flutter version, plugin lifecycle, and savedInstanceState —
- none of which were the actual bug. The whole timeline rolls into this
- single release under its proper version.

- Also renames the repository: enkinvsh/dropweb-app → enkinvsh/dropweb.
- Updated README.md, README_EN.md, and .github/release_template.md.
- GitHub preserves a redirect from the old URL.

- Update changelog

- fix(fatal): splash hang — file_logger infinite microtask loop

- ROOT CAUSE FOUND via Dart VM service getStack on a live hung debug build:

-     0  verifiedLocale @ intl_helpers.dart
-     1  verifiedLocale @ intl_helpers.dart
-     2  DateFormat @ date_format.dart
-     3  _getTodayDate @ file_logger.dart:52
-     4  _getCurrentLogFile @ file_logger.dart
-     5  _ensureSink @ file_logger.dart
-     6  _processQueue @ file_logger.dart:170
-     7  _processQueue @ file_logger.dart:188   <-- recursive retry
-     ... runBinary / handleError / _propagateToListeners / _completeErrorObject
-     ... runBinary / handleError / _propagateToListeners / _completeErrorObject
-     _microtaskLoop
-     _startMicrotaskLoop

- DateFormat('yyyy-MM-dd') with no explicit locale falls through to
- Intl.systemLocale, and during early cold start (before locale data is
- loaded) it throws in intl_helpers.verifiedLocale.

- _processQueue catches this silently and then checks if queue is non-empty
- and recursively schedules itself via unawaited(_processQueue()). Since
- every log message entering the queue re-triggers the same throw, the
- microtask loop runs forever. Microtasks have higher priority than event
- loop tasks, so runApp's scheduleAttachRootWidget never fires, and the
- splash screen sits on DRAW_PENDING indefinitely.

- Why post-reboot specifically: on warm start _service logs less and the
- race loses, but on cold start after reboot the service isolate floods
- commonPrint.log() calls (dns handshake, socks port init, service ready
- signaling) before the main isolate has a chance to schedule its first
- runApp frame. The queue saturates, the recursive retry wedges main.

- Explains every symptom seen across v0.4.5 → v0.4.17:
- - Post-reboot / cold-start specific (locale data not yet loaded)
- - All devices (Pixel 5, 10) — not a hardware issue
- - Impeller/Flutter-bump 'fixes' worked by accident (changed timing
-   enough that locale loaded before first log)
- - 10 previous tags churning around plugin lifecycle were all red herrings

- Fix:
- 1. Replace DateFormat with manual ISO string formatting for both date
-    and timestamp. No locale dependency.
- 2. On sink failure, drop the queue instead of retrying the same broken
-    sink — infinite retry on persistent errors is never correct anyway.

- Verified fix on live debug build via flutter run + Dart VM service:
- after hot-restart with these changes, Application.initState fires,
- UI renders, subscription card visible, VPN toggle button present.

- Bumps version to 0.4.18.

- diag: add granular [MAIN] and [APP] tracing around runApp

- Live logcat from v0.4.16 after force-stop+relaunch under memory pressure
- shows main isolate reaches '[MAIN] globalState.initApp done' and then
- goes silent — splash still hangs. The remaining code before runApp and
- inside Application.initState was untraced.

- This release adds debugPrint at every step from globalState.initApp
- completion through runApp return, and at every step of Application.initState
- including the postFrameCallback. Next repro will pinpoint exact line.

- Not a fix, just instrumentation. Bumps version to 0.4.17.

- Update changelog

- fix(android): discard stale savedInstanceState post-reboot

- Actual root cause of post-reboot splash hang (reproducible on Pixel 5 and
- Pixel 10, not device-specific):

- Android keeps our Task persistent across reboots (isPersistable=true,
- mNeverRelinquishIdentity=true by default for singleTop launcher Activity).
- After reboot, launcher does LAUNCH_SINGLE_TOP on the saved Task, and Android
- passes a savedInstanceState Bundle from the pre-reboot process into the
- freshly-forked MainActivity.onCreate. FlutterActivity.onCreate then tries
- to restore FlutterEngine state from that Bundle — but the engine it
- references no longer exists (process was killed). Restoration path
- blocks in native code indefinitely.

- Logcat evidence: wm_on_create_called/wm_on_resume_called fire normally,
- but no Impeller/flutter/Dart logs ever appear. Main thread sits at R(running)
- in userspace, CPU burned but no forward progress for minutes.

- Fix: pass null to super.onCreate. We don't use Flutter's restoration API
- (no RestorationScope / restorationId anywhere), so there's nothing to
- recover. Fresh engine boot every cold-start is what we want anyway.

- Bumps version to 0.4.16.

- Update changelog

- fix(android): ServicePlugin.init — post initServiceEngine, don't block channel call

- v0.4.14 didn't fix splash hang. Stack trace from Log.w(Throwable) on live
- device deobfuscated via R8 mapping:

-     GlobalState.initServiceEngine() (from Throwable at line 156)
-     ServicePlugin.onMethodCall("init") at ServicePlugin.kt:40
-     (invoked via MethodChannel "service" from Dart main isolate)

- Cold-start flow:

- 1. lib/main.dart main() runs: await clashCore.preload()
- 2. ClashCore._internal() instantiates clashLib (lazy) → ClashLib._internal()
- 3. ClashLib._internal() synchronously calls _initService()
- 4. _initService() calls await service?.init() → platform channel 'init'
- 5. ServicePlugin.onMethodCall("init") calls GlobalState.initServiceEngine()
-    synchronously, which runs runLock.withLock { executeDartEntrypoint(_service) }
-    on the Android platform thread.
- 6. While the platform thread is busy bootstrapping the service Dart VM,
-    main engine never gets a chance to progress its own Dart isolate.
-    MainActivity surface stays DRAW_PENDING, splash stuck with 'db' logo.

- Fix: post initServiceEngine onto the next main looper tick so the
- platform channel 'init' call returns immediately. result.success(true)
- fires synchronously, Dart main isolate keeps running, clashCore.preload()
- awaits its handshake, and on the next looper tick the service engine
- bootstraps without starving the platform thread.

- Also adds [MAIN] diagnostic logs to lib/main.dart so we can confirm where
- main isolate is progressing (previously had ZERO logs from main() in
- production logcat — impossible to tell if it was blocked or not running
- at all). v0.4.14's GlobalState defer guard stays in place: it's a belt-
- and-braces defense for any other caller that might hit the same path
- (AppPlugin.onActivityResult on VPN_PERMISSION_REQUEST_CODE, tile quick-
- start). Bumps version to 0.4.15.

- Update changelog

- fix(android): defer initServiceEngine when main engine is alive

- Root cause of post-reboot/cold-start splash hang found via live logcat on
- v0.4.13 (Pixel 10): something triggers GlobalState.initServiceEngine() on
- the platform thread during MainActivity.onCreate, BEFORE FlutterActivity
- schedules main FlutterEngine's default Dart entrypoint. The synchronous
- serviceEngine.dartExecutor.executeDartEntrypoint(_service) call under
- runLock starves the platform thread, main engine's Dart main() never
- starts, and the splash screen sits with mDrawState=DRAW_PENDING forever.

- Symptoms in logcat (v0.4.13, fresh cold start, no VPN active):
- - TilePlugin.onAttachedToEngine fires twice (main + service)
- - 16x "plugin already registered" warnings
- - ConnectivityManager: NetworkCallback was already registered (ERROR)
- - _service entrypoint runs to completion
- - NOT a single log line from lib/main.dart's main() entrypoint
- - splash window HAS_DRAWN, MainActivity surface DRAW_PENDING for minutes

- Fix: when MainActivity's flutterEngine is already alive, post the service
- engine init onto the next main looper cycle instead of running it
- synchronously. This lets FlutterActivity's pending runnables (including
- main engine's executeDartEntrypoint) drain first. Service engine still
- gets created — VPN connect path (AppPlugin.onActivityResult RESULT_OK,
- DropwebVpnService.onCreate, GlobalState.handleStart with no TilePlugin)
- keeps working, just one looper tick later.

- Also adds a Throwable to the deferred-path log so the next reproduction
- will tell us WHICH callsite is firing initServiceEngine on cold-start —
- the four known callers (handleStart, AppPlugin.onActivityResult,
- ServicePlugin.onMethodCall("init"), DropwebVpnService.onCreate) all
- showed no preceding log line in the captured trace, so the trigger
- remains to be confirmed.

- Bumps version to 0.4.14.

- Update changelog

- fix(android): re-enable Impeller — disabling it broke post-reboot launch

- Diff against last-known-working v0.4.4 showed I'd flipped
- EnableImpeller from \"true\" to \"false\" with a comment claiming
- two FlutterEngine instances couldn't share Vulkan. That comment
- was wrong: upstream FlClashX has been on Impeller=true since
- 2025-09-11 with no issue.

- On Pixel 10 with an active VPN profile, the Skia GLES backend
- fails Surface init after a cold device boot. UI never renders,
- which is exactly the splash hang every CI 0.4.7→0.4.12 build
- reproduced. Local builds happened to work because Gradle still
- had warm OpenGL ES context state from prior `flutter run` debug
- sessions; they reproduced reliably only after a real reboot.

- Reverting to Impeller=true matches upstream and resolves the
- hang. The trade-off (custom shaders silently fail on Impeller's
- GLES backend) is documented in the dropweb skill and not in play
- for our current asset set.

- fix(ci): bump Flutter to 3.41.6 — 3.32.8 causes post-reboot splash hang

- CI was pinned to Flutter 3.32.8 (Dec 2024). Local builds against
- 3.41.6 do not reproduce the post-reboot splash hang with an active
- VPN profile; CI-built 0.4.11 APKs hang consistently. Diff was
- traced to this single line after confirming Go 1.24 produces an
- identical-size libclash.so either way.

- Bump to 3.41.6 (3 weeks old stable) to match the local toolchain
- and unblock release. Also drop the diagnostic `[MAIN]` traces from
- main.dart now that the splash-hang path has been isolated.

- Update changelog

- chore: bump version to 0.4.11

- chore: drop diagnostic [MAIN] tracing + bump 0.4.11

- Splash hang confirmed fixed on-device (double reboot + active profile +
- active VPN → clean UI render). Ship a clean 0.4.11 without the debug
- logging that helped locate the issue.

- docs: add Telegram discussion forum link

- docs: fix FlClashX link — point to pluralplay/FlClashX, not chen08209/FlClash

- Description said "Fork of FlClashX" but linked to chen08209/FlClash,
- which is FlClash (no X). Our real parent is pluralplay/FlClashX.
- Link both: FlClashX as the parent fork we sync from, FlClash as the
- original project the whole chain descends from.

- chore: trim verbose comments + bump 0.4.10

- Strip narrative comments from this session's commits — keep only those
- explaining non-obvious security/perf decisions or upstream-inherited
- rationale. Drop the diagnostic [MAIN] tracing now that the splash hang
- is fixed and the logging served its purpose.

- diag: add startup tracing to track post-reboot splash hang

- main.dart: log every step of main() so we can see exactly where the
- main isolate stops in the (still-occurring) post-reboot splash hang.
- Logs fire for: start, system.version, preload(), initApp, android.init,
- window.init, vpn singleton, runApp.

- GlobalState.initServiceEngine: log a Throwable to capture the call
- site. This already proved the service engine is born from
- ServicePlugin.onMethodCall (Dart main isolate calling service.init()
- inside ClashLib._initService) — not from VpnService restoration.

- These print through commonPrint.log → debugPrint, which keeps showing
- up in release logcat as I/flutter, so they are visible without a debug
- build.

- Verified on Pixel 10: fresh install of the release APK now traces
- all main-isolate steps and renders the UI (Surface HAS_DRAWN).
- Awaiting on-device reboot test with an active profile to capture the
- hang scenario.

- fix(android): revert proguard-rules.pro to upstream (1 line)

- ROOT CAUSE of the post-reboot splash hang, found after running
- flutter run on debug and seeing main isolate log everything it's
- supposed to. Debug build works fine. Release build hangs. The only
- release-specific thing I'd touched was ProGuard / R8.

- My previous 85-line proguard-rules.pro (commit dbdd8b6 as part of
- "security harden") stripped logs in release:

-   -assumenosideeffects class android.util.Log {
-       public static int v(...);
-       public static int d(...);
-   }

- That tells R8 "Log.v and Log.d are pure, their arguments don't need
- to be evaluated". In practice it deletes ANY code passed as an
- argument. Flutter's embedding has Log.d calls where the argument
- is an expression with side effects during engine startup — R8
- drops the side effect, engine init is now skipped, and the Dart
- main() never fires. Splash stays forever.

- Upstream pluralplay/FlClashX ships a one-line proguard-rules.pro:

-   -keep class com.follow.clashx.models.**{ *; }

- Everything else is left to Flutter's default rules which Flutter
- Gradle plugin merges in automatically. That's it. No hardening
- needed at this layer — AAB signing and Play Store obfuscation
- already give us the defense-in-depth the custom rules were meant
- to provide.

- Fix: replace the full 85-line file with the upstream one-liner
- (adjusted to `app.dropweb.models`).

- Verified on Pixel 10: release APK (95MB, 275KB smaller than the
- previous broken build) installs and launches cleanly to the
- disclaimer screen. Debug build also works as it did before.
- Awaiting on-device reboot test with an active profile.

- fix(android): revert all my splash-hang "fixes" back to upstream baseline

- After four failed attempts at debugging the post-reboot splash hang,
- I pulled upstream pluralplay/FlClashX at 0a5afe9 and diffed. All my
- "fixes" were regressions against a baseline that works. The real
- culprit was a change I'd made but never attributed to: forcing
- START_STICKY on the VPN service.

- Changes reverted to upstream form:

- 1. DropwebVpnService: drop `onStartCommand { return START_STICKY }`.
-    Upstream FlClashXVpnService has no onStartCommand override — it
-    inherits the default (START_STICKY_COMPATIBILITY, treated as
-    START_NOT_STICKY on modern Android). My override forced the
-    service to be revived by Android after any process death,
-    including post-boot. That revival triggered GlobalState
-    .initServiceEngine() BEFORE MainActivity.onCreate ran, which
-    left the service FlutterEngine first-in-line for singleton
-    plugin attachment and broke the main engine's handshake.

- 2. VpnPlugin: `class` → `data object` (my 2bbe737 was a wrong turn).
-    ServicePlugin: same. Upstream uses singletons and the main/
-    service engine share them by design — re-attaching rebinds the
-    MethodChannel to the currently-active engine, which is correct.

- 3. MainActivity.configureFlutterEngine: restore
-    `GlobalState.syncStatus()` call (reverting cf9f2a2). Upstream
-    has this exact call and their app boots fine post-reboot; the
-    "deadlock" I theorized wasn't real.

- 4. DropwebApplication: drop the FlutterLoader.startInitialization
-    pre-warm (reverting 59c3add). Upstream doesn't do this, so it
-    was never the actual race condition fix I thought it was.

- Net diff is small: -12 lines. All that debugging, just to delete
- code I never should have written.

- Verified: release APK built, installed, launches on fresh install.
- Awaiting on-device reboot test with an active profile — the scenario
- that originally reproduced the hang.

- fix(android): pre-warm FlutterLoader in Application.onCreate

- Third attempt at the post-reboot splash hang. Logs on a hung release
- process showed:

-   - main engine created (Impeller opt-out @ T+0.45s)
-   - MainActivity window ready (VRI, T+0.54s)
-   - second engine created (Impeller opt-out @ T+0.56s) = service engine
-   - 15× FlutterEngineCxnRegstry warnings "already registered" on the
-     service engine for every pub plugin (PathProvider, SharedPrefs,
-     URL launcher, etc.)
-   - service isolate Dart reaches `[DART] Not quickStart, calling
-     _handleMainIpc` and goes idle waiting for the main isolate
-   - main isolate NEVER produces a single log line — no system.version,
-     no clashCore.preload, nothing; main() never starts

- The race: FlutterLoader.startInitialization loads libflutter.so and
- the AOT snapshot once per process. On a fresh boot that first load
- takes hundreds of ms and is traditionally done during
- FlutterActivity.onCreate on the Android UI thread. Meanwhile the
- service engine creation path (triggered from Dart IPC) calls
- FlutterLoader.startInitialization on a background thread. Both paths
- racing on the same native initializers leaves the main engine in a
- half-initialized state where its DartExecutor never fires the Dart
- entrypoint.

- Fix: call startInitialization exactly once, from Application.onCreate,
- before any engine is created. Android guarantees Application.onCreate
- runs on the UI thread before any component (Activity, Service,
- ContentProvider) sees `onCreate`. Subsequent startInitialization calls
- short-circuit because it caches state in a FlutterLoader singleton.
- This removes the race entirely.

- Still needs real post-reboot testing on a device with an active
- profile — that's the only scenario where the race reproduced.

- fix(android): convert VpnPlugin/ServicePlugin from data object to class

- REAL root cause of the post-reboot splash hang (previous attempts
- targeted symptoms, not this). Logs from a hung release build showed:

-   - Only the service engine FlutterEngine@f20dfb6 is created
-   - Main engine Dart main() never runs
-   - FlutterEngineCxnRegstry warnings: "plugin (X) already registered
-     with this FlutterEngine" — for every VpnPlugin/ServicePlugin
-     attempt on the second engine

- Flutter's plugin registry deduplicates by class instance. Attaching
- the same Kotlin `data object` (singleton) to a second engine is a
- no-op: onAttachedToEngine is NEVER called for the second engine. So:

-   1. VpnService revives post-boot (START_STICKY) → initServiceEngine
-      creates service FlutterEngine → VpnPlugin singleton attaches →
-      flutterMethodChannel bound to service engine's binaryMessenger.
-   2. User taps icon → MainActivity creates main FlutterEngine →
-      tries to register the SAME VpnPlugin singleton → registry
-      silently ignores → main engine has no `vpn` channel handler.
-   3. Dart main() runs `vpn; // init singleton` → method channel
-      call into native → no handler on main engine → suspends
-      forever. Main UI isolate never gets past that line, never
-      renders first frame, splash stays on screen.

- Fix: convert VpnPlugin and ServicePlugin to regular classes, add
- new instances per engine. Persistent state that must be shared
- across engines (bound service, vpn options, foreground-params
- cache, network subscription, timer job) moved into the Companion
- object of VpnPlugin. ServicePlugin holds no state so it was a
- straight `data object` → `class`. TilePlugin and AppPlugin were
- already classes, no changes needed.

- MainActivity.configureFlutterEngine and GlobalState.initServiceEngine
- updated to instantiate (`VpnPlugin()` / `ServicePlugin()`).

- Verified: release APK built locally, installed on Pixel 10, launches
- cleanly to the disclaimer screen on first run. Needs on-device
- reboot test with an active profile to close the loop — that's the
- scenario that originally reproduced the hang.

- fix(android): remove syncStatus deadlock from MainActivity startup

- Second splash-hang regression on post-boot with an active profile.
- `DropwebVpnService` is marked START_STICKY, so Android revives it on
- boot before the user even taps the icon. `onCreate` calls
- `GlobalState.initServiceEngine()` which attaches the singleton
- `VpnPlugin` to the service engine — binding its MethodChannel to the
- service engine's binaryMessenger.

- When the user then launches the app, `MainActivity.configureFlutterEngine`
- adds the same `VpnPlugin` data-object to the main engine. Kotlin's plugin
- registry invokes `onAttachedToEngine` again, which rebinds
- `flutterMethodChannel` to the main engine's messenger. The service
- isolate is now holding references to an unwired channel.

- Immediately after that rebind the old code called `syncStatus()` —
- which routed `flutterMethodChannel.awaitResult("status")` across a
- channel that could only be answered by the UI Dart isolate. But the UI
- Dart `main()` had not even begun executing yet; it won't register
- handlers until after `runApp`. `awaitResult` suspends forever. The
- native splash stays on screen because the UI never renders its first
- frame.

- Fix: drop the synchronous sync. The UI side already reconciles run
- state in `AppController.syncRunStateFromNative()` on
- `AppLifecycleState.resumed`, which fires after runApp and the first
- frame when all channels are properly wired.

- A comment was added inline documenting exactly why this call is
- forbidden here — this is the third time the bug has cycled through
- (b438704 fix → c920cc2 revert → this), and I'd like to stop the cycle.

- fix(android): don't block startup on Android Keystore IPC

- Symptom: after a cold device reboot the release build stays on the
- native splash forever. `dumpsys window` shows MainActivity
- `Surface shown=false mDrawState=DRAW_PENDING`, i.e. Flutter never
- produced the first frame. Debug build doesn't reproduce because its
- Keystore IPC path warms up while Gradle is still pushing the APK.

- Root cause: `preferences.getConfig()` — called synchronously on the
- critical path of `globalState.init()` before `runApp` — was fetching
- every profile's subscription URL from `flutter_secure_storage`. On
- Pixel 10 after a cold boot the Gatekeeper/Keystore daemon can take
- 10-30 s to answer the first IPC, and the call blocks the main
- isolate. No UI, no splash handoff, no timeout.

- Fix: URLs no longer live in the in-memory Config. getConfig() now
- returns the Config straight from SharedPreferences (with empty URL
- fields, which is the scrubbed-on-disk shape). Callers that actually
- need the URL read it on demand through the two new accessors on
- Preferences:
-   - `preferences.getProfileUrl(profile)`
-   - `preferences.getProfileFallbackUrl(profile)`

- Updated call sites:
-   - `Profile.update()` (subscription refresh)
-   - `EditProfileView.initState()` (populates the URL field async)
-   - `_TvItem` (Send-to-TV ListItem; now async-aware)

- Phase-9 migration (move plaintext URLs out of the JSON blob into the
- encrypted store) runs from a `WidgetsBinding.addPostFrameCallback`
- inside `AppController.init()`, AFTER the first frame, so a slow
- keystore can no longer freeze the splash. Idempotent:
- `migrateProfileUrlsIfNeeded()` exits immediately if the marker is
- already set.

- Verified on Pixel 10 debug + release builds: UI renders immediately,
- secure-storage reads happen only when the user opens a profile form
- or fires a subscription refresh. `flutter_analyze` clean on the
- touched files.

- Update changelog

- fix(android): suppress R8 warnings for unused Play Core / tika classes

- v0.4.8 CI failed at :app:minifyReleaseWithR8 with
- "Missing class com.google.android.play.core.splitcompat.SplitCompatApplication"
- and a dozen similar Play Core / tika stubs. Flutter's embedding
- references those classes for deferred components even when the feature
- is not enabled, so R8 choked when my hardened proguard-rules.pro
- (commit 2dd7106) dropped the implicit -dontwarn that the AGP-default
- rules used to carry.

- Re-add targeted `-dontwarn` for:
-   - com.google.android.play.core.** (Flutter deferred components)
-   - com.google.android.play.**      (umbrella for Play Services stubs)
-   - javax.xml.stream.**             (via transitive tika pull)
-   - org.apache.tika.**

- Runtime behaviour is unchanged — the stripped code paths are gated by
- runtime feature checks, and we don't ship the Play Core library.

- chore: bump version to 0.4.8

- fix(android): bump minSdk to 24 for flutter_secure_storage v10

- CI for v0.4.7 failed at :app:processReleaseMainManifest because the
- newly-added flutter_secure_storage 10.0.0 ships minSdkVersion=24 in
- its AndroidManifest and we were still hardcoded to 23. The merged
- manifest picks the highest min across all modules, and AGP rejected
- the mismatch instead of auto-uplifting silently.

- Bumped minSdk from 23 → 24 (Android 7.0, 2016). That's the floor
- that flutter_secure_storage v10 requires; we inherited the tighter
- requirement when Phase 9 migrated subscription URLs into the
- encrypted store. Downgrading to v9.x would drop the automatic
- Jetpack-Security→AES-GCM migration path the plugin handles for us,
- which is not worth the handful of Android 6 users.

- Also bumps pubspec to 0.4.8.

- chore: bump version to 0.4.7

- fix(android): FAB now reacts when VPN is stopped from outside the app

- The connect button used a ConsumerStatefulWidget backed by a local
- `isStart` mirror that was only updated from
- `startButtonSelectorStateProvider`. That provider's inputs
- (init/profiles/proxies) don't change when the VPN toggles, so stopping
- the tunnel via the QS tile, the foreground notification's STOP action,
- or a system revoke left the icon stuck on "stop" even though the tunnel
- was already torn down.

- Now the icon watches `runTimeProvider` directly in build(), which is
- the canonical source that TileManager.onStop resets. The breathing
- halo's ticker is driven from a post-frame callback so flipping
- AnimationController state doesn't re-enter the build phase (an earlier
- attempt to run it inline produced an ANR).

- Belt-and-braces additions:
- - AppStateManager now calls a new `syncRunStateFromNative()` on
-   AppLifecycleState.resumed. Read-only sync — it reconciles Dart-side
-   bookkeeping with the actual native runtime when the app comes back
-   without ever calling handleStart/Stop on its own.
- - TileManager.onStart/onStop log the sync event. commonPrint already
-   strips these in release via kDebugMode.

- Verified on Pixel 10: connect → notification STOP → icon flips to
- "plug" within a frame of LTE🔐 going away. No ANR, no rebuild loop.

- security: move subscription URLs to flutter_secure_storage

- Hybrid storage split: subscription URLs (plus their fallback twins) now
- live in the OS-encrypted store (Android EncryptedSharedPrefs/AES-GCM via
- Keystore, iOS Keychain, OS credential vault on desktop). Everything else
- in Config stays in SharedPreferences — cheaper, no IPC on UI reads.

- Why: subscription URLs almost always embed an auth token
- (`https://example.com/sub/<token>`). Plaintext in `shared_prefs/*.xml`
- meant anyone with root, an ADB backup, or a debug dump could harvest
- live VPN credentials.

- What changed
- - add `flutter_secure_storage: ^10.0.0` (already integrates on
-   Android/iOS/macOS/Linux/Windows; no native code here)
- - new `SecureProfileUrlStore` singleton — per-profile-id URL + fallback
- - `Preferences.saveConfig` now strips `url`/`fallbackUrl` out of the
-   Config blob before JSON-encoding to SharedPrefs, mirror-writing the
-   real values to the secure store
- - `Preferences.getConfig` rehydrates stripped profiles with values from
-   the secure store
- - One-time migration on first upgraded launch: harvest URLs already
-   sitting in SharedPrefs, copy them to the secure store, overwrite the
-   SharedPrefs blob with stripped copies, then set
-   `profile_url_migrated_v1` so we never scan plaintext again

- Verified: fresh install boots, one-time migration runs (log shows
- `Migrated 0 items` on a first-time install — expected), SOCKS port loads,
- mihomo initialises, UI renders with the real subscription label.

- perf: cache Theme.of() + debounce sticky-header scroll updates

- - widgets/scaffold.dart: _buildAppBar hit Theme.of(context) 7× per frame
-   via the InheritedWidget lookup chain. Cache theme + derived flags
-   (isDark, iconBrightness, transparentAppBar) once per build.

- - views/proxies/list.dart: ScrollController fires 60+ times/sec during a
-   scroll; we rebuilt the sticky header on every pixel. Coalesce to one
-   update per frame via addPostFrameCallback, guarded by mounted +
-   hasClients so we never touch disposed state.

- Verified on Pixel 10: dashboard renders, subscription fetch, VPN connect
- and disconnect all work; no regressions observed.

- security: harden Dart + Android surface for Play submission

- Dart:
- - http.dart: remove global cert bypass, only trust self-signed for localhost
- - system.dart: rewrite Linux sudo call — Process.start with stdin, no shell interpolation
- - request.dart: strip subscription URLs/tokens from print(), null-safe checkIp,
-   Dio timeouts (15s/15s/30s), 50 MiB size cap on profile fetches
- - controller.dart: validate profile URL (http/https only) before fetch;
-   hook PlatformDispatcher.instance.onError for isolate errors
- - state.dart: _vpnTransitionInFlight flag against double-tap start/stop race;
-   5 s timeout on service.stopVpn with graceful degradation
- - string.dart: toMd5() → SHA-256 truncated; add toSha256()
- - constant.dart: Random.secure() for unix socket path (was Mersenne Twister, 10K variants)
- - receive_profile_dialog.dart: log length only, never URLs
- - managers: async void → Future<void> (window/clash); dispose() sync + unawaited

- Android:
- - AndroidManifest: TempActivity exported=false (was open VPN toggle to any app),
-   widget receiver gets BIND_APPWIDGET, allowBackup=false,
-   data_extraction_rules.xml excludes everything, legacy flclash:// scheme removed,
-   QUERY_ALL_PACKAGES backed up by narrow <queries> block
- - file_paths.xml: scoped to configs/ + logs/ + cache/shared/ (was whole filesDir)
- - network_security_config: base cleartext=false, localhost-only exception
- - proguard-rules: full production set (services, widgets, JNI, Flutter, Kotlin, log strip)

- Misc:
- - .gitignore: local.properties, key.properties, *.keystore, signing.properties
- - pubspec: pin rationale for git-deps (re_editor, flutter_js)
- - Remove redundant Unbounded-Regular.ttf (−760 KB; Variable font covers all weights)
- - l10n: +invalidProfileUrl, +connectTv, +connectTvDesc across en/ru/ja/zh_CN

- Verified: flutter_analyze 0 errors; flutter run on Pixel 10 boots cleanly,
- subscription fetch with strict cert validation works, SOCKS protection active,
- VPN interface allocates on demand.

- fix(android): revert VpnPlugin service-engine guard — broke VPN connect

- v0.4.5 added `if (flutterEngine == null)` around VpnPlugin/AppPlugin/
- TilePlugin attachment to service engine. The intent was to avoid
- singleton VpnPlugin's MethodChannel getting rebound to service's
- binaryMessenger. In practice this broke everything:

- Service engine runs the `_service` Dart entrypoint which invokes
- MethodChannel("vpn", "start") on its own binaryMessenger. With the
- guard, those channels had no handler registered on the service engine
- side, so all MethodChannel calls from the service isolate silently
- dropped. Symptoms:
- - UI showed subscription but proxy list never loaded
- - Connect button tap did nothing (no handleStart fired)
- - Logcat went silent after save preferences

- The splash hang that guard was meant to fix was actually just an
- adb screencap quirk (native splash overlay cached in screenshot even
- after Flutter drew first frame). A real touch input removed it.

- Restore both plugin attachments. Keep Impeller=false and mesh glow.

- Update changelog

- fix(android): hardcode minSdk=23 for CI compatibility

- CI uses Flutter 3.32.8 where flutter.minSdkVersion defaults to 21.
- Core module declares minSdk=23 — Manifest merger fails with
- "minSdkVersion 21 cannot be smaller than version 23 declared in [:core]".

- Local builds on Flutter 3.41.6 worked because newer Flutter bumped
- its default to 23, masking the issue.

- chore: bump version to 0.4.5 (sync pubspec with release tag)

- fix(android): splash hang + restore bottom-right ambient glow

- Splash hang (cold-start, critical):
- - GlobalState.initServiceEngine no longer re-attaches VpnPlugin /
-   AppPlugin / TilePlugin when a MainActivity engine already owns them.
-   VpnPlugin is a Kotlin `data object` (singleton); re-attaching rebinds
-   its MethodChannel to the service engine's binaryMessenger, silently
-   breaking the UI↔native bridge and freezing the app on the launcher
-   splash screen after first resume.
- - Disabled Impeller in AndroidManifest (EnableImpeller=false). Two
-   parallel FlutterEngines (UI + VPN service) both initializing Impeller
-   Vulkan+GLES contexts caused surface creation contention on Pixel 10.
-   Custom shaders are already gone — Skia covers everything we render.

- UX:
- - MeshBackground: bottom-right tertiary glow dimmed and tightened after
-   user feedback (radius 1.8→1.3, alpha 0.42/0.18→0.28/0.10). Gives the
-   dashboard a visible but not overwhelming ambient glow in the dark
-   theme; light theme unaffected (MeshBackground short-circuits).
- - Removed the LightPillar experiment from the dashboard Stack — the
-   mesh glow is the single source of ambient light now.

- Verification: APK rebuilt, installed on Pixel 10. `AppLifecycleState
- .resumed` observed on first cold-start post-fix; splash disappears
- immediately on first touch input.

- perf(ui): fix memory leaks, cut rebuild cascades, remove dead code

- Memory leaks (3 files):
- - announce_widget, metainfo_widget, service_info_widget:
-   TapGestureRecognizer was created inline in TextSpan.recognizer and
-   never disposed — each rebuild leaked a recognizer holding callbacks
-   and context. Converted widgets to ConsumerStatefulWidget, track
-   recognizers in a List, dispose on rebuild and in dispose().

- Rebuild cascades (ProxyCard):
- - Narrowed three Consumer watches with .select() to bool predicates.
-   Sibling proxies in the same group no longer rebuild when the active
-   proxy changes — only the two cards whose selection state flipped do.
-   Applied to: _buildProxyNameText (oneline), main card Consumer,
-   _ProxyComputedMark visibility check.

- Tray CPU (Windows):
- - tray_manager._startMenuMonitor: bumped Timer.periodic from 100ms to
-   200ms (50% CPU reduction, user-imperceptible). Added debugPrint to
-   previously silent catch block. TODO noted for proper
-   SetWinEventHook event-driven implementation.

- Dead code cleanup:
- - Removed color_bends_bg.dart widget + shader asset (GLSL program has
-   been silently failing on Impeller since 2025-09-11, dashboard use
-   was commented out as a perf test). Removed shader registration from
-   pubspec.yaml and export from widgets barrel.
- - Removed commented-out ServiceMessageListener mixin, SetupParamsExt,
-   ProcessData/Fd freezed classes from models/core.dart (36 lines).
- - Removed commented CommonCardTypeExt from enum/enum.dart.
- - Removed dead corePalette conditional from providers/state.dart.

- Verification:
- - flutter analyze: 0 errors, 18 warnings, 632 infos (baseline 655).
- - Warnings/infos now concentrated in setup.dart and tool/ helpers, not
-   lib/ runtime code.

- deps(flutter_js): bump fork to 17be98e for 16KB page size alignment

- libfastdev_quickjs_runtime.so was the last native library in the APK
- with 4KB ELF LOAD alignment, triggering the Android 15+ system modal
- ('Совместимость приложений Android') on every launch on Pixel 10 and
- blocking Google Play acceptance of release builds targeting SDK 36.

- Root cause: flutter_js 0.8.3 depends on the JitPack artifact
- com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-quickjs:0.3.5,
- which was built before the 16KB page-size requirement landed. Upstream
- fast-development/android-js-runtimes shipped 0.3.6 in Sep 2025 (PR #5)
- rebuilding the QuickJS .so with -Wl,-z,max-page-size=16384.

- The enkinvsh/flutter_js fork (master) was bumped to pull 0.3.6 instead
- of 0.3.5 in commit 17be98e. This file locks dropweb-app to that commit.

- Verified: built release APK (dist/dropweb-arm64-v8a.apk), extracted
- libfastdev_quickjs_runtime.so, checked ELF p_align via python struct —
- LOAD segments now align=65536 (64KB, valid 16KB-multiple) instead of
- 4096. Installed the APK on Pixel 10, launched: no system modal appears,
- main UI renders normally. libclash.so (16KB) and libflutter.so (64KB)
- remain correctly aligned.

- feat(socks): persist random SOCKS port across app restarts

- The SOCKS protection port was regenerated on every cold start, which
- made the randomization useless for evading port-scan-based VPN detection
- (detectors care about port stability over a session, not first-launch
- entropy). Persist the port to SharedPreferences on first generation and
- reuse it on subsequent launches. Username/password are still rotated
- per-session for credential security.

- - constant.dart: add socksPortKey
- - preferences.dart: getSocksPort/saveSocksPort helpers
- - proxy_credentials.dart: generate(persistedPort:) reuses port if given
- - state.dart: load persisted port in init(), save on first generation

- Verified on Pixel 10: first launch logs 'Generated and saved new port
- 33932', subsequent launches log 'Loaded persisted port: 33932'.

- build(android): 16KB page alignment — defensive hardening

- Android 16 on Pixel 10 fires a system warning dialog claiming libclash,
- libflutter, libdatastore, camera libs are not 16KB-aligned. Reality
- check via llvm-readelf -l on the installed debug APK:

-   libclash.so                       0x4000  (16KB OK — Go already 16KB-safe)
-   libflutter.so                     0x10000 (64KB OK — Flutter 3.38+ fixed)
-   libdatastore_shared_counter.so    0x4000  (16KB OK)
-   libimage_processing_util_jni.so   0x4000  (16KB OK)
-   libsurface_util_jni.so            0x4000  (16KB OK)
-   libfastdev_quickjs_runtime.so     0x1000  (4KB — the actual offender)

- zipalign -P 16 passes, so Play Store won't reject. The Android 16
- warning was generic and over-listed. Real outstanding work is
- rebuilding enkinvsh/flutter_js fork with max-page-size=16384.

- This commit applies precautionary 16KB flags so future builds stay
- compliant even if Go/NDK/deps regress:

- - setup.dart: CGO_LDFLAGS='-O2 -s -w -Wl,-z,max-page-size=16384' for
-   Android Go lib builds (libclash.so). No-op on other platforms.

- - build.gradle.kts: useLegacyPackaging=false. Legacy packaging extracts
-   .so at install time which destroys 16KB alignment at runtime. Required
-   by Google Play for Android 15+ targets.

- - build.gradle.kts: force androidx.datastore 1.1.7. Version 1.2.0 ships
-   a 4KB-aligned libdatastore_shared_counter.so and breaks 16KB compliance.
-   Pin until 1.3.0 (with proper alignment) stabilizes.
-   Refs: flutter/flutter#182898

- Also includes pre-existing minSdk flutter.minSdkVersion revert
- (core module still needs ≥23 at runtime — comment preserved).

- fix(ui): audit-found UX regressions on Pixel 10

- Found during 2026-04-17 full UI audit on Pixel 10 Android 16:

- 1. AccessView app bar title 'Контроль доступа приложений' was being
-    truncated to 'Контроль доступа прил...'. OpenDelegate passed the
-    long appAccessControl label; the switch row INSIDE AccessView
-    already shows the long form, so the app bar only needs the short
-    'Контроль доступа' — eliminates both truncation and redundancy.

- 2. MagicRingsOverlay is placed at scaffold level and rendered on every
-    dark-themed page with a bottomNavigationBar. After connect, the
-    rings stayed visible on Settings and sub-pages, overlapping
-    content. Gate visibility on isCurrentPageProvider(PageLabel.dashboard)
-    so rings only animate on the dashboard where the connect button
-    lives.

- 3. StartButton breathing glow alpha was 0.15-0.3 (from Tier-1 perf
-    pass). Invisible on OLED Pixel 10. Bumped to 0.25-0.45 — still
-    gentler than the pre-Tier-1 0.2-0.5, now actually visible.

- fix(windows): complete Wave 1 rebrand — kill FlClashX shared config

- Runner.rc exe metadata still identified as 'clashx' by 'com.follow'.
- inno_setup.iss killed non-existent FlClashCore.exe/FlClashHelperService.exe
- and its uninstaller wiped {userappdata}\com.follow\clashx — the SAME
- folder original FlClashX uses. Installing both apps side-by-side would
- let dropweb's uninstaller nuke FlClashX's config.

- - Runner.rc: CompanyName/InternalName/ProductName → dropweb, copyright 2026
- - inno_setup.iss: kill DropwebCore.exe/DropwebHelperService.exe (real names)
- - inno_setup.iss: uninstaller path → {userappdata}\dropweb\dropweb
-   (matches path_provider Windows layout from new Runner.rc values)

- Note: existing Windows users upgrading to this version will see their
- settings reset (old path was com.follow\clashx, new is dropweb\dropweb).
- No migration path — clean break.

- docs: add SEO keywords (Clash Meta, DPI bypass, split tunneling, Xray-core)

- docs: fix legal phrasing, remove dropweb.org links, improve disclaimer

- docs: rewrite README with Gemini 3.1 — engineer-to-engineer tone, detection protection focus

- - Honest fork positioning (FlClashX → dropweb for non-tech users)
- - Added detection protection section with Habr link (YourVPNDead/RKNHardering)
- - Build from source instructions (setup.dart)
- - Removed AI service name-dropping (was SEO bullshit)
- - for-the-badge style badges
- - Dual language (RU/EN)

- Update changelog

## v0.4.4

- fix(ci): add write permissions for changelog job

## v0.4.3

- fix(android): restore minSdk 23 (required by core module)

## v0.4.2

- feat(windows): unified tray icon - black bg, gray db when inactive

## v0.4.1

- chore: use flutter SDK minSdkVersion, update fork refs

- perf: optimize UI for mid-range devices (Pixel 5)

- - disable BackdropFilter blur on navbar, connect button, subscription tabs
- - disable ColorBendsBg shader (reloads on every rebuild)
- - enable keep: true for dashboard/tools pages to avoid rebuild on switch
- - add AutomaticKeepAliveClientMixin for Proxies/Profiles tabs

- Fixes 12fps lag on swipes and page transitions on Snapdragon 765G.

- docs: improve README - stars badge, SEO alt texts, sync EN version

- docs: remove build instructions

- docs: add dropweb.org link

- docs: add trending AI keywords

- docs: add disclaimer with SEO keywords

- docs: clean up README, restore header

## v0.4.0

- fix(windows): regenerate icons with 32-bit color depth

- Old: 16 colors, 4 bits/pixel (garbage quality)
- New: 32 bits/pixel, proper sizes (256/128/64/48/32/16)

- fix(desktop): minimize to tray on close, restore macOS tray icon

- - Windows: close button now minimizes to tray instead of quitting
- - macOS: restore icon_white.png for menu bar icon

- fix(desktop): keep fixed port for system proxy, protect only mobile

- - Mobile (Android/iOS): random port + auth (YourVPNDead protection)
- - Desktop (Mac/Win/Linux): fixed port + skip-auth for localhost

- chore: migrate git deps to own forks (re-editor, flutter_js)

- Full autonomy from chen08209 (FlClash author) repos.

- fix(android): restore minSdk 23 (required by core module)

- chore: migrate mihomo submodule to own fork (enkinvsh/xHomo)

- docs: changelog v0.3.5

- chore: remove unused legacy brand assets

- fix(android): complete SOCKS protection against VPN detection

- - Remove setHttpProxy from VpnService (was exposing proxy to system)
- - Mobile apps go DIRECT (excluded from VPN, no proxy needed)
- - Enable auth on random port, remove skip-auth-prefixes
- - Use flutter.minSdkVersion instead of hardcoded value

- Tested with YourVPNDead: 7 ports found, 0 vulnerable.

- fix(icons): use nearest-neighbor for pixel-perfect ASCII art scaling

- fix(icons): regenerate tray icons with proper sizes (16/32/48/64/256)

- fix(windows): update app icon, enable minimize to tray, fix bottom padding

- - Replace Windows app_icon.ico with Dropweb icon
- - Set minimizeOnExit default to true (close → tray instead of exit)
- - Increase bottom bar padding from 12 to 20px for desktop

- fix(ui): reduce default desktop window height from 900 to 650

- feat(security): add SOCKS port protection against VPN detection

- - Generate random port (10000-59999) + auth credentials per session
- - Inject into mihomo config: mixed-port, authentication, skip-auth-prefixes
- - Regenerate on connect, clear on disconnect
- - Update ProxyManager for desktop system proxy

- Prevents RKN-style detectors that scan known ports (7890, 1080, 8080).
- Reference: https://habr.com/ru/articles/1022422/

- fix: regenerate freezed files properly + fix build_runner

- - Add dependency_overrides for analyzer_plugin ^0.13.0 (fixes
-   incompatibility with analyzer 7.6.0)
- - Regenerate core.freezed.dart and core.g.dart with proper
-   includePackage/excludePackage fields
- - Remove dead import for non-existent controllers.dart

- docs: add FlClashX feature port plan

- feat(ui): add proxies search bar

- Wire SearchBar to existing proxiesQueryProvider - backend
- filtering was already ported, just needed the UI input field.

- fix(android): VPN include/exclude package priority + MTU 9000

- Port from upstream FlClashX commit a4b131b:
- - Profile-level tun.include-package/exclude-package now take
-   precedence over app-level access control
- - MTU increased from 1500 to 9000 for better throughput
- - Added try/catch for package add/remove to handle missing apps

- chore(cleanup): remove legacy code, fix Go issues, rebrand to Dropweb

- Go core fixes:
- - Fix panic without recover in dart-bridge/lib.go and server.go
- - Fix inverted error logic in common.go sideUpdateExternalProvider
- - Add missing return in action.go getExternalProviderMethod case
- - Rename lib_no_android.go → lib_other.go (match upstream FlClashX)
- - Fix nextHandle signature mismatch

- Chinese legacy cleanup:
- - Replace hardcoded Chinese strings with i18n/English
- - Update FlClash references in comments to Dropweb
- - Keep GPL attribution in about.dart

- Dead code removal:
- - Delete empty files: common/state.dart, providers/controllers.dart
- - Delete unused widgets: view.dart, bar_chart.dart
- - Delete unused glass_audio.dart
- - Remove ~120 lines of commented code (memory_info.dart, builder.dart)
- - Remove unused deps: webview_flutter, audioplayers

- fix(ci): left-aligned flat badges, no center div, add macOS section

## v0.3.5

- fix(ci): update release template with new artifact names + add macOS badge

- fix(rebrand): rename FlClashCore → DropwebCore across all platforms

- Windows CMakeLists.txt, Linux CMakeLists.txt, macOS pbxproj + Swift,
- Dart corePath, setup.dart coreName. This fixes Windows build failure
- (CMake could not find FlClashHelperService.exe — was renamed to
- DropwebHelperService but CMakeLists.txt still referenced old name).

- ci: add macOS to unified build matrix (drop separate build-macos workflow)

- fix(android): restore minSdk=23, Go core requires it (flutter default is 21)

- chore(build): drop platform prefix from artifact names

- Extension already identifies the platform (.apk=Android, .dmg=macOS, .exe=Windows).
- dropweb-android-arm64-v8a.apk → dropweb-arm64-v8a.apk
- dropweb-macos-arm64.dmg → dropweb-arm64.dmg

- chore: add .opencode/ and opencode.json to .gitignore

- chore(android): migrate minSdk to flutter.minSdkVersion

- Auto-upgrade by Flutter tooling — uses Flutter's default minSdkVersion (23)
- instead of hardcoded value.

- fix(macos): align core path — Swift now uses app.dropweb to match Dart

- feat(theme): replace Unbounded with Onest font across all text levels

- Add Onest (9 weights, 100-900) as the app-wide font family. Covers all 15
- Material TextTheme levels (display/headline/title/body/label). Replace
- Unbounded references in about.dart. Add FontFamily.onest to enum.

- feat(dashboard): rework MetainfoWidget — replace subscription label with service name + announce text

- Remove useless subscription label (user_468...), show provider service name
- with logo from providerHeaders instead (fallback: 'Подписка'). Add announce
- text section with clickable URLs below expiry, ported from ServiceInfoWidget.

- fix(macos): deep re-sign app bundle to unify Team IDs across frameworks

- fix(macos): dropweb icon + drag-to-Applications DMG installer

- feat(notification): show mode + speed + uptime, sync mode via IPC

- Notification shade now shows:
- - Title: 'По правилам • Server name' (localized mode + server)
- - Content: '↑ 1.2 MB/s ↓ 5.6 MB/s' (live speeds)
- - SubText: '3h 24m • 1.8 GB' (uptime + session traffic)

- Mode changes sync from UI to service isolate via IPC message
- 'updateMode' to keep notification in sync with actual routing mode.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(ux): add 5-tap developer mode, fix ring animation tracking

- Developer mode: 5 rapid taps on Settings tab in navbar enables dev mode
- (Google-style). Shows snackbar confirmation.

- Ring animation fix: connect button position now tracked every frame via
- self-rescheduling post-frame callback instead of only on widget rebuild.
- Fixes stale ring origin when layout changes (e.g. navbar appears).

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- refactor(dashboard): merge AnnounceWidget into ServiceInfoWidget

- Provider announcements now display below the service name/logo in the
- same card with clickable URLs, instead of a separate dashboard widget.
- Remove announce grid item from DashboardWidget enum.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(theme): set default scheme to vibrant (Яркие)

- Change ThemeProps.schemeVariant default from content to vibrant.
- Update freezed generated file and theme reset handler to match.

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(settings): restructure menu — remove backup, hide dev options, add TV

- - Remove Backup item entirely
- - Hide Core Config + App Settings behind developerMode flag
- - Remove section header 'Настройки' (keep screen title only)
- - Add 'Подключить TV / Передать подписку' menu item using existing SendToTvPage

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- feat(l10n): add TV menu strings, update settings subtitles

- - connectTv / connectTvDesc for new TV menu item
- - themeDesc → 'Изменить' / 'Change'
- - accessControlDesc → 'Настроить приложения' / 'Configure apps'

- Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)

- Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>

- fix(ci): replace create-dmg with hdiutil — no signing identity needed

- fix(ci): fix macOS build — create missing libclash/ dir, configure ad-hoc signing

- ci: add standalone macOS build workflow (manual trigger)

## v0.3.4

- fix(ci): minimal release page — no headers, no bloat

- fix(ci): badge download buttons with counters, clean release layout

- fix(ci): clean release notes — template first, one-line commits

- fix(ci): make Telegram notification non-blocking

- fix(ci): await Windows/Linux build to ensure dist/ is populated

- fix(android): bump minSdk to 23 to match core module

- chore: bump version to 0.3.4

- refactor(ui): use theme colors for mesh background instead of hardcoded Lumina

- feat(ui): rework navbar — oval glass pill selector, dual icons, compact layout

- feat(ux): add profile bottom sheet with QR/URL + glow pulse when no profile

- feat(ux): hide navbar when no profile — onboarding-ready first launch

- feat(android): add home screen VPN toggle widget with Lumina styling

- feat(ui): remove Direct mode, auto-select fastest proxy for Global

- fix: map DioException and HTTP errors to human-readable messages

- Add HTTP status code patterns (404, 403, 5xx) and DioException patterns
- to ErrorMapper. Hook mapper into loadingRun() which catches all profile
- add/update/backup errors — covers the entire app, not just core logs.

- feat: human-readable VPN error messages + fix silent start failure

- Add ErrorMapper that translates raw mihomo core errors to clear messages
- in Russian/English with actionable suggestions. Fix VPN start silently
- failing without any feedback to the user.

- feat(profile): add fallback URL support for subscription updates

- Parse fallback-url header from provider response and retry with it
- when primary subscription URL fails (timeout, HTTP error, network).

- fix: keep core module at org.dropweb.vpn.core for JNI compat

- Go native library (libcore.so) has org/dropweb/vpn/core/TunInterface
- hardcoded in JNI_OnLoad. Cannot rename without recompiling Go core.
- App package stays app.dropweb, only core module keeps old path.

- refactor: rename package org.dropweb.vpn → app.dropweb

- Move Kotlin/Java sources to app/dropweb/ directory structure,
- update all package declarations, Gradle configs, Manifest,
- Dart references and proguard rules. Final package name before
- Google Play submission.

- fix(ui): regenerate monochrome icon from logo.svg, max size

- Render from vector SVG instead of tracing bitmap. Zero padding,
- edge-to-edge db silhouette for tile and notification visibility.

- fix(ui): monochrome icon for tile + black splash background

- Generate proper db silhouette from icon.png, crop to fill canvas,
- point tile service to drawable instead of adaptive mipmap, set all
- splash and icon backgrounds to pure black.

- fix(vpn): survive Android Doze without manual warm-up

- Add setUnderlyingNetworks() on network changes, onLinkPropertiesChanged
- callback, screen-ON BroadcastReceiver for DNS refresh, and START_STICKY
- to auto-restart killed service. Inherited gap from FlClashX fork.

- perf(proxies): debounce lifecycle save + lazy ListView

- - savePreferences → savePreferencesDebounce in didChangeAppLifecycleState (was firing 5-10x per minimize)

- - ListView → ListView.builder in _RulesProxiesView (lazy card creation)

- - getSelectedProxyNameProvider → getProxyNameProvider (avoids groupsProvider dependency, no rebuild on ping)



- fix(proxies): instant visual update on proxy selection

- Subscription proxies view was reading group.realNow (Go core state) instead of the Riverpod selectedMap provider, causing the UI to not reflect proxy changes until page re-entry. Wire _RulesGroupCard and _ProxySelectorSheet through getSelectedProxyNameProvider for optimistic updates, and use updateCurrentSelectedMap + changeProxyDebounce in the sheet tap handler (matching ProxyCard behavior).

- Also swap tab order (Proxies first) and mode order (Global before Direct).



- core: bump sing-tun for GSO fix + TUN MTU 1500 hardcode

- Fix slow Telegram / general VPN throughput regression caused by a GSO
- UDP/ICMP bug in pluralplay/xHomo fork base (b64d7d11, mihomo v1.19.18).
- Upstream fix landed in mihomo commit b7b05e07 as a one-line sing-tun
- pseudo-version bump.

- We can't upgrade the Clash.Meta submodule itself — v1.19.19+ removed
- features.Android, listener.StopListener, tunnel.ProxiesWithProviders
- and constant.DefaultTestURL which the forked core/*.go wrapper still
- depends on. Instead, override sing-tun in core/go.mod via `replace`
- pointing at the fixed pseudo-version b67c0377e081. GSO fix lives
- entirely in sing-tun; no Clash.Meta source changes needed. Submodule
- pointer unchanged at b64d7d11.

- Also:
- - DropwebVpnService.kt: setMtu 9000 → 1500 (match mobile link MTU,
-   prevent fragmentation; 9000 was inherited FlClashX gigabit desktop
-   hardcode).
- - .gitmodules: fix broken enkinvsh/xHomo.git URL (wrong repo; xHomo
-   is a Python project) → https://github.com/MetaCubeX/mihomo.git.
- - pubspec.yaml: 2026040801 → 2026042802 (allow install -r over the
-   pre-fix APK with the future-dated versionCode).

- Verified on Pixel 10 + Remnawave nl-001 cascade:
- - libclash.so embeds sing-tun@v0.4.16-0.20260303144527-b67c0377e081
- - tun0 mtu = 1500 at runtime, zero RX errors
- - Cloudflare 20MB download via mixed-port 7891: 20.5 MB/s (164 Mbps)
- - Previous baseline from 2026-04-09 session: 4.4 MB/s (35 Mbps)
- - +370% throughput improvement

- Prod template mihomo.fixed.yml (v1) remains unchanged.

- docs(readme): screenshots table with captions + ASCII fork lineage tree

- docs(readme): terminal identity pass — code headers, tighter badges, drop h1

- docs(readme): replace logo with retro wireframe header banner

- docs(readme): replace HWID (inherited) with real security, strip to essentials

- docs(readme): separate fork features from inherited ones

- docs(readme): point download links to /releases instead of /releases/latest

- GitHub treats /releases/latest as 'most recent stable', which
- currently resolves to v0.3.3 and hides pre-releases like
- v0.3.4-pre.1. Link to the full /releases page instead so the
- latest build (stable or pre-release) is always discoverable.

- ci(build): trim matrix to android+windows-amd64

- - Drop linux, macos and windows-arm build entries from the matrix.
-   They were consistently failing on setup/signing and blocking the
-   upload + changelog jobs from running (needs.build.result was
-   never 'success' with a broken matrix entry).
- - Remove dead build steps: Rust setup for Windows ARM64, macOS
-   signing certificate, Xcode signing configuration, macOS keychain
-   cleanup, Flutter master channel for ARM runners.
- - Remove sign-macos job entirely and delete the
-   macos-sign-notarize.yaml reusable workflow.
- - Drop 'sign-macos' from upload job needs.
- - Remove the 'Download signed macOS artifacts' step in upload.

- Linux / macOS / Windows-arm entries can be restored from git
- history once their build failures are fixed.

- docs(repo): polish README, templates and metadata for v0.3.4

- - Rewrite README.md + README_EN.md with hero block, brand-color
-   badges, polished feature list, screenshots section and trimmed
-   download table (Android + Windows amd64 only).
- - Rewrite release_template.md + pre_release_template.md with
-   structured sections: Download / Known issues / Build from source
-   / License. Pre-release variant carries a yellow warning header
-   and bug-report CTA.
- - Delete .github/FUNDING.yml (was pointing to dropweb.org, dead).
- - Add docs/screenshots/ with dashboard.png and proxy.png taken
-   from Pixel 10 running the current build.

- Repo description + 14 topics were also set via 'gh repo edit'.

- chore(release): bump to v0.3.4-pre.1

- Pre-release patch bundling two user-facing improvements:

- - perf(ui): lumina Tier 1+2 — weaken GPU-heavy effects and narrow
-   traffic rebuild scope (commit 65be18a). Lumina blur sigma halved,
-   shader targetFps 30→15, breathing glow parameters softened, magic
-   rings 4→2, light pillars 4→2, traffic update loop 1s→2s,
-   NetworkSpeed/TrafficUsage split into per-leaf Consumer widgets,
-   LineChart computeMetrics dead work removed.

- - refactor(modes): restore FlClashX three-mode model rule/direct/global
-   (commit 1a1e3d9). Removed the e477230 Smart repurpose (_SmartProxiesView
-   was read-only and trapped users on mixed templates). Mode enum, UI
-   label and mihomo mode are now 1:1: rule→Правила, direct→Прямой,
-   global→Глобальный. All three modes use the tappable _RulesProxiesView
-   so the compact card UI gains interactivity in every mode.

- Using pre-release marker (-pre.1) because the perf changes have not
- been validated on mid-range Android hardware yet — awaiting feedback
- from the users who originally reported the lag. Internal track only.

- refactor(modes): restore FlClashX three-mode model (rule/direct/global)

- Previously commit e477230 introduced a "Smart / Rules / Global" mode
- switcher that repurposed Mode.direct as a UI "Rules" tab (manual
- selector) while force-patching all select proxy-groups to url-test
- when Mode.rule ("Smart") was active. Commit 7426bde later reverted
- the force-patcher because it broke nested template router groups
- (by-legiz etc.) via recursive url-test, but left the repurpose and
- read-only _SmartProxiesView behind. That created two latent issues:

-   1. UX dead-end: _SmartGroupCard was read-only (no InkWell onTap),
-      so on mixed templates (select groups inside Smart mode) users
-      could see proxies but had no way to change them.
-   2. Mode semantics: Mode.direct in the UI meant "Rules" but in
-      mihomo config was mapped to "rule" mode. Mode enum, UI label,
-      and mihomo mode were three different concepts.

- Restore the original FlClashX three-mode model — enum, label, and
- mihomo mode are now 1:1:

-   Mode.rule   → "Правила"    → mihomo "rule"
-   Mode.direct → "Прямой"     → mihomo "direct"  (real bypass)
-   Mode.global → "Глобальный" → mihomo "global"

- Changes:

- - lib/views/subscription.dart:
-   - Delete _SmartProxiesView + _SmartGroupCard (~130 lines of read-
-     only duplicate of _RulesProxiesView)
-   - _ProxiesContent: was ConsumerWidget with switch(mode), now a
-     plain StatelessWidget rendering _RulesProxiesView for all modes.
-     The bottom mode bar watches mode internally for its highlight.
-   - SharedProxiesBody: same simplification
-   - _modeLabel: smart→rules, rules→direct (shift labels to match
-     enum semantics; uses existing "rules"/"direct" l10n keys)

- - lib/views/dashboard/widgets/outbound_mode.dart:
-   - _modeLabel: same shift (smart→rules, rules→direct)
-   - _modeIcon: Mode.rule now uses strokeRoundedFilter (rule filter),
-     Mode.direct uses strokeRoundedArrowRight01 (direct bypass)
-   - Header comment rewritten for FlClashX-original semantics

- - lib/providers/state.dart: updateParams no longer remaps
-   Mode.direct → Mode.rule; mode passes through verbatim

- - lib/state.dart: patchRawConfig no longer remaps; mihomo config
-   gets realPatchConfig.mode.name directly

- Visually verified on Pixel 10: compact card style preserved (emoji
- + type·selected + delay badge + chevron), tap-to-select now works
- in all three modes (was read-only in the previous Smart mode),
- bottom bar shows "Правила / Прямой / Глобальный". No regressions
- in flutter analyze (0 errors, 16 warnings, 569 infos — same baseline
- as pre-change).

- No migration shipped: Mode.direct users from the brief (<24h) window
- between e477230 and this commit will land in real Direct/bypass mode
- on first launch. They can switch back to "Правила" manually. Deemed
- acceptable because the affected cohort is small and this restores
- the long-standing FlClashX behavior.

- perf(ui): lower lumina GPU load + narrow traffic rebuild scope

- Mid-range Android users reported UI lag after the LUMINA 2027
- redesign (commit 0e516bf and follow-ups). Root cause: a stack of
- ~5 simultaneous GPU-heavy effects running on the dashboard. Two-tier
- fix without architectural changes — Tier 1 weakens each effect's
- parameters; Tier 2 narrows Riverpod rebuild scopes on the hot
- traffic update path and trims dead work.

- Tier 1 — weaken lumina effects globally:
- - lumina.dart: blurSigma 10→4, blurSigmaHeavy 16→8 (BackdropFilter
-   cost is ~quadratic in sigma → ~6x cheaper for nav bar, connect
-   button, subscription glass tabs; all use Lumina.glassBlur centrally)
- - color_bends_bg.dart: default targetFps 30→15
- - start_button.dart: breathing glow 3s→4s, tween 0.2-0.5→0.15-0.3,
-   BoxShadow blurRadius 16→8, spreadRadius 2→1
- - magic_rings.dart: duration 8000ms→14000ms, _ringCount 4→2
- - light_pillar.dart: 4 pillars → 2 (kept the two widest)

- Tier 2 — narrow traffic rebuild scope and remove dead work:
- - state.dart: traffic update loop 1s→2s (halves background cascade
-   work; slightly less live speedometer)
- - color_bends_bg.dart: Ticker is now lazily created only after the
-   shader loads successfully. Previously ran every frame even though
-   shaders/color_bends.frag has been silently failing on Impeller
-   since 2025-09-11 (upstream manifest sets EnableImpeller=true,
-   FragmentProgram fails on GLES, widget falls back to SizedBox.shrink)
- - network_speed.dart: split into StatelessWidget scaffolding +
-   _SpeedChart ConsumerWidget (full traffics list watch) + _SpeedText
-   ConsumerWidget using ref.watch(trafficsProvider.select(...)) on a
-   derived display string — rebuilds only when the formatted text
-   actually changes (String has proper value equality)
- - traffic_usage.dart: split into StatelessWidget +
-   _TrafficUsageContent ConsumerWidget → CommonCard chrome no longer
-   rebuilds on every totalTrafficProvider tick
- - line_chart.dart: removed computeMetrics().first.extractPath(0,
-   length) dead work in getAnimatedPath. For a simple connected
-   quadraticBezierTo sequence it produces an equivalent path but
-   walks it O(n) per repaint. Equivalent output, cheaper per frame.

- Visually verified on Pixel 10 (not mid-range, but sufficient to
- confirm no visual regression): magic rings animate smoothly,
- breathing glow lit, glass tab bar renders, VPN state persists
- through hot restart. Impeller-related static color-bends background
- is pre-existing state since 2025-09-11, unrelated to this change;
- skill flutter-dropweb-dev Gotcha #1 was updated separately to
- document that situation.

- flutter analyze: 0 errors (16 warnings, 568 infos — baseline clean,
- no regressions vs pre-change state).

- revert: stop force-patching proxy-groups in Smart mode

- Remove client-side select→url-test patcher from state.dart and
- simplify changeMode back to pre-e477230 behavior. The patcher from
- commit e477230 was breaking template router groups: e.g. by-legiz
- template has 🌍 VPN (select) referencing ⚡ Fastest / 📶 First
- Available — when force-patched to url-test, mihomo started running
- recursive url-test across nested group references, producing
- unpredictable selection (cascade nodes usually winning on raw latency,
- masking direct nodes even when template explicitly tried to structure
- them separately).

- The correct solution lives server-side: Remnawave templates use native
- mihomo filter / exclude-filter on their url-test groups to shape which
- proxies enter the auto-selection pool. Client should respect template
- structure, not reshape it.

- Security tier 1-2 from e477230 (_apiSecret random API auth,
- _randomMixedPort localhost hardening) is preserved — only the proxy
- group patching and custom changeMode reload/firstRuleGroup logic are
- reverted.

- fix: remove leftover FlClashX vector drawables

- Wave 1 icon rebrand regenerated launcher PNGs via flutter_launcher_icons
- but missed two vector XMLs which silently overrode them at Android
- resource resolution:

- - drawable/ic_launcher_foreground.xml (cyan X-bars gradient) — used by
-   adaptive launcher icon and windowSplashScreenAnimatedIcon
- - drawable/ic.xml (white X-bars vector) — used by VPN notification
-   small icon via setSmallIcon(R.drawable.ic)

- Notification now uses R.drawable.ic_launcher_monochrome (regenerated
- dropweb silhouette). Splash screen animated icon dropped — Android 12+
- falls back to the app launcher icon which is now dropweb. Play Store
- listing asset ic_launcher-playstore.png regenerated from canonical
- assets/images/icon.png source.

- fix: add clash-verge UA prefix for Remnawave subscription compat

- fix: replace icons with official db neon logo

- fix: minSdk 21 → 23 to match core module

- rebrand: FlClashX → dropweb v0.3.3

- Full rebrand across all platforms:
- - Dart: DropwebHttpOverrides, UA 'dropweb/v...', repository enkinvsh/dropweb-app
- - Kotlin: 4 files renamed (DropwebApplication/Service/VpnService/TileService)
- - Android: manifests, adaptive icons from official db pixel-art logo
- - macOS: bundle ID org.dropweb.vpn, copyright, xib, pbxproj
- - Windows/Linux: publisher dropweb, service names, packager info
- - Icons: official neon db logo, monochrome, tray variants, TV banner
- - Meta: README RU+EN rewritten, GitHub templates, CI workflows, .gitmodules
- - Submodules: forked to enkinvsh/xHomo + enkinvsh/flutter_distributor
- - Rust helper: DropwebHelperService
- - GPL-3.0 attribution preserved for chen08209/FlClash and pluralplay/FlClashX

- BREAKING: flclashx-* HTTP headers unchanged (Remnawave protocol compat)

- refactor: unify desktop proxies/profiles with mobile UI

- - Add SharedProxiesBody/SharedProfilesBody public widgets in subscription.dart
- - Desktop ProxiesView (328→40 lines): delegates to SharedProxiesBody, clears actions/FAB
- - Desktop ProfilesView: delegates to SharedProfilesBody, clears actions/FAB
- - Both platforms now share same Smart/Rules/Global views, mode bar, add card, pull-to-refresh

- refactor: subscription page UX overhaul — glass tabs, inline add, pull-to-refresh

- - Replace rectangular tab bars with Lumina glass-styled containers (blur, radiusLg, glass border)
- - Move mode switcher from AppBar popup to bottom segmented control (text-only, matching top tabs)
- - Replace FAB with inline '+' card in profiles grid
- - Replace AppBar action buttons with pull-to-refresh (profiles: update subs, proxies: ping all)
- - Remove dead code: ProxiesTabView/ListeView/Setting imports, _proxiesTabKey, _isTab, _hasProviders
- - Clean unused _ModeSelectorAction, expand/collapse, tab scroll-to-selected, DelayTestButton

- fix: revert mixed-port randomization — caused connection refused on restart

- Random per-session port desynchronized with persisted Dio proxy config,
- breaking subscription updates. Port scanning mitigation is ineffective
- anyway (65535 ports scanned in seconds). The secret on external-controller
- is the real protection.


- feat: localhost API protection + Smart/Rules/Global mode switcher

- Security (Tier 1-2):
- - Inject random 64-char secret on external-controller API (per-session)
- - Randomize mixed-port when default 7890 (hinders localhost scanning)

- Mode switcher:
- - Smart: url-test groups, interval=60s, tolerance=100ms, lazy=false
-   Compact row view (group → auto-selected proxy → delay badge)
- - Rules: select groups, same compact rows + tap → bottom sheet selector
- - Global: mihomo global mode
- - Full config reload (setupClashConfigDebounce) on Smart↔Rules switch

- Localization: smart/rules keys for en/ru/ja/zh_CN


- feat: migrate all icons from Material to HugeIcons strokeRounded

- Replace 205 Material Icons with HugeIcons SVG across 45 files:
- views, widgets, pages, managers. Add hugeicons package to pubspec.
- Consistent strokeRounded style throughout the app.


- feat: add SubscriptionPage with profiles/proxies tabs, restructure navigation

- New fullscreen SubscriptionPage (MetainfoWidget tap → Subscription).
- Two tabs: Profiles (subscription list + FAB) and Proxies (proxy groups).
- Remove Proxies from bottom nav — now 2 tabs: Home | Settings.
- Compact island layout (ConstrainedBox 55% width, connect button right).
- MeshBackground on subscription page.


- refactor: widen NavigationItem.icon to Widget, PopupMenuItemData.icon to Widget?

- Prepare model types for HugeIcons migration — Icon and IconData are
- too narrow for SVG-based icon widgets. Freezed generated code updated
- manually (build_runner broken).


- feat: add subscription localization key across all languages

- Add "subscription" key to en/ru/ja/zh_CN ARB files and regenerate
- l10n + intl message files.


- feat: magic rings fade-in/out animation with thinner strokes

- - AnimatedOpacity 800ms ease-in-out on connect/disconnect
- - Stroke width 2.0→0.8px, quadratic radial fade
- - Controller stops only after fade-out completes (onEnd)



- fix: keep magic rings under tab bar island, not above

- MagicRingsOverlay stays in dashboard body Stack (under bottomNavigationBar).
- Rings pass behind the glass tab bar island — intentional layering.

- feat: fullscreen magic rings from connect button, haptic feedback

- - MagicRingsOverlay: 4 rings expand from connect button to full screen
-   diagonal, 8s cycle, GlobalKey → RenderBox.localToGlobal for exact
-   button position, globalToLocal for paint-space conversion
- - _ConnectCircle reports screen position via connectButtonCenter notifier
- - Removed glow shadow on connect button (glassShadow only)
- - HapticFeedback on tab switch (selectionClick) and connect (mediumImpact)
- - Added audioplayers + glass sound assets (unused for now, haptic preferred)
- - Glass audio service (GlassAudio) created but not wired — available for
-   future use if needed

- fix: remove PRE badge, subtle ring animation, haptic feedback on connect

- - Remove PRE/DEBUG banner from app_state_manager entirely
- - Tone down ring BoxShadow: spread 2→20 (was 4→32), blur 1→5 (was 2→14),
-   alpha 0.25 (was 0.35) — cleaner, less blurry rings
- - Add HapticFeedback.mediumImpact on VPN connect/disconnect
- - Add HapticFeedback.lightImpact on add profile action

- feat: color bends shader bg, transparent AppBar, connect button as add-profile

- - Add GLSL color bends fragment shader (reactbits port) on dashboard
- - Disable Impeller on Android (Skia fallback) — Impeller GLES silently
-   fails to load custom FragmentProgram shaders
- - Make AppBar transparent in dark mode + extendBodyBehindAppBar so
-   gradient bleeds through from top edge
- - Remove 'Добавить профиль' dashboard card — replaced by connect button
- - Connect button shows '+' icon when no profile, opens URL dialog on tap
- - MeshBackground rewritten: DecoratedBox stack instead of CustomPaint +
-   ImageFiltered (avoids Size.infinite + blur clipping issues)
- - LightPillar: bump opacity, add docs, guard zero-size
- - ColorBendsBg: ValueNotifier-driven repaint, 30fps throttle, zero
-   widget rebuilds during animation

- feat: LUMINA 2027 design system — glass surfaces, mesh gradient, light pillars, bioluminescent glow

- - Add Lumina design tokens (lumina.dart): void #030305, glass 3%/8%, blur sigma 10, glow colors, animation curve
- - Theme: void surface hierarchy, glass CardTheme for dark mode
- - Mesh gradient background: 3 radial gradients (green/lightgreen/blue) with blur, in scaffold
- - Animated light pillars: 4 vertical beams with slow drift, Home screen only
- - Glass tab bar + connect button: BackdropFilter blur, specular borders, deep shadows
- - Glass dashboard widgets: CommonCard uses Lumina glass values on dark theme
- - Bioluminescent active states: connect button breathe animation, tab glow dot
- - Light theme fallback: solid surfaces, no blur, clean Material 3

- redesign: dropweb branded UI — floating island tab bar, circular connect button, Unbounded font, green theme

- - Tab bar: floating island pill with outline, blur, shadow
- - Connect button: circle next to tab bar, fills primary on connect
- - Theme: #15803D green accent, pureBlack dark mode default
- - Font: Unbounded (variable) for headings, system for body
- - Dashboard: removed title bar, removed widget edit button
- - Defaults: removed announce & mode switcher from home widgets
- - Layout: connect button + widgets in scrollable content

- rebrand FlClashX → dropweb: package org.dropweb.vpn, custom icon, cleanup nav

- fix: tg channel link

## v0.3.2

- release: version 0.3.2

- critical fix: ClashHelperService

- fix: ClashHelper installer

- feat: new tray icon, new title bar

- fix: tg notify

## v0.3.1

- fix: androidTV focusing dpad proxy page

- feat: new readme

## v0.3.1-pre.1

- fix: windows logic service
- fix: Linux arm build

## v0.3.0

- fix 0.3.0 release

- fix: added pureblack variant hex header
- fix: optimize base
- fix: icon linux-based distrib

- fix: HWID notify logic
- fix: removed the proxy group type from the proxy page

- feat: 3 days notice of expiring subscription every day (only Android for now)

- feat: new header flclashx-globalmode
- feat: visible servicename and host in foreground notify
- fix: update dependencies packages
- fix: flclashx-custom logic
- fix: windows installer
- fix: update logic empty widgets visible
- fix: update notify TG

## v0.3.0-pre.13

- ci: fix notify

- fix: android tile service
- feat: manual check in IPchecker widget
- feat: mode selector in ProxyPage
- feat: notify modal in HWID limit
- fix: logic geo updater

- fix: android tile service
- feat: manual check in IPchecker widget
- feat: mode selector in ProxyPage
- feat: notify modal in HWID limit
- fix: logic geo updater

- feat: manually check ip from networkDetection widget

- fix: cache icons

- fix: the proxy tab disappears when renewing a subscription or in other cases

- feat: add restart button in tray control
- feat: new pop-up window when HWID Limit is reached

- fix: blur on bottomsheets, sidesheets

## v0.3.0-pre.12

- fix: memtagmode off (temp solution)

- fix: serivceinfo widget base64 issue

- fix: backup/restore app function

## v0.3.0-pre.11

- fix: release script

- fix: init proxiesgroup for start/stop button

- feat: add button to check latency across all proxy groups
- feat: new header flclashx-hex (custom theme app)
- fix: search button in proxy groups
- fix: setting up proxy group sorting

- fix android tile service

- fix: andriod adaptive icon

- fix: release template

## v0.3.0-pre.10

- fix: build pages RepaintBoundary widgets
- feat: notify release
- fix: modal pages opacity

- fix: windows arm actions

- fix: coreversion on build app

- fix: artefact slidemenu

- fix: serviceinfo and changeserver support latin or base64 header for cyrillic, unicode and emoji support
- fix: support https:// links announce widget

- update flclashx-serverinfo description

## v0.3.0-pre.9

- fix: android icons and splashscreen
- refactor: changeserverbutton widget
- fear: new header flclashx-serverinfo
- refactor: update readme and templates
- fix: cache logo in service-logo header
- fix: theme opacity layer

- fix: optimize theme for opacity layers
- fix: deprecated core version
- fix: about page

## v0.3.0-pre.8

- fix: release template

- new submodule init

- Remove old submodule

- Remove old submodule

- fix: visible log folder button on andriod

- fix: gtk flags

- fix: workflow

- feat: logs folder button in settings menu
- refactor: about page

- refactor: cleaning up excess logs

- feat: logger in file (logrotate10 days)

- fix: android hwid generator (Settings.Secure_ID)

- fix: running a single instance on Linux

## v0.3.0-pre.7

- fix: pubsec.yaml

- fix: workflow flutter version

- update: geofiles

- fix: locale
- refactor: recive mixed-port from subscription

- fix: recieve App Setting from provider
- fix: en localization
- update: readme

- fix: migrate deprecated iconstyle

- feat: add flclashx-backgroud header (the ability to customize the application background)
- feat: button to hide/show all proxy groups
- fix: kill application when installing over an older version

- refactor: apply comprehensive linting rules and code style improvements
- Add extensive lint rules in analysis_options.yaml (100+ rules)
- Apply automated code formatting across entire codebase
- Changes to Linux distribution descriptions
- Adding full support for 120Hz screens on Android

- Delete workflow
- test comm
- test
- Merge pull request #29 from pluralplay/pluralplay-patch-1

- wf
- wf
- Merge branch 'main' of https://github.com/pluralplay/FlClashX

- Revert "fix: macos naming artifact"

- This reverts commit 72fe70aa9d4737e750bc41ffa180367c1113f149.

- Merge pull request #27 from pluralplay/dev

- 0.3.0-pre.6

## v0.3.0-pre.6

- feat: recive parameters from a subscription and enabling from an override in client: allow-lan, ipv6, find-process-mode, tun-stack
- feat: the ability to completely reset application profiles from settings

- update: readme
- fix: exclude closeConnections provider control

- fix: android notification start bug
- refactor: cardType fill flexible

- Merge pull request #25 from katsukibtw/main

- Proxies list view refactoring using Expansible widget
- add custom logo and new header flclashx-servicelogo (work only with flclashx-servicename header)

- Merge pull request #26 from pluralplay/main

- fix: macos naming artifact
- fix: macos naming artifact

- remove standard icon style

- refactor: use Expansible for proxy groups in proxies list view

- update dev branch pre release

- update dev branch
- fix: notify icon android

- Merge pull request #6 from pluralplay/main

- todev

## v0.3.0-pre.4


## v0.3.0-pre.5

- fix: main settings UI and default variable
- fix: hwid generator
- fix: macos version artifact rename

## v0.3.0-pre.3

- fix: pre-release posting gh

- fix: delete message from update core version

## v0.3.0-pre.2

- fix template

- fix: init FlClashX

- fix: init

- fix: init universal apk
- fix: init fork flutter_distributor

- feat: universal APK
- feat: new UI for geofiles menu
- feat: Application settings from sub-header (disableable setting override)
- feat: saving custom settings from the profile header
- fix: custom geofiles loader (check hash from URL)
- fix: safe_patch error
- fix: metainfo widget logical
- fix: localization

- fix about page and adding new translate

- fix declension
- adding hour counter remaining sub

- fix russian translate

- fix timecounter start/stop button

- fix lang metainfo card

- refactor about page

- update proxy state before update sub

- fix tray control and change color depending on Windows theme
- fix stop service helper
- fix external-ui subupdate

- fix server description standard card
- fix macos deeplink (add flclashx)
- add core version in About page
- fix uninstaller and uninstall logo
- fix deeplink first install

- Merge pull request #18 from prettyleaf/main

- feat(release): add Repology badge for FlClashX version tracking
- feat(release): add Repology badge for FlClashX version tracking

- Merge pull request #15 from kastov/macos-features

- New widgets, macOS signing&notarization, macOS tray
- feat(dashboard): enhance MetainfoWidget with improved expiration display and UI adjustments

- - Updated the logic to show days left until subscription expiration, limiting display to within 3 days.

- fix(utils): update time formatting for getTimeText method

- - Changed the default return value for null timestamps from '00:00:00' to '000:00:00' to accommodate larger hour values.
- - Adjusted the hour limit check from 99 to 999 to support longer durations.
- - Updated the return statement to ensure hours are padded to three digits for consistent formatting.

- chore(build): update macOS configuration and clean up Windows platform entries

- - Changed macOS version from 'macos-13' to 'macos-latest' for improved compatibility.
- - Commented out Windows platform configuration to simplify the build workflow.
- - Updated the Flutter subproject commit to indicate a dirty state.

- feat(build): clean up build workflow

- - Removed the Telegram bot service configuration from the GitHub Actions workflow to streamline the build process.

- feat(dashboard): add serviceInfo widget and update profile handling

- - Introduced the `serviceInfo` widget to the dashboard for enhanced service display.
- - Updated the `Profile` model to include a new `serviceName` field for better service management.
- - Enhanced README files to document the new `serviceInfo` widget and its usage.

- feat(proxy): enhance proxy card functionality and UI

- - Introduced a new 'oneline' card type for improved display options in the proxy list.
- - Updated the ProxyCard widget to handle the new card type, including layout adjustments and conditional rendering.
- - Enhanced the getItemHeight function to accommodate the new card type.
- - Refactored the handling of proxy descriptions and delay text for better clarity and user experience.
- - Added support for the new card type in the computed mark display logic.

- feat(proxy): enhance proxy handling with server descriptions and JSON integration

- - Added extraction of server descriptions from raw YAML config to improve proxy management.
- - Updated Proxy model to include an optional serverDescription field for better data representation.
- - Enhanced handleGetProxies function to include server descriptions in the returned JSON structure.
- - Adjusted UI components to display server descriptions where applicable, improving user experience.

- feat(macos): adjust popover dimensions and enhance macOS app layout

- - Updated the popover dimensions in AppDelegate and StatusBarController to 375x600 for better fit.
- - Added platform-specific handling in ApplicationState to adjust the app layout for macOS, including a FittedBox for improved display.
- - Ensured the app maintains a consistent appearance across different macOS environments.

- feat(dashboard): enhance StartButton with animation and tap feedback

- - Updated StartButton to use TickerProviderStateMixin for improved animation control.
- - Added a new press animation for tap feedback, enhancing user interaction.
- - Adjusted button duration for animations and improved visual feedback with scaling and size transitions.
- - Refactored button layout to include GestureDetector for handling tap events.
- - Updated text styling for better visibility and added keys for widget identification.

- fix(window_manager): simplify macOS logic in WindowHeaderContainer and remove unused import

- - Removed the unused import of app provider.
- - Streamlined the macOS-specific logic in the WindowHeaderContainer to improve clarity and maintainability.

- refactor: remove unused code

- feat(localization): add "Change Server" string to multiple language files and update UI elements for macOS

- - Added "Change Server" localization to English, Japanese, Russian, and Simplified Chinese ARB files.
- - Updated the localization messages in the respective Dart files.
- - Adjusted macOS UI elements for better integration, including window size and rounded corners for the popover.
- - Enhanced the window manager logic to handle macOS-specific behavior more effectively.

- feat(build): enhance Makefile and Xcode project for macOS notarization and code signing

- feat(macos): implement native status bar and code signing support

- Adds comprehensive macOS status bar integration and app signing capabilities:

- - Replaces window-based UI with native status bar menu
- - Implements secure core binary installation in Application Support
- - Adds code signing and notarization workflow
- - Updates build configuration for proper macOS code signing
- - Improves DMG creation process using create-dmg
- - Configures launch-at-login functionality
- - Sets minimum macOS version to 11.0

- This change significantly improves the native macOS experience by making the app behave more like a traditional menu bar utility while ensuring proper security measures through code signing and notarization.

- Update bug_report.yml
- Update bug_report.yml
- Update bug_report.yml
- Update feature_request.yml
- Update config.yml
- Update release_template.md
- clean

## v0.2.1

- update mihomo core

- update logo
- update mihomo core

- Create FUNDING.yml
- update readme

## v0.2.0

- Merge branch 'dev'

- - add new widget "Meta Info"
- - add new catch-header (flclashx-view,flclashx-denywidgets,flclashx-custom)
- - bug-fixes qr-code scanner

- Update README.md
- Update README_EN.md
- Update README_EN.md
- Update README.md
- Update README.md
- Update README.md
- Update README.md
- Update README.md
- Merge pull request #4 from pluralplay/main

- new
- update snapshots

## v0.1.0

- Update flutter_distributor submodule to latest commit

- Update .gitmodules
- some changes

- change GI dependence

- enchance profile card UI
- add catch new header flclashx-widget
- flclashx-hidemode is deprecated
- add support button in profile

- enchance profile card UI
- add catch new header flclashx-widget
- flclashx-hidemode is deprecated
- add support button in profile

## v0.0.7

- Feature: add profile from mobile on AndroidTV (QR-code init)

- Merge pull request #3 from pluralplay/dev

- Feature: add profile from mobile on AndroidTV (QR-code init)
- Feature: add profile from mobile on AndroidTV (QR-code init)

## v0.0.6

- some changes

- Add button "Paste" in Add Profile from URL (Android TV optimisation)
- In Proxy page default mode - list
- New header catch - flclashx-hidemode (boolean) - hide all widgets form Main Page in first Add Profile
- Change About page

- delete cache

- Delete cache

## v0.0.5

- some changes

- add hidemode widget feature

## v0.0.4

- some changes

- - support redirect links (pinger work)
- - some fixes tun on android

- Update README.md
- Update README.md
- Delete cache

## v0.0.3

- tun mode android bug fixes

## v0.0.2

- some changes

- add ru locale instalation, some bugfixes

## v0.0.1

- some changes

- some changes

- Merge branch 'main' of https://github.com/pluralplay/FlClashX

- release 1

- Delete services/helper/target directory
- some changes

- Release 1

- Merge pull request #2 from pluralplay/dev

- final dev build v.0.0.1
- final dev build v.0.0.1

- Merge pull request #1 from pluralplay/dev

- new features
- add announce widget, change default settings

- add HWID

- Update changelog

- Fix windows tun issues

- Optimize android get system dns

- Optimize more details

- Update changelog

- Support override script

- Support proxies search

- Support svg display

- Optimize config persistence

- Add some scenes auto close connections

- Update core

- Optimize more details

- Fix issues that TUN repeat failed to open.

- Update changelog

- Fix windows service verify issues

- Update changelog

- Add windows server mode start process verify

- Add linux deb dependencies

- Add backup recovery strategy select

- Support custom text scaling

- Optimize the display of different text scale

- Optimize windows setup experience

- Optimize startTun performance

- Optimize android tv experience

- Optimize default option

- Optimize computed text size

- Optimize hyperOS freeform window

- Add developer mode

- Update core

- Optimize more details

- Add issues template

- Update changelog

- Optimize android vpn performance

- Add custom primary color and color scheme

- Add linux nad windows arm release

- Optimize requests and logs page

- Fix map input page delete issues

- Update changelog

- Add rule override

- Update core

- Optimize more details

- Update changelog

- Optimize dashboard performance

- Fix some issues

- Fix unselected proxy group delay issues

- Fix asn url issues

- Update changelog

- Fix tab delay view issues

- Fix tray action issues

- Fix get profile redirect client ua issues

- Fix proxy card delay view issues

- Add Russian, Japanese adaptation

- Fix some issues

- Update changelog

- Fix list form input view issues

- Fix traffic view issues

- Update changelog

- Optimize performance

- Update core

- Optimize core stability

- Fix linux tun authority check error

- Fix some issues

- Fix scroll physics error

- Update changelog

- Add windows storage corruption detection

- Fix core crash caused by windows resource manager restart

- Optimize logs, requests, access to pages

- Fix macos bypass domain issues

- Update changelog

- Fix some issues

- Update changelog

- Update popup menu

- Add file editor

- Fix android service issues

- Optimize desktop background performance

- Optimize android main process performance

- Optimize delay test

- Optimize vpn protect

- Update changelog

- Update core

- Fix some issues

- Update changelog

- Remake dashboard

- Optimize theme

- Optimize more details

- Update flutter version

- Update changelog

- Support better window position memory

- Add windows arm64 and linux arm64 build script

- Optimize some details

- Remake desktop

- Optimize change proxy

- Optimize network check

- Fix fallback issues

- Optimize lots of details

- Update change.yaml

- Fix android tile issues

- Fix windows tray issues

- Support setting bypassDomain

- Update flutter version

- Fix android service issues

- Fix macos dock exit button issues

- Add route address setting

- Optimize provider view

- Update changelog

- Update CHANGELOG.md

- Add android shortcuts

- Fix init params issues

- Fix dynamic color issues

- Optimize navigator animate

- Optimize window init

- Optimize fab

- Optimize save

- Fix the collapse issues

- Add fontFamily options

- Update core version

- Update flutter version

- Optimize ip check

- Optimize url-test

- Update release message

- Init auto gen changelog

- Fix windows tray issues

- Fix urltest issues

- Add auto changelog

- Fix windows admin auto launch issues

- Add android vpn options

- Support proxies icon configuration

- Optimize android immersion display

- Fix some issues

- Optimize ip detection

- Support android vpn ipv6 inbound switch

- Support log export

- Optimize more details

- Fix android system dns issues

- Optimize dns default option

- Fix some issues

- Update readme

- Fix build error2

- Fix build error

- Support desktop hotkey

- Support android ipv6 inbound

- Support android system dns

- fix some bugs

- Fix delete profile error

- Fix submit error 2

- Fix submit error

- Optimize DNS strategy

- Fix the problem that the tray is not displayed in some cases

- Optimize tray

- Update core

- Fix some error

- Fix tun update issues

- Add DNS override
- Fixed some bugs
- Optimize more detail

- Add Hosts override

- fix android tip error
- fix windows auto launch error

- Fix windows tray issues

- Optimize windows logic

- Optimize app logic

- Support windows administrator auto launch

- Support android close vpn

- Change flutter version

- Support profiles sort

- Support windows country flags display

- Optimize proxies page and profiles page columns

- Update flutter version

- Update version

- Update timeout time

- Update access control page

- Fix bug

- Optimize provider page

- Optimize delay test

- Support local backup and recovery

- Fix android tile service issues

- Fix linux core build error

- Add proxy-only traffic statistics

- Update core

- Optimize more details

- Add fdroid-repo

- Optimize proxies page

- Fix ua issues

- Optimize more details

- Fix windows build error

- Update app icon

- Fix desktop backup error

- Optimize request ua

- Change android icon

- Optimize dashboard

- Remove request validate certificate

- Sync core

- Fix windows error

- Fix setup.dart error

- Fix android system proxy not effective

- Add macos arm64

- Optimize proxies page

- Support mouse drag scroll

- Adjust desktop ui

- Revert "Fix android vpn issues"

- This reverts commit 891977408e6938e2acd74e9b9adb959c48c79988.

- Fix android vpn issues

- Fix android vpn issues

- Rollback partial modification

- Fix the problem that ui can't be synchronized when android vpn is occupied by an external

- Override default socksPort,port

- Fix fab issues

- Update version

- Fix the problem that vpn cannot be started in some cases

- Fix the problem that geodata url does not take effect

- Update ua

- Fix change outbound mode without check ip issues

- Separate android ui and vpn

- Fix url validate issues 2

- Add android hidden from the recent task

- Add geoip file

- Support modify geoData URL

- Fix url validate issues

- Fix check ip performance problem

- Optimize resources page

- Add ua selector

- Support modify test url

- Optimize android proxy

- Fix the error that async proxy provider could not selected the proxy

- Fix android proxy error

- Fix submit error

- Add windows tun

- Optimize android proxy

- Optimize change profile

- Update application ua

- Optimize delay test

- Fix android repeated request notification issues

- Fix memory overflow issues

- Optimize proxies expansion panel 2

- Fix android scan qrcode error

- Optimize proxies expansion panel

- Fix text error

- Optimize proxy

- Optimize delayed sorting performance

- Add expansion panel proxies page

- Support to adjust the proxy card size

- Support to adjust proxies columns number

- Fix autoRun show issues

- Fix Android 10 issues

- Optimize ip show

- Add intranet IP display

- Add connections page

- Add search in connections, requests

- Add keyword search in connections, requests, logs

- Add basic viewing editing capabilities

- Optimize update profile

- Update version

- Fix the problem of excessive memory usage in traffic usage.

- Add lightBlue theme color

- Fix start unable to update profile issues

- Fix flashback caused by process

- Add build version

- Optimize quick start

- Update system default option

- Update build.yml

- Fix android vpn close issues

- Add requests page

- Fix checkUpdate dark mode style error

- Fix quickStart error open app

- Add memory proxies tab index

- Support hidden group

- Optimize logs

- Fix externalController hot load error

- Add tcp concurrent switch

- Add system proxy switch

- Add geodata loader switch

- Add external controller switch

- Add auto gc on trim memory

- Fix android notification error

- Fix ipv6 error

- Fix android udp direct error

- Add ipv6 switch

- Add access all selected button

- Remove android low version splash

- Update version

- Add allowBypass

- Fix Android only pick .text file issues

- Fix search issues

- Fix LoadBalance, Relay load error

- Fix build.yml4

- Fix build.yml3

- Fix build.yml2

- Fix build.yml

- Add search function at access control

- Fix the issues with the profile add button to cover the edit button

- Adapt LoadBalance and Relay

- Add arm

- Fix android notification icon error

- Add one-click update all profiles
- Add expire show

- Temp remove tun mode

- Remove macos in workflow

- Change go version

- Update Version

- Fix tun unable to open

- Optimize delay test2

- Optimize delay test

- Add check ip

- add check ip request

- Fix the problem that the download of remote resources failed after GeodataMode was turned on, which caused the application to flash back.

- Fix edit profile error

- Fix quickStart change proxy error

- Fix core version

- Fix core version

- Update file_picker

- Add resources page

- Optimize more detail

- Add access selected sorted

- Fix notification duplicate creation issue

- Fix AccessControl click issue

- Fix Workflow

- Fix Linux unable to open

- Update README.md 3

- Create LICENSE
- Update README.md 2

- Update README.md

- Optimize workFlow

- optimize checkUpdate

- Fix submit error

- add WebDAV

- add Auto check updates

- Optimize more details

- optimize delayTest

- upgrade flutter version

- Update kernel
- Add import profile via QR code image

- Add compatibility mode and adapt clash scheme.

- update Version

- Reconstruction application proxy logic

- Fix Tab destroy error

- Optimize repeat healthcheck

- Optimize Direct mode ui

- Optimize Healthcheck

- Remove proxies position animation, improve performance
- Add Telegram Link

- Update healthcheck policy

- New Check URLTest

- Fix the problem of invalid auto-selection

- New Async UpdateConfig

- add changeProfileDebounce

- Update Workflow

- Fix ChangeProfile block

- Fix Release Message Error

- Update Selector 2

- Update Version

- Fix Proxies Select Error

- Fix the problem that the proxy group is empty in global mode.

- Fix the problem that the proxy group is empty in global mode.

- Add ProxyProvider2

- Add ProxyProvider

- Update Version

- Update ProxyGroup Sort

- Fix Android quickStart VpnService some problems

- Update version

- Set Android notification low importance

- Fix the issue that VpnService can't be closed correctly in special cases

- Fix the problem that TileService is not destroyed correctly in some cases

- Adjust tab animation defaults

- Add Telegram in README_zh_CN.md

- Add Telegram

- update mobile_scanner

- Initial commit

## Unreleased

### Changed (breaking for closed test group)

- Windows: dropweb no longer hijacks `flclash://` and `clashx://` deep-link
  handlers. Users with FlClashX installed will see their FlClashX handler
  restored on next launch of either app. One-time migration during first
  launch (guarded by `windows_protocol_cleanup_v1` SharedPreferences flag)
  removes our existing claims on those shared schemes so FlClashX reclaims
  them.
- Windows: window width is now capped at 600 px (portrait/compact layout
  only). The connect button, navigation bar, and widget layout only exist
  in the ≤600 px viewport — this is a design decision, not a regression.
- Subscription protocol: Remnawave panels must now emit `dropweb-*` HTTP
  response headers (`dropweb-widgets`, `dropweb-hex`, `dropweb-servicename`,
  `dropweb-servicelogo`, `dropweb-serverinfo`, `dropweb-view`,
  `dropweb-settings`, `dropweb-background`, `dropweb-globalmode`,
  `dropweb-custom`) instead of `flclashx-*`. Legacy `flclashx-*` headers
  are silently ignored.

### Fixed

- Windows: connect button disappearing when the window was dragged wider
  than 600 px.
- Windows: dropweb inadvertently loading FlClashX-targeted subscription
  links via hijacked `flclash://` protocol handler — combined with
  Remnawave panels serving `flclashx-widgets` headers, this caused dropweb
  to silently render FlClashX's dashboard layout after a user clicked a
  Telegram-bot `flclash://install-config?url=...` link.

## v0.5.2

- fix(macos): tray popover was growing vertically past its configured
  600 px height — on a narrow tray popover it stretched to ~1180 px
  because the Flutter view pushed the NSPopover to fit content.
  Pinning `preferredContentSize = 375×600` on `PopoverContainer-
  ViewController` locks the popover to the intended size.

- fix(home): MagicRings stayed anchored to a stale global offset when
  the window resized (macOS desktop / orientation changes). Added
  `WidgetsBindingObserver.didChangeMetrics` to `_ConnectCircle` so the
  ring origin is re-reported after the layout settles post-resize.

## v0.5.1

- feat(about): full game-feel pass on the File Transfer easter egg.

  - Friction mechanic #1 — WANDERING TARGET: the `shipped/` drop zone
    drifts in a Lissajous-like path with the amplitude (×1.6) and
    frequency (×1.8) jumping the moment a card is picked up. The target
    actively flees while you aim.
  - Friction mechanic #2 — SHRINKING TARGET: when idle the drop zone
    fills the available height (reads as "obvious target"), but the
    moment a drag starts it animates down to a 220-dp square in the
    centre (`AnimatedContainer`, 280 ms ease-out-cubic). The surrounding
    empty space becomes a miss zone.
  - Friction mechanic #3 — ANTI-DRAG PINGS: speech-bubble taunts cycle
    every 1.1 s while dragging ("куда?", "не туда", "точно?", …). The
    kinvsh card switches to an escalating dread set ("НЕТ", "умоляю",
    "это конец").
  - Success polish: animated progress bar (350 ms), 14-particle confetti
    via `CustomPainter`, drop-zone pulse (1.0→1.08→1.0), "+1 shipped"
    float-up, medium haptic.
  - Failure polish: releasing outside the target triggers a heavy haptic
    and a shard burst via the same painter with a muted grey palette +
    slimmer rectangles, originating at the global drop point.
  - Surprise A — CHEN BOOMERANG: chen08209's first "successful" drop is
    a fakeout. The card pops back out with a red "не так быстро /
    chen08209 вернулся" banner, progress rolls back to 0, you drop him
    again. Triggers once. The joke is you think the game glitched.
  - Surprise B — KINVSH GHOST COUNTER: while kinvsh is hovering the
    drop zone, the "Перенеси 9 из 9" counter cycles through nonsense
    frames ("9 из 13" → "9 из ∞" → "? из ?"). Pure typographic dread.
  - Surprise C — KINVSH GLITCH EXIT: instead of a calm "connection lost"
    screen, dropping kinvsh fires a 4-flash black/red sequence
    (~120 ms each, heavy haptic on each) followed by a fake terminal
    stack trace ("kernel panic: unexpected contributor") before the app
    actually calls `handleExit()`. Total ~1.5 s of drama before exit.

- fix(game): `AnimatedContainer` between `double.infinity` and a finite
  number crashed with "Cannot interpolate between finite and unbounded
  constraints" (box.dart:495). Wrapped the drop zone in `LayoutBuilder`
  and animate between two resolved finite numbers instead. Added a
  fallback (360/480) for the first layout pass when the parent can be
  unbounded.

## v0.5.0

- perf: fix Dashboard → Settings transition stutter

  Root cause: `_TvItem` in `lib/views/tools.dart` triggered a Keystore
  IPC call (`preferences.getProfileUrl`) via `unawaited()` on every
  ToolsView `build()`. During a page transition the home state cascade
  rebuilt ToolsView several times back-to-back, blocking the UI thread
  on repeated Keystore reads.

  Fix: move the profile-URL fetch from `build()` into `initState()`
  via `ref.listenManual(currentProfileProvider, ...)`, so the IPC
  fires only when the profile actually changes.

  Measured on Pixel 10 (SurfaceFlinger --latency, debug build):

  |          | before | after |
  |----------|--------|-------|
  | p50      |   9 ms |  8 ms |
  | p95      |  55 ms | 11 ms |
  | p99      | 335 ms | 15 ms |
  | slow (>12ms) | 19% |  6%  |

  The 335ms single-frame spike on first transition is gone.

- fix(about): restore missing icon.png

  The logo asset was accidentally removed in `61fe7c0` ("remove unused
  legacy brand assets") but still referenced by the About page,
  sidebar, and launcher icon config. Restored from git history.

- refactor(about): clean up the About page

  Dropped the three separate "contributors / thanks / gratitude"
  sections inherited from upstream forks. Public About is now lean:
  logo + name + version + core + description + `Based on FlClashX` +
  a single "Благодарность" menu entry that opens a credits sheet.

  Removed in-app "Check for updates" on Android (Play Store policy
  forbids it — updates go through the store channel). Retained for
  desktop builds.

  Fixed stale repo links: `Оригинальный репозиторий` now points to
  pluralplay/FlClashX (our direct upstream, not chen08209/FlClash),
  `Ядро` points to MetaCubeX/mihomo (the actual VPN engine).

- feat(about): 3D flip on dropweb header

  Tap the logo + name block to flip it 180° — the front shows the
  dropweb icon and name/version, the back shows the author's avatar
  and `kinvsh`. Tap again to flip back. Subtle vanity, nothing more.

- feat(about): File Transfer drag-and-drop easter egg

  Ten taps on the header open a game: drag each contributor card from
  `contributors/` into `shipped/`, in credits order (chen08209 →
  pluralplay → ... → kinvsh). The last card (kinvsh) closes the app
  on drop via `appController.handleExit()`. You literally can't finish
  shipping yourself.

  Added avatars: `chen08209.jpg`, `enkinvsh.jpg` (GitHub).

## v0.4.5

- fix(fatal): resolve splash hang on cold start / post-reboot

  Root cause: `lib/common/file_logger.dart` used `DateFormat('yyyy-MM-dd')`
  without an explicit locale. During early cold start (before
  `Intl.systemLocale` is loaded), `intl_helpers.verifiedLocale` throws.
  `_processQueue` caught the error silently and recursively re-scheduled
  itself via `unawaited(_processQueue())`. Every queued log message
  re-triggered the same throw, producing an infinite microtask loop that
  starved the event loop — so `runApp`'s widget mount never fired and
  the splash screen sat on `DRAW_PENDING` forever.

  Most visible after reboot (the service isolate floods logs before the
  main isolate schedules its first frame), but the bug was fundamentally
  a time-of-check / locale-availability race, independent of device.

  Fix:
  - Replace `DateFormat` with manual ISO formatting in `_getTodayDate`
    and `_getTimestamp`. No locale dependency.
  - Drop the write queue on sink failure instead of retrying a broken
    sink — infinite retry on persistent errors is never correct.

  Diagnosed via Dart VM service `getStack` on a live hung debug build.

- security: move subscription URLs to flutter_secure_storage
- security: harden Dart + Android surface for Play submission
- perf: cache Theme.of() + debounce sticky-header scroll updates
- fix(android): FAB now reacts when VPN is stopped from outside the app
- fix(android): bump minSdk to 24 for flutter_secure_storage v10
- fix(android): suppress R8 warnings for unused Play Core / tika classes
- fix(android): restore bottom-right ambient glow on splash

## v0.4.4

- fix(ci): add write permissions for changelog job

## v0.4.3

- fix(android): restore minSdk 23 (required by core module)

## v0.4.2

- feat(windows): unified tray icon - black bg, gray db when inactive

## v0.4.1

- chore: use flutter SDK minSdkVersion, update fork refs

- perf: optimize UI for mid-range devices (Pixel 5)

- - disable BackdropFilter blur on navbar, connect button, subscription tabs
- - disable ColorBendsBg shader (reloads on every rebuild)
- - enable keep: true for dashboard/tools pages to avoid rebuild on switch
- - add AutomaticKeepAliveClientMixin for Proxies/Profiles tabs

- Fixes 12fps lag on swipes and page transitions on Snapdragon 765G.

- docs: improve README - stars badge, SEO alt texts, sync EN version

- docs: remove build instructions

- docs: add dropweb.org link

- docs: add trending AI keywords

- docs: add disclaimer with SEO keywords

- docs: clean up README, restore header

# Changelog

## v0.4.0

- Улучшена стабильность и безопасность соединения

## v0.3.4

- feat(ui): remove Direct mode, auto-select fastest proxy for Global
- feat(android): add home screen VPN toggle widget with Lumina styling
- feat(ux): hide navbar when no profile — onboarding-ready first launch
- feat(ux): add profile bottom sheet with QR/URL + glow pulse when no profile
- feat(ui): rework navbar — oval glass pill selector, dual icons, compact layout
- refactor(ui): use theme colors for mesh background instead of hardcoded Lumina
- fix(android): bump minSdk to 23 to match core module
- fix(ci): await Windows/Linux build, clean release layout
