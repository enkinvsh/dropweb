import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, LiquidRoundedSuperellipse;

class MessageManager extends StatefulWidget {
  const MessageManager({
    super.key,
    required this.child,
    this.useM3e,
  });
  final Widget child;

  /// Рисовать сообщения плашкой M3E. `null` — только на Android; параметр нужен, чтобы
  /// тест на macOS мог включить новый путь, а `lib/ui/m3e` при этом не читал `Platform`.
  final bool? useM3e;

  @override
  State<MessageManager> createState() => MessageManagerState();
}

class MessageManagerState extends State<MessageManager> {
  /// Минимум между показом сообщения и приходом следующего на его место (как 1 с в
  /// старом `_showMessage`).
  static const Duration _minGap = Duration(seconds: 1);

  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  bool _pushing = false;

  // Путь M3E. Сообщение на экране; презентер сам убирает его через `kM3eToastHold`.
  final _toast = ValueNotifier<M3eToastMessage?>(null);
  final List<M3eToastMessage> _toastQueue = [];

  /// Таймер минимальной паузы живёт только секунду после показа. Время не меряем часами
  /// (`DateTime.now`): таймер одинаково работает на устройстве и под fake async в тестах.
  Timer? _gapTimer;
  bool _gapOpen = true;

  bool get _m3e => widget.useM3e ?? Platform.isAndroid;

  @override
  void dispose() {
    _gapTimer?.cancel();
    _toast.dispose();
    _messagesNotifier.dispose();
    super.dispose();
  }

  /// [kind] — значок плашки на Android. Без [kind] плашка идёт без значка.
  Future<void> message(String text, {M3eToastKind? kind}) async {
    commonPrint.log(text);
    if (_m3e) {
      _enqueueToast(M3eToastMessage(kind: kind, text: text));
      return;
    }
    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
    );
    _bufferMessages.add(commonMessage);
    await _showMessage();
  }

  void _enqueueToast(M3eToastMessage message) {
    if (!mounted) return;
    _toastQueue.add(message);
    // Заменяем показанное сразу, если плашки нет или пауза в 1 с уже прошла; иначе
    // ждёт таймер паузы, он сам возьмёт очередь.
    if (_toast.value == null || _gapOpen) _showNextToast();
  }

  void _showNextToast() {
    if (!mounted || _toastQueue.isEmpty) return;
    _toast.value = _toastQueue.removeAt(0);
    _gapOpen = false;
    _gapTimer?.cancel();
    _gapTimer = Timer(_minGap, _onGapPassed);
  }

  void _onGapPassed() {
    _gapTimer = null;
    _gapOpen = true;
    _showNextToast();
  }

  /// Презентер зовёт в начале ухода по истечении `hold`: если никого нет в очереди,
  /// снимаем сообщение, иначе следующее уже заняло место.
  void _onToastDismissed(M3eToastMessage message) {
    if (!mounted || !identical(_toast.value, message)) return;
    if (_toastQueue.isNotEmpty) {
      _showNextToast();
    } else {
      _toast.value = null;
    }
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
    if (_m3e) {
      return Stack(
        children: [
          widget.child,
          // Тема M3E ставится только вокруг плашки: старые экраны остаются на Lumina,
          // а плашка получает цвета схемы. Презентер сам не перехватывает касания.
          Positioned.fill(
            child: M3eThemeScope(
              child: ValueListenableBuilder<M3eToastMessage?>(
                valueListenable: _toast,
                builder: (_, message, __) => M3eToastPresenter(
                  message: message,
                  onDismissed: _onToastDismissed,
                ),
              ),
            ),
          ),
        ],
      );
    }
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
