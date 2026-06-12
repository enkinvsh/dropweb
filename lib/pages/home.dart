import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

String _navigationLabel(PageLabel label) => switch (label) {
      PageLabel.cabinet => 'Кабинет',
      _ => Intl.message(label.name),
    };

const double _connectBaseSize = 128.0;
const double _connectTallScreenGrowth = 28.0;
const double _connectMaxSize = 160.0;
const Alignment _mobileConnectAlignment = Alignment(0, 0.58);

double _connectSizeFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final aspect = size.width == 0 ? 0.0 : size.height / size.width;
  final t = ((aspect - 2.0) / 0.45).clamp(0.0, 1.0).toDouble();
  return (_connectBaseSize + _connectTallScreenGrowth * t)
      .clamp(
        _connectBaseSize,
        _connectMaxSize,
      )
      .toDouble();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (_, ref, child) {
            final state = ref.watch(homeStateProvider);
            final viewMode = state.viewMode;
            final navigationItems = state.navigationItems;
            final pageLabel = state.pageLabel;
            final index = navigationItems.lastIndexWhere(
              (element) => element.label == pageLabel,
            );
            final currentIndex = index == -1 ? 0 : index;
            final navigationBar = CommonNavigationBar(
              viewMode: viewMode,
              navigationItems: navigationItems,
              currentIndex: currentIndex,
            );
            final sideNavigationBar =
                viewMode != ViewMode.mobile ? navigationBar : null;
            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              title: viewMode == ViewMode.mobile ||
                      pageLabel == PageLabel.dashboard
                  ? ''
                  : _navigationLabel(pageLabel),
              sideNavigationBar: sideNavigationBar,
              body: child!,
            );
          },
          child: const _HomePageView(),
        ),
      );
}

class _HomePageView extends ConsumerStatefulWidget {
  const _HomePageView();

