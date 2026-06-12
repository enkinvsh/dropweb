import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:flutter_svg/flutter_svg.dart';
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

/// Decodes Remnawave-style `base64:<value>` header values (same local
/// convention as metainfo/service_info widgets); plain values pass through.
String? _decodeBase64IfNeeded(String? value) {
  if (value == null || value.isEmpty) return value;
  var textToDecode = value;
  if (textToDecode.startsWith('base64:')) {
    textToDecode = textToDecode.substring(7);
  }
  try {
    final normalized = base64.normalize(textToDecode);
    return utf8.decode(base64.decode(normalized));
  } catch (e) {
    return value;
  }
}

class _ConnectCircleState extends ConsumerState<_ConnectCircle>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _key = GlobalKey();
  bool _isPressed = false;

  /// Liquid provider watermark: the subscription provider's logo
  /// (`dropweb-logo` header) rasterized once and slowly drifting inside the
  /// lens glass — the app-side counterpart of the site's LiquidLogoLayer.
  ui.Image? _logoImage;
  String? _requestedLogoUrl;
  int _logoLoadSeq = 0;

  /// Seamless distortion-field loop for the watermark (reference
  /// `flowSpeed`; dialed in tool/liquid_lab.html). Runs only while a logo
  /// is loaded and reduced motion is off.
  late final AnimationController _flowController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 19),
  );

  /// Fade-in once the logo image arrives, so the watermark never pops.
  late final AnimationController _logoFadeController = AnimationController(
    vsync: this,
    duration: Lumina.luminaDuration,
  );
  late final CurvedAnimation _logoFade = CurvedAnimation(
    parent: _logoFadeController,
    curve: Lumina.luminaCurve,
  );

  /// Iris bloom: one-shot radial luminance pulse through the glass disc on
  /// connect, mirrored recede on disconnect. Hands off to the perimeter halo
  /// + icon halo for sustained ambient — Iris itself does NOT loop. Idle at
  /// value 0 paints nothing.
  late final AnimationController _irisController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
  );

  /// Connect morph: 0 = plain button (watermark ghosted at 30%), 1 = logo
  /// lens (watermark full). Driven OPTIMISTICALLY — forward starts the moment
  /// the user requests a start ([GlobalState.isConnecting]), not when the TUN
  /// ack lands — and reverses when the start fails or the VPN stops. The
  /// multiplier rides on top of [_logoFade], so a logo that finishes loading
  /// mid-morph still fades in through its own channel and never pops.
  late final AnimationController _morphController = AnimationController(
    vsync: this,
    duration: Lumina.luminaDuration,
  );
  late final CurvedAnimation _morph = CurvedAnimation(
    parent: _morphController,
    curve: Lumina.luminaCurve,
  );

  /// Optimistic leg of the connect morph (see [_morphController]).
  void _onConnectingChanged() {
    if (!mounted) return;
    final connecting = globalState.isConnecting.value;
    final running = ref.read(runTimeProvider) != null;
    if (MediaQuery.disableAnimationsOf(context)) {
      _morphController.value = (connecting || running) ? 1.0 : 0.0;
      return;
    }
    if (connecting) {
      _morphController.forward();
    } else if (!running) {
      // Start failed or was cancelled before the core came up — settle back.
      _morphController.reverse();
    }
  }

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

    // Returning to the dashboard already connected: start settled, no replay.
    if (ref.read(runTimeProvider) != null) {
      _morphController.value = 1.0;
    }
    globalState.isConnecting.addListener(_onConnectingChanged);

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
            _morphController.value = running ? 1.0 : 0.0;
            return;
          }
          if (running) {
            _irisController.forward();
            _morphController.forward();
          } else {
            _irisController.reverse();
            _morphController.reverse();
          }
        },
      )
      // Liquid watermark source: provider logo header + the same
      // applySubscriptionLogo gate the metainfo card uses.
      ..listenManual<String?>(
        currentProfileProvider
            .select((profile) => profile?.providerHeaders['dropweb-logo']),
        (_, __) => _recomputeLogoTarget(),
      )
      ..listenManual<bool>(
        appSettingProvider.select((setting) => setting.applySubscriptionLogo),
        (_, __) => _recomputeLogoTarget(),
        fireImmediately: true,
      );
  }

  /// Re-reads the logo header + setting and (re)starts the async rasterize
  /// when the effective URL changed. Absent/blocked logo clears the layer.
  void _recomputeLogoTarget() {
    final show = ref.read(appSettingProvider).applySubscriptionLogo;
    final raw = show
        ? ref.read(currentProfileProvider)?.providerHeaders['dropweb-logo']
        : null;
    final url = _decodeBase64IfNeeded(raw);
    final target = (url == null || url.isEmpty) ? null : url;
    if (target == _requestedLogoUrl) return;
    _requestedLogoUrl = target;
    final seq = ++_logoLoadSeq;
    if (target == null) {
      _setLogoImage(null);
      return;
    }
    _loadLogoImage(target).then((image) {
      if (!mounted || seq != _logoLoadSeq) {
        image?.dispose();
        return;
      }
      _setLogoImage(image);
    });
  }

  void _setLogoImage(ui.Image? image) {
    if (image != null) {
      commonPrint.log(
        'liquid logo decoded: ${image.width}x${image.height}',
      );
    }
    if (_logoImage == null && image == null) return;
    _logoImage?.dispose();
    _logoImage = image;
    _logoFadeController.value = 0.0;
    if (image != null) {
      if (mounted && MediaQuery.disableAnimationsOf(context)) {
        _logoFadeController.value = 1.0;
      } else {
        _logoFadeController.forward();
      }
    }
    if (mounted) {
      setState(() {});
    }
    _syncFlowAnimation();
  }

  /// Drift loop runs only while there is a logo to move and the user has
  /// not enabled reduced motion (same gate as MeshBackground).
  void _syncFlowAnimation() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shouldFlow = _logoImage != null && !reduceMotion;
    if (shouldFlow && !_flowController.isAnimating) {
      _flowController.repeat();
    } else if (!shouldFlow && _flowController.isAnimating) {
      _flowController.stop();
    }
  }

  /// Resolves the provider logo URL into a [ui.Image] for the lens
  /// watermark. Raster URLs go through the shared CachedNetworkImage cache
  /// (decoded at <=512px, matching the lab's raster size); `.svg` URLs are
  /// rasterized via flutter_svg. Returns null on any failure — the lens
  /// then simply renders without the watermark.
  Future<ui.Image?> _loadLogoImage(String url) async {
    try {
      if (url.toLowerCase().endsWith('.svg')) {
        final pictureInfo = await vg.loadPicture(SvgNetworkLoader(url), null);
        final srcSize = pictureInfo.size;
        final longest = srcSize.longestSide;
        final ratio = longest > 0 ? 512.0 / longest : 1.0;
        final image = await pictureInfo.picture.toImage(
          (srcSize.width * ratio).ceil().clamp(1, 512),
          (srcSize.height * ratio).ceil().clamp(1, 512),
        );
        pictureInfo.picture.dispose();
        return image;
      }
      final provider = ResizeImage(
        CachedNetworkImageProvider(url),
        width: 512,
        allowUpscaling: false,
      );
      final completer = Completer<ui.Image>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (imageInfo, _) {
          if (!completer.isCompleted) {
            completer.complete(imageInfo.image.clone());
          }
          imageInfo.dispose();
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace ?? StackTrace.current);
          }
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return await completer.future;
    } catch (e) {
      commonPrint.log('connect lens logo load failed: $e');
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameReport();
    // Reduced-motion can flip while we're alive; re-evaluate the drift loop.
    _syncFlowAnimation();
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
    globalState.isConnecting.removeListener(_onConnectingChanged);
    _logoLoadSeq++;
    _logoImage?.dispose();
    _logoFade.dispose();
    _logoFadeController.dispose();
    _flowController.dispose();
    _irisController.dispose();
    _morph.dispose();
    _morphController.dispose();
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

    // Site GlassCTA gradient start (`from-orb-1`): the theme's primary orb
    // color, resolved exactly like MeshBackground (variant-filtered, accent
    // fallback when the theme defines no orb).
    final liquidSettings = ref.watch(
      themeSettingProvider.select((s) => (s.orbColorPrimary, s.schemeVariant)),
    );
    final liquidBase = liquidSettings.$1 != null
        ? applyColorFilter(Color(liquidSettings.$1!), liquidSettings.$2)
        : accent;

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
                      animation: Listenable.merge(
                        [_irisController, _flowController, _logoFade, _morph],
                      ),
                      builder: (_, __) => CustomPaint(
                        painter: _ConnectGlassPainter(
                          pressT: pressT,
                          isRunning: isRunning,
                          accent: accent,
                          irisT: _irisController.value,
                          logo: _logoImage,
                          flowT: _flowController.value,
                          // Plain↔logo morph: the watermark idles as a 30%
                          // ghost and surges to full with the (optimistic)
                          // connect transition, multiplying the load fade.
                          logoT: _logoFade.value * (0.30 + 0.70 * _morph.value),
                          liquidBase: liquidBase,
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
///   2.5. Liquid provider watermark — the subscription provider's logo
///      stretched across the lens and slowly drifting (luminosity blend),
///      ported from the site's GlassCTA liquid logo layer.
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
    required this.logo,
    required this.flowT,
    required this.logoT,
    required this.liquidBase,
  });

  final double pressT;
  final bool isRunning;
  final Color accent;

  /// Provider logo rasterized for the liquid watermark; null = no layer.
  final ui.Image? logo;

  /// Drift loop phase in [0, 1). Sine arguments use integer multiples of
  /// 2*pi*flowT so the loop is seamless.
  final double flowT;

  /// Watermark fade-in progress in [0, 1]. Crossfades the whole liquid CTA
  /// treatment (gradient base + highlight + logo) over the dark glass body.
  final double logoT;

  /// Gradient start color for the liquid base (theme orb primary — the
  /// app-side `from-orb-1`). The end stop derives from [accent] darkened.
  final Color liquidBase;

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

    // 2.5. Liquid CTA treatment — 1:1 port of the site's GlassCTA +
    //      LiquidLogoLayer, crossfaded in by [logoT] once the provider
    //      logo (`dropweb-logo`) is rasterized:
    //        a. accent gradient base (orb primary -> deep accent, the
    //           site's `from-orb-1 to-accent-deep` to bottom-right);
    //        b. top radial glass highlight (white 22% fading by 60%);
    //        c. the logo itself, stretched past the lens bounds, white
    //           luminosity blend at 45%, slowly drifting.
    //      Painted below the inset/specular/rim layers so the existing
    //      glass surface keeps reading on top. Pure canvas — no fragment
    //      shaders (Impeller silently kills them in this app).
    final logo = this.logo;
    if (logo != null && logoT > 0.001) {
      // Idle dimming: muted lens while disconnected, full brightness when
      // running; irisT drives the smooth transition on connect/disconnect.
      final live = _liquidIdleDim + (1 - _liquidIdleDim) * irisT;

      // a. Gradient base.
      final basePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            liquidBase.withValues(alpha: logoT * live),
            accent.darken(30).withValues(alpha: logoT * live),
          ],
        ).createShader(rect);
      canvas.drawCircle(center, r, basePaint);

      // b. Top glass highlight.
      final highlightPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 1.0,
          colors: [
            Colors.white.withValues(alpha: 0.35 * logoT * live),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.6],
        ).createShader(rect);
      canvas.drawCircle(center, r, highlightPaint);

      // c. Liquid logo — a faithful canvas port of the reference SVG filter
      //    chain (feTurbulence -> 3x feDisplacementMap -> R/G/B isolate ->
      //    screen recombine -> luminosity composite). The logo itself stays
      //    put; what animates is the displacement FIELD. Three drawVertices
      //    passes sample the logo through an ImageShader with mesh vertices
      //    displaced by a 2-octave fractal value-noise field; per-pass scales
      //    (d+c / d / d-c) plus channel-isolating color filters reproduce
      //    the chromatic fringing; additive blending recombines the
      //    channels; the recombined layer lands on the gradient with
      //    luminosity at 60% (zencab CONNECT_GLASS dial).
      _paintLiquidLogo(canvas, rect, center, r, logo);
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
      // The liquid CTA has NO iris wash in the lab reference — the accent
      // bloom would sit on top of the logo and wash the pattern out, so it
      // fades out together with the watermark fade-in.
      final irisAlpha = ((_irisSettledAlpha * irisT + overshoot) * (1 - logoT))
          .clamp(0.0, 1.0);
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

  // --- Liquid logo mesh-warp (reference: zencab LiquidLogoLayer) -----------

  /// Reference dials. The zencab SVG filter works in ABSOLUTE CSS px:
  /// distortion 84 -> max offset ~42px, chroma 40 (0.476 of distortion),
  /// noise wavelength 1/0.015 ~ 67px. On a ~150dp lens that maps to
  /// ampl ~0.55r and wavelength ~0.45 of the diameter — several turbulence
  /// periods must fit ACROSS the lens or the field degenerates into a
  /// near-constant shift (no visible distortion).
  static const double _liquidAmpl = 0.85; // max displacement, fraction of r
  static const double _liquidChroma = 0.02; // chroma / distortion
  static const double _liquidWavelength = 0.64; // fraction of diameter
  static const double _liquidOctave2 = 0.76; // 2nd fbm octave weight
  static const double _liquidBreath = 0.43; // base-frequency breathing
  static const double _liquidOpacity = 1.0;

  /// Liquid stack brightness when the VPN is OFF (lerps to 1.0 with the
  /// iris running transition) — the lens must read muted while idle.
  static const double _liquidIdleDim = 0.45;
  static const double _liquidCoverScale = 2.8; // logo overscale vs lens

  /// Optical-centering lift for the liquid logo, as a fraction of the lens
  /// radius. The provider mark reads low when sampled dead-centre, so the
  /// shader is nudged up by this amount to sit at the optical centre of the
  /// lens (slightly above geometric centre).
  static const double _liquidLogoLift = 0.12;

  /// Fresnel rim brightness (lab `rim`): 0.55 == the pre-liquid baseline.
  static const double _rimAlpha = 1.0;

  static const int _meshCols = 32;
  static const int _meshRows = 32;

  /// The lab (tool/liquid_lab.html) samples noise at ABSOLUTE canvas
  /// coordinates with the 150dp lens centered at (155,155). The user dials
  /// the look against that exact field patch, so the painter maps its
  /// local coordinates into the lab's frame before sampling.
  static const double _labRadius = 75.0;
  static const double _labCenter = 155.0;
  static Uint16List? _meshIndicesCache;

  /// Channel-isolating filters — the feColorMatrix trio. Alpha is preserved
  /// so the additive recombination only ever brightens its own channel.
  static const ColorFilter _redOnly = ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
  static const ColorFilter _greenOnly = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
  static const ColorFilter _blueOnly = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Deterministic 2D value noise — the feTurbulence fractalNoise stand-in.
  /// Same formulas live in tool/liquid_lab.html so lab dials transfer 1:1.
  static double _hash2(double x, double y) {
    final s = math.sin(x * 127.1 + y * 311.7) * 43758.5453123;
    return s - s.floorToDouble();
  }

  static double _valueNoise(double x, double y) {
    final xi = x.floorToDouble();
    final yi = y.floorToDouble();
    final xf = x - xi;
    final yf = y - yi;
    final u = xf * xf * (3 - 2 * xf);
    final v = yf * yf * (3 - 2 * yf);
    final a = _hash2(xi, yi);
    final b = _hash2(xi + 1, yi);
    final c = _hash2(xi, yi + 1);
    final d = _hash2(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }

  /// Two-octave fbm, like the reference's `numOctaves={2}`.
  static double _fbm(double x, double y) =>
      (_valueNoise(x, y) +
          _liquidOctave2 * _valueNoise(x * 2 + 37.2, y * 2 + 17.9)) /
      (1 + _liquidOctave2);

  static Uint16List _meshIndices() {
    final cached = _meshIndicesCache;
    if (cached != null) return cached;
    const cols = _meshCols;
    const rows = _meshRows;
    final indices = Uint16List(cols * rows * 6);
    var i = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final topLeft = row * (cols + 1) + col;
        final topRight = topLeft + 1;
        final bottomLeft = topLeft + cols + 1;
        final bottomRight = bottomLeft + 1;
        indices[i++] = topLeft;
        indices[i++] = topRight;
        indices[i++] = bottomLeft;
        indices[i++] = topRight;
        indices[i++] = bottomRight;
        indices[i++] = bottomLeft;
      }
    }
    return _meshIndicesCache = indices;
  }

  void _paintLiquidLogo(
    Canvas canvas,
    Rect rect,
    Offset center,
    double r,
    ui.Image logo,
  ) {
    // Static logo placement: stretched cover, centered — like the
    // reference's background-size/-position (only the field moves).
    final imgW = logo.width.toDouble();
    final imgH = logo.height.toDouble();
    final aspect = imgH > 0 ? imgW / imgH : 1.0;
    final cover = r * 2 * _liquidCoverScale;
    final destW = aspect >= 1 ? cover * aspect : cover;
    final destH = aspect >= 1 ? cover : cover / aspect;
    final shaderMatrix = Float64List(16)
      ..[0] = destW / imgW
      ..[5] = destH / imgH
      ..[10] = 1.0
      ..[15] = 1.0
      ..[12] = center.dx - destW / 2
      ..[13] = center.dy - destH / 2 - r * _liquidLogoLift;
    final logoShader = ui.ImageShader(
      logo,
      ui.TileMode.decal,
      ui.TileMode.decal,
      shaderMatrix,
      // Explicit: paint.filterQuality does NOT govern shader sampling on
      // Impeller; without this the shader may sample through a blurrier
      // default path. Bilinear == the lab's WebGL LINEAR (no mipmaps).
      filterQuality: FilterQuality.low,
    );

    // Fractal displacement field — like the reference, the noise itself is
    // STATIC in space (fixed seed); motion comes from the base-frequency
    // breathing (+-_liquidBreath with two phase-shifted sines == the fx/fy
    // modulation) and the chroma pulse. Loop phase enters only via sin(w),
    // so the cycle is seamless.
    final w = math.pi * 2 * flowT;
    final ampl = r * _liquidAmpl;
    // 1:1 with the lab: lambda is in lab pixels (lens diameter 150).
    const lambda = _labRadius * 2 * _liquidWavelength;
    final fx = (1 + _liquidBreath * math.sin(w)) / lambda;
    final fy = (1 + _liquidBreath * math.sin(w + 1.3)) / lambda;
    // Chroma pulse: c(t) = chroma * (0.6 + 0.4 sin), as in the reference.
    final chromaT = _liquidChroma * (0.6 + 0.4 * math.sin(w));
    final scaleR = 1 + chromaT;
    const scaleG = 1.0;
    final scaleB = 1 - chromaT;

    // BACKWARD warp, like feDisplacementMap: the mesh GEOMETRY is a static
    // grid over the lens; what shifts per vertex are the TEXTURE
    // COORDINATES (each grid point samples the logo from a displaced
    // location). Forward vertex warp smears the logo into blobs; backward
    // texcoord warp shreds it locally — the reference look. Per-channel
    // texcoord sets (scales d+c / d / d-c) give the chromatic fringes.
    const cols = _meshCols;
    const rows = _meshRows;
    const vertexCount = (cols + 1) * (rows + 1);
    final positions = Float32List(vertexCount * 2);
    final texR = Float32List(vertexCount * 2);
    final texG = Float32List(vertexCount * 2);
    final texB = Float32List(vertexCount * 2);
    var v = 0;
    for (var row = 0; row <= rows; row++) {
      final y = rect.top + rect.height * row / rows;
      for (var col = 0; col <= cols; col++) {
        final x = rect.left + rect.width * col / cols;
        // R/G noise channels of the reference displacement map: two
        // independent fields via a fixed sampling offset. Coordinates are
        // mapped into the lab's absolute frame (same field patch the user
        // dialed), normalized by the actual lens radius.
        final labX = (x - center.dx) / r * _labRadius + _labCenter;
        final labY = (y - center.dy) / r * _labRadius + _labCenter;
        final nx = (_fbm(labX * fx, labY * fy) - 0.5) * 2;
        final ny =
            (_fbm(labX * fx + 57.31, labY * fy + 113.57) - 0.5) * 2;
        positions[v] = x;
        positions[v + 1] = y;
        texR[v] = x + nx * ampl * scaleR;
        texR[v + 1] = y + ny * ampl * scaleR;
        texG[v] = x + nx * ampl * scaleG;
        texG[v + 1] = y + ny * ampl * scaleG;
        texB[v] = x + nx * ampl * scaleB;
        texB[v + 1] = y + ny * ampl * scaleB;
        v += 2;
      }
    }

    final indices = _meshIndices();
    final live = _liquidIdleDim + (1 - _liquidIdleDim) * irisT;
    final groupAlpha = _liquidOpacity * logoT * live;

    if (_liquidChroma < 0.05) {
      // Single-pass fast path (chroma effectively off): luminosity straight
      // onto the canvas, NO saveLayer. Impeller rasterizes advanced-blend
      // saveLayers at logical resolution (no DPR), which blurred the whole
      // watermark ("CRT" look); a direct draw keeps full device resolution.
      final paint = Paint()
        ..shader = logoShader
        ..color = Colors.white.withValues(alpha: groupAlpha)
        ..blendMode = BlendMode.luminosity
        ..filterQuality = FilterQuality.low;
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect))
        ..drawVertices(
          ui.Vertices.raw(
            ui.VertexMode.triangles,
            positions,
            textureCoordinates: texG,
            indices: indices,
          ),
          BlendMode.srcOver,
          paint,
        )
        ..restore();
      return;
    }

    final layerPaint = Paint()
      ..color = Colors.white.withValues(alpha: groupAlpha)
      ..blendMode = BlendMode.luminosity;
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect))
      ..saveLayer(rect, layerPaint);
    final channels = <(Float32List, ColorFilter)>[
      (texR, _redOnly),
      (texG, _greenOnly),
      (texB, _blueOnly),
    ];
    for (final (texCoords, filter) in channels) {
      final paint = Paint()
        ..shader = logoShader
        ..colorFilter = filter
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.low;
      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          positions,
          textureCoordinates: texCoords,
          indices: indices,
        ),
        BlendMode.srcOver,
        paint,
      );
    }
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _ConnectGlassPainter old) =>
      old.pressT != pressT ||
      old.isRunning != isRunning ||
      old.accent != accent ||
      old.irisT != irisT ||
      old.logo != logo ||
      old.flowT != flowT ||
      old.logoT != logoT ||
      old.liquidBase != liquidBase;
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
