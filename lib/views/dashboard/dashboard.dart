import 'dart:async';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/card_menu.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with PageMixin {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void initState() {
    ref.listenManual(
      isCurrentPageProvider(PageLabel.dashboard),
      (prev, next) {
        if (prev != next && next == true) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
    return super.initState();
  }

  @override
  void dispose() {
    _isEditNotifier.dispose();
    super.dispose();
  }

  @override
  Widget? get floatingActionButton => null; // Moved to bottom of body

  // ignore: avoid_positional_boolean_parameters
  Widget _buildIsEdit(Widget Function(bool) builder) => ValueListenableBuilder(
        valueListenable: _isEditNotifier,
        builder: (_, isEdit, ___) => builder(isEdit),
      );

  @override
  List<Widget> get actions => [];

  // ignore: unused_element
  void _showAddWidgetsModal() {
    showSheet(
      builder: (_, type) => ValueListenableBuilder(
        valueListenable: _addedWidgetsNotifier,
        builder: (_, value, __) => AdaptiveSheetScaffold(
          type: type,
          body: _AddDashboardWidgetModal(
            items: value,
            onAdd: (gridItem) {
              key.currentState?.handleAdd(gridItem);
            },
          ),
          title: appLocalizations.add,
        ),
      ),
      context: context,
    );
  }

  void _handleUpdateIsEdit() {
    if (_isEditNotifier.value == true) {
      _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  void _handleSave() {
    final children = key.currentState?.children;
    if (children == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardWidgets = children
          .map(
            DashboardWidget.getDashboardWidget,
          )
          .toList();
      ref.read(appSettingProvider.notifier).updateState(
            (state) => state.copyWith(dashboardWidgets: dashboardWidgets),
          );
    });
  }

  bool _isAllowedWidget(
    DashboardWidget item, {
    required bool hasServiceInfoData,
    required bool hasServerInfoData,
  }) {
    if (!item.platforms.contains(SupportPlatform.currentPlatform)) {
      return false;
    }

    if (item == DashboardWidget.serviceInfo && !hasServiceInfoData) {
      return false;
    }
    if (item == DashboardWidget.changeServerButton && !hasServerInfoData) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final hasServiceInfo = ref.watch(hasServiceInfoDataProvider);
    final hasServerInfo = ref.watch(hasServerInfoDataProvider);
    final hasNoProfiles = ref.watch(
      profilesProvider.select((state) => state.isEmpty),
    );
    final isMobileView = ref.watch(isMobileViewProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    const columns = 8;
    final spacing = 16.ap;

    if (hasNoProfiles) {
      return const SizedBox.expand();
    }

    // Mobile / narrow-window view overlays the floating connect button at
    // ~79% of viewport height (see `_mobileConnectAlignment` /
    // `_MobileConnectButtonOverlay` in `pages/home.dart`). When the
    // desktop window is shrunk vertically the subscription/metainfo
    // card ends up *behind* the connect lens because the scroll content
    // has no room to slide above it. Reserve bottom padding proportional
    // to the viewport height (with a sensible floor / ceiling) so the
    // last dashboard widget can always scroll out from under the lens.
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomReserve = isMobileView
        ? (viewportHeight * 0.42).clamp(200.0, 320.0)
        : 16.0;

    bool isAllowed(DashboardWidget item) => _isAllowedWidget(
          item,
          hasServiceInfoData: hasServiceInfo,
          hasServerInfoData: hasServerInfo,
        );

    final children = [
      ...dashboardState.dashboardWidgets.where(isAllowed).map(
            (item) => item.widget,
          ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) => !children.contains(item.widget) && isAllowed(item),
          )
          .map((item) => item.widget)
          .toList();
    });
    Future<void> handleRefresh() async {
      final profile = currentProfile;
      if (profile == null) return;
      unawaited(App().playUiSound(DropwebSoundCue.subscriptionRefresh));
      try {
        await globalState.appController.updateProfile(profile);
      } catch (e, st) {
        debugPrint('Dashboard pull-to-refresh failed: $e\n$st');
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RefreshIndicator(
          onRefresh: handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16).copyWith(
              bottom: bottomReserve,
            ),
            child: Column(
              children: [
                // Dashboard widgets
                _buildIsEdit(
                  (isEdit) => Column(
                    children: [
                      isEdit
                          ? SystemBackBlock(
                              child: CommonPopScope(
                                child: SuperGrid(
                                  key: key,
                                  crossAxisCount: columns,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  onUpdate: _handleSave,
                                  children: [
                                    ...dashboardState.dashboardWidgets
                                        .where(isAllowed)
                                        .map(
                                          (item) => item.widget,
                                        ),
                                  ],
                                ),
                                onPop: () {
                                  _handleUpdateIsEdit();
                                  return false;
                                },
                              ),
                            )
                          : Grid(
                              crossAxisCount: columns,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              children: children,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom swipe-up handle that opens the shared card menu. The accent
        // up-arrow is pinned near the TOP of the hit band; the band stretches
        // down to the bottom edge so a natural bottom-up swipe (started below
        // the arrow) is still captured. Band height scales with viewport height
        // (adaptive). An upward fling OR a tap opens the menu. Translucent hit
        // area so it never blocks the connect button, scroll, or pull-to-refresh.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: isMobileView
              ? (viewportHeight * 0.06).clamp(56.0, 150.0).toDouble()
              : 64.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => showCardMenu(context, ref),
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -250) {
                showCardMenu(context, ref);
              }
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUp01,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  const _AddDashboardWidgetModal({
    required this.items,
    required this.onAdd,
  });
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  @override
  Widget build(BuildContext context) => DeferredPointerHandler(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            16,
          ),
          child: Grid(
            crossAxisCount: 8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: items
                .map(
                  (item) => item.wrap(
                    builder: (child) => _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
}

class _AddedContainer extends StatefulWidget {
  const _AddedContainer({
    required this.child,
    required this.onAdd,
  });
  final Widget child;
  final VoidCallback onAdd;

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          ActivateBox(
            child: widget.child,
          ),
          Positioned(
            top: -8,
            right: -8,
            child: DeferPointer(
              child: SizedBox(
                width: 24,
                height: 24,
                child: IconButton.filled(
                  iconSize: 20,
                  padding: const EdgeInsets.all(2),
                  onPressed: _handleAdd,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 20,
                  ),
                ),
              ),
            ),
          )
        ],
      );
}
