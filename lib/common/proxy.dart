import 'dart:async';

import 'package:dropweb/common/system.dart';
import 'package:proxy/proxy.dart';
import 'package:proxy/proxy_platform_interface.dart';

final proxy = system.isDesktop ? Proxy() : null;

/// The single writer of the desktop OS system proxy.
///
/// dropweb must not wipe a proxy it does not own: the OS setting is shared
/// with the user's own PAC / WPAD / corporate proxy, and clearing it on every
/// launch and disconnect (while dropweb's own «system proxy» is off) silently
/// broke those setups. The OS proxy is therefore cleared only when dropweb set
/// it in this session, or when the user has dropweb's system proxy enabled —
/// the latter keeps the old recovery of a proxy left behind by a crash or a
/// forced shutdown.
class SystemProxyOwner {
  SystemProxyOwner(this._proxy);

  final ProxyPlatform? _proxy;
  bool _applied = false;
  Future<void> _last = Future.value();

  /// OS mutations run strictly one after another: an unawaited start racing a
  /// stop (quick toggles) could otherwise leave the wrong final state.
  Future<void> _serial(Future<void> Function() op) {
    final next = _last.then((_) => op());
    _last = next.catchError((Object _) {});
    return next;
  }

  Future<void> apply(int port, List<String> bypassDomain) => _serial(() async {
        final proxy = _proxy;
        if (proxy == null) return;
        _applied = true;
        await proxy.startProxy(port, bypassDomain);
      });

  Future<void> clear({required bool userEnabled}) => _serial(() async {
        final proxy = _proxy;
        if (proxy == null) return;
        if (!_applied && !userEnabled) return;
        if (await proxy.stopProxy() == true) {
          _applied = false;
        }
      });
}

final systemProxyOwner = SystemProxyOwner(proxy);
