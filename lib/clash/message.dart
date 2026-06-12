import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/foundation.dart';

class ClashMessage {

  ClashMessage._() {
    // Core messages carry untrusted-derived data (connection hosts,
    // server-influenced log payloads). A single malformed message must never
    // tear down the subscription — onError logs and keeps the stream alive so
    // logs/delays/tun updates do not silently stop.
    controller.stream.listen(
      dispatch,
      onError: (Object error, StackTrace stack) {
        commonPrint.log('[ffi] message stream error: $error');
      },
    );
  }

  @visibleForTesting
  void dispatch(Map<String, Object?> message) {
    if (message.isEmpty) {
      return;
    }
    // Guard the per-message parse: a wrong-shape map (e.g. an undecodable
    // `type`) must be dropped, not throw out of the stream callback.
    final AppMessage m;
    try {
      m = AppMessage.fromJson(message);
    } catch (e) {
      commonPrint.log('[ffi] dropped malformed core message: $e');
      return;
    }
    // The tun payload is hard-cast to a Map below; reject a non-Map payload
    // up front so a ClassCastError can't kill dispatch for every listener.
    if (m.type == AppMessageType.tun && m.data is! Map) {
      commonPrint.log('[ffi] dropped malformed tun message: data is not a Map');
      return;
    }
    for (final listener in _listeners) {
      // Per-listener guard: one throwing listener (or a malformed payload that
      // only surfaces during parse, e.g. Log/Delay/Connection.fromJson) must
      // not starve the remaining listeners.
      try {
        switch (m.type) {
          case AppMessageType.log:
            listener.onLog(Log.fromJson(m.data));
            break;
          case AppMessageType.delay:
            listener.onDelay(Delay.fromJson(m.data));
            break;
          case AppMessageType.request:
            listener.onRequest(Connection.fromJson(m.data));
            break;
          case AppMessageType.loaded:
            listener.onLoaded(m.data);
            break;
          case AppMessageType.tun:
            listener.onTun(Map<String, dynamic>.from(m.data as Map));
            break;
        }
      } catch (e) {
        commonPrint.log('[ffi] dropped malformed core message: $e');
      }
    }
  }
  final controller = StreamController<Map<String, Object?>>();

  static final ClashMessage instance = ClashMessage._();

  final ObserverList<AppMessageListener> _listeners =
      ObserverList<AppMessageListener>();

  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(AppMessageListener listener) {
    _listeners.add(listener);
  }

  void removeListener(AppMessageListener listener) {
    _listeners.remove(listener);
  }
}

final clashMessage = ClashMessage.instance;
