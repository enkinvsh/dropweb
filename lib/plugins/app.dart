import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dropweb/common/app_localizations.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class App {

  factory App() {
    _instance ??= App._internal();
    return _instance!;
  }

  App._internal() {
    methodChannel = const MethodChannel("app");
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "exit":
          if (onExit != null) {
            await onExit!();
          }
        case "getText":
          try {
            return Intl.message(call.arguments as String);
          } catch (_) {
            return "";
          }
        default:
          throw MissingPluginException();
      }
    });
  }
  static App? _instance;
  late MethodChannel methodChannel;
  Function()? onExit;

  Future<bool?> moveTaskToBack() async => methodChannel.invokeMethod<bool>("moveTaskToBack");

  Future<List<Package>> getPackages() async {
    final packagesString =
        await methodChannel.invokeMethod<String>("getPackages");
    return Isolate.run<List<Package>>(() {
      final List<dynamic> packagesRaw =
          packagesString != null ? json.decode(packagesString) : [];
      return packagesRaw.map((e) => Package.fromJson(e)).toSet().toList();
    });
  }

  Future<List<String>> getChinaPackageNames() async {
    final packageNamesString =
        await methodChannel.invokeMethod<String>("getChinaPackageNames");
    return Isolate.run<List<String>>(() {
      final List<dynamic> packageNamesRaw =
          packageNamesString != null ? json.decode(packageNamesString) : [];
      return packageNamesRaw.map((e) => e.toString()).toList();
    });
  }

  Future<bool> openFile(String path) async => await methodChannel.invokeMethod<bool>("openFile", {
          "path": path,
        }) ??
        false;

  Future<ImageProvider?> getPackageIcon(String packageName) async {
    final base64 = await methodChannel.invokeMethod<String>("getPackageIcon", {
      "packageName": packageName,
    });
    if (base64 == null) {
      return null;
    }
    return MemoryImage(base64Decode(base64));
  }

  Future<bool?> tip(String? message) async => methodChannel.invokeMethod<bool>("tip", {
      "message": "$message",
    });

  Future<bool?> initShortcuts() async => methodChannel.invokeMethod<bool>(
      "initShortcuts",
      appLocalizations.toggle,
    );

  Future<bool?> updateExcludeFromRecents(bool value) async => methodChannel.invokeMethod<bool>("updateExcludeFromRecents", {
      "value": value,
    });

  /// Pixel-tuned native haptic cues for the dashboard power button.
  ///
  /// On Android the call routes through `AppPlugin.performHapticFeedback`,
  /// which maps each cue to a `View.performHapticFeedback` constant (e.g.
  /// `GESTURE_START`, `CONFIRM`, `GESTURE_END`) so the system haptic engine
  /// renders the platform-native feel. If the native channel is missing
  /// (desktop, tests, very old Android) or fails, we fall back to Flutter's
  /// generic `HapticFeedback` shim so callers never need a try/catch.
  Future<void> performHapticFeedback(DropwebHapticCue cue) async {
    try {
      final ok = await methodChannel.invokeMethod<bool>(
        "performHapticFeedback",
        {"cue": cue.name},
      );
      if (ok == true) return;
    } on MissingPluginException catch (_) {
      // Native side absent — fall through to Flutter fallback.
    } on PlatformException catch (_) {
      // Native side errored — fall through to Flutter fallback.
    }
    await _fallbackHaptic(cue);
  }

  Future<void> _fallbackHaptic(DropwebHapticCue cue) async {
    switch (cue) {
      case DropwebHapticCue.gestureStart:
        await HapticFeedback.selectionClick();
      case DropwebHapticCue.confirm:
        await HapticFeedback.mediumImpact();
      case DropwebHapticCue.cancel:
        await HapticFeedback.lightImpact();
    }
  }
}

/// Semantic haptic cues consumed by the dashboard power button.
///
/// String names (`.name`) are part of the public method-channel contract
/// with `AppPlugin.kt` and are covered by `test/plugins/app_haptics_test.dart`.
enum DropwebHapticCue {
  gestureStart,
  confirm,
  cancel,
}

final app = Platform.isAndroid ? App() : null;
