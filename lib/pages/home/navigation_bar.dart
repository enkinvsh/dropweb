import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

String navigationLabel(PageLabel label) => switch (label) {
      PageLabel.cabinet => 'Кабинет',
      _ => Intl.message(label.name),
    };

/// Developer mode activation via 5 rapid CONSECUTIVE taps on the Settings
/// tab. Any tap on another tab (or a pause >3s) resets the counter so
/// users bouncing between Dashboard and Settings don't accidentally
/// unlock dev mode.
int _devTapCount = 0;
DateTime _devTapLast = DateTime(0);
const _devTapThreshold = 5;
const _devTapWindow = Duration(seconds: 3);

void _resetDevTapCount() {
  _devTapCount = 0;
  _devTapLast = DateTime(0);
}

void _handleDevTap(BuildContext context, WidgetRef ref) {
  final now = DateTime.now();
  if (now.difference(_devTapLast) > _devTapWindow) {
    _devTapCount = 0;
  }
  _devTapLast = now;
  _devTapCount++;
  final alreadyEnabled = ref.read(appSettingProvider).developerMode;
  if (alreadyEnabled) return;
  if (_devTapCount >= _devTapThreshold) {
    _devTapCount = 0;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(developerMode: true),
        );
    globalState.showNotifier(appLocalizations.developerModeEnableTip);
  }
}

class CommonNavigationBar extends ConsumerWidget {
  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  static const double _mobileNavigationHeight = 80.0;

  static const _icons = <PageLabel, (IconData, IconData)>{
    PageLabel.cabinet: (Icons.account_circle_outlined, Icons.account_circle),
    PageLabel.dashboard: (Icons.dashboard_outlined, Icons.dashboard_rounded),
    PageLabel.tools: (Icons.settings_outlined, Icons.settings_rounded),
  };

  static IconData _navIcon(PageLabel label, bool selected) {
    final pair = _icons[label];
    if (pair == null) return Icons.circle_outlined;
    return selected ? pair.$2 : pair.$1;
  }

  Widget _buildTabBarContent(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) =>
      Container(
        height: _mobileNavigationHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: Lumina.glassOpacity),
          borderRadius: BorderRadius.circular(Lumina.radiusXxl),
          border: Border.all(
            color: Colors.white.withValues(alpha: Lumina.glassBorderOpacity),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List.generate(navigationItems.length, (index) {
              final item = navigationItems[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: Semantics(
                  identifier: 'dw_nav_${item.label.name}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      globalState.appController.toPage(item.label);
                      if (item.label == PageLabel.tools) {
                        _handleDevTap(context, ref);
                      } else if (item.label == PageLabel.dashboard) {
                        _resetDevTapCount();
                      } else {
                        _resetDevTapCount();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(Lumina.radiusXxl - 6),
                      ),
                      child: Center(
                        child: Icon(
                          _navIcon(item.label, isSelected),
                          size: 36,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewMode == ViewMode.mobile) {
      final colorScheme = Theme.of(context).colorScheme;
      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            boxShadow: Lumina.glassShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            // BackdropFilter disabled for perf test
            child: _buildTabBarContent(context, colorScheme, ref),
          ),
        ),
      );
    }
    final showLabel =
        ref.watch(appSettingProvider.select((state) => state.showLabel));
    return Material(
      color: context.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // App logo at the top of sidebar
          if (!Platform.isMacOS) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircleAvatar(
                      foregroundImage: AssetImage("assets/images/icon.png"),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      appName,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: context.colorScheme.surfaceContainer,
                    selectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    selectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    unselectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    destinations: navigationItems
                        .map(
                          (e) => NavigationRailDestination(
                            icon: Semantics(
                              identifier: 'dw_nav_${e.label.name}',
                              child: e.icon,
                            ),
                            label: Text(
                              navigationLabel(e.label),
                            ),
                          ),
                        )
                        .toList(),
                    onDestinationSelected: (index) {
                      globalState.appController
                          .toPage(navigationItems[index].label);
                    },
                    extended: false,
                    selectedIndex: currentIndex,
                    labelType: showLabel
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          IconButton(
            onPressed: () {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(
                      showLabel: !state.showLabel,
                    ),
                  );
            },
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu01, size: 24),
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}

class HomeBackScope extends StatelessWidget {
  const HomeBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return CommonPopScope(
        onPop: () async {
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
          return false;
        },
        child: child,
      );
    }
    return child;
  }
}
