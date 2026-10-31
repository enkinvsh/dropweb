import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/plugins/ios_tunnel.dart';
import 'package:dropweb/plugins/ios_tunnel_forwarder.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dropweb/ios_tunnel');

IosTunnelPayload _payload(String signature) => (
      init: '{}',
      setup: '{}',
      state: '{}',
      signature: signature,
      stillRemote: <String>[],
    );

/// Сценарий для [GlobalState.syncIosTunnelConfig] через шов
/// [IosTunnelSyncHooks]: на хосте нет iOS, канала и `AppController`.
class _Harness {
  /// Статус туннеля в моке канала: 3 — connected, 1 — disconnected.
  int status = 3;
  String nextSignature = 'B';

  /// Пока не завершён, новый старт туннеля «поднимается».
  Completer<void>? startGate;
  bool startResult = true;

  final channelCalls = <String>[];
  final startedSignatures = <String>[];
  int restartedCalls = 0;
  int teardownCalls = 0;
  final notifications = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      channelCalls.add(call.method);
      switch (call.method) {
        case 'status':
          return status;
        case 'stop':
          status = 1;
          return null;
      }
      return null;
    });
    globalState.iosTunnelSyncHooks = IosTunnelSyncHooks(
      buildPayload: () async => _payload(nextSignature),
      restarter: () => IosTunnelRestarter(
        log: (_) {},
        tunnel: IosTunnel.instance,
        stopTimeout: const Duration(milliseconds: 200),
        pollInterval: const Duration(milliseconds: 5),
        statusTimeout: const Duration(milliseconds: 50),
      ),
      startTunnel: (payload) async {
        startedSignatures.add(payload.signature);
        final gate = startGate;
        if (gate != null) await gate.future;
        if (startResult) status = 3;
        return startResult;
      },
      onRestarted: () => restartedCalls++,
      teardown: () async {
        teardownCalls++;
        // Как штатный стоп: handleStop обнуляет таймер сеанса.
        globalState.startTime = null;
      },
      notify: notifications.add,
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    globalState.iosTunnelSyncHooks = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Harness h;
  late DateTime sessionStart;

  // commonPrint.log пишет и в файловый журнал: ему нужен каталог приложения.
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('ios_tunnel_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
  });

  setUp(() {
    h = _Harness()..install();
    sessionStart = DateTime.now().subtract(const Duration(minutes: 5));
    globalState.timer?.cancel();
    globalState.timer = null;
    globalState.startTime = sessionStart;
    globalState.isConnecting.value = false;
    globalState.iosTunnelSignatureForTest = 'A';
  });

  tearDown(() {
    h.uninstall();
    globalState.startTime = null;
    globalState.isConnecting.value = false;
    globalState.iosTunnelSignatureForTest = null;
  });

  test('подпись не изменилась: перезапуска нет', () async {
    h.nextSignature = 'A';

    await globalState.syncIosTunnelConfig(reason: 'test');

    expect(h.channelCalls, isEmpty);
    expect(h.startedSignatures, isEmpty);
    expect(h.restartedCalls, 0);
    expect(globalState.startTime, sessionStart);
  });

  test('подпись изменилась: перезапуск, таймер сеанса сохранён, проверка IP',
      () async {
    await globalState.syncIosTunnelConfig(reason: 'test');

    expect(h.channelCalls, ['status', 'stop', 'status']);
    expect(h.startedSignatures, ['B']);
    expect(h.restartedCalls, 1);
    expect(h.teardownCalls, 0);
    expect(h.notifications, isEmpty);
    expect(globalState.startTime, sessionStart);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.iosTunnelSignatureForTest, 'B');
  });

  test('failed: штатный стоп, подпись null, ровно один тост', () async {
    h.startResult = false;

    await globalState.syncIosTunnelConfig(reason: 'test');

    expect(h.teardownCalls, 1);
    expect(h.notifications, [ErrorMapper.vpnStartFailed]);
    expect(h.restartedCalls, 0);
    expect(globalState.startTime, isNull);
    expect(globalState.isStart, isFalse);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.iosTunnelSignatureForTest, isNull);
  });

  test('notConnected: штатный стоп без тоста', () async {
    h.status = 1; // туннель пропал сам

    await globalState.syncIosTunnelConfig(reason: 'test');

    expect(h.startedSignatures, isEmpty);
    expect(h.teardownCalls, 1);
    expect(h.notifications, isEmpty);
    expect(globalState.startTime, isNull);
    expect(globalState.isConnecting.value, isFalse);
    expect(globalState.iosTunnelSignatureForTest, isNull);
  });

  test('вызов во время перезапуска: ровно один отложенный повтор', () async {
    h.startGate = Completer<void>();
    final first = globalState.syncIosTunnelConfig(reason: 'A→B');
    await _until(() => h.startedSignatures.isNotEmpty);

    // Две смены подряд, пока туннель поднимается: обе сливаются в один повтор.
    h.nextSignature = 'C';
    await globalState.syncIosTunnelConfig(reason: 'B→C');
    await globalState.syncIosTunnelConfig(reason: 'B→C again');
    expect(globalState.iosSyncPending, isTrue);

    h.startGate!.complete();
    h.startGate = null;
    await first;

    expect(h.startedSignatures, ['B', 'C']);
    expect(h.restartedCalls, 2);
    expect(globalState.iosSyncPending, isFalse);
    expect(globalState.iosTunnelSignatureForTest, 'C');
    expect(globalState.isConnecting.value, isFalse);
  });

  test('стоп пользователя во время перезапуска: повтора нет', () async {
    h.startGate = Completer<void>();
    final first = globalState.syncIosTunnelConfig(reason: 'A→B');
    await _until(() => h.startedSignatures.isNotEmpty);

    h.nextSignature = 'C';
    await globalState.syncIosTunnelConfig(reason: 'B→C');
    expect(globalState.iosSyncPending, isTrue);
    // Во время перехода стоп игнорируется, но отложенный повтор снимает.
    expect(await globalState.handleStop(), isFalse);
    expect(globalState.iosSyncPending, isFalse);

    h.startGate!.complete();
    h.startGate = null;
    await first;

    expect(h.startedSignatures, ['B']);
    expect(h.restartedCalls, 1);
  });
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}
