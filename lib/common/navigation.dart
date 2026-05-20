import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
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
  }) =>
      [
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
          // Desktop-only: on mobile, Settings is reached via the explicit
          // settings icon on the Dashboard subscription card rather than a
          // horizontal swipe / bottom-tab page.
          modes: [NavigationItemMode.desktop],
        ),
      ];
}

final navigation = Navigation();
