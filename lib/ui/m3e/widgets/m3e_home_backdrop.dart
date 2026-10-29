import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_hero_button.dart';
import 'm3e_shape.dart';

/// Ключ фона главной.
const Key kM3eBackdropKey = ValueKey<String>('m3e.backdrop');

/// Стороны трёх форм-колец: `--s` у `.dr-sh--1..3` (android.css 257–259).
const List<double> _sizes = [940, 600, 330];

/// Позы форм `[поворот°, масштаб]` на кольцо по состоянию: android.css 257–275.
/// Спокойное положение — базовые повороты `.dr-sh--N`; `error` меняет только 2-е и 3-е.
const Map<M3eHeroState, List<double>> _poses = {
  M3eHeroState.off: [4, 1, -8, 1, 10, 1],
  M3eHeroState.connecting: [19, .97, -28, .95, 36, .9],
  M3eHeroState.on: [34, 1.03, -48, 1.05, 62, 1.08],
  M3eHeroState.error: [4, 1, -2, 1, 2, .94],
};

/// Фон главной: три формы Cookie вокруг кнопки подключения и заливка цветом
/// провайдера волной от кнопки (Circular reveal).
///
/// Повторяет `BG_SHAPES`/`.dr-bg` доски (android.js 453–460, android.css 239–293).
/// Анимируются только поворот, масштаб, радиус заливки и прозрачность, и все
/// переходы прерываемы: смена состояния посреди анимации разворачивается с текущего
/// места. Под `MediaQuery.disableAnimations` состояния меняются мгновенно.
class M3eHomeBackdrop extends StatefulWidget {
  const M3eHomeBackdrop({
    super.key,
    required this.state,
    this.blocked = false,
    required this.waveOrigin,
  });

  final M3eHeroState state;

  /// Подписка закончилась или трафик исчерпан: фон остаётся спокойным, как в `off`
  /// (`bgState` доски, android.js 460).
  final bool blocked;

  /// Центр кнопки подключения в координатах фона: отсюда растёт волна и вокруг этой
  /// точки стоят формы.
  final Offset waveOrigin;

  @override
  State<M3eHomeBackdrop> createState() => _M3eHomeBackdropState();
}

class _M3eHomeBackdropState extends State<M3eHomeBackdrop>
    with TickerProviderStateMixin {
  late final _Channel _pose = _Channel(this, _poses[M3eHeroState.off]!);
  late final _Channel _flood = _Channel(this, const [0]);
  late final _Channel _live = _Channel(this, const [0]);
  bool _reduced = false;
  bool _ready = false;

  M3eHeroState get _bgState => widget.blocked ? M3eHeroState.off : widget.state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_ready) {
      _ready = true;
      _jump();
    } else if (_reduced) {
      _jump();
    }
  }

  @override
  void didUpdateWidget(M3eHomeBackdrop old) {
    super.didUpdateWidget(old);
    final was = old.blocked ? M3eHeroState.off : old.state;
    if (was != _bgState) _retarget(was);
  }

  @override
  void dispose() {
    _pose.dispose();
    _flood.dispose();
    _live.dispose();
    super.dispose();
  }

  void _jump() {
    final on = _bgState == M3eHeroState.on;
    _pose.jump(_poses[_bgState]!);
    _flood.jump([on ? 1 : 0]);
    _live.jump([on ? 1 : 0]);
  }

  void _retarget(M3eHeroState was) {
    if (_reduced) {
      _jump();
      return;
    }
    final now = _bgState;
    final on = now == M3eHeroState.on;
    // Формы везде на пружине slow spatial (android.css 255).
    _pose.go(
      _poses[now]!,
      const Duration(milliseconds: 568),
      const M3eSpringCurve(M3eSpring.slowSpatial, 0.568),
    );
    // Волна входит пружиной, выходит быстрее по emphasized accelerate:
    // отключение не должно тянуться (android.css 276–285).
    _flood.go(
      [on ? 1 : 0],
      on
          ? const Duration(milliseconds: 568)
          : const Duration(milliseconds: 300),
      on
          ? const M3eSpringCurve(M3eSpring.slowSpatial, 0.568)
          : M3eEasing.emphasizedAccelerate,
    );
    // Живой набор проявляется, когда волна до него дошла: задержка 140 мс.
    _live.go(
      [on ? 1 : 0],
      on
          ? const Duration(milliseconds: 440)
          : const Duration(milliseconds: 120),
      on
          ? const _Delayed(
              140 / 440, M3eSpringCurve(M3eSpring.slowEffects, 0.3))
          : Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = M3eColors.of(context).home;
    return RepaintBoundary(
      key: kM3eBackdropKey,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_pose.controller, _flood.controller, _live.controller]),
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BackdropPainter(
            origin: widget.waveOrigin,
            pose: _pose.value,
            flood: _flood.value[0],
            live: _live.value[0],
            bg: c.bg,
            calm: [c.shA, c.shB, c.shC],
            lively: [c.lvA, c.lvB, c.lvC],
            floodColor: c.flood,
          ),
        ),
      ),
    );
  }
}

