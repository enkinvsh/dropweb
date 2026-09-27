import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassQuality, LiquidGlassSettings;

class Lumina {
  Lumina._();

  // Void — NOT pure black, slight blue tint
  static const Color void_ = Color(0xFF030305);

  // Surface hierarchy
  static const Color surface1 = Color(0xFF060608);
  static const Color surface2 = Color(0xFF0A0A0D);
  static const Color surface3 = Color(0xFF0F0F12);
  static const Color surface4 = Color(0xFF141417);
  static const Color surface5 = Color(0xFF1A1A1D);

  // Glass
  static const double glassOpacity = 0.03;
  static const double glassBorderOpacity = 0.08;
  static const double glassHoverOpacity = 0.06;
  static const double glassHoverBorderOpacity = 0.15;

  // Blur — reduced from 10/16 to 4/8 for mid-range Android perf
  // (Skia without Impeller; BackdropFilter GPU cost ≈ quadratic in sigma).
  // Visual difference on dark glass is minor; frame-time win is large.
  static const double blurSigma = 4.0;
  static const double blurSigmaHeavy = 8.0;

  // Glow colors (adapted for dropweb)
  static const Color glowPrimary = Color(0xFF15803D);
  static const Color glowSecondary = Color(0xFF22C55E);
  static const Color glowAccent = Color(0xFF38BDF8);

  // Component / semantic colors
  // Connect-lens glass body fill (dark, blue-tinted). Also the lerp base for
  // the dashboard inactive-icon tint and the metainfo accent ring.
  static const Color lensBody = Color(0xFF15151D);
  // Connect-lens outer radial edge — near-black blue tint the body fades into.
  static const Color lensDeep = Color(0xFF080810);
  // Connect-lens contact shadow (tight, opaque) under the glass button.
  static const Color scrimHeavy = Color(0x99000000);
  // Connect-lens ambient drop shadow (soft, translucent) under the glass button.
  static const Color scrimSoft = Color(0x66000000);
  // Connect-lens glyph rim highlight — the pure-white top of the conic Fresnel
  // sweep on the power glyph and the glyph body base the ShaderMask tints.
  static const Color lensHighlight = Color(0xFFFFFFFF);
  // Connect-lens glyph outline/glow — pure-black base blurred UNDER the power
  // glyph (SVG can't take a shadow), tinted by its own alpha at the call site.
  static const Color lensShadow = Color(0xFF000000);
  // Status: VPN connected indicator (desktop title-bar / tray dot).
  static const Color statusConnected = Color(0xFF4CAF50);
  // Elevated-latency badge accent (amber); delays >= 600ms.
  static const Color latencyWarn = Color(0xFFC57F0A);
  // Faint inset shadow tint painted 0.5px behind the segmented-tab thumb to lift
  // it off the track (drawn as a flat Paint fill, not a BoxShadow).
  static const Color shadowFaint = Color(0x0A000000);

  // Shadows
  static const List<BoxShadow> glassShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> glassDeepShadow = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 15)),
  ];

  // Radii
  static const double radiusMd = 16.0;
  static const double radiusLg = 26.0;
  static const double radiusXl = 32.0;
  static const double radiusXxl = 48.0;

  // Animation
  static const Curve luminaCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Duration luminaDuration = Duration(milliseconds: 400);

  // ── Liquid Glass (liquid_glass_widgets) ──
  // Menu glass tint — void_ at ~55%: dims clear glass over the bright orbs so
  // menu text stays legible (Apple HIG: dim clear glass over busy content).
  static const Color liquidTintMenu = Color(0x8C030305);
  // Card glass tint — void_ at ~30%: lighter dim for the subscription card.
  static const Color liquidTintCard = Color(0x4D030305);
  // Dashboard MENU panel glass. Blur stays on the house cap (heavy = 8).
  static const LiquidGlassSettings liquidMenu = LiquidGlassSettings(
    glassColor: liquidTintMenu,
    thickness: 24,
    blur: blurSigmaHeavy,
    refractiveIndex: 1.25,
    lightIntensity: 0.6,
    saturation: 1.4,
  );
  // Subscription card substrate glass. Blur stays on the house cap (4).
  static const LiquidGlassSettings liquidCard = LiquidGlassSettings(
    glassColor: liquidTintCard,
    thickness: 18,
    blur: blurSigma,
    refractiveIndex: 1.2,
    lightIntensity: 0.5,
    saturation: 1.5,
  );
  // Standalone glass button (dashboard MENU pill) — neutral dim glass with
  // a bright specular rim, so it reads as a raised 3D capsule without
  // competing with the accent-coloured connect button.
  static const LiquidGlassSettings liquidButton = LiquidGlassSettings(
    glassColor: liquidTintCard,
    thickness: 22,
    blur: blurSigma,
    refractiveIndex: 1.2,
    lightIntensity: 2.0,
    ambientStrength: 0.4,
    fresnelStrength: 1.5,
    saturation: 1.6,
  );
  // Connect lens — the menu's dark veil (so the glyph keeps its contrast
  // over bright orbs) with the thumb's bright rim. The accent glow and the
  // connection effects are painted on top by the lens painter.
  static const LiquidGlassSettings liquidLens = LiquidGlassSettings(
    glassColor: liquidTintMenu,
    thickness: 28,
    blur: blurSigma,
    refractiveIndex: 1.2,
    lightIntensity: 2.0,
    ambientStrength: 0.4,
    fresnelStrength: 1.5,
    saturation: 1.6,
  );
  // premium = real refraction via ImageFilter.shader (Impeller only); Skia
  // desktop (Windows) throws on it, so fall back to standard.
  static GlassQuality get liquidOverlayQuality =>
      ImageFilter.isShaderFilterSupported
          ? GlassQuality.premium
          : GlassQuality.standard;

  // Glass decoration helper
  static BoxDecoration glass({
    double opacity = glassOpacity,
    double borderOpacity = glassBorderOpacity,
    double radius = radiusXl,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity), width: 1),
        boxShadow: shadow ?? glassShadow,
      );

  // Glass decoration for circles (connect button)
  static BoxDecoration glassCircle({
    double opacity = glassOpacity,
    double borderOpacity = glassBorderOpacity,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity), width: 1),
        boxShadow: shadow ?? glassShadow,
      );

  // Glow shadow for active elements
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) => [
        BoxShadow(
            color: color.withValues(alpha: intensity),
            blurRadius: 16,
            spreadRadius: 2),
      ];

  // ImageFilter for glass blur
  static ImageFilter get glassBlur =>
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
  static ImageFilter get heavyBlur =>
      ImageFilter.blur(sigmaX: blurSigmaHeavy, sigmaY: blurSigmaHeavy);
}
