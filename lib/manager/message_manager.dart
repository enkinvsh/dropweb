import 'dart:async';
import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, LiquidRoundedSuperellipse;

class MessageManager extends StatefulWidget {
  const MessageManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  State<MessageManager> createState() => MessageManagerState();
}

class MessageManagerState extends State<MessageManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  bool _pushing = false;

  @override
  void dispose() {
    _messagesNotifier.dispose();
    super.dispose();
  }

  Future<void> message(String text) async {
    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
    );
    commonPrint.log(text);
    _bufferMessages.add(commonMessage);
    await _showMessage();
  }

  Future<void> _showMessage() async {
    if (_pushing == true) {
      return;
    }
    _pushing = true;
    while (_bufferMessages.isNotEmpty) {
      final commonMessage = _bufferMessages.removeAt(0);
      // Bail before mutating if the State was disposed mid-drain: the
      // ValueNotifier is disposed in dispose() and mutating it throws.
      if (!mounted) return;
      _messagesNotifier.value = List.from(_messagesNotifier.value)
        ..add(
          commonMessage,
        );
      await Future.delayed(const Duration(seconds: 1));
      // The manager may have been disposed during the delay above.
      if (!mounted) return;
      Future.delayed(commonMessage.duration, () {
        _handleRemove(commonMessage);
      });
      if (_bufferMessages.isEmpty) {
        _pushing = false;
      }
    }
  }

  void _handleRemove(CommonMessage commonMessage) {
    // Fired from a delayed callback or a swipe; the State (and its
    // ValueNotifier) may have been disposed by the time this runs, and a
    // swiped message is already gone when its timer fires.
    if (!mounted || !_messagesNotifier.value.contains(commonMessage)) return;
    _messagesNotifier.value = List<CommonMessage>.from(_messagesNotifier.value)
      ..remove(commonMessage);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final desktop = system.isDesktop;
    return Stack(
      children: [
        widget.child,
        // Mobile pages have no title, so the empty app bar is where a
        // notification drops in. Desktop keeps titles: toasts sit below
        // the bar on the right, as before.
        Positioned(
          top: desktop
              ? kToolbarHeight + 8
              : MediaQuery.paddingOf(context).top + 6,
          left: 12,
          right: 12,
          child: Align(
            alignment: desktop ? Alignment.topRight : Alignment.topCenter,
            child: ValueListenableBuilder(
              valueListenable: _messagesNotifier,
              builder: (_, messages, __) => AnimatedSwitcher(
                duration: Lumina.luminaDuration,
                reverseDuration: const Duration(milliseconds: 260),
                switchInCurve: Lumina.luminaCurve,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: reduceMotion
                      ? child
                      : SlideTransition(
                          position: Tween(
                            begin: const Offset(0, -0.6),
                            end: Offset.zero,
                          ).animate(animation),
                          child: ScaleTransition(
                            scale:
                                Tween(begin: 0.9, end: 1.0).animate(animation),
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                ),
                child: messages.isEmpty
                    ? const SizedBox.shrink()
                    : _LiquidToast(
                        key: ValueKey(messages.last.id),
                        text: messages.last.text,
                        onDismissed: () => _handleRemove(messages.last),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A notification on the same glass as MENU. Swipe it up or sideways to
/// dismiss; a short drag springs back.
class _LiquidToast extends StatefulWidget {
  const _LiquidToast({
    super.key,
    required this.text,
    required this.onDismissed,
  });

  final String text;
  final VoidCallback onDismissed;

  @override
  State<_LiquidToast> createState() => _LiquidToastState();
}

class _LiquidToastState extends State<_LiquidToast>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 24,
  );

  /// Drag distance or fling speed past which a release dismisses.
  static const _dismissDistance = 48.0;
  static const _dismissVelocity = 700.0;

  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  );
  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _motion.addListener(() {
      setState(() {
        _offset = Offset.lerp(_from, _to, _motion.value)!;
      });
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    if (_leaving) return;
    _motion.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leaving) return;
    final dx = _offset.dx + details.delta.dx;
    var dy = _offset.dy + details.delta.dy;
    // Pulling down fights back: the toast only wants to leave upward.
    if (dy > 0) dy = _offset.dy + details.delta.dy * 0.25;
    setState(() => _offset = Offset(dx, min(dy, 24)));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.velocity.pixelsPerSecond;
    final size = context.size ?? Size.zero;
    final sideways = _offset.dx.abs() > _dismissDistance ||
        velocity.dx.abs() > _dismissVelocity;
    final upward =
        _offset.dy < -_dismissDistance / 2 || velocity.dy < -_dismissVelocity;
    if (sideways && _offset.dx.abs() >= _offset.dy.abs() ||
        sideways && !upward) {
      final direction = (_offset.dx + velocity.dx * 0.1).sign;
      _leave(Offset(direction * (size.width + 48), _offset.dy));
    } else if (upward) {
      _leave(Offset(_offset.dx, -(size.height + 64)));
    } else {
      _animateTo(Offset.zero, velocity);
    }
  }

  void _leave(Offset target) {
    _leaving = true;
    _animateTo(target, Offset.zero).whenComplete(widget.onDismissed);
  }

  TickerFuture _animateTo(Offset target, Offset velocity) {
    _from = _offset;
    _to = target;
    final distance = (_to - _from).distance;
    if (distance < 0.5 || MediaQuery.of(context).disableAnimations) {
      _motion.value = 1;
      return TickerFuture.complete();
    }
    // Project the release speed onto the travel direction so a fling
    // carries into the spring instead of restarting from rest.
    final along = (_to - _from) / distance;
    final speed = (velocity.dx * along.dx + velocity.dy * along.dy) / distance;
    _motion.value = 0;
    return _motion.animateWith(SpringSimulation(_spring, 0, 1, speed));
  }

  @override
  Widget build(BuildContext context) {
    final width = min(MediaQuery.sizeOf(context).width - 24, 500).toDouble();
    final travel = _offset.dx.abs() / (width * 0.9);
    final opacity = (1 - travel).clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        onPanEnd: _onDragEnd,
        child: Transform.translate(
          offset: _offset,
          child: Opacity(
            opacity: opacity,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: GlassContainer(
                useOwnLayer: true,
                quality: Lumina.liquidOverlayQuality,
                shape: const LiquidRoundedSuperellipse(
                  borderRadius: Lumina.radiusLg,
                ),
                settings: Lumina.liquidMenu,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Lumina.radiusLg),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Lumina.lensHighlight.opacity15,
                        Lumina.lensHighlight.opacity0,
                        Lumina.lensShadow.opacity0,
                        Lumina.lensShadow.opacity15,
                      ],
                      stops: const [0, 0.5, 0.55, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
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
