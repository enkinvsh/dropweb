import 'package:dropweb/common/proxy.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  const ProxyManager({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _updateProxy(ProxyState proxyState) async {
    if (proxyState.isStart && proxyState.systemProxy) {
      // The core's mixed-port. On desktop patchRawConfig keeps the patched /
      // provider mixed-port; the random credentials port is the MOBILE
      // listener only — nothing listens on it here.
      await systemProxyOwner.apply(proxyState.port, proxyState.bassDomain);
    } else {
      await systemProxyOwner.clear(userEnabled: proxyState.systemProxy);
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      proxyStateProvider,
      (prev, next) {
        if (prev != next) {
          _updateProxy(next);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
