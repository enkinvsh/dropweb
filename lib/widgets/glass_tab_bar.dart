import 'package:dropweb/common/common.dart';
import 'package:flutter/material.dart';

/// The top tab bar the Подписка page introduced, now shared with meowzic.
///
/// It lives here rather than in either page because both pages are the same
/// piece of chrome: a glass pill above the content, holding the same 48 height,
/// the same [Lumina.radiusLg] squircle and the same ripple-free indicator. Any
/// change belongs in this one file — the two pages must not drift apart, or
/// arriving at meowzic from the subscription screen starts reading as a
/// different app.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<String> tabs;

  Widget _buildContent(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: isDark
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Lumina.radiusLg - 6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerHeight: 0,
        // Suppress the default Material ink ripple + hover/press overlay.
        // The Tab hit-rect is the full tab cell, which makes the default
        // overlay bleed into a rectangle that ignores the pill indicator's
        // border radius. The mode bottom bar uses GestureDetector and
        // doesn't have this problem; matching that visual contract here.
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: [for (final label in tabs) Tab(text: label)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        boxShadow: isDark ? Lumina.glassShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        // BackdropFilter disabled for perf test
        child: _buildContent(context),
      ),
    );
  }
}
