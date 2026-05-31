import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ambient mesh-gradient background used in dark mode.
///
/// The three radial orbs "breathe" with a slow, phase-offset alpha pulse so
/// the dashboard never looks fully static, with a gentle ±18% alpha swing
/// per orb over a 14s loop — visible but still restrained. When the user
/// has enabled reduced motion (`MediaQuery.disableAnimationsOf`), the
/// animation is paused and the canonical static frame is rendered instead.
class MeshBackground extends ConsumerStatefulWidget {
  const MeshBackground({super.key});

  @override
  ConsumerState<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends ConsumerState<MeshBackground>
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      return RepaintBoundary(
        child: _buildLayers(orbA, orbB, sharpness, 0, 0, 0),
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
