import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/vpn.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../common/common.dart';

/// Connect-lifecycle concern carved out of [AppController].
///
/// [AppController] keeps thin delegating methods with identical signatures, so
/// every existing call site (`globalState.appController.updateStatus(...)`,
/// `updateStart()`, `syncRunStateFromNative()`, …) stays untouched — the nine
/// `updateStatus` callers (start button, QS tile, tray, hotkey, init reconcile,
/// core-death self-heal) never move.
///
/// No [BuildContext] is stored here — the moved code reaches the rest of the
/// app exclusively via `_ref`, `globalState`, and the public [AppController]
/// facade (`globalState.appController.*`) for the few controller-resident
/// concerns that stay: config setup-hash invalidation ([invalidateSetupHash]),
/// core (re)initialization ([initCore]), and the debounced apply / check-ip
/// tasks (`applyProfileDebounce`, `addCheckIpNumDebounce`). The setup-hash and
/// `lastProfileModified` remain owned by the controller's config domain; the
/// realign restart-budget moves here with its sole heavy user ([requestAdmin])
/// and is reset from the staying config entry points via
/// [resetCoreRealignBudget].
///
/// Private controller callers that stay ([AppController.changeProxyDebounce] →
/// [updateForegroundServerName], [AppController.init] →
/// [handleUnexpectedCoreDeath], `_setupClashConfig`/`_updateClashConfig` →
/// [requestAdmin]) reach these now-public service methods through the
/// controller's private delegate stubs.
class ConnectService {
  ConnectService(this._ref);

  final WidgetRef _ref;

  /// Bounded guard for core restarts issued from [requestAdmin] (both the
  /// post-authorize restart and the Windows realign self-heal). Every
  /// restartCore() from requestAdmin recurses via initCore → applyProfile →
  /// setupClashConfig → requestAdmin, and loadingRun has no re-entrancy
  /// guard — an unbounded success↔none alternation under a flapping helper
  /// would recurse forever. So: every restart from here counts against ONE
  /// shared cap, nothing inside the recursion ever resets it, and the counter
  /// is reset only at non-recursive user-action entry points
  /// ([updateStatus], `updateClashConfig`, `handleChangeProfile`) so a later
  /// user action always gets a fresh chance to realign (no permanent
  /// per-session TUN-off).
  int _coreRealignAttempts = 0;

  static const _maxCoreRealignAttempts = 3;

  /// Resets the realign restart-budget. Called from the controller's staying
  /// config entry points (`updateClashConfig`, `handleChangeProfile`) so a
  /// later user action always gets a fresh realign chance.
  void resetCoreRealignBudget() {
    _coreRealignAttempts = 0;
  }

  /// Update cached server name in VPN plugin for foreground notification
  /// Also sends IPC message to service isolate to update selectedMap
  void updateForegroundServerName(String groupName, String serverName) {
    vpn?.updateServerName(serverName);
    // Send IPC message to service isolate (Android only)
    clashLib?.sendIpcMessage({
      'action': 'updateForegroundServer',
      'groupName': groupName,
      'serverName': serverName,
    });
  }

