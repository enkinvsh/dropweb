import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  const AppStateManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Unclean-exit recovery (macOS): if a previous session injected 1.1.1.1
    // into the system DNS and crashed before restoring, the true origin sits
    // in SharedPreferences (`macos_origin_dns`). Restoring here heals the
    // system DNS at launch instead of waiting for the next connect cycle.
    // In a clean state (no persisted origin, no in-memory origin) this is a
    // no-op, and the _dnsOp queue serializes it ahead of any auto-connect.
    unawaited(system.setMacOSDns(true));
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.cacheHeightMap = {};
        }
      });
    });
    ref.listenManual(
      checkIpProvider,
      (prev, next) {
        if (prev != next && next.b) {
          detectionState.startCheck();
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    ref.listenManual(
      autoSetSystemDnsStateProvider,
      (prev, next) async {
        if (prev == next) {
          return;
        }
        // Fire-and-forget is safe: set/restore ordering is guaranteed by the
        // _dnsOp promise queue inside System.setMacOSDns, so rapid toggles can't
        // interleave and capture the injected DNS as the origin.
        if (next.a == true && next.b == true) {
          system.setMacOSDns(false);
        } else {
          system.setMacOSDns(true);
        }
      },
    );
  }

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void dispose() {
    // dispose() is sync; DNS reset is fire-and-forget. Ordering vs. any pending
    // set/restore is guaranteed by the _dnsOp queue inside System.setMacOSDns.
    unawaited(system.setMacOSDns(true));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log("$state");
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      globalState.appController.savePreferencesDebounce();
    } else if (state == AppLifecycleState.resumed) {
      render?.resume();
      // Reconcile FAB with native state — QS tile / notification STOP don't notify us.
      unawaited(globalState.appController.syncRunStateFromNative());
    } else {
      render?.resume();
    }
    // Gate the 20s proxy-group poll on real backgrounding only. inactive fires
    // for transient overlays (permission dialog, notification shade) and on
    // desktop window blur — it must NOT pause the poll. Pause on
    // paused/hidden/detached; resume (with an immediate refresh) on resumed.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        globalState.pauseGroupsPolling?.call();
      case AppLifecycleState.resumed:
        globalState.resumeGroupsPolling?.call();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerHover: (_) {
          render?.resume();
        },
        child: widget.child,
      );
}

class AppEnvManager extends StatelessWidget {
  const AppEnvManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
