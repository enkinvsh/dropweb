import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A `dropweb-logo` header value may be a raw URL or a `base64:`-wrapped URL.
/// Decode the wrapper if present; otherwise return the value unchanged.
String? decodeLogoUrl(String? value) {
  if (value == null || value.isEmpty) {
    return value;
  }
  var text = value;
  if (text.startsWith('base64:')) {
    text = text.substring(7);
  }
  try {
    return utf8.decode(base64.decode(base64.normalize(text)));
  } catch (_) {
    return value;
  }
}

/// Whether [url] points at an SVG (rendered as a vector, not background-keyed).
bool isSvgLogoUrl(String url) => url.toLowerCase().endsWith('.svg');

/// Provider-logo flourish on the subscription card: the logo bleeds off the
/// card's right edge, recoloured to the theme accent, its (dark/opaque)
/// background dropped via a render-time luminance->alpha key, and every edge
/// feathered to zero so it grows smoothly into the card. Reads `dropweb-logo`
/// from the current profile; renders nothing when the subscription-logo toggle
/// is off or no logo is present. Pointer-transparent.
class SubscriptionCardLogo extends ConsumerWidget {
  const SubscriptionCardLogo({super.key, this.headers});

  /// Provider headers to read `dropweb-logo` from. When null, the widget
  /// tracks the currently selected profile (dashboard behaviour); when
  /// provided, it renders that specific profile's logo (e.g. profiles list).
  final Map<String, String>? headers;

  // Baked placement (tuned on-device).
  static const double _sizeFraction = 0.60; // side as a fraction of card width
  static const double _alignX = 0.60; // -1..1, biased right to bleed off-edge
  static const double _alignY = 0.0; // -1..1
  static const double _opacity = 0.80;
  static const double _feather = 0.44; // outer fraction of each edge -> 0

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appSettingProvider.select((s) => s.applySubscriptionLogo),
    );
    final resolvedHeaders = headers ??
        ref.watch(
          currentProfileProvider.select((p) => p?.providerHeaders),
        );
    final url = decodeLogoUrl(resolvedHeaders?['dropweb-logo']);
    if (!enabled || url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }

    final accent = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          // Square mark; biased right so it bleeds half its size off the card
          // edge (clipped by the card), as tuned.
          final side = c.maxWidth * _sizeFraction;
          final over = side * 0.5;
          final left =
              -over + ((c.maxWidth - side) + 2 * over) * ((_alignX + 1) / 2);
          final top =
              -over + ((c.maxHeight - side) + 2 * over) * ((_alignY + 1) / 2);
          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: side,
                height: side,
                child: Opacity(
                  opacity: _opacity,
                  child: _feathered(_accentKeyedLogo(url, accent)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Feather all four edges to zero over the outer [_feather] fraction (the
  /// intersection of a horizontal and a vertical edge-fade) so the logo
  /// dissolves into the card with no hard seam on any side.
  Widget _feathered(Widget child) {
    const fc = [
      Colors.transparent,
      Colors.white,
      Colors.white,
      Colors.transparent,
    ];
    const stops = [0.0, _feather, 1 - _feather, 1.0];
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: fc,
        stops: stops,
      ).createShader(r),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fc,
          stops: stops,
        ).createShader(r),
        child: child,
      ),
    );
  }

  /// Recolour the logo to [color] and drop its dark/opaque background with a
  /// render-time luminance->alpha matrix (reliable, GPU-side). Black ->
  /// transparent, bright glyph -> opaque [color]. SVGs are tinted as vectors.
  Widget _accentKeyedLogo(String url, Color color) {
    if (isSvgLogoUrl(url)) {
      return _LogoFadeIn(
        child: SvgPicture.network(
          url,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    const k = 1.5;
    const lr = 0.2126 * k, lg = 0.7152 * k, lb = 0.0722 * k;
    final matrix = <double>[
      0, 0, 0, 0, color.r * 255, //
      0, 0, 0, 0, color.g * 255, //
      0, 0, 0, 0, color.b * 255, //
      lr, lg, lb, 0, 0, //
    ];
    // The colour matrix recomputes alpha from luminance, which discards the
    // CachedNetworkImage fade (it animates the source alpha). So fade the keyed
    // result OURSELVES, outside the filter, once the image is ready.
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      imageBuilder: (context, imageProvider) => _LogoFadeIn(
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
      placeholder: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Fades its child in once (when the logo first becomes available) and then
/// holds, so the logo appears smoothly instead of popping in the instant it
/// finishes downloading. State is preserved across rebuilds, so theme/accent
/// changes recolour instantly without re-triggering the fade.
class _LogoFadeIn extends StatefulWidget {
  const _LogoFadeIn({required this.child});

  final Widget child;

  @override
  State<_LogoFadeIn> createState() => _LogoFadeInState();
}

class _LogoFadeInState extends State<_LogoFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