  /// Initialize foreground notification cache with current profile and server.
  ///
  /// Pushes profileName / serviceName / serverName into the VPN plugin's
  /// in-memory cache that feeds the Android foreground notification. Call sites:
  ///   • connect ([updateStatus] `isStart==true`) — seed the cache before the
  ///     service comes up.
  ///   • profile switch ([AppController.handleChangeProfile]) — a switch while
  ///     connected hot-swaps the core config but left this cache untouched, so
  ///     the notification kept showing the PREVIOUS profile's label until a
  ///     reconnect/restart (owner-reported).
  ///   • current-profile update ([AppController.updateProfile], active-profile
  ///     branch) — a subscription refresh can change `dropweb-servicename` /
  ///     the label rendered in the notification.
  /// The plugin setters (`updateProfileInfo`/`updateServerName`) are pure
  /// in-memory writes with no MethodChannel/notification side effect, so calling
  /// this while disconnected is a cheap, harmless cache prime (never flashes a
  /// notification).
  void initForegroundCache() {
    final profile = globalState.config.currentProfile;
    if (profile == null) return;

    final profileName = profile.label ?? profile.id;

    // Decode service name from header (may be `base64:`-prefixed base64).
    String serviceName = "";
    final svc = profile.providerHeaders['dropweb-servicename'];
    if (svc != null && svc.isNotEmpty) {
      serviceName = decodeMaybeBase64(svc).trim();
    }

    vpn?.updateProfileInfo(
      profileName: profileName,
      serviceName: serviceName,
    );

    // Get current server name from selectedMap
    final groupName = profile.providerHeaders['dropweb-serverinfo'];
    if (groupName != null && groupName.isNotEmpty) {
      final decodedGroupName = decodeMaybeBase64(groupName).trim();
      final serverName = profile.selectedMap[decodedGroupName] ?? "";
      vpn?.updateServerName(serverName);
    }

    // The plugin cache writes above only feed the notification when the MAIN
    // isolate composes foreground params. In Android service mode the title is
    // composed by the handler in main.dart from the SERVICE isolate's OWN
    // `globalState.config.currentProfile` snapshot, which mutates ONLY via IPC
    // ('updateForegroundServer' → selectedMap, 'updateMode' → mode). A profile
    // switch/update sends no IPC, so that snapshot keeps the OLD profile and the
    // title (profile-title → dropweb-serverinfo → servicename chain) stays stale
    // even after the cache write above (live speed updates masked it — the
    // service isolate was the one answering). Mirror the updateForegroundServer
    // precedent: push the freshly-active profile to the service isolate so its
    // title chain resolves the NEW profile. Fire-and-forget — sendIpcMessage
    // awaits the handshake internally, so this stays sync (same as
    // updateForegroundServerName, which also does not await).
    clashLib?.sendIpcMessage({
      'action': 'updateCurrentProfile',
      'profileId': profile.id,
      'profile': json.encode(profile.toJson()),
    });
  }

  Future<void> restartCore() async {
    commonPrint.log("restart core");
    // A restarted core process starts UNCONFIGURED. The content-hash gate in
    // _setupClashConfig compares against the last SUCCESSFUL setup of the
    // PREVIOUS process — with unchanged inputs it would "hash match" and skip
    // the setup entirely, leaving the fresh core with no proxies/rules while
    // the UI claims connected. A new process must never hit the cache.
    globalState.appController.invalidateSetupHash();
    await clashService?.reStart();
    await globalState.appController.initCore();
    if (_ref.read(runTimeProvider.notifier).isStart) {
      await globalState.handleStart();
    }
  }

  /// Timestamp of the last automatic recovery from an unexpected desktop core
  /// death. Bounds the self-heal to at most ONE auto-restart per
  /// [_coreDeathRecoveryCooldown]: a crash-looping core must not be restarted
  /// forever — once the budget is spent we fail HONEST (stopped state + a
  /// visible error) instead of hammering a doomed core or lying "connected".
  DateTime? _lastCoreDeathRecovery;
  static const _coreDeathRecoveryCooldown = Duration(minutes: 5);

