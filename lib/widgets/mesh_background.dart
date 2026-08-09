import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ambient mesh-gradient background used in dark mode.
///
/// The three radial orbs "breathe" with a slow, phase-offset alpha pulse
/// (±18% over a 14s loop). The breathe is driven by a wall-clock phase
/// sampled at 12.5 Hz (80 ms) — visually identical to per-vsync for an
/// alpha-only drift this slow, but it stops the app from re-rasterizing
/// three fullscreen gradients at 120 Hz forever (measured 5-6 ms/frame of
/// raster at idle on Pixel 10 before this change).
///
/// The 80 ms sampling used to be a raw periodic timer. It isn't anymore: a
/// bare timer fires whether or not this widget — or the whole window — is on
/// screen, which on macOS kept the process permanently ineligible for App Nap
/// (measured: 12h energy 2415, ~5x the next app, "App Nap: No"). The pump is
/// now an [AnimationController] on a [TickerMode]-aware vsync ticker, so
/// Flutter's own scheduler stops ticking it the moment the subtree goes
/// off-screen and the process can finally idle. The controller's own value is
/// deliberately unused — sampling the wall clock is what keeps every mesh on
/// every screen in the same phase (see below) — and an 80 ms step throttles
/// the repaint back down to 12.5 Hz so the vsync pump costs no extra raster.
///
/// Motion is FROZEN (last frame stays) whenever animating would be wasted
/// or would fight a transition for GPU time:
///  - OS reduce-motion is enabled (static canonical frame),
///  - the app is backgrounded,
///  - the owning route is covered by a sheet/dialog/pushed screen
///    (a static backdrop also makes the modal's BackdropFilter free at rest),
///  - the owning route's entrance/exit transition is in flight.
///
/// Wall-clock phase means every mesh on every screen breathes in the same
/// phase and resumes without drift after a freeze.
class MeshBackground extends ConsumerStatefulWidget {
  const MeshBackground({super.key});

  @override
  ConsumerState<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends ConsumerState<MeshBackground>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _periodMs = 14000;
  // 12.5 Hz repaint — imperceptible for a 14s alpha breathe.
  static const int _stepMs = 80;

  // Gentle: orb alpha varies by ±18% around the static baseline.
  static const double _breathAmplitude = 0.18;

  final ValueNotifier<double> _phase = ValueNotifier(0);
  late final AnimationController _controller;
  int _lastStepMs = 0;
  ModalRoute<dynamic>? _route;
  bool _lifecyclePaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pure vsync pump: `repeat()` needs a duration, and the breathe period is
    // the honest one to give it even though the value itself is never read.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _periodMs),
    )..addListener(_onFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of() subscribes us to route changes: didChangeDependencies
    // re-fires when routes are pushed/popped above this one, which is what
    // resumes the breathe after a covering sheet/dialog goes away.
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _detachRouteListeners();
      _route = route;
      route?.animation?.addStatusListener(_onRouteStatus);
      route?.secondaryAnimation?.addStatusListener(_onRouteStatus);
    }
    _syncMotion();
  }

  void _onRouteStatus(AnimationStatus _) => _syncMotion();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecyclePaused = state != AppLifecycleState.resumed;
    _syncMotion();
  }

  bool get _shouldAnimate {
    if (_lifecyclePaused) return false;
    if (MediaQuery.disableAnimationsOf(context)) return false;
    final route = _route;
    if (route != null) {
      if (!route.isCurrent) return false;
      if (route.animation?.status == AnimationStatus.forward ||
          route.animation?.status == AnimationStatus.reverse) {
        return false;
      }
      if (route.secondaryAnimation?.status == AnimationStatus.forward ||
          route.secondaryAnimation?.status == AnimationStatus.reverse) {
        return false;
      }
    }
    return true;
  }

  void _syncMotion() {
    if (!mounted) return;
    if (_shouldAnimate) {
      if (!_controller.isAnimating) {
        _tick(DateTime.now().millisecondsSinceEpoch);
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  // Runs on every vsync the ticker is allowed to schedule; collapses that back
  // to one phase update per 80 ms so the repaint rate is unchanged.
  void _onFrame() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastStepMs < _stepMs) return;
    _tick(now);
  }

  void _tick(int now) {
    _lastStepMs = now;
    _phase.value = (now % _periodMs) / _periodMs;
  }

  void _detachRouteListeners() {
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
  }

  @override
  void dispose() {
    _detachRouteListeners();
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onFrame)
      ..dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    final orbSettings = ref.watch(
      themeSettingProvider.select(
        (s) =>
            (s.orbColorPrimary, s.orbColorSecondary, s.orbBlur, s.schemeVariant),
      ),
    );
    final accent = theme.colorScheme.primary;
    final variant = orbSettings.$4;
    final orbA = orbSettings.$1 != null
        ? applyColorFilter(Color(orbSettings.$1!), variant)
        : accent;
    final orbB = orbSettings.$2 != null
        ? applyColorFilter(Color(orbSettings.$2!), variant)
        : orbA;
    // Slider maps to the middle gradient stop (sharpness), not a post-blur.
    final sharpness =
        ((5.0 - orbSettings.$3) / 8.0).clamp(0.0, 0.95).toDouble();

    if (MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(
        child: _buildLayers(orbA, orbB, sharpness, 0, 0, 0),
      );
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _phase,
        builder: (_, phase, __) {
          final t = phase * 2 * math.pi;
          // Phase-offset each orb by 120° so they breathe independently.
          final p1 = math.sin(t);
          final p2 = math.sin(t + (2 * math.pi / 3));
          final p3 = math.sin(t + (4 * math.pi / 3));
          return _buildLayers(orbA, orbB, sharpness, p1, p2, p3);
        },
      ),
    );
  }

  Widget _buildLayers(
    Color orbA,
    Color orbB,
    double sharpness,
    double p1,
    double p2,
    double p3,
  ) {
    double mul(double p) => 1.0 + p * _breathAmplitude;
    double a(double base, double p) =>
        (base * mul(p)).clamp(0.0, 1.0).toDouble();

    Widget orb(
      Alignment center,
      double radius,
      Color color,
      double base,
      double p,
    ) {
      final c = color.withValues(alpha: a(base, p));
      return Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: radius,
              colors: [c, c, Colors.transparent],
              stops: [0.0, sharpness, 1.0],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        orb(Alignment.topLeft, 1.7, orbA, 0.28, p1),
        orb(Alignment.topRight, 1.6, orbA, 0.20, p2),
        orb(Alignment.bottomRight, 1.9, orbB, 0.32, p3),
      ],
    );
  }
}
