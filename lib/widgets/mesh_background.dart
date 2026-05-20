import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ambient mesh-gradient background used in dark mode.
///
/// The three radial orbs "breathe" with a slow, phase-offset alpha pulse so
/// the dashboard never looks fully static, with a gentle ±18% alpha swing
/// per orb over a 14s loop — visible but still restrained. When the user
/// has enabled reduced motion (`MediaQuery.disableAnimationsOf`), the
/// animation is paused and the canonical static frame is rendered instead.
class MeshBackground extends StatefulWidget {
  const MeshBackground({super.key});

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Gentle: orb alpha varies by ±18% around the static baseline.
  static const double _breathAmplitude = 0.18;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    final primary = theme.colorScheme.primary;
    final tertiary = theme.colorScheme.tertiary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      return RepaintBoundary(
        child: _buildLayers(primary, tertiary, 0, 0, 0),
      );
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value * 2 * math.pi;
          // Phase-offset each orb by 120° so they breathe independently.
          final p1 = math.sin(t);
          final p2 = math.sin(t + (2 * math.pi / 3));
          final p3 = math.sin(t + (4 * math.pi / 3));
          return _buildLayers(primary, tertiary, p1, p2, p3);
        },
      ),
    );
  }

  Widget _buildLayers(
    Color primary,
    Color tertiary,
    double p1,
    double p2,
    double p3,
  ) {
    double mul(double p) => 1.0 + p * _breathAmplitude;
    double a(double base, double p) =>
        (base * mul(p)).clamp(0.0, 1.0).toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.2,
                colors: [
                  primary.withValues(alpha: a(0.24, p1)),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.2,
                colors: [
                  primary.withValues(alpha: a(0.18, p2)),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomRight,
                radius: 1.43,
                colors: [
                  tertiary.withValues(alpha: a(0.28, p3)),
                  tertiary.withValues(alpha: a(0.10, p3)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