  /// Wired to [ClashService.onUnexpectedCoreDeath] (desktop only). The core
  /// process died or the bridge socket dropped without us initiating it.
  Future<void> handleUnexpectedCoreDeath(String reason) async {
    commonPrint.log('[core-bridge] controller: core died — $reason');
    final now = DateTime.now();
    final last = _lastCoreDeathRecovery;
    if (last != null && now.difference(last) < _coreDeathRecoveryCooldown) {
      // Budget spent within the cooldown window: stop restarting. Present an
      // honest stopped state and a user-visible error rather than a lying
      // "connected" UI whose every request silently times out.
      commonPrint.log(
        '[core-bridge] within cooldown — failing honest (stopped)',
      );
      await updateStatus(false);
      globalState.showNotifier(ErrorMapper.vpnStartFailed);
      return;
    }
    _lastCoreDeathRecovery = now;
    // One bounded self-heal: restartCore() clears _lastSetupHash and re-runs
    // handleStart if the UI still shows started.
    try {
      await restartCore();
    } on CoreBootException catch (error, stackTrace) {
      commonPrint.log(
        '[core-bridge] automatic recovery exhausted: $error\n$stackTrace',
      );
      await updateStatus(false);
      final message =
          ErrorMapper.mapError(error.toString()) ?? error.toString();
      unawaited(
        globalState.showErrorMessage(
          message: TextSpan(text: message),
          diagnosticPhase: error.diagnosticPhase,
        ),
      );
    }
  }

  /// Confirm window before treating a `null` runtime as a real external stop.
  /// A single `getRunTime()==null` during screen-lock churn is a transient miss
  /// (dropped bridge reply / invoke timeout), NOT a stop (handoff §2). Wait,
  /// then re-probe: a live tunnel answers on the second read within this window.
  static const _stopConfirmDelay = Duration(milliseconds: 300);

  /// Single-flight state for [syncRunStateFromNative]. Every `resumed` fires an
  /// unawaited sync; overlapping probes whose stale, out-of-order completion
  /// could tear down a live dashboard are collapsed: a probe already running
  /// marks the run dirty (re-reconcile once) and the generation counter makes
  /// every post-`await` continuation bail if a newer resume superseded it.
  int _syncGeneration = 0;
  bool _syncInFlight = false;
  bool _syncDirty = false;

