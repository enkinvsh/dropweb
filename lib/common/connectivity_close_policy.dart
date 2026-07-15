import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether a `connectivity_plus` change may destructively close core
/// connections.
///
/// Desktop (Windows/macOS/Linux) keeps its historical behavior: it has no
/// native bearer watcher, so a connectivity change without an active VPN
/// interface closes stale flows. Android must NEVER close from here — the
/// native active-bearer tracker (VpnPlugin/BearerTracker) is the single
/// authority for destructive resets, and `connectivity_plus` events on
/// Android would double-fire against it.
bool shouldCloseConnectionsForConnectivity({
  required bool isDesktop,
  required List<ConnectivityResult> results,
}) =>
    isDesktop && !results.contains(ConnectivityResult.vpn);

/// Coordinator for the `onConnectivityChanged` callback: applies the close
/// policy, then unconditionally runs the two non-destructive updates. The
/// updates are deliberately NOT gated behind desktop or VPN state and are
/// not debounced here.
Future<void> handleConnectivityChanged({
  required bool isDesktop,
  required List<ConnectivityResult> results,
  required FutureOr<Object?> Function() closeConnections,
  required void Function() updateLocalIp,
  required void Function() addCheckIpNumDebounce,
}) async {
  if (shouldCloseConnectionsForConnectivity(
    isDesktop: isDesktop,
    results: results,
  )) {
    await Future.sync(closeConnections);
  }
  updateLocalIp();
  addCheckIpNumDebounce();
}
