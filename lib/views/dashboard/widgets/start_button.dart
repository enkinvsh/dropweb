import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
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

  void handleSwitchStart() {
    final currentlyRunning = ref.read(runTimeProvider) != null;
    final next = !currentlyRunning;
    App().performHapticFeedback(DropwebHapticCue.confirm);
    App().playUiSound(
      next ? DropwebSoundCue.powerOn : DropwebSoundCue.powerOff,
    );
    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(next);
      },
      duration: commonDuration,
    );
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

    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile = state.hasProfile;
    final isInactive = hasProfile && !isStart;
    final iconColor = isInactive
        ? Color.lerp(const Color(0xFF15151D), colorScheme.primary, 0.28)!
        : colorScheme.primary;

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
        onTapDown: (_) => _handleTapDown(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: hasProfile ? handleSwitchStart : _handleAddProfile,
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
                    builder: (_, __) => HugeIcon(
                      icon: !hasProfile
                          ? HugeIcons.strokeRoundedAddCircleHalfDot
                          : HugeIcons.strokeRoundedPower,
                      size: widget.iconSize,
                      strokeWidth: _pressController.value > 0 ? 3.0 : 2.0,
                      color: color ?? iconColor,
                    ),
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
