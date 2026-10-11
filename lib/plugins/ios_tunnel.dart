import 'dart:io';

import 'package:flutter/services.dart';

/// Bridge to ios/Runner/IosTunnelPlugin.swift (NETunnelProviderManager).
class IosTunnel {
  const IosTunnel._();
  static const instance = IosTunnel._();
  static const _channel = MethodChannel('dropweb/ios_tunnel');

  Future<String?> groupPath() => _channel.invokeMethod<String>('groupPath');

  /// Writes the three quickStart JSONs into the App Group and starts the tunnel.
  Future<bool?> start({
    required String init,
    required String setup,
    required String state,
  }) =>
      _channel.invokeMethod<bool>(
          'start', {'init': init, 'setup': setup, 'state': state});

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  /// NEVPNStatus raw value: 0 invalid, 1 disconnected, 2 connecting,
  /// 3 connected, 4 reasserting, 5 disconnecting.
  Future<int?> status() => _channel.invokeMethod<int>('status');

  /// One invokeAction JSON to the extension; returns its ActionResult JSON,
  /// or null when the tunnel is not connected.
  Future<String?> send(String actionJson) =>
      _channel.invokeMethod<String>('send', actionJson);

  void onStatus(void Function(int status) listener) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'status') listener(call.arguments as int);
    });
  }
}

IosTunnel? get iosTunnel => Platform.isIOS ? IosTunnel.instance : null;
