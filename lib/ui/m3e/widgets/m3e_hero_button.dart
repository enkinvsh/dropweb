import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../symbols.g.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_shape.dart';
import 'm3e_symbol.dart';

/// Ключ корня кнопки (88x88): по нему тест сверяет прямоугольник с `hero` из layout.json.
const Key kM3eHeroKey = ValueKey<String>('m3e.hero');

/// Ключ формы кнопки (`hero.shape` в layout.json).
const Key kM3eHeroShapeKey = ValueKey<String>('m3e.hero.shape');

/// Состояние кнопки подключения. Подписка с истёкшим сроком или трафиком не отдельное
/// состояние: это `off` с `disabled: true`.
enum M3eHeroState { off, connecting, on, error }

/// Сторона кнопки: android.css 211, коробка 88 при боковых кнопках 48.
const double kM3eHeroSize = 88;

/// Доля стороны, которую занимает индикатор подключения (`IND`, android.js 649).
const double kM3eHeroIndicator = 0.56;

/// Один оборот включённой формы: `SPIN_MS` (android.js 645), CSS `dr-turn 24s`.
const Duration kM3eHeroSpin = Duration(milliseconds: 24000);

/// Размер значка внутри кнопки: `.dr-hero > .md-icon` (android.css 223).
const double _iconSize = 36;

/// Время морфа: пружина доски считается 0,7 с (android.js 690), потом контур садится.
const double _morphSeconds = 0.7;

/// Нажатие сжимает форму до 0,92 на пружине fast spatial (android.css 225).
const double _pressedScale = 0.92;

/// `ExpressiveLoadingIndicator` рисует форму размером 38 dp независимо от рамки.
const double _indicatorActiveSize = 38;

/// Кнопка подключения: круг → контейнер с индикатором → вращающееся Cookie → SoftBurst.
///
/// Только отрисовка и жест: провайдеры приложения не читаются. Цвета берутся из
/// [M3eColors]. Морф и вращение остановлены при `MediaQuery.disableAnimations`.
class M3eHeroButton extends StatefulWidget {
  const M3eHeroButton({
    super.key,
    required this.state,
    this.disabled = false,
    this.onPressed,
    this.semanticLabel,
  });

  final M3eHeroState state;

  /// Подписка закончилась или трафик исчерпан: кнопка серая и не нажимается.
  final bool disabled;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  State<M3eHeroButton> createState() => _M3eHeroButtonState();
}

