// Regression: ReceiveProfileDialog must not leak its LAN handoff server
// (port 8899) when the dialog is closed while the server is still starting.
// Cancel before the bind completes → dispose() sees no server; the State must
// close the server itself once `serve()` returns into an unmounted State, so
// the port is free and the next «Add from phone» can bind it.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/views/profiles/receive_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Live binding: real event loop, so the leaked HttpServer's idle timer is a
  // real timer (the fake-async binding would flag it as 'pending timer' —
  // which is itself the leak, but aborts the test before the assertions print).
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('closing the dialog before bind completes frees port 8899',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final ipGate = Completer<String?>();
    // A LAN IPv4 of this host (127.0.0.1:8899 may be taken by an unrelated
    // local service on the audit machine).
    final host = (await tester.runAsync(() async {
      final ifs = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return ifs
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .firstWhere((a) => !a.startsWith('169.254.'));
    }))!;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => call.method == 'wifiIPAddress' ? ipGate.future : null,
    );

    // Precondition: nothing is listening on <host>:8899.
    final before = await tester.runAsync(() async {
      try {
        final s = await Socket.connect(host, 8899,
            timeout: const Duration(seconds: 1));
        s.destroy();
        return true;
      } catch (_) {
        return false;
      }
    });
    expect(before, isFalse, reason: 'port must be free before the probe');

    await tester.pumpWidget(const MaterialApp(home: ReceiveProfileDialog()));
    // User presses Cancel while the IP is still resolving → State disposed.
    await tester.pumpWidget(const SizedBox());

    // IP resolves after dispose; let the real bind run, then flush callbacks.
    ipGate.complete(host);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final leaked = await tester.runAsync(() async {
      try {
        final s = await Socket.connect(host, 8899,
            timeout: const Duration(seconds: 1));
        s.destroy();
        return true;
      } catch (_) {
        return false;
      }
    });
    expect(leaked, isFalse,
        reason: 'handoff server must not outlive its dialog');

    // A second dialog can bind the same port again.
    final second = await tester.runAsync(() async {
      try {
        final srv = await HttpServer.bind(host, 8899);
        await srv.close(force: true);
        return 'bound';
      } on SocketException catch (e) {
        return 'SocketException: ${e.osError?.message}';
      }
    });
    expect(second, 'bound');
  });
}
