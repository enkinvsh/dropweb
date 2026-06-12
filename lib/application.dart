import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/manager.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({
    super.key,
  });

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;
  bool _groupPollPaused = false;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
      TargetPlatform.macOS: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) =>
      ref.read(genColorSchemeProvider(brightness));

  @override
  void initState() {
    super.initState();

    // Cap the global decoded-image cache to bound PSS from network logos/bg.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

    if (Platform.isWindows) {
      windows?.enableDarkModeForApp();
    }

    _autoUpdateGroupTask();
    _autoUpdateProfilesTask();
    // Let the app-lifecycle observer (AppStateManager) gate the group poll so
    // it doesn't keep hitting the Go core every 20s while backgrounded.
    globalState.pauseGroupsPolling = _pauseGroupTask;
    globalState.resumeGroupsPolling = _resumeGroupTask;
    globalState.appController = AppController(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        globalState.appController = AppController(currentContext, ref);
      }
      await globalState.appController.init();
      globalState.appController.initLink();
      app?.initShortcuts();
    });
  }

  void _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer?.cancel();
    // Re-arm guard: a timer that fired just before pause schedules a
    // post-frame re-arm; bail out here so it doesn't restart the poll while
    // the app is backgrounded.
    if (_groupPollPaused) {
      return;
    }
    _autoUpdateGroupTaskTimer = Timer(const Duration(milliseconds: 20000), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_groupPollPaused) {
          return;
        }
        globalState.appController.updateGroupsDebounce();
        _autoUpdateGroupTask();
      });
    });
  }

  // Stop the 20s proxy-group poll while the app is backgrounded. Cancels any
  // pending timer so a fire scheduled just before pause can't re-arm.
  void _pauseGroupTask() {
    _groupPollPaused = true;
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateGroupTaskTimer = null;
  }

  // Resume on foreground with one immediate refresh so the UI reflects current
  // groups right away, then re-arm the periodic poll.
  void _resumeGroupTask() {
    if (!_groupPollPaused) {
      return;
    }
    _groupPollPaused = false;
    globalState.appController.updateGroupsDebounce();
    _autoUpdateGroupTask();
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await globalState.appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      // `HotKeyManager` (global numpad/modifier registration + Ctrl+W
      // Shortcut wrapper) was removed for the Play readiness wave —
      // the settings UI no longer exposes the hotkey configuration
      // screen so persisted (often broken) numpad mappings should not
      // be registered at startup. The wrapper itself was unwound
      // here rather than gutted in `hotkey_manager.dart` so the file
      // can come back later if we re-introduce a curated set.
      return WindowManager(
        child: TrayManager(
          child: ProxyManager(
            child: child,
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(
        child: child,
      ),
    );
  }

  Widget _buildState(Widget child) => AppStateManager(
        child: ClashManager(
          child: ConnectivityManager(
            onConnectivityChanged: (results) async {
              if (!results.contains(ConnectivityResult.vpn)) {
                clashCore.closeConnections();
              }
              globalState.appController.updateLocalIp();
              globalState.appController.addCheckIpNumDebounce();
            },
            child: child,
          ),
        ),
      );

  Widget _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(
        child: child,
      );
    }
    return VpnManager(
      child: child,
    );
  }

  Widget _buildApp(Widget child) => MessageManager(
        child: ThemeManager(
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => _buildPlatformState(
        _buildState(
          Consumer(
            builder: (_, ref, child) {
              final locale =
                  ref.watch(appSettingProvider.select((state) => state.locale));
              final themeProps = ref.watch(themeSettingProvider);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: globalState.navigatorKey,
                checkerboardRasterCacheImages: false,
                checkerboardOffscreenLayers: false,
                showPerformanceOverlay: false,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate
                ],
                builder: (_, child) {
                  final Widget app = AppEnvManager(
                    child: _buildPlatformApp(
                      _buildApp(child!),
                    ),
                  );

                  if (Platform.isMacOS) {
                    return FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 500,
                        height: 800,
                        child: app,
                      ),
                    );
                  }

                  return app;
                },
                scrollBehavior: BaseScrollBehavior(),
                title: appName,
                locale: utils.getLocaleForString(locale),
                supportedLocales: AppLocalizations.delegate.supportedLocales,
                // Dropweb is shipped as a dark-only product. The light /
                // system options used to live behind `_ThemeModeItem` in
                // Settings → Theme but have been removed; any persisted
                // `ThemeMode.light` / `ThemeMode.system` value from older
                // installs is intentionally ignored here.
                themeMode: ThemeMode.dark,
                theme: _buildThemeData(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                  pureBlack: themeProps.pureBlack,
                ),
                darkTheme: _buildThemeData(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                  pureBlack: themeProps.pureBlack,
                ),
                home: child,
              );
            },
            child: const HomePage(),
          ),
        ),
      );

  ThemeData _buildThemeData({
    required Brightness brightness,
    required int? primaryColor,
    required bool pureBlack,
  }) {
    final colorScheme = _getAppColorScheme(
      brightness: brightness,
      primaryColor: primaryColor,
    );
    const onest = TextTheme(
      displayLarge: TextStyle(fontFamily: 'Onest'),
      displayMedium: TextStyle(fontFamily: 'Onest'),
      displaySmall: TextStyle(fontFamily: 'Onest'),
      headlineLarge: TextStyle(fontFamily: 'Onest'),
      headlineMedium: TextStyle(fontFamily: 'Onest'),
      headlineSmall: TextStyle(fontFamily: 'Onest'),
      titleLarge: TextStyle(fontFamily: 'Onest'),
      titleMedium: TextStyle(fontFamily: 'Onest'),
      titleSmall: TextStyle(fontFamily: 'Onest'),
      bodyLarge: TextStyle(fontFamily: 'Onest'),
      bodyMedium: TextStyle(fontFamily: 'Onest'),
      bodySmall: TextStyle(fontFamily: 'Onest'),
      labelLarge: TextStyle(fontFamily: 'Onest'),
      labelMedium: TextStyle(fontFamily: 'Onest'),
      labelSmall: TextStyle(fontFamily: 'Onest'),
    );
    var scheme = pureBlack ? colorScheme.toPureBlack(true) : colorScheme;
    // LUMINA: override surfaces for dark theme — tactile void
    if (brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        surface: Lumina.void_,
        surfaceContainerLowest: Lumina.surface1,
        surfaceContainerLow: Lumina.surface2,
        surfaceContainer: Lumina.surface3,
        surfaceContainerHigh: Lumina.surface4,
        surfaceContainerHighest: Lumina.surface5,
      );
    }
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: scheme,
      textTheme: onest,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // LUMINA: cards use void-level elevation
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          side: brightness == Brightness.dark
              ? BorderSide(
                  color:
                      Colors.white.withValues(alpha: Lumina.glassBorderOpacity))
              : BorderSide.none,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    globalState.pauseGroupsPolling = null;
    globalState.resumeGroupsPolling = null;
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateProfilesTaskTimer?.cancel();
    await clashCore.destroy();
    await globalState.appController.savePreferences();
    await globalState.appController.handleExit();
    super.dispose();
  }
}
