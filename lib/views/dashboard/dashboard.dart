import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/cabinet/cabinet_view.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
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

  void _showAddSubscriptionModal() {
    showSheet(
      context: context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.addSubscription,
        body: _AddSubscriptionKeyQuestion(
          onHasKey: () {
            Navigator.of(context).pop();
            _showSubscriptionImportModal();
          },
          onNeedsSubscription: () {
            Navigator.of(context).pop();
            BaseNavigator.push(
              context,
              const CabinetWebView(initialPath: '/login'),
            );
          },
        ),
      ),
    );
  }

  void _showSubscriptionImportModal() {
    showSheet(
      context: context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.addSubscription,
        body: _SubscriptionImportSelector(
          onScanQr: () {
            Navigator.of(context).pop();
            scanProfileQrCode(context);
          },
          onPasteUrl: () {
            Navigator.of(context).pop();
            showProfileUrlDialog(context);
          },
        ),
      ),
    );
  }

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
    required bool globalModeEnabled,
    required bool hasServiceInfoData,
    required bool hasServerInfoData,
  }) {
    if (!item.platforms.contains(SupportPlatform.currentPlatform)) {
      return false;
    }

    if (!globalModeEnabled) {
      if (item == DashboardWidget.outboundMode ||
          item == DashboardWidget.outboundModeV2) {
        return false;
      }
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
    final globalModeEnabled = ref.watch(globalModeEnabledProvider);
    final hasServiceInfo = ref.watch(hasServiceInfoDataProvider);
    final hasServerInfo = ref.watch(hasServerInfoDataProvider);
    final hasNoProfiles = ref.watch(
      profilesProvider.select((state) => state.isEmpty),
    );
    final columns = max(4 * ((dashboardState.viewWidth / 320).ceil()), 8);
    final spacing = 16.ap;

    if (hasNoProfiles) {
      return _EmptySubscriptionDashboard(
        onPressed: _showAddSubscriptionModal,
      );
    }

    bool isAllowed(DashboardWidget item) => _isAllowedWidget(
          item,
          globalModeEnabled: globalModeEnabled,
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
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16).copyWith(
            bottom: 16,
          ),
          child: Column(
            children: [
              // Dashboard widgets
              _buildIsEdit((isEdit) => isEdit
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
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptySubscriptionDashboard extends StatelessWidget {
  const _EmptySubscriptionDashboard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
              minHeight: 240,
            ),
            child: CommonCard(
              radius: Lumina.radiusLg,
              enterAnimated: true,
              onPressed: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: Lumina.glassCircle(
                        opacity: Lumina.glassHoverOpacity,
                        borderOpacity: Lumina.glassHoverBorderOpacity,
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAddCircle,
                          size: 28,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      appLocalizations.addSubscription,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appLocalizations.doYouHaveConnectionKey,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _AddSubscriptionKeyQuestion extends StatelessWidget {
  const _AddSubscriptionKeyQuestion({
    required this.onHasKey,
    required this.onNeedsSubscription,
  });

  final VoidCallback onHasKey;
  final VoidCallback onNeedsSubscription;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appLocalizations.doYouHaveConnectionKey,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onHasKey,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedKey02,
                size: 20,
              ),
              label: Text(appLocalizations.iHaveKey),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onNeedsSubscription,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedUserAccount,
                size: 20,
              ),
              label: Text(appLocalizations.iNeedSubscription),
            ),
          ],
        ),
      );
}

class _SubscriptionImportSelector extends StatelessWidget {
  const _SubscriptionImportSelector({
    required this.onScanQr,
    required this.onPasteUrl,
  });

  final VoidCallback onScanQr;
  final VoidCallback onPasteUrl;

  @override
  Widget build(BuildContext context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          ListItem(
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedQrCode,
              size: 24,
            ),
            title: Text(appLocalizations.scanQrCode),
            subtitle: Text(appLocalizations.qrcodeDesc),
            onTap: onScanQr,
          ),
          ListItem(
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedCloudDownload,
              size: 24,
            ),
            title: Text(appLocalizations.pasteSubscriptionUrl),
            subtitle: Text(appLocalizations.urlDesc),
            onTap: onPasteUrl,
          ),
        ],
      );
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
