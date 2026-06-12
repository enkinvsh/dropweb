import 'dart:io';
import 'package:flutter/services.dart';

class StatusBarManager {
  static const MethodChannel _channel = MethodChannel('status_bar_icon');

  static Future<void> updateIcon({required bool isConnected}) async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('updateIcon', {
        'isConnected': isConnected,
      });
    } catch (e) {
      // silent
    }
  }

  /// Bring the macOS status-bar popover to the foreground. No-op off macOS.
  static Future<void> showWindow() async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('showWindow');
    } catch (e) {
      // silent
    }
  }
}
