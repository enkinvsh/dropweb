import 'dart:io';

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/pages/home/connect_circle.dart';
import 'package:dropweb/pages/home/home_overlays.dart';
import 'package:dropweb/pages/home/navigation_bar.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home.dart';
import 'package:dropweb/ui/ios27/ios27_switch.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/m3e/home/m3e_actions.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widget/m3e_widget_sync.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:dropweb/pages/home/connect_circle.dart' show connectButtonCenter;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(homeStateProvider);
            final viewMode = state.viewMode;
            final navigationItems = state.navigationItems;
            final pageLabel = state.pageLabel;
            // M3E-экраны только на телефоне с Android: у планшетной раскладки есть
            // боковая навигация, которой fullBleed не рисует. Главная и пустой экран
            // меняются сами по `profilesProvider`: после добавления первой подписки
            // перезапуск не нужен.
            final useM3eHome =
                Platform.isAndroid && viewMode == ViewMode.mobile;
            // iOS-главная по тому же правилу: только телефонная раскладка. Подбор вынесен
            // в `useIos27HomeFor`, потому что `HomePage` в тестах не поднимается.
            final useIos27Home =
                useIos27HomeFor(isIOS: Platform.isIOS, viewMode: viewMode);
            final hasProfiles =
                ref.watch(profilesProvider.select((p) => p.isNotEmpty));
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
                  : navigationLabel(pageLabel),
              sideNavigationBar: sideNavigationBar,
              fullBleed: useM3eHome || useIos27Home,
              body: useM3eHome
                  ? M3eThemeScope(
                      child: M3eWidgetStyleSync(
                        child: hasProfiles
                            ? const M3eHome()
                            // Те же «Настройки», что у кнопки на главной.
                            : M3eEmptyHome(
                                onSettings: () => ref
                                    .read(m3eHomeActionsProvider)
                                    .openSettings(context, ref),
                              ),
                      ),
                    )
                  : useIos27Home
                      ? Ios27ThemeScope(
                          child: hasProfiles
                              ? const Ios27Home()
                              : const Ios27EmptyHome(),
                        )
                      : child!,
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
    final connectSize = isMobile ? connectSizeFor(context) : 0.0;
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
              // First-run guidance under the lens. Kept mounted (opacity-driven,
              // not an `if` gate) so it FADES out when the first profile lands
              // instead of popping; `visible` mirrors the exact empty-state
              // condition (`!hasProfiles`) that makes StartButton show the "+"
              // add glyph. Painted before the button so the lens sits on top.
              MobileEmptyGuidanceOverlay(
                buttonSize: connectSize,
                visible: !hasProfiles,
              ),
              MobileConnectButtonOverlay(buttonSize: connectSize),
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
        MobileIndicatorOverlay(
          buttonSize: connectSize,
          currentIndex: currentIndex == -1 ? 0 : currentIndex,
          itemCount: effectiveNavigationItems.length,
        ),
      ],
    );
  }
}
