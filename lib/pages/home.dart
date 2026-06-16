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

  /// Continuous motion for the aurora core + holo rim. Repeats only while
  /// connecting/connected; stopped (frozen) when idle to spare battery.
  /// Connecting spins faster (2.6s) than the settled running drift (8s).
  late final AnimationController _auraController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  // Handshake spins continuously; on connect it does ONE graceful settle spin
  // and then freezes — no perpetual 60fps repaint while connected.
  static const Duration _auraConnectingPeriod = Duration(milliseconds: 2600);
  static const Duration _auraSettlePeriod = Duration(milliseconds: 1400);

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
          // Connection established — settle haptic on the OFF→ON edge only.
          if (running && previous == false) {
            unawaited(App().performHapticFeedback(DropwebHapticCue.success));
          }
          _syncAura();
        },
      );

    // Aurora/holo motion also spins up during the connecting phase.
    globalState.isConnecting.addListener(_syncAura);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAura());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameReport();
    // Re-sync motion when inherited deps change (e.g. OS reduced-motion
    // toggled mid-handshake) so the aura honours it immediately instead of
    // waiting for the next connect/disconnect.
    _syncAura();
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
    globalState.isConnecting.removeListener(_syncAura);
    _auraController.dispose();
    _irisController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    connectButtonCenter.value = null;
    super.dispose();
  }

  /// Starts/stops the aurora+holo motion based on connect state, and picks
  /// the spin speed (connecting = fast, running = settled). Frozen when idle
  /// and under reduced-motion, so the dashboard never animates needlessly.
  void _syncAura() {
    if (!mounted) return;
    final running = ref.read(runTimeProvider) != null;
    final connecting = globalState.isConnecting.value;
    final active = running || connecting;
    final reduced = MediaQuery.disableAnimationsOf(context);

    // Iris doubles as the liveness ramp — it fades the aurora + holo in on
    // connect-start and out on disconnect (not just the bloom).
    if (reduced) {
      _irisController.value = active ? 1.0 : 0.0;
    } else if (active) {
      _irisController.forward();
    } else {
      _irisController.reverse();
    }

    // Motion: only while alive. Idle/reduced → frozen.
    if (!active || reduced) {
      if (_auraController.isAnimating) _auraController.stop();
      return;
    }
    if (connecting) {
      // Handshake — continuous fast spin/drift.
      if (_auraController.duration != _auraConnectingPeriod ||
          !_auraController.isAnimating) {
        _auraController
          ..duration = _auraConnectingPeriod
          ..repeat();
      }
    } else if (_auraController.status != AnimationStatus.completed) {
      // Connected — ONE graceful settle spin, then freeze (no perpetual
      // repaint → battery/thermal-safe on mid-range). Re-entry guard: skip if
      // a settle is already in flight, so even a per-frame caller can't
      // restart it and defeat the freeze.
      final alreadySettling = _auraController.isAnimating &&
          _auraController.duration == _auraSettlePeriod;
      if (!alreadySettling) {
        _auraController
          ..duration = _auraSettlePeriod
          ..forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.buttonSize;
    final iconSize = buttonSize * 0.4;

    // Theme-driven accent. The lens pulls its glow color straight from
    // ColorScheme.primary so it follows whatever theme is active —
    // no hardcoded Lumina green here.
    final accent = Theme.of(context).colorScheme.primary;

    // Aurora + holo pull the theme's two ambient orb colours (mesh_background
    // parity); fall back to accent when unset, and follow the scheme variant.
    final orbSettings = ref.watch(
      themeSettingProvider.select(
        (s) => (s.orbColorPrimary, s.orbColorSecondary, s.schemeVariant),
      ),
    );
    // Orb → glow colour: apply the scheme filter, then keep it readable on the
    // dark glass. Near-black orbs would read as a dead spot, so they fall back;
    // merely-dark orbs are lifted to a lightness floor so the hue still reads.
    Color orbGlow(int? raw, Color fallback) {
      if (raw == null) return fallback;
      final c = applyColorFilter(Color(raw), orbSettings.$3);
      if (c.computeLuminance() < 0.04) return fallback;
      final hsl = HSLColor.fromColor(c);
      return hsl.lightness < 0.5 ? hsl.withLightness(0.5).toColor() : c;
    }

    final orbPrimary = orbGlow(orbSettings.$1, accent);
    final orbSecondary = orbGlow(orbSettings.$2, orbPrimary);

    // Connect state amplifies the perimeter halo and inner edge glow.
    final isRunning =
        ref.watch(runTimeProvider.select((state) => state != null));

    return ValueListenableBuilder<bool>(
      valueListenable: globalState.isConnecting,
      builder: (context, isConnecting, _) => RepaintBoundary(
      key: _key,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _isPressed ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (_, pressT, __) => AnimatedBuilder(
            animation: Listenable.merge([_irisController, _auraController]),
            builder: (_, __) {
              final irisT = _irisController.value;
              final auraT = _auraController.value;
              // Connecting heartbeat for the perimeter glow.
              final pulse = 0.5 + 0.5 * math.sin(auraT * 2 * math.pi * 2);
              // Smoothly ramp dormant→alive via iris (0.2→0.59); the perimeter
              // pulses while connecting, and press always intensifies.
              final haloAlpha = (0.2 +
                      0.39 * irisT +
                      (isConnecting ? pulse * 0.16 : 0.0) +
                      pressT * 0.18)
                  .clamp(0.0, 1.0);
              final haloBlur =
                  16.0 + pressT * 10.0 + (isConnecting ? pulse * 6.0 : 0.0);
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
                      CustomPaint(
                        painter: _ConnectGlassPainter(
                          pressT: pressT,
                          isRunning: isRunning,
                          accent: accent,
                          irisT: irisT,
                          auraT: auraT,
                          isConnecting: isConnecting,
                          orbPrimary: orbPrimary,
                          orbSecondary: orbSecondary,
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
    required this.auraT,
    required this.isConnecting,
    required this.orbPrimary,
    required this.orbSecondary,
  });

  final double pressT;
  final bool isRunning;
  final Color accent;

  /// Theme ambient orb colours (mesh_background parity) — aurora blobs 2/3
  /// and the holo ring cycle through accent → orbPrimary → orbSecondary.
  final Color orbPrimary;
  final Color orbSecondary;

  /// True during the connect handshake — aurora + holo spin up early.
  final bool isConnecting;

  /// Continuous 0→1 phase for the aurora drift + holo-rim rotation.
  final double auraT;

  /// Iris animation progress in [0, 1]. 0 = no bloom, 1 = settled subtle
  /// luminance. Triggered only on real connect/disconnect transitions, never
  /// on rebuilds or initial mount.
  final double irisT;

  // Sustained alpha at irisT == 1 — kept low so the perimeter halo and
  // Fresnel rim stay dominant. Iris is the *transition* effect, not the
  // running indicator.
  // Lowered from 0.18: the aurora core now carries the sustained glow, so the
  // iris only needs a faint settle wash (avoids double-glow at rest).
  static const double _irisSettledAlpha = 0.10;
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

    // 2b. Aurora mesh core — drifting colour blobs glowing through the glass.
    //     Alive only while connected; fades in with iris on the connect
    //     transition. The continuous drift is driven by [auraT].
    // Iris is the liveness ramp — aurora fades in/out with it (no pop).
    final auroraLive = irisT;
    if (auroraLive > 0.01) {
      final ang = auraT * 2 * math.pi;
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect));
      void blob(Color c, double a, double ox, double oy, double br) {
        final p = center.translate(ox * r, oy * r);
        canvas.drawCircle(
          p,
          br * r,
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2)
            ..shader = RadialGradient(
              colors: [
                c.withValues(alpha: a * auroraLive),
                c.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: br * r)),
        );
      }

      blob(accent, 0.22, 0.30 * math.cos(ang) - 0.12,
          0.30 * math.sin(ang) - 0.08, 0.80);
      blob(orbPrimary, 0.20, 0.28 * math.cos(ang + 2.1) + 0.18,
          0.28 * math.sin(ang + 2.1) + 0.12, 0.78);
      blob(orbSecondary, 0.168, 0.24 * math.cos(ang + 4.2),
          0.24 * math.sin(ang + 4.2) + 0.22, 0.78);
      canvas.restore();
    }

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
    if (irisT > 0.01) {
      // Iridescent holo ring (rotating): accent → orbPrimary → orbSecondary.
      // Spins 8/3× the aurora phase — a tuned visual constant (the aura period
      // is 2.6s handshake / 1.4s settle, so the rim's real speed varies).
      // Fades in/out with iris (irisT) so it never pops on connect.
      final holoPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.021
        ..shader = SweepGradient(
          transform:
              GradientRotation(auraT * (8 / 3) * 2 * math.pi - math.pi / 2),
          colors: [
            accent.withValues(alpha: irisT),
            orbPrimary.withValues(alpha: irisT),
            orbSecondary.withValues(alpha: irisT),
            accent.withValues(alpha: irisT),
          ],
          stops: const [0.0, 0.33, 0.67, 1.0],
        ).createShader(rect);
      canvas.drawCircle(center, r - r * 0.015, holoPaint);
      // crisp white glass lip on top of the holo ring
      canvas.drawCircle(
        center,
        r - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: 0.18 * irisT),
      );
    } else {
      // Calm Fresnel edge while dormant.
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
    }

    // (Icon halo replaced by the aurora mesh core — layer 2b.)
  }

  /// Fresnel rim brightness (lab `rim`): 0.55 == the pre-liquid baseline.
  static const double _rimAlpha = 1.0;

  @override
  bool shouldRepaint(covariant _ConnectGlassPainter old) =>
      old.pressT != pressT ||
      old.isRunning != isRunning ||
      old.accent != accent ||
      old.irisT != irisT ||
      old.auraT != auraT ||
      old.isConnecting != isConnecting ||
      old.orbPrimary != orbPrimary ||
      old.orbSecondary != orbSecondary;
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
