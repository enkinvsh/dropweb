import 'dart:ui';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
}

@immutable
class ExtendProps {
  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
  });
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
}

enum SheetType {
  page,
  bottomSheet,
  sideSheet,
}

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: props.isScrollControlled,
        backgroundColor: Colors.transparent,
        builder: (_) => BackdropFilter(
          filter: props.blur ? commonFilter : ImageFilter.blur(),
          child: SafeArea(
            child: builder(context, SheetType.bottomSheet),
          ),
        ),
        showDragHandle: false,
        useSafeArea: props.useSafeArea,
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur ? commonFilter : null,
        builder: (_) => builder(context, SheetType.sideSheet),
      ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => BaseNavigator.push(
        context,
        builder(context, SheetType.page),
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur ? commonFilter : null,
        builder: (context) => builder(context, SheetType.sideSheet),
      ),
  };
}

class AdaptiveSheetScaffold extends StatefulWidget {
  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.disableBackground = true,
    this.onTitleTap,
  });
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final bool disableBackground;

  /// Optional tap handler attached to the AppBar title. Used by the
  /// Settings sheet to surface the 5-rapid-taps developer-mode unlock on
  /// the screen header (see `DevUnlockCounter`).
  final VoidCallback? onTitleTap;

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomSheet = widget.type == SheetType.bottomSheet;
    final sideSheet = widget.type == SheetType.sideSheet;
    final page = widget.type == SheetType.page;
    final backgroundColor = colorScheme.surface.withValues(alpha: 0.92);
    // Page-mode (mobile push from showExtend) renders inside CommonScaffold's
    // dark void with the mesh background. Forcing an opaque surface tint on
    // the AppBar produced the black header users saw when opening Settings
    // from the dashboard. Let the mesh bleed through instead.
    final appBar = AppBar(
      forceMaterialTransparency: bottomSheet || page,
      automaticallyImplyLeading: bottomSheet
          ? false
          : widget.actions.isEmpty && sideSheet
              ? false
              : true,
      centerTitle: bottomSheet,
      backgroundColor: page ? Colors.transparent : backgroundColor,
      elevation: page ? 0 : null,
      title: widget.onTitleTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTitleTap,
              child: Text(widget.title),
            )
          : Text(widget.title),
      actions: genActions([
        if (widget.actions.isEmpty && sideSheet) const CloseButton(),
        ...widget.actions,
      ]),
    );
    if (bottomSheet) {
      const handleSize = Size(32, 4);
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                alignment: Alignment.center,
                height: handleSize.height,
                width: handleSize.width,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(handleSize.height / 2),
                  ),
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            appBar,
            Flexible(
              flex: 1,
              child: widget.body,
            )
          ],
        ),
      );
    }
    return CommonScaffold(
      appBar: appBar,
      // For page-mode we want CommonScaffold's normal dark-mode treatment
      // (Lumina.void_ fill + mesh) to show, so don't pass a custom tint and
      // re-enable the background layer.
      backgroundColor: page ? null : backgroundColor,
      body: widget.body,
      disableBackground: page ? false : widget.disableBackground,
    );
  }
}