/// Значение (вектор), которое плавно едет к новой цели; смена цели посреди хода
/// стартует с текущего места, а не с нуля. Контроллер ходит только пока идёт переход.
class _Channel {
  _Channel(TickerProvider vsync, List<double> initial)
      : controller = AnimationController(vsync: vsync, value: 1),
        _from = initial,
        _to = initial;

  final AnimationController controller;
  List<double> _from;
  List<double> _to;
  Curve _curve = Curves.linear;

  List<double> get value {
    final t = _curve.transform(controller.value.clamp(0.0, 1.0));
    return [
      for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t
    ];
  }

  void go(List<double> to, Duration duration, Curve curve) {
    _from = value;
    _to = to;
    _curve = curve;
    controller
      ..duration = duration
      ..forward(from: 0);
  }

  void jump(List<double> to) {
    controller.stop();
    _from = to;
    _to = to;
    controller.value = 1;
  }

  void dispose() => controller.dispose();
}

/// Кривая, выдерживающая долю [delay] времени на нуле, затем идущая по [inner].
class _Delayed extends Curve {
  const _Delayed(this.delay, this.inner);

  final double delay;
  final Curve inner;

  @override
  double transformInternal(double t) =>
      t <= delay ? 0 : inner.transform((t - delay) / (1 - delay));
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.origin,
    required this.pose,
    required this.flood,
    required this.live,
    required this.bg,
    required this.calm,
    required this.lively,
    required this.floodColor,
  });

  final Offset origin;
  final List<double> pose;
  final double flood;
  final double live;
  final Color bg;
  final List<Color> calm;
  final List<Color> lively;
  final Color floodColor;

  static final List<Path> _paths = [
    MaterialShapes.cookie12Sided,
    MaterialShapes.cookie9Sided,
    MaterialShapes.cookie7Sided,
  ].map((p) => m3eUnitPath(m3ePlacedShape(p))).toList(growable: false);

  void _shapes(Canvas canvas, List<Color> colors) {
    for (var i = 0; i < 3; i++) {
      canvas
        ..save()
        ..translate(origin.dx, origin.dy)
        ..rotate(pose[i * 2] * math.pi / 180)
        ..scale(_sizes[i] * pose[i * 2 + 1])
        ..translate(-0.5, -0.5)
        ..drawPath(_paths[i], Paint()..color = colors[i])
        ..restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..clipRect(Offset.zero & size)
      ..drawRect(Offset.zero & size, Paint()..color = bg);
    _shapes(canvas, calm);
    // Радиус волны — до дальнего угла экрана: к концу она закрывает всё.
    final reach = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    if (flood > 0) {
      canvas.drawCircle(origin, reach * flood, Paint()..color = floodColor);
    }
    if (live <= 0) return;
    if (live >= 1) {
      _shapes(canvas, lively);
    } else {
      // Прозрачность набора целиком, а не каждой формы: кольца перекрываются.
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, live.clamp(0.0, 1.0)),
      );
      _shapes(canvas, lively);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => true;
}
