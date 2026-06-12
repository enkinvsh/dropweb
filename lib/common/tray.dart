import 'dart:io';

import 'package:dropweb/common/utils.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'window.dart';

class Tray {
  Future _updateSystemTray({
    required Brightness? brightness,
    required bool isRunning,
    bool force = false,
  }) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      // Skip tray on Android and macOS (macOS uses native status bar)
      return;
    }
    if (Platform.isLinux || force) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      utils.getTrayIconPath(
        brightness: brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        isRunning: isRunning,
      ),
      isTemplate: true,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(
        appName,
      );
    }
  }

  Future<void> update({
    required TrayState trayState,
    bool focus = false,
  }) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      // Skip tray on Android and macOS (macOS uses native status bar)
      return;
    }
    if (!Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        isRunning: trayState.isStart,
        force: focus,
      );
    }
    // Intentionally minimal tray menu: only Показать / Автозапуск / Выход.
    // The старт-стоп, TUN, системный прокси, копирование переменных
    // окружения and перезапуск entries were removed — connect/disconnect
    // and proxy toggles live in the window UI; the mode axis
    // (rule/global/direct) is DERIVED from the profile's work mode in
    // AppController._setupClashConfig and must not be switched from the tray.
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        globalState.appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await globalState.appController.handleExit();
      },
    );
    final menuItems = <MenuItem>[
      showMenuItem,
      autoStartMenuItem,
      MenuItem.separator(),
      exitMenuItem,
    ];
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    if (Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        isRunning: trayState.isStart,
        force: focus,
      );
    }
  }

  Future<void> updateTrayTitle([Traffic? traffic]) async {}
}

final tray = Tray();