class _M3eHeroButtonState extends State<M3eHeroButton>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_morphSeconds * 1000).round()),
  )..addStatusListener(_onMorphStatus);

  // Вращение крутится только в `on` и не в режиме «меньше движения».
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: kM3eHeroSpin);

  late M3eHeroState _state = widget.state;
  M3eCubics? _from;
  M3eCubics? _to;
  late M3eCubics _cur = _target(widget.state);
  bool _reduced = false;
  bool _ready = false;
  bool _pressed = false;

  static M3eCubics _target(M3eHeroState s) => switch (s) {
        M3eHeroState.on => m3ePlacedShape(MaterialShapes.cookie9Sided),
        M3eHeroState.error => m3ePlacedShape(MaterialShapes.softBurst),
        _ => m3ePlacedShape(MaterialShapes.circle),
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_ready && reduced == _reduced) return;
    _ready = true;
    _reduced = reduced;
    if (reduced) {
      _morph.stop();
      _from = null;
      _to = null;
      _cur = _target(_state);
      _stopSpin();
    } else if (_state == M3eHeroState.on && !_spin.isAnimating) {
      _startSpin();
    }
  }

  @override
  void didUpdateWidget(M3eHeroButton old) {
    super.didUpdateWidget(old);
    if (widget.state != _state) _heroTo(widget.state);
  }

  @override
  void dispose() {
    _morph.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _startSpin() {
    _spin
      ..value = 0
      ..repeat();
  }

  void _stopSpin() {
    _spin
      ..stop()
      ..value = 0;
  }

  double get _spinDegrees => _state == M3eHeroState.on ? _spin.value * 360 : 0;

  void _onMorphStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Пружина на 0,7 с ещё чуть не дошла до 1: садим точный контур цели.
    setState(() {
      _from = null;
      _to = null;
      _cur = _target(_state);
    });
  }

  /// Контур в данный момент: форма цели, середина морфа или (в `on`) без поворота —
  /// поворот накладывается при рисовании.
  M3eCubics _display() {
    final from = _from, to = _to;
    if (from == null || to == null) return _cur;
    return m3eLerp(
      from,
      to,
      m3eSpringValue(M3eSpring.defaultSpatial, _morph.value * _morphSeconds),
    );
  }

  void _heroTo(M3eHeroState next) {
    final prev = _state;
    if (_reduced) {
      _from = null;
      _to = null;
      _cur = _target(next);
    } else {
      // Поворот включённой формы делает рисование; при выходе из `on` запекаем
      // его в точки, чтобы контур не дёрнулся, когда вращение снимется. Незавершённый
      // морф продолжается с текущего места, а не с начала.
      var from = _display();
      if (prev == M3eHeroState.on) {
        from = m3ePlace(from, degrees: _spinDegrees);
      }
      final target = _target(next);
      final n =
          [96, from.length, target.length].reduce((a, b) => a > b ? a : b);
      final fromN = m3eResample(from, n);
      final toN = m3eResample(target, n);
      _from = fromN;
      _to = m3eShift(toN, m3eAlignShift(fromN, toN));
      _morph.forward(from: 0);
    }
    _state = next;
    if (next == M3eHeroState.on && !_reduced) {
      _startSpin();
    } else {
      _stopSpin();
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  ({Color bg, Color fg}) _colors(M3eColors c) {
    if (widget.disabled) {
      return (
        bg: c.scheme.onSurface.withValues(alpha: 0.10),
        fg: c.scheme.onSurface.withValues(alpha: M3eState.disabledContent),
      );
    }
    return switch (_state) {
      M3eHeroState.on => (bg: c.home.heroOn, fg: c.home.onHeroOn),
      M3eHeroState.error => (
          bg: c.scheme.errorContainer,
          fg: c.scheme.onErrorContainer,
        ),
      _ => (bg: c.scheme.primaryContainer, fg: c.scheme.onPrimaryContainer),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final (:bg, :fg) = _colors(colors);
    final enabled = !widget.disabled;
    final instant = _reduced;
    final connecting = _state == M3eHeroState.connecting;

    Widget shape = AnimatedBuilder(
      animation: Listenable.merge([_morph, _spin]),
      builder: (context, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: bg),
        duration: instant ? Duration.zero : const Duration(milliseconds: 212),
        builder: (context, fill, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: _pressed && enabled ? M3eState.pressed : 0),
          duration: instant ? Duration.zero : const Duration(milliseconds: 138),
          builder: (context, layer, _) => CustomPaint(
            painter: _HeroPainter(
              cubics: _display(),
              degrees: _spinDegrees,
              fill: fill ?? bg,
              layer: fg.withValues(alpha: layer * fg.a),
            ),
          ),
        ),
      ),
    );
    shape = SizedBox.expand(key: kM3eHeroShapeKey, child: shape);

    final Widget content = Stack(
      alignment: Alignment.center,
      children: [
        shape,
        if (connecting) _Indicator(color: fg, reduced: instant),
        if (!connecting)
          M3eSymbolIcon(
            _state == M3eHeroState.error
                ? M3eSymbol.refresh
                : M3eSymbol.powerSettingsNew,
            fill: _state == M3eHeroState.on,
            size: _iconSize,
            color: fg,
          ),
      ],
    );

    return Semantics(
      container: true,
      identifier: 'dw_connect',
      button: true,
      enabled: enabled,
      toggled: _state == M3eHeroState.on,
      label: widget.semanticLabel,
      onTap: enabled ? widget.onPressed : null,
      child: ExcludeSemantics(
        child: SizedBox(
          key: kM3eHeroKey,
          width: kM3eHeroSize,
          height: kM3eHeroSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? widget.onPressed : null,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: AnimatedScale(
              scale: _pressed && enabled ? _pressedScale : 1,
              duration:
                  instant ? Duration.zero : const Duration(milliseconds: 348),
              curve: const M3eSpringCurve(M3eSpring.fastSpatial, 0.348),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Индикатор подключения: `ExpressiveLoadingIndicator` на месте значка.
/// Под «меньше движения» — одна статичная форма SoftBurst (android.js 655–657).
class _Indicator extends StatelessWidget {
  const _Indicator({required this.color, required this.reduced});

  final Color color;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    const box = kM3eHeroSize * kM3eHeroIndicator;
    // Под закрытым маршрутом (TickerMode выключен) тоже статичная форма: внутри пакета
    // живёт Timer.periodic(650 мс), который TickerMode не глушит и который, дёргая
    // контроллер, просил бы кадр каждые 650 мс, пока экран не виден. Замена виджета
    // снимает таймер вместе с состоянием пакета; при возврате индикатор создаётся заново.
    if (reduced || !TickerMode.valuesOf(context).enabled) {
      return M3eShapeView(MaterialShapes.softBurst, color: color, size: box);
    }
    // Пакет рисует форму в 38 dp при любой рамке; доска даёт индикатору 56 %
    // кнопки, поэтому рамку 38 растягиваем масштабом, а не просим пакет.
    return Transform.scale(
      scale: box / _indicatorActiveSize,
      child: ExpressiveLoadingIndicator(
        color: color,
        constraints: BoxConstraints.tight(
          const Size.square(_indicatorActiveSize),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({
    required this.cubics,
    required this.degrees,
    required this.fill,
    required this.layer,
  });

  final M3eCubics cubics;
  final double degrees;
  final Color fill;
  final Color layer;

  @override
  void paint(Canvas canvas, Size size) {
    final path = m3eUnitPath(cubics);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(degrees * 3.141592653589793 / 180)
      ..translate(-size.width / 2, -size.height / 2)
      ..scale(size.width, size.height)
      ..drawPath(path, Paint()..color = fill);
    if (layer.a > 0) canvas.drawPath(path, Paint()..color = layer);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter old) => true;
}
