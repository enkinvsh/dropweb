import 'dart:async';
import 'dart:ui' as ui;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/vpn_disclosure_dialog.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key, this.iconSize = 48.0});

  final double iconSize;

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  /// Power-glyph drop shadow (lab `icon shadow` dials): a blurred dark copy
  /// of the glyph painted underneath, since HugeIcon (SVG) has no shadows.
  static const double _iconShadowBlur = 5.9;
  static const double _iconShadowAlpha = 0.81;

  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> handleSwitchStart() async {
    final currentlyRunning = ref.read(runTimeProvider) != null;
    final next = !currentlyRunning;

    // Disconnect keeps the existing feedback timing — play the power-off
    // cue immediately so the user gets a confirmation tick on tap. Feedback
    // is fire-and-forget so we don't block the status update.
    if (!next) {
      unawaited(App().performHapticFeedback(DropwebHapticCue.confirm));
      unawaited(App().playUiSound(DropwebSoundCue.powerOff));
      unawaited(globalState.appController.updateStatus(false));
      return;
    }

    // First-start path: the disclosure gate runs BEFORE any confirm haptic
    // and BEFORE the power-on cue. If the user cancels the dialog, no
    // feedback should suggest a connection was about to happen.
    final allowed = await _ensureVpnConsent();
    if (!allowed) return;

    ConnectTrace.start();
    unawaited(App().performHapticFeedback(DropwebHapticCue.confirm));
    unawaited(App().playUiSound(DropwebSoundCue.powerOn));
    unawaited(globalState.appController.updateStatus(true));
  }

  /// Returns true when the user has previously accepted the disclosure OR
  /// just accepted it in the dialog AND the accepted flag was successfully
  /// persisted. Returning true without a persisted flag would let the
  /// dashboard play the power-on feedback while the central
  /// `AppController.updateStatus` guard silently refuses the start, leaving
  /// the user with a tick but no connection. If `markAccepted()` fails to
  /// write, we treat the attempt as cancelled so the dialog can re-prompt
  /// next time.
  Future<bool> _ensureVpnConsent() async {
    if (await vpnConsent.isAccepted()) return true;
    if (!mounted) return false;
    final accepted = await showVpnDisclosureDialog(context);
    if (accepted != true) return false;
    final persisted = await vpnConsent.markAccepted();
    return persisted;
  }

  void _handleTapDown() {
    // Press-down only fires the gestureStart haptic — the audible cue was
    // removed (user feedback: the per-press tick felt redundant on top of
    // the powerOn/powerOff cue). Animation still runs so the visual press
    // affordance is preserved.
    if (ref.read(startButtonSelectorStateProvider).hasProfile) {
      App().performHapticFeedback(DropwebHapticCue.gestureStart);
    }
    _pressController.forward();
  }

  void _handleAddProfile() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: AddProfileView(context: context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    // Watch boolean running state only — was watching raw int timestamp,
    // which forced a rebuild on every runTimeProvider tick (every second
    // while connected) even though the icon depends only on null/not-null.
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));
    if (!state.isInit) return const SizedBox.shrink();

    // Connecting affordance: while handleStart is waiting on the native TUN
    // readiness ack, reuse the existing dimmed/disabled look and swallow taps.
    // No new colors/animations — just the opacity60 extension + null onTap.
    return ValueListenableBuilder<bool>(
      valueListenable: globalState.isConnecting,
      builder: (context, isConnecting, _) =>
          _buildButton(context, state, isStart, isConnecting),
    );
  }

  Widget _buildButton(
    BuildContext context,
    StartButtonSelectorState state,
    bool isStart,
    bool isConnecting,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile = state.hasProfile;
    final isInactive = hasProfile && !isStart;
    final baseIconColor = isInactive
        ? Color.lerp(const Color(0xFF15151D), colorScheme.primary, 0.28)!
        : colorScheme.primary;
    // While connecting, dim the icon with the existing opacity extension so it
    // reads as a pending/disabled affordance.
    final iconColor = isConnecting ? baseIconColor.opacity60 : baseIconColor;

    const motionDuration = Duration(milliseconds: 180);
    const motionCurve = Curves.easeOutCubic;

    return AnimatedBuilder(
      animation: _pressController,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Ignore press feedback + taps while connecting so a second tap can't
        // race the in-flight start transition.
        onTapDown: isConnecting ? null : (_) => _handleTapDown(),
        onTapUp: isConnecting ? null : (_) => _pressController.reverse(),
        onTapCancel: isConnecting ? null : () => _pressController.reverse(),
        onTap: isConnecting
            ? null
            : (hasProfile ? handleSwitchStart : _handleAddProfile),
        child: SizedBox.expand(
          child: Center(
            child: RepaintBoundary(
              child: AnimatedScale(
                scale: isInactive ? 0.94 : 1.0,
                duration: motionDuration,
                curve: motionCurve,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: iconColor),
                  duration: motionDuration,
                  curve: motionCurve,
                  builder: (_, color, __) => AnimatedBuilder(
                    animation: _pressController,
                    builder: (_, __) {
                      final iconData = !hasProfile
                          ? HugeIcons.strokeRoundedAddCircleHalfDot
                          : HugeIcons.strokeRoundedPower;
                      final strokeWidth =
                          _pressController.value > 0 ? 3.0 : 2.0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outline/glow: the same glyph, dark + blurred,
                          // painted UNDER the main icon. Mirrors the tuner's
                          // drawGlyphPaths(..., rgba(#000,0.72), blur 5.5) pass
                          // since HugeIcon (SVG) doesn't accept shadows.
                          ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: _iconShadowBlur,
                              sigmaY: _iconShadowBlur,
                            ),
                            child: HugeIcon(
                              icon: iconData,
                              size: widget.iconSize,
                              strokeWidth: strokeWidth,
                              color: const Color(0xFF000000)
                                  .withValues(alpha: _iconShadowAlpha),
                            ),
                          ),
                          HugeIcon(
                            icon: iconData,
                            size: widget.iconSize,
                            strokeWidth: strokeWidth,
                            color: color ?? iconColor,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
