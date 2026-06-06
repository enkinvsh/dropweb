import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidManager extends ConsumerStatefulWidget {
  const AndroidManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Phone-only product: portrait is locked ONCE by the manifest
    // (android:screenOrientation="portrait" on MainActivity). We intentionally
    // do NOT re-assert it here via setPreferredOrientations — that redundant
    // runtime setRequestedOrientation re-triggers Android's fixed-orientation
    // letterbox machinery, which on some Android versions (15) leaks a compat
    // display frame to the launcher on app exit (home-screen icons shift /
    // black bar). See flutter/flutter#184963. Manifest lock is authoritative.
    ref.listenManual(appSettingProvider.select((state) => state.hidden),
        (prev, next) {
      app?.updateExcludeFromRecents(next);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
