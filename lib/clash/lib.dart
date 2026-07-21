import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/service.dart';
import 'package:dropweb/state.dart';

import 'generated/clash_ffi.dart';
import 'interface.dart';
import 'start_listener_result.dart';

class ClashLib extends ClashHandlerInterface with AndroidClashInterface {

  factory ClashLib() {
    _instance ??= ClashLib._internal();
    return _instance!;
  }

  ClashLib._internal() {
    _initService();
  }
  static ClashLib? _instance;
  Completer<bool> _canSendCompleter = Completer();
  SendPort? sendPort;
  // A ReceivePort is single-subscription: a second listen() on the same port
  // throws StateError. reStart() must be able to re-arm the bridge, so the port
  // is a re-creatable nullable field rather than a `final` created once.
  ReceivePort? _receiverPort;

  /// Upper bound for the cold-boot service handshake. `main()` awaits
  /// [preload] BEFORE `runApp`: an unbounded wait here is an eternal native
  /// splash whenever the service engine, `libclash.so`, or the SendPort
  /// handshake fails (the global error handlers swallow the throw but nothing
  /// ever completes the completer). Bounded, the app always reaches its first
  /// frame; a late handshake still lands via [_listenPort] and heals the
  /// bridge for subsequent calls.
  static const _preloadTimeout = Duration(seconds: 15);

  @override
  Future<bool> preload() async {
    try {
      return await _canSendCompleter.future.timeout(_preloadTimeout);
    } on TimeoutException {
      commonPrint.log(
        "[bridge] preload timed out after ${_preloadTimeout.inSeconds}s — "
        "booting UI without a live core bridge",
      );
      return false;
    }
  }

  /// How long [_tryRehandshake] waits for the live service isolate to answer a
  /// re-handshake before falling back to destroy+init. Bounded so a zombie
  /// isolate (registered port but dead listener) can never hang app startup.
  static const _rehandshakeTimeout = Duration(seconds: 2);

  Future<void> _initService() async {
    // Arm the bridge listener FIRST so the mainIsolate port is registered before
    // we ask the service isolate to re-handshake to it.
    _listenPort();
    final revived = await _tryRehandshake();
    if (!revived) {
      // No live service isolate answered (cold start, or a dead/zombie isolate)
      // — take the original destroy+recreate path.
      await service?.destroy();
      await service?.init();
    }
  }

  /// Reattach to an ALREADY-RUNNING service isolate instead of destroying and
  /// recreating it. Destroying the service engine tears down the live VPN
  /// tunnel (bug 1a/1b): on app reopen the process is still alive with a healthy
  /// core, so we ask that isolate — via its control port registered under
  /// [serviceIsolate] — to repeat the SendPort handshake toward this freshly
  /// created main isolate.
  ///
  /// Returns true only when the service isolate answers and re-sends its
  /// SendPort within [_rehandshakeTimeout]. MUST NEVER throw and MUST NEVER wait
  /// longer than the timeout: any missing port, send error, or timeout returns
  /// false so [_initService] degrades to the old destroy+init path.
  Future<bool> _tryRehandshake() async {
    try {
      final servicePort = IsolateNameServer.lookupPortByName(serviceIsolate);
      if (servicePort == null) {
        return false;
      }
      servicePort.send({'action': 'rehandshake'});
      // serviceInitFailed completes the same bridge future with false. Preserve
      // that value so a failed service cannot masquerade as a revived one and
      // suppress the destroy+init recovery path.
      return await _canSendCompleter.future.timeout(_rehandshakeTimeout);
    } catch (_) {
      return false;
    }
  }

  /// (Re)creates the single-subscription [ReceivePort] and attaches the bridge
  /// listener. Any previous port is closed first so re-entry (reStart) never
  /// listens twice on one port — which would throw StateError.
  void _listenPort() {
    _receiverPort?.close();
    final receiverPort = ReceivePort();
    _receiverPort = receiverPort;
    _registerMainPort(receiverPort.sendPort);
    receiverPort.listen((message) {
      if (message is SendPort) {
        if (_canSendCompleter.isCompleted) {
          sendPort = null;
          _canSendCompleter = Completer();
        }
        sendPort = message;
        _canSendCompleter.complete(true);
      } else if (message is Map) {
        if (message['type'] == 'serviceInitFailed') {
          // The service isolate failed before it could hand us a SendPort
          // (e.g. DynamicLibrary.open("libclash.so") threw). Complete the
          // handshake with `false` IMMEDIATELY so preload()/sendMessage do
          // not sit out their full timeouts on a wait that can never win.
          commonPrint.log(
            "[bridge] service isolate reported init failure: "
            "${message['error']}",
          );
          if (!_canSendCompleter.isCompleted) {
            _canSendCompleter.complete(false);
          }
          return;
        }
        // Ignore other IPC responses (Map type) - they don't need processing
        return;
      } else {
        handleResult(
          ActionResult.fromJson(json.decode(
            message,
          )),
        );
      }
    });
  }

  void _registerMainPort(SendPort sendPort) {
    IsolateNameServer.removePortNameMapping(mainIsolate);
    IsolateNameServer.registerPortWithName(sendPort, mainIsolate);
  }

  @override
  Future<bool> destroy() async {
    await service?.destroy();
    return true;
  }

  @override
  void reStart() {
    _initService();
  }

  @override
  Future<bool> shutdown() async {
    await super.shutdown();
    destroy();
    return true;
  }

