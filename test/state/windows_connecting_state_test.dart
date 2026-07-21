import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/services/tun_start_recovery.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';

class _CompletingStartHandler extends ClashHandlerInterface {
  final List<Completer<StartListenerOutcome>> starts = [];

  @override
  Future<StartListenerOutcome> startListener() {
    final completer = Completer<StartListenerOutcome>();
    starts.add(completer);
    return completer.future;
  }

  @override
  Future<bool> stopListener() async => true;

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

Future<void> _waitForStarts(_CompletingStartHandler handler, int count) async {
  while (handler.starts.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClashHandlerInterface originalInterface;
  late _CompletingStartHandler handler;

  setUp(() {
    originalInterface = clashCore.clashInterface;
    handler = _CompletingStartHandler();
    clashCore.clashInterface = handler;
    globalState.timer?.cancel();
    globalState.timer = null;
    globalState.tasks = [];
    globalState.startTime = null;
    globalState.isConnecting.value = false;
  });

  tearDown(() {
    globalState.timer?.cancel();
    globalState.timer = null;
    globalState.startTime = null;
    globalState.isConnecting.value = false;
    clashCore.clashInterface = originalInterface;
  });

  test('desktop listener wait owns pending and defers runtime until success',
      () async {
    final previousStartTime = DateTime.utc(2026, 7, 21);
    globalState.startTime = previousStartTime;
    final start = globalState.handleStart([]);
    await _waitForStarts(handler, 1);

    final pendingDuringStart = globalState.isConnecting.value;
    final startTimeDuringStart = globalState.startTime;

    handler.starts.single.complete(const StartListenerOk());

    expect(await start, isTrue);
    expect(pendingDuringStart, isTrue);
    expect(startTimeDuringStart, isNull);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.startTime, isNotNull);
    expect(globalState.startTime, isNot(previousStartTime));
  });

  test('outer pending owner spans the timeout recovery and final success',
      () async {
    globalState.isConnecting.value = true;
    bool? pendingDuringRecovery;
    final recovery = runTunStartRecovery(
      start: () async {
        await globalState.handleStart([]);
      },
      recover: () async {
        pendingDuringRecovery = globalState.isConnecting.value;
      },
    );
    await _waitForStarts(handler, 1);

    handler.starts.first.completeError(
      StartListenerTimeoutException(const Duration(seconds: 30)),
    );
    await _waitForStarts(handler, 2);

    final pendingDuringRetry = globalState.isConnecting.value;
    handler.starts.last.complete(const StartListenerOk());

    expect(await recovery, TunStartRecovery.connected);
    expect(pendingDuringRecovery, isTrue);
    expect(pendingDuringRetry, isTrue);
    expect(globalState.isConnecting.value, isTrue);
  });

  test('desktop listener error clears pending after the final outcome',
      () async {
    final start = globalState.handleStart([]);
    await _waitForStarts(handler, 1);

    final pendingDuringStart = globalState.isConnecting.value;
    handler.starts.single.complete(
      const StartListenerTunError('wintun unavailable'),
    );

    await expectLater(start, throwsA(isA<TunStartException>()));
    expect(pendingDuringStart, isTrue);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.startTime, isNull);
  });

  test('desktop listener timeout clears pending after the final outcome',
      () async {
    final start = globalState.handleStart([]);
    await _waitForStarts(handler, 1);

    final pendingDuringStart = globalState.isConnecting.value;
    handler.starts.single.completeError(
      StartListenerTimeoutException(const Duration(seconds: 30)),
    );

    await expectLater(start, throwsA(isA<StartListenerTimeoutException>()));
    expect(pendingDuringStart, isTrue);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.startTime, isNull);
  });
}
