import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:dropweb/views/views.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class Navigation {
  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }

  Navigation._internal();
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    Uri? cabinetUri,
  }) =>
      [
        if (cabinetUri != null)
          NavigationItem(
            keep: true,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedUserAccount,
              size: 24,
            ),
            label: PageLabel.cabinet,
            path: cabinetUri.toString(),
            view: CabinetBrowserEntry(
              key: const GlobalObjectKey(PageLabel.cabinet),
              url: cabinetUri,
            ),
          ),
        const NavigationItem(
          keep: true, // keep alive to avoid rebuild lag on return
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedDashboardSquare01,
            size: 24,
          ),
          label: PageLabel.dashboard,
          view: DashboardView(
            key: GlobalObjectKey(PageLabel.dashboard),
          ),
        ),
        const NavigationItem(
          keep: true, // keep alive to avoid rebuild lag on return
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedSettings02,
            size: 24,
          ),
          label: PageLabel.tools,
          view: ToolsView(
            key: GlobalObjectKey(
              PageLabel.tools,
            ),
          ),
          modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
        ),
      ];
}

final navigation = Navigation();