  @override
  ConsumerState<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _pageIndex,
      keepPage: true,
    );
    ref
      ..listenManual(currentPageLabelProvider, (prev, next) {
        if (prev != next) {
          _toPage(next);
        }
      })
      ..listenManual(currentNavigationsStateProvider, (prev, next) {
        if (prev?.value != next.value) {
          _updatePageController();
        }
      });
  }

  int get _pageIndex {
    final navigationItems = ref.read(currentNavigationsStateProvider).value;
    final index = navigationItems.indexWhere(
      (item) => item.label == globalState.appState.pageLabel,
    );
    return index == -1 ? 0 : index;
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final navigationItems = ref.read(currentNavigationsStateProvider).value;
    final index = navigationItems.indexWhere((item) => item.label == pageLabel);
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = globalState.appState.pageLabel;
    final navigationItems = ref.read(currentNavigationsStateProvider).value;
    final hasPage = navigationItems.any((item) => item.label == pageLabel);
    if (!hasPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        globalState.appController.toPage(PageLabel.dashboard);
      });
      return;
    }
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationItems = ref.watch(currentNavigationsStateProvider).value;
    final isMobile = ref.watch(isMobileViewProvider);
    final currentLabel = ref.watch(currentPageLabelProvider);
    // Defensive HomePage-level guard: regardless of what the provider
    // returns, when there is no profile/subscription we collapse the
    // visible navigation to Dashboard only. This is the second line of
    // defense behind `currentNavigationsState` so the swipe, indicator
    // and PageView item count cannot expose a Tools page that the user
    // hasn't unlocked yet.
    final hasProfiles = ref.watch(
      profilesProvider.select((profiles) => profiles.isNotEmpty),
    );
    final effectiveNavigationItems = hasProfiles
        ? navigationItems
        : navigationItems
            .where((item) => item.label == PageLabel.dashboard)
            .toList();
    final currentIndex = effectiveNavigationItems.indexWhere(
      (item) => item.label == currentLabel,
    );
    final canSwipe = isMobile && effectiveNavigationItems.length > 1;
    final connectSize = isMobile ? _connectSizeFor(context) : 0.0;
    final pageView = PageView.builder(
      controller: _pageController,
      // Mobile: horizontal swipe between dashboard ↔ tools (settings).
      // Non-mobile and no-profile single-page state: swipe stays disabled.
      physics: canSwipe
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: effectiveNavigationItems.length,
      onPageChanged: !canSwipe
          ? null
          : (index) {
              if (index < 0 || index >= effectiveNavigationItems.length) {
                return;
              }
              final newLabel = effectiveNavigationItems[index].label;
              // Guard against the swipe → toPage → animate → onPageChanged
              // → toPage feedback loop: only push the new label up if it
              // actually differs from what the provider currently holds.
              final currentLabel = ref.read(currentPageLabelProvider);
              if (currentLabel == newLabel) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (ref.read(currentPageLabelProvider) == newLabel) return;
                globalState.appController.toPage(newLabel);
              });
            },
      itemBuilder: (_, index) {
        final navigationItem = effectiveNavigationItems[index];
        final page = KeepScope(
          keep: navigationItem.keep,
          key: Key(navigationItem.label.name),
          child: navigationItem.view,
        );
        // The connect/add button belongs to the Dashboard page itself so
        // PageView physics slides it off-screen with the rest of Dashboard
        // when the user swipes to Tools. The tab indicator is rendered
        // outside the PageView (see below) so it stays visible across
        // pages.
        if (isMobile && navigationItem.label == PageLabel.dashboard) {
          return Stack(
            children: [
              page,
              _MobileConnectButtonOverlay(buttonSize: connectSize),
            ],
          );
        }
        return page;
      },
    );

    if (!isMobile) {
      return pageView;
    }

    return Stack(
      children: [
        pageView,
        _MobileIndicatorOverlay(
          buttonSize: connectSize,
          currentIndex: currentIndex == -1 ? 0 : currentIndex,
          itemCount: effectiveNavigationItems.length,
        ),
        // Onboarding Moment 1: one-time coach hint over the lens on first run
        // (0 profiles). The overlay self-gates on the persisted hint flag and
        // is mobile-only by virtue of living in the mobile-only Stack. When a
        // profile exists there is nothing to teach, so it is omitted entirely.
        if (!hasProfiles) _FirstRunHintOverlay(buttonSize: connectSize),
      ],
    );
  }
}

