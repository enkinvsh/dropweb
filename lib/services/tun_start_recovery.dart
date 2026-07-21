import 'package:dropweb/clash/start_listener_result.dart';

enum TunStartRecovery { connected, timedOut }

typedef TunStartAttempt = Future<void> Function();
typedef TunStartRecoverStep = Future<void> Function();

/// Pure two-element recovery loop for a desktop TUN start.
///
/// [start] performs one logical connect; it returns normally on success,
/// throws [StartListenerTimeoutException] on the 30s RPC timeout, and throws
/// [TunStartException] on a real synchronous core cause. The loop runs [start]
/// at most twice: the initial start, then — only on a FIRST timeout — exactly
/// one [recover] (poison + exact helper stop + single restart + strict init)
/// followed by one retry. A second timeout ends the loop as
/// [TunStartRecovery.timedOut]. Recovery failures propagate fail-closed, and a
/// [TunStartException] is never retried.
Future<TunStartRecovery> runTunStartRecovery({
  required TunStartAttempt start,
  required TunStartRecoverStep recover,
}) async {
  try {
    await start();
    return TunStartRecovery.connected;
  } on StartListenerTimeoutException {
    await recover();
  }

  try {
    await start();
    return TunStartRecovery.connected;
  } on StartListenerTimeoutException {
    return TunStartRecovery.timedOut;
  }
}