  /// Bound for waiting on the bridge before sending. Unbounded waits here
  /// make every core call sit until its outer invoke timeout. On timeout the
  /// message is dropped; downstream invoke() calls fail via their existing
  /// timeout sentinels instead of waiting on the bridge forever.
  static const _sendTimeout = Duration(seconds: 10);

  Future<bool> _awaitBridge() async {
    try {
      return await _canSendCompleter.future.timeout(_sendTimeout);
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> sendMessage(String message) async {
    if (!await _awaitBridge()) {
      commonPrint.log("[bridge] dropping message — no live service bridge");
      return;
    }
    sendPort?.send(message);
  }

  /// Send a custom IPC message to service (for foreground notification updates)
  Future<void> sendIpcMessage(Map<String, dynamic> message) async {
    if (!await _awaitBridge()) {
      commonPrint.log("[bridge] dropping IPC message — no live service bridge");
      return;
    }
    sendPort?.send(message);
  }

  // @override
  // Future<bool> stopTun() {
  //   return invoke<bool>(
  //     method: ActionMethod.stopTun,
  //   );
  // }

  @override
  Future<AndroidVpnOptions?> getAndroidVpnOptions() async {
    final res = await invoke<String>(
      method: ActionMethod.getAndroidVpnOptions,
    );
    if (res.isEmpty) {
      return null;
    }
    return AndroidVpnOptions.fromJson(json.decode(res));
  }

  @override
  Future<bool> updateDns(String value) => invoke<bool>(
      method: ActionMethod.updateDns,
      data: value,
    );

  @override
  Future<DateTime?> getRunTime() async {
    final runTimeString = await invoke<String>(
      method: ActionMethod.getRunTime,
    );
    if (runTimeString.isEmpty) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  @override
  Future<String> getCurrentProfileName() => invoke<String>(
      method: ActionMethod.getCurrentProfileName,
    );
}

class ClashLibHandler {

  factory ClashLibHandler() {
    _instance ??= ClashLibHandler._internal();
    return _instance!;
  }

  ClashLibHandler._internal() {
    lib = DynamicLibrary.open("libclash.so");
    clashFFI = ClashFFI(lib);
    clashFFI.initNativeApiBridge(
      NativeApi.initializeApiDLData,
    );
  }
  static ClashLibHandler? _instance;

  late final ClashFFI clashFFI;

  late final DynamicLibrary lib;

  Future<String> invokeAction(String actionParams) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final actionParamsChar = actionParams.toNativeUtf8().cast<Char>();
    clashFFI.invokeAction(
      actionParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(actionParamsChar);
    return completer.future;
  }

  void attachMessagePort(int messagePort) {
    clashFFI.attachMessagePort(
      messagePort,
    );
  }

  void updateDns(String dns) {
    final dnsChar = dns.toNativeUtf8().cast<Char>();
    clashFFI.updateDns(dnsChar);
    malloc.free(dnsChar);
  }

  void setState(CoreState state) {
    final stateChar = json.encode(state).toNativeUtf8().cast<Char>();
    clashFFI.setState(stateChar);
    malloc.free(stateChar);
  }

  String getCurrentProfileName() {
    final currentProfileRaw = clashFFI.getCurrentProfileName();
    final currentProfile = currentProfileRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(currentProfileRaw);
    return currentProfile;
  }

  AndroidVpnOptions getAndroidVpnOptions() {
    final vpnOptionsRaw = clashFFI.getAndroidVpnOptions();
    final vpnOptions = json.decode(vpnOptionsRaw.cast<Utf8>().toDartString());
    clashFFI.freeCString(vpnOptionsRaw);
    return AndroidVpnOptions.fromJson(vpnOptions);
  }

  Traffic getTraffic() {
    final trafficRaw = clashFFI.getTraffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Traffic getTotalTraffic(bool value) {
    final trafficRaw = clashFFI.getTotalTraffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<StartListenerOutcome> startListener() async {
    clashFFI.startListener();
    return const StartListenerOk();
  }

  Future<bool> stopListener() async {
    clashFFI.stopListener();
    return true;
  }

  DateTime? getRunTime() {
    final runTimeRaw = clashFFI.getRunTime();
    final runTimeString = runTimeRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(runTimeRaw);
    if (runTimeString.isEmpty) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final path = await appPath.getProfilePath(id);
    final pathChar = path.toNativeUtf8().cast<Char>();
    final configRaw = clashFFI.getConfig(pathChar);
    final configString = configRaw.cast<Utf8>().toDartString();
    if (configString.isEmpty) {
      return {};
    }
    final config = json.decode(configString);
    malloc.free(pathChar);
    clashFFI.freeCString(configRaw);
    return config;
  }

  Future<String> quickStart(
    InitParams initParams,
    SetupParams setupParams,
    CoreState state,
  ) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final params = json.encode(setupParams);
    final initValue = json.encode(initParams);
    final stateParams = json.encode(state);
    final initParamsChar = initValue.toNativeUtf8().cast<Char>();
    final paramsChar = params.toNativeUtf8().cast<Char>();
    final stateParamsChar = stateParams.toNativeUtf8().cast<Char>();
    clashFFI.quickStart(
      initParamsChar,
      paramsChar,
      stateParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(initParamsChar);
    malloc.free(paramsChar);
    malloc.free(stateParamsChar);
    return completer.future;
  }
}

ClashLib? get clashLib =>
    Platform.isAndroid && !globalState.isService ? ClashLib() : null;

ClashLibHandler? get clashLibHandler =>
    Platform.isAndroid && globalState.isService ? ClashLibHandler() : null;
