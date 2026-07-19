import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'print.dart';
import 'system.dart';

class AutoLaunch {
  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  AutoLaunch._internal() {
    try {
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );
    } catch (err) {
      commonPrint.log('[autolaunch] setup failed: $err');
    }
  }
  static AutoLaunch? _instance;

  Future<bool> get isEnable async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (err) {
      commonPrint.log('[autolaunch] isEnable failed: $err');
      return false;
    }
  }

  Future<bool> enable() async {
    try {
      return await launchAtStartup.enable();
    } catch (err) {
      commonPrint.log('[autolaunch] enable failed: $err');
      return false;
    }
  }

  Future<bool> disable() async {
    try {
      return await launchAtStartup.disable();
    } catch (err) {
      commonPrint.log('[autolaunch] disable failed: $err');
      return false;
    }
  }

  Future<void> updateStatus(bool isAutoLaunch) async {
    try {
      if (kDebugMode) {
        return;
      }
      if (await isEnable == isAutoLaunch) return;
      if (isAutoLaunch) {
        await enable();
      } else {
        await disable();
      }
    } catch (err) {
      commonPrint.log('[autolaunch] updateStatus failed: $err');
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;