class _ScreenIndicator extends StatelessWidget {
  const _ScreenIndicator({
    required this.currentIndex,
    required this.itemCount,
  });

  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 1) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex =
        currentIndex >= itemCount ? itemCount - 1 : currentIndex;

    return IgnorePointer(
      child: SizedBox(
        height: 24,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(itemCount, (index) {
              final isActive = index == selectedIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isActive ? 16 : 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Connect/add button overlay — Dashboard-scoped. Lives inside the
/// Dashboard PageView item so it slides off with the rest of Dashboard
/// when the user swipes to Tools.
class _MobileConnectButtonOverlay extends StatelessWidget {
  const _MobileConnectButtonOverlay({required this.buttonSize});

  final double buttonSize;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Align(
          alignment: _mobileConnectAlignment,
          child: SizedBox.square(
            dimension: buttonSize,
            child: _ConnectCircle(buttonSize: buttonSize),
          ),
        ),
      );
}

/// Tab/screen indicator overlay — page-independent. Rendered in an outer
/// Stack above the PageView so it stays visible on Dashboard, Settings
/// and any other page. The indicator anchors visually to the same spot
/// the connect button would occupy on Dashboard.
class _MobileIndicatorOverlay extends StatelessWidget {
  const _MobileIndicatorOverlay({
    required this.buttonSize,
    required this.currentIndex,
    required this.itemCount,
  });

  final double buttonSize;
  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const indicatorGap = 10.0;
    const indicatorHeight = 24.0;

    return Positioned.fill(
      child: Align(
        alignment: _mobileConnectAlignment,
        child: Transform.translate(
          offset: Offset(
            0,
            buttonSize / 2 + indicatorGap + indicatorHeight / 2,
          ),
          child: _ScreenIndicator(
            currentIndex: currentIndex,
            itemCount: itemCount,
          ),
        ),
      ),
    );
  }
}

/// Onboarding Moment 1 — a one-time coach hint over the connect lens on the
/// very first run (0 profiles). Shows a glass callout below the lens, then
/// never again once the Add sheet has opened ([OnboardingState.markHintSeen],
/// written from `AddProfileView`).
///
/// Anchoring: the overlay is positioned with the SAME [_mobileConnectAlignment]
/// the lens itself uses (`_MobileConnectButtonOverlay`), so the callout tracks
/// it without any global→local coordinate conversion. The overlay is purely
/// visual ([IgnorePointer]) so it can never swallow the lens tap — the lens
/// stays the single tap target the copy points at, and the hint auto-dismisses
/// the instant the sheet opens.
class _FirstRunHintOverlay extends StatefulWidget {
  const _FirstRunHintOverlay({required this.buttonSize});

  final double buttonSize;

  @override
  State<_FirstRunHintOverlay> createState() => _FirstRunHintOverlayState();
}

class _FirstRunHintOverlayState extends State<_FirstRunHintOverlay>
    with TickerProviderStateMixin {
  /// Entrance fade + slide-up of the callout.
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: Lumina.luminaDuration,
  );
  late final CurvedAnimation _entrance = CurvedAnimation(
    parent: _entranceController,
    curve: Lumina.luminaCurve,
  );

  bool _started = false;

  @override
  void initState() {
    super.initState();
    OnboardingState.hintSeenListenable.addListener(_onHintSeenChanged);
    // Resolve the persisted flag; the overlay stays hidden (value == null)
    // until it lands, so a returning user never sees a flash of the hint.
    unawaited(onboardingState.load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToFlag());
  }

  void _onHintSeenChanged() {
    if (!mounted) return;
    _syncToFlag();
    setState(() {});
  }

  void _syncToFlag() {
    if (!mounted) return;
    final seen = OnboardingState.hintSeenListenable.value;
    if (seen == false) {
      _start();
    } else if (seen == true) {
      _stop();
    }
  }

  void _start() {
    if (_started) return;
    _started = true;
    // Reduced motion: snap the callout straight to its settled state.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceController.value = 1.0;
      return;
    }
    _entranceController.forward();
  }

  void _stop() {
    if (_entranceController.value > 0) {
      _entranceController.reverse();
    }
  }

  @override
  void dispose() {
    OnboardingState.hintSeenListenable.removeListener(_onHintSeenChanged);
    _entrance.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden until we know the flag is explicitly false (not seen).
    if (OnboardingState.hintSeenListenable.value != false) {
      return const SizedBox.shrink();
    }
    final buttonSize = widget.buttonSize;

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: _mobileConnectAlignment,
          child: Transform.translate(
            offset: Offset(0, buttonSize / 2 + 28),
            child: FadeTransition(
              opacity: _entrance,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(_entrance),
                child: _HintCallout(
                  text: appLocalizations.onboardingAddHint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass callout body for the first-run hint. Composes [Lumina.glass] + the
/// theme text style (Onest, inherited) + a primary-tinted up-arrow pointing at
/// the lens above it. No raw container styling, no inline TextStyle.
class _HintCallout extends StatelessWidget {
  const _HintCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: Lumina.glass(radius: Lumina.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUp01,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connect button — glass lens. Reports its screen position via
/// [connectButtonCenter] for any overlay that needs the button anchor.
///
/// Material model: dark void body, Fresnel rim, top specular arc, concave
/// inset, inner edge glow, and an outer perimeter halo. Accent color is
/// pulled live from `Theme.of(context).colorScheme.primary`, so the lens
/// follows whichever theme is active.
class _ConnectCircle extends ConsumerStatefulWidget {
  const _ConnectCircle({required this.buttonSize});

  final double buttonSize;

  @override
  ConsumerState<_ConnectCircle> createState() => _ConnectCircleState();
}

/// Global notifier for the connect button's screen-space center.
/// Written by [_ConnectCircle].
final connectButtonCenter = ValueNotifier<Offset?>(null);

class _ConnectCircleState extends ConsumerState<_ConnectCircle>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _key = GlobalKey();
  bool _isPressed = false;

  /// Iris bloom: one-shot radial luminance pulse through the glass disc on
  /// connect, mirrored recede on disconnect. Hands off to the perimeter halo
  /// + icon halo for sustained ambient — Iris itself does NOT loop. Idle at
  /// value 0 paints nothing.
  late final AnimationController _irisController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
  );

  void _reportPosition() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final center =
        box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    if (connectButtonCenter.value != center) {
      connectButtonCenter.value = center;
    }
  }

  void _schedulePostFrameReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportPosition());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Report position once after first layout — the button doesn't move
    // within a stable layout, so the old per-frame tracking loop was pure
    // waste (it was burning 2-4 ms every frame on findRenderObject +
    // localToGlobal + notifier writes).
    _schedulePostFrameReport();

    // Profile availability can change the mobile pages and rebuild the body.
    // Re-anchor the rings origin if the button shifts with that state.
    ref
      ..listenManual<bool>(
        profilesProvider.select((profiles) => profiles.isNotEmpty),
        (_, __) => _schedulePostFrameReport(),
      )
      // Iris bloom — triggered ONLY on actual OFF↔ON transitions.
      // listenManual does not fire-immediately, so initial state never
      // replays the animation (e.g. coming back to dashboard while already
      // connected does not re-bloom).
      ..listenManual<bool>(
        runTimeProvider.select((state) => state != null),
        (previous, running) {
          if (!mounted) return;
          // Connection actually established — settle haptic. Fires only on
          // the OFF→ON transition (never on initial-state replays).
          if (running && previous == false) {
            unawaited(App().performHapticFeedback(DropwebHapticCue.success));
          }
          // Reduced-motion: snap to terminal state, no animation.
          if (MediaQuery.disableAnimationsOf(context)) {
            _irisController.value = running ? 1.0 : 0.0;
            return;
          }
          if (running) {
            _irisController.forward();
          } else {
            _irisController.reverse();
          }
        },
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameReport();
  }

  /// Window resize on desktop / orientation change on mobile shifts the
  /// button without touching inherited dependencies, so we need a metrics
  /// callback to re-anchor the rings origin.
  @override
  void didChangeMetrics() {
    _schedulePostFrameReport();
  }

  @override
  void didUpdateWidget(covariant _ConnectCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any rebuild of the parent could shift the button (e.g. theme switch
    // changes border thickness, padding, etc). Cheap to re-report.
    _schedulePostFrameReport();
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() {
      _isPressed = value;
    });
  }

  @override
  void dispose() {
    _irisController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    connectButtonCenter.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.buttonSize;
    final iconSize = buttonSize * 0.4;

    // Theme-driven accent. The lens pulls its glow color straight from
    // ColorScheme.primary so it follows whatever theme is active —
    // no hardcoded Lumina green here.
    final accent = Theme.of(context).colorScheme.primary;

    // Connect state amplifies the perimeter halo and inner edge glow.
    final isRunning =
        ref.watch(runTimeProvider.select((state) => state != null));

    return RepaintBoundary(
      key: _key,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _isPressed ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (_, pressT, __) {
            // Outer perimeter halo — the visible theme-colored ring of
            // light hugging the lens edge. Idle is visible but restrained;
            // press and live-connection intensify.
            // Lab `glow` dial: running == glow, idle == glow * 0.625.
            final haloAlpha = (isRunning ? 0.59 : 0.37) + pressT * 0.18;
            final haloBlur = 16.0 + pressT * 10.0;
            final perimeterGlow = BoxShadow(
              color: accent.withValues(alpha: haloAlpha),
              blurRadius: haloBlur,
              spreadRadius: -1.0,
            );

            return SizedBox.square(
              dimension: buttonSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    perimeterGlow,
                    const BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 26,
                      spreadRadius: -6,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Iris drives painter repaints only while it's animating.
                    // When _irisController sits at 0.0 (idle off) or 1.0
                    // (idle on) it stops ticking — no continuous loop.
                    AnimatedBuilder(
                      animation: _irisController,
                      builder: (_, __) => CustomPaint(
                        painter: _ConnectGlassPainter(
                          pressT: pressT,
                          isRunning: isRunning,
                          accent: accent,
                          irisT: _irisController.value,
                        ),
                      ),
                    ),
                    StartButton(iconSize: iconSize),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the connect lens. Seven layers, in order:
///   1. Body — dark fill, lifted just enough off the void background to be
///      visibly present as glass rather than a black hole.
///   2. Accent veil — a low-alpha radial of the theme accent caught in the
///      upper-mid body. Reads as refracted ambient theme light, not a fill.
///   3. Concave inset — a soft dark sweep on the lower inner arc so the
///      lens reads as a recessed/convex cap rather than a flat disk.
///   4. Top-edge specular — a single soft arc near 11-1 o'clock. No
///      rotated rectangle stickers.
///   5. Inner edge glow — a wide blurred accent stroke hugging the inner
///      rim. Light caught at the rim from inside the lens; works with the
///      outer perimeter BoxShadow to make the edge read as luminous.
///   6. Fresnel rim — 1px stroke with a sweep gradient that brightens at
///      the top and falls off toward the bottom (true lit-edge behavior).
///      Top/side carry a small constant accent tint; pressed state warms.
///   7. Icon halo — a tight radial in the accent color. Idle floor + live
///      connection + press progress all stack additively.
///
/// All accent color comes from the painter's [accent] argument, which is
/// the active theme primary — nothing in this painter hardcodes a brand
/// hue.
class _ConnectGlassPainter extends CustomPainter {
  const _ConnectGlassPainter({
    required this.pressT,
    required this.isRunning,
    required this.accent,
    required this.irisT,
  });

  final double pressT;
  final bool isRunning;
  final Color accent;

  /// Iris animation progress in [0, 1]. 0 = no bloom, 1 = settled subtle
  /// luminance. Triggered only on real connect/disconnect transitions, never
  /// on rebuilds or initial mount.
  final double irisT;

  // Sustained alpha at irisT == 1 — kept low so the perimeter halo and
  // Fresnel rim stay dominant. Iris is the *transition* effect, not the
  // running indicator.
  static const double _irisSettledAlpha = 0.18;
  // Peak alpha mid-bloom (irisT ≈ 0.5). Restrained, premium, not neon.
  static const double _irisPeakAlpha = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);

    // 1. Body. Lifted off the void surface (#030305) so the lens reads
    //    as glass-on-void instead of a black hole.
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, 0.25),
        radius: 0.8,
        colors: [Lumina.lensBody, Color(0xFF080810)],
        stops: [0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, r, bodyPaint);

    // 2. Accent veil — theme glow refracted through the upper-mid body.
    //    Low alpha; reads as caught light, not a filled disk.
    final veilPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 0.9,
        colors: [
          accent.withValues(alpha: 0.19),
          accent.withValues(alpha: 0.19 * 0.38),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect))
      ..drawCircle(center, r, veilPaint)
      ..restore();

    // 3. Concave inset on the lower interior arc.
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.21
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.045)
      ..shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: [
          const Color(0x00000000),
          Colors.black.withValues(alpha: 0.75),
          const Color(0x00000000),
        ],
        stops: const [0.08, 0.5, 0.92],
      ).createShader(rect);
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect.deflate(1)))
      ..drawCircle(center, r - r * 0.085, insetPaint)
      ..restore();

    // 4. Top-edge specular. Single soft arc, blurred, ~10→2 o'clock.
    final specRect = Rect.fromCircle(
      center: center.translate(0, r * 0.025),
      radius: r - r * 0.045,
    );
    final specPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04)
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(
      specRect,
      -math.pi * 0.78,
      math.pi * 0.55,
      false,
      specPaint,
    );

    // 5. Inner edge glow — wide blurred accent stroke at the inner rim.
    //    Clipped to the circle so the blur reads as light caught at the
    //    edge fading inward. This is the painter-side counterpart of the
    //    outer perimeter BoxShadow; together they make the lens edge
    //    luminous with the theme color.
    final innerEdgeAlpha = (isRunning ? 0.205 : 0.055) + pressT * 0.16;
    if (innerEdgeAlpha > 0.005) {
      final innerEdgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.055)
        ..color = accent.withValues(alpha: innerEdgeAlpha);
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect))
        ..drawCircle(center, r - r * 0.035, innerEdgePaint)
        ..restore();
    }

    // 5b. Iris bloom — one-shot radial luminance wash across the lens body,
    //     driven by [irisT]. Painted *under* the Fresnel rim so the rim
    //     highlight stays crisp and Iris reads as light caught inside the
    //     lens, not slapped on top. No-op while irisT == 0.
    if (irisT > 0) {
      // Triangular overshoot: 0 → +(peak-settled) at t=0.5 → 0 at t=1.
      final overshoot =
          (_irisPeakAlpha - _irisSettledAlpha) * 4 * irisT * (1 - irisT);
      final irisAlpha =
          (_irisSettledAlpha * irisT + overshoot).clamp(0.0, 1.0);
      if (irisAlpha > 0.001) {
        final irisPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: irisAlpha),
              accent.withValues(alpha: irisAlpha * 0.4),
              accent.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect);
        canvas
          ..save()
          ..clipPath(Path()..addOval(rect))
          ..drawCircle(center, r, irisPaint)
          ..restore();
      }
    }

    // 6. Fresnel rim. Bright top → mid sides → dark bottom → back to top.
    //    Top/side carry a small constant accent tint so the theme color
    //    catches the rim even at rest; press warms it further.
    // _rimAlpha scales the whole ring; 0.55 maps to the original alphas.
    const rimBoost = _rimAlpha / 0.55;
    double rimA(double a) => (a * rimBoost).clamp(0.0, 1.0);
    final rimTop = Color.lerp(
      Colors.white.withValues(alpha: rimA(0.6)),
      accent.withValues(alpha: rimA(0.35)),
      0.41,
    )!;
    final rimSide = Color.lerp(
      Colors.white.withValues(alpha: rimA(0.14)),
      accent.withValues(alpha: rimA(0.18)),
      0.369,
    )!;
    final rimBottom = Colors.white.withValues(alpha: rimA(0.05));
    final warmTop = Color.lerp(
        rimTop, accent.withValues(alpha: rimA(0.60)), pressT * 0.6)!;
    final warmSide = Color.lerp(
        rimSide, accent.withValues(alpha: rimA(0.30)), pressT * 0.45)!;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: [warmTop, warmSide, rimBottom, warmSide, warmTop],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, r - 0.5, rimPaint);

    // 7. Icon halo. Tight, scoped to icon region. Small idle floor keeps
    //    the lens "alive" with theme glow at rest; live connection and
    //    press stack on top.
    final haloAlpha = (isRunning ? 0.28 : 0.07) + pressT * 0.10;
    if (haloAlpha > 0.001) {
      final haloRadius = r * 0.46;
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: haloAlpha),
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
      canvas.drawCircle(center, haloRadius, haloPaint);
    }
  }

  /// Fresnel rim brightness (lab `rim`): 0.55 == the pre-liquid baseline.
  static const double _rimAlpha = 1.0;

  @override
  bool shouldRepaint(covariant _ConnectGlassPainter old) =>
      old.pressT != pressT ||
      old.isRunning != isRunning ||
      old.accent != accent ||
      old.irisT != irisT;
}

