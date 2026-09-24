// SystemProxyOwner is the only writer of the desktop OS system proxy.
//
// Regression lock for A6-3: dropweb used to call stopProxy() on EVERY launch
// and disconnect — even with its own «system proxy» switched off — which wiped
// the user's own PAC / WPAD / corporate proxy. It now clears the OS proxy only
// when it set it this session, or when the user has dropweb's system proxy on
// (that keeps the crash / forced-shutdown recovery the old behaviour gave).
import 'dart:async';

import 'package:dropweb/common/proxy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy_platform_interface.dart';

class _FakeProxy extends ProxyPlatform {
  final calls = <String>[];
  bool stopResult = true;
  Completer<void>? startGate;

  @override
  Future<bool?> startProxy(int port, List<String> bypassDomain) async {
    calls.add('start:$port');
    await startGate?.future;
    return true;
  }

  @override
  Future<bool?> stopProxy() async {
    calls.add('stop');
    return stopResult;
  }
}

void main() {
  late _FakeProxy fake;
  late SystemProxyOwner owner;

  setUp(() {
    fake = _FakeProxy();
    owner = SystemProxyOwner(fake);
  });

  test('launch/disconnect with system proxy off never touches the OS proxy',
      () async {
    await owner.clear(userEnabled: false);
    await owner.clear(userEnabled: false);
    expect(fake.calls, isEmpty);
  });

  test('system proxy on: cleared even if not set this session (crash recovery)',
      () async {
    await owner.clear(userEnabled: true);
    expect(fake.calls, ['stop']);
  });

  test('a proxy dropweb applied is cleared after the user turns the switch off',
      () async {
    await owner.apply(7890, const []);
    await owner.clear(userEnabled: false);
    expect(fake.calls, ['start:7890', 'stop']);

    // Ownership released: the next disconnect leaves the OS alone.
    await owner.clear(userEnabled: false);
    expect(fake.calls, ['start:7890', 'stop']);
  });

  test('a failed stop keeps ownership so the next clear retries', () async {
    await owner.apply(7890, const []);
    fake.stopResult = false;
    await owner.clear(userEnabled: false);
    fake.stopResult = true;
    await owner.clear(userEnabled: false);
    expect(fake.calls, ['start:7890', 'stop', 'stop']);
  });

  test('start and stop are serialized: a stop never overtakes a slow start',
      () async {
    fake.startGate = Completer<void>();
    final start = owner.apply(7890, const []);
    final stop = owner.clear(userEnabled: false);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['start:7890']);
    fake.startGate!.complete();
    await Future.wait([start, stop]);
    expect(fake.calls, ['start:7890', 'stop']);
  });

  test('no proxy backend (mobile): both calls are no-ops', () async {
    final mobile = SystemProxyOwner(null);
    await mobile.apply(7890, const []);
    await mobile.clear(userEnabled: true);
  });
}