  /// Read-only reconcile of Dart VPN state with native runtime. Never toggles VPN.
  Future<void> syncRunStateFromNative() async {
    if (!Platform.isAndroid) return;
    ++_syncGeneration;
    if (_syncInFlight) {
      _syncDirty = true;
      return;
    }
    _syncInFlight = true;
    try {
      do {
        _syncDirty = false;
        await _reconcileRunStateOnce(_syncGeneration);
      } while (_syncDirty);
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _reconcileRunStateOnce(int gen) async {
    final firstProbe = await clashLib?.getRunTime();
    if (gen != _syncGeneration) return; // superseded by a newer resume
    final nativeIsRunning = firstProbe != null;
    final uiIsRunning = _ref.read(runTimeProvider.notifier).isStart;
    if (nativeIsRunning == uiIsRunning) return;

    if (nativeIsRunning) {
      // Native running, UI not (external start / fresh isolate) — heal to running.
      globalState.startTime = firstProbe;
      commonPrint.log(
        'syncRunStateFromNative: native=true ui=false '
        'disposition=heal_running (startTime=$firstProbe)',
      );
      await _applyRunning();
      return;
    }

    // Suspected stop: first probe null while UI shows running. Confirm before teardown.
    await Future<void>.delayed(_stopConfirmDelay);
    if (gen != _syncGeneration) return;
    final confirmProbe = await clashLib?.getRunTime();
    if (gen != _syncGeneration) return;

    if (confirmProbe != null) {
      // Transient miss — tunnel is alive. Heal instead of tearing down.
      globalState.startTime = confirmProbe;
      commonPrint.log(
        'syncRunStateFromNative: native=true ui=false '
        'disposition=heal_transient (startTime=$confirmProbe)',
      );
      if (!_ref.read(runTimeProvider.notifier).isStart) {
        await _applyRunning();
      } else {
        await StatusBarManager.updateIcon(isConnected: true);
      }
      return;
    }

    // UI may have caught up to stopped during the confirm delay.
    if (!_ref.read(runTimeProvider.notifier).isStart) return;

    // Two consecutive nulls, UI still running — a REAL external stop
    // (QS tile / notification STOP). Tunnel already down; tear down Dart state.
    globalState.startTime = null;
    commonPrint.log(
      'syncRunStateFromNative: native=false ui=true disposition=confirmed_stop',
    );
    await _applyStopped();
  }

  /// Re-arm the live dashboard (runtime + speed ticker + connected icon). The
  /// periodic ticker is armed only by handleStart -> startUpdateTasks; on an
  /// external start the app isolate can be fresh with an empty task list, so the
  /// dashboard would freeze at a static runtime and 0 B/s. startUpdateTasks is
  /// idempotent via its timer.isActive guard.
  Future<void> _applyRunning() async {
    updateRunTime();
    // The periodic ticker (runtime + speed) is armed only by
    // handleStart -> startUpdateTasks. On an EXTERNAL start (QS tile /
    // notification) the app isolate can be fresh, so globalState.tasks is
    // empty and the dashboard would freeze at a static runtime and 0 B/s.
    // Re-arm with the same task pair handleStart uses; startUpdateTasks is
    // idempotent via its timer.isActive guard.
    unawaited(globalState.startUpdateTasks([updateRunTime, updateTraffic]));
    // Symmetry with the stop branch's updateIcon(false) — macOS-only no-op
    // on Android, kept for parity with updateStatus(true)'s connected icon.
    await StatusBarManager.updateIcon(isConnected: true);
  }

  /// Tear down Dart bookkeeping for a confirmed native stop WITHOUT re-calling
  /// handleStop (the native side already stopped). Body preserved verbatim from
  /// the original else-branch — do not alter its order or calls.
  Future<void> _applyStopped() async {
    // Native already stopped — tear down Dart bookkeeping without re-calling handleStop.
    clashCore.resetTraffic();
    _ref.read(trafficsProvider.notifier).clear();
    _ref.read(totalTrafficProvider.notifier).value = Traffic();
    _ref.read(runTimeProvider.notifier).value = null;
    globalState.stopUpdateTasks();
    await StatusBarManager.updateIcon(isConnected: false);
    globalState.appController.addCheckIpNumDebounce();
  }

  Future<void> updateStatus(bool isStart) async {
    // Fresh user action — new core-restart budget for requestAdmin.
    _coreRealignAttempts = 0;
    if (isStart) {
      ConnectTrace.mark('updateStatus');
      // Central safety gate: every code path that turns the VPN on must
      // pass through here, so first-run disclosure consent is enforced
      // even for non-UI entry points (Quick Settings tile, desktop tray,
      // hotkey, hidden auto-run). Disconnect is intentionally never gated.
      // UI is NOT shown from the controller — the dashboard StartButton is
      // responsible for surfacing the dialog and persisting consent before
      // it calls back into this method. If consent is missing we simply
      // refuse the start so external triggers can't bypass the disclosure.
      if (!await vpnConsent.isAccepted()) {
        commonPrint.log(
          'updateStatus(true) refused: VPN disclosure consent not granted',
        );
        return;
      }
    }
    if (isStart) {
      // Regenerate proxy credentials for this session (SOCKS port protection)
      globalState.regenerateProxyCredentials();
      // Initialize foreground notification cache before starting
      initForegroundCache();
      final started = await globalState.handleStart([
        updateRunTime,
        updateTraffic,
      ]);
      // null => a start/stop transition is already in flight (double-tap).
      // Do nothing: no toast, and leave the status icon untouched.
      if (started == null) {
        return;
      }
      // false => the start was attempted but failed. Revert the icon (it may
      // have been flipped on by an optimistic UI) and surface the error.
      if (started == false) {
        await StatusBarManager.updateIcon(isConnected: false);
        globalState.showNotifier(ErrorMapper.vpnStartFailed);
        return;
      }
      // true => connected. Only now is it honest to show the connected icon.
      await StatusBarManager.updateIcon(isConnected: true);
      if (Platform.isAndroid) {
        // FlClashX parity: the long-lived mihomo executor (DNS resolver, fake-ip
        // pool, providers) survives stop→start and degrades over long sessions —
        // force a full profile re-setup on every Android connect.
        globalState.appController.applyProfileDebounce();
        return;
      }
      final currentLastModified =
          await _ref.read(currentProfileProvider)?.profileLastModified;
      if (currentLastModified == null ||
          globalState.appController.lastProfileModified == null) {
        globalState.appController.addCheckIpNumDebounce();
        return;
      }
      if (currentLastModified <=
          (globalState.appController.lastProfileModified ?? 0)) {
        globalState.appController.addCheckIpNumDebounce();
        return;
      }
      globalState.appController.applyProfileDebounce();
    } else {
      // false => stop was ignored because a transition is in flight; do not
      // tear down UI/providers for a stop that never happened.
      final stopped = await globalState.handleStop();
      if (!stopped) return;
      await StatusBarManager.updateIcon(isConnected: false);
      // The mihomo executor survives stop→start and degrades over long
      // sessions (B2). The forced Android applyProfileDebounce() on connect
      // would be defeated by the setup-hash cache ("setup skipped"), so drop
      // the hash here: every connect-after-disconnect performs a REAL core
      // re-setup, while repeated applies during a live session stay cached.
      globalState.appController.invalidateSetupHash();
      // Clear credentials on disconnect
      globalState.clearProxyCredentials();
      clashCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      _ref.read(runTimeProvider.notifier).value = null;
      globalState.appController.addCheckIpNumDebounce();
    }
  }

  void updateRunTime() {
    final startTime = globalState.startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      _ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      _ref.read(runTimeProvider.notifier).value = null;
    }
  }

  Future<void> updateTraffic() async {
    final traffic = await clashCore.getTraffic();
    _ref.read(trafficsProvider.notifier).addTraffic(traffic);
    _ref.read(totalTrafficProvider.notifier).value =
        await clashCore.getTotalTraffic();
  }

  Future<Result<bool>> requestAdmin(bool enableTun) async {
    final realTunEnable = _ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          if (_coreRealignAttempts >= _maxCoreRealignAttempts) {
            commonPrint.log(
                "[helper] restart budget exhausted after authorize — degrading to TUN-off for this apply cycle");
            enableTun = false;
            break;
          }
          _coreRealignAttempts++;
          await restartCore();
          return Result.error("");
        case AuthorizeCode.none:
          // Windows: AuthorizeCode.none only means "the helper service is up
          // and verified" — it does NOT mean the LIVE core was spawned through
          // it. On first launch / after an update / on the logon auto-start
          // race the core was spawned directly (unprivileged) before the
          // helper came up; pushing tun.enable=true at it silently fails
          // (wintun needs privileges) and used to poison the session until an
          // app restart. Realign: restart the core through the now-ready
          // helper, sharing the same bounded restart budget as the success
          // path so no authorize-outcome alternation can recurse forever.
          if (Platform.isWindows &&
              clashService?.coreStartedByHelper == false) {
            if (_coreRealignAttempts >= _maxCoreRealignAttempts) {
              // Budget exhausted — ship an honest proxy-only session instead
              // of a fake TUN one. The next user action resets the budget.
              commonPrint.log(
                  "[helper] realign budget exhausted — degrading to TUN-off for this apply cycle");
              enableTun = false;
              break;
            }
            _coreRealignAttempts++;
            commonPrint.log(
                "[helper] core is unprivileged but helper is ready — realigning core via helper (attempt $_coreRealignAttempts/$_maxCoreRealignAttempts)");
            await restartCore();
            return Result.error("");
          }
          break;
        case AuthorizeCode.error:
          enableTun = false;
          break;
      }
    }
    _ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
  }

  void updateStart() {
    updateStatus(!_ref.read(runTimeProvider.notifier).isStart);
  }
}
