import 'package:dropweb/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

/// Resolves the on-screen rect of the widget a [LiquidZoomRoute] grows out
/// of, or null when it is gone (unmounted or not laid out).
typedef ZoomSourceResolver = Rect? Function();

/// Apple-style zoom navigation (iOS App Store card / `.navigationTransition(
/// .zoom)`): the page grows out of the tapped card into the full screen on a
/// soft spring and, on close, shrinks back into wherever that card is now.
///
/// * [source] is re-read every frame, so the closing zoom lands on the card
///   even if the dashboard moved underneath.
/// * [anchor] is the point of the destination page that starts on the card's
///   top-left corner — pass the offset of the page's own header card so the
///   card visibly *becomes* the page. Ignored without a source.
/// * Without a source the page zooms in from a slightly smaller centered
///   frame instead.
/// * Reduce-motion falls back to a plain cross-fade.
class LiquidZoomRoute<T> extends PageRoute<T> {
  LiquidZoomRoute({
    required this.builder,
    this.source,
    this.anchor,
    super.settings,
  });

  final WidgetBuilder builder;
  final ZoomSourceResolver? source;
  final Offset Function(BuildContext context)? anchor;

  // Apple's smooth spring (response ≈ 0.5 s) with a touch of bounce so the
  // glass settles like a liquid instead of stopping dead.
  static final SpringSimulation _spring = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 158, damping: 21),
    0,
    1,
    0,
  );
  static const double _springSeconds = 0.5;

  static double _springAt(double progress) {
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    return _spring.x(progress * _springSeconds);
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: animation, child: child);
    }
    // Size from the overlay's constraints, not MediaQuery: the macOS shell
    // lays the app out on a 500x800 canvas scaled into the 375x600 popover
    // (application.dart), and MediaQuery there still reports the popover — a
    // MediaQuery-sized page filled only the top-left 75% of it.
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final value = animation.value;
          // Opening springs forward; closing springs back into the card from
          // the other end, so both directions land with the same settle.
          final t = animation.status == AnimationStatus.reverse
              ? 1 - _springAt(1 - value)
              : _springAt(value);
          final size = constraints.biggest;
          final full = Offset.zero & size;
          final sourceRect = _toOverlay(source?.call());
          final Rect from;
          final Offset startAnchor;
          final double startScale;
          if (sourceRect != null) {
            from = sourceRect;
            startAnchor = anchor?.call(context) ?? Offset.zero;
            startScale = 1;
          } else {
            from = Rect.fromCenter(
              center: full.center,
              width: size.width * 0.9,
              height: size.height * 0.9,
            );
            startAnchor = Offset.zero;
            startScale = 0.9;
          }

          final rect = Rect.lerp(from, full, t)!;
          final scale = startScale + (1 - startScale) * t;
          final origin = Offset.lerp(
            from.topLeft - startAnchor * startScale,
            Offset.zero,
            t,
          )!;
          final radius =
              (Lumina.radiusLg * (1 - t)).clamp(0.0, Lumina.radiusLg);
          // Cross-fade over the first quarter of the travel: the page takes
          // over from the card fast on open and melts into it on close.
          final fade = (t / 0.25).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Lumina.scrimSoft.withValues(
                      alpha: Lumina.scrimSoft.a * t.clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(radius),
                  // Same tree at rest (the page keeps its state); just no clip.
                  clipBehavior: t >= 1 ? Clip.none : Clip.antiAlias,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: size.width,
                    maxWidth: size.width,
                    minHeight: size.height,
                    maxHeight: size.height,
                    child: Transform.translate(
                      offset: origin - rect.topLeft,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topLeft,
                        child: Opacity(opacity: fade, child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// [source] resolves to a window (global) rect, but the page is positioned
  /// in the navigator's overlay. The two differ whenever an ancestor
  /// transforms the app — again the macOS canvas scale — so map it across.
  Rect? _toOverlay(Rect? global) {
    if (global == null) return null;
    final overlay = navigator?.overlay?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.attached) return global;
    return Rect.fromPoints(
      overlay.globalToLocal(global.topLeft),
      overlay.globalToLocal(global.bottomRight),
    );
  }
}

/// On-screen rect of [context]'s render box, or null once it is gone.
Rect? zoomSourceRectOf(BuildContext context) {
  if (!context.mounted) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