/// Developer mode activation via 5 rapid CONSECUTIVE taps on the Settings
/// tab. Any tap on another tab (or a pause >3s) resets the counter so
/// users bouncing between Dashboard and Settings don't accidentally
/// unlock dev mode.
int _devTapCount = 0;
DateTime _devTapLast = DateTime(0);
const _devTapThreshold = 5;
const _devTapWindow = Duration(seconds: 3);

void _resetDevTapCount() {
  _devTapCount = 0;
  _devTapLast = DateTime(0);
}

void _handleDevTap(BuildContext context, WidgetRef ref) {
  final now = DateTime.now();
  if (now.difference(_devTapLast) > _devTapWindow) {
    _devTapCount = 0;
  }
  _devTapLast = now;
  _devTapCount++;
  final alreadyEnabled = ref.read(appSettingProvider).developerMode;
  if (alreadyEnabled) return;
  if (_devTapCount >= _devTapThreshold) {
    _devTapCount = 0;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(developerMode: true),
        );
    globalState.showNotifier(appLocalizations.developerModeEnableTip);
  }
}

class CommonNavigationBar extends ConsumerWidget {
  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  static const double _mobileNavigationHeight = 80.0;

  static const _icons = <PageLabel, (IconData, IconData)>{
    PageLabel.cabinet: (Icons.account_circle_outlined, Icons.account_circle),
    PageLabel.dashboard: (Icons.dashboard_outlined, Icons.dashboard_rounded),
    PageLabel.tools: (Icons.settings_outlined, Icons.settings_rounded),
  };

  static IconData _navIcon(PageLabel label, bool selected) {
    final pair = _icons[label];
    if (pair == null) return Icons.circle_outlined;
    return selected ? pair.$2 : pair.$1;
  }

  Widget _buildTabBarContent(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) =>
      Container(
        height: _mobileNavigationHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: Lumina.glassOpacity),
          borderRadius: BorderRadius.circular(Lumina.radiusXxl),
          border: Border.all(
            color: Colors.white.withValues(alpha: Lumina.glassBorderOpacity),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List.generate(navigationItems.length, (index) {
              final item = navigationItems[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    globalState.appController.toPage(item.label);
                    if (item.label == PageLabel.tools) {
                      _handleDevTap(context, ref);
                    } else if (item.label == PageLabel.dashboard) {
                      _resetDevTapCount();
                    } else {
                      _resetDevTapCount();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(Lumina.radiusXxl - 6),
                    ),
                    child: Center(
                      child: Icon(
                        _navIcon(item.label, isSelected),
                        size: 36,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewMode == ViewMode.mobile) {
      final colorScheme = Theme.of(context).colorScheme;
      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            boxShadow: Lumina.glassShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            // BackdropFilter disabled for perf test
            child: _buildTabBarContent(context, colorScheme, ref),
          ),
        ),
      );
    }
    final showLabel =
        ref.watch(appSettingProvider.select((state) => state.showLabel));
    return Material(
      color: context.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // App logo at the top of sidebar
          if (!Platform.isMacOS) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircleAvatar(
                      foregroundImage: AssetImage("assets/images/icon.png"),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      appName,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: context.colorScheme.surfaceContainer,
                    selectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    selectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    unselectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    destinations: navigationItems
                        .map(
                          (e) => NavigationRailDestination(
                            icon: e.icon,
                            label: Text(
                              _navigationLabel(e.label),
                            ),
                          ),
                        )
                        .toList(),
                    onDestinationSelected: (index) {
                      globalState.appController
                          .toPage(navigationItems[index].label);
                    },
                    extended: false,
                    selectedIndex: currentIndex,
                    labelType: showLabel
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          IconButton(
            onPressed: () {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(
                      showLabel: !state.showLabel,
                    ),
                  );
            },
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu01, size: 24),
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}

class HomeBackScope extends StatelessWidget {
  const HomeBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return CommonPopScope(
        onPop: () async {
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
          return false;
        },
        child: child,
      );
    }
    return child;
  }
}
