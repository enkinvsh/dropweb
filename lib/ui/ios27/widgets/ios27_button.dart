// Кнопка-капсула iOS 27: стеклянная, цветное стекло (prominent), серая и красная (доска `.btn`, app.css:112-121, 399-401).

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27SpringSpec, Ios27Text;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Вид кнопки.
enum Ios27ButtonStyle {
  /// `.btn.glass` («Glass» кита): стекло, подпись Medium (500) `--glass-label`.
  glass,

  /// `.btn.glass.glass--tint` («Glass Prominent»): стекло цвета провайдера, одно главное действие
  /// на экране («Добавить», «Вставить ссылку»).
  prominent,

  /// `.btn--primary`: плотная заливка `--accent`, подпись `--on-accent`.
  primary,

  /// `.btn--plain`: серая капсула `--fill-3`, подпись `--label`.
  plain,

  /// `.btn--danger`: серая капсула `--fill-3`, подпись `--red-text` (разрушительное действие
  /// в алерте кита).
  danger,
}

/// Размер кнопки.
enum Ios27ButtonSize {
  /// `.btn`: высота 50, поля 22, радиус 25.
  regular(50, 22),

  /// `.alert__actions .btn`: высота 48, поля 12 (app.css:399).
  compact(48, 12),

  /// `.btn--sm`: высота 34, поля 12, радиус 17 (app.css:120); не растягивается.
  small(34, 12);

  const Ios27ButtonSize(this.height, this.padding);

  final double height;
  final double padding;
}

/// Кнопка-капсула по доске: [label] и/или значок [icon] (20 px) через зазор 8.
///
/// * [onPressed] `null` — отключена: подпись `--label-3`; у плотных видов фон `--fill-4`
///   (`.btn:disabled`), у цветного стекла оно гаснет до обычного (`glass.css:261`).
/// * [block] растягивает кнопку на всю ширину (`.btn--block`); `small` не растягивается.
/// * [nested] — стекло внутри стекла (листы, алерты, карточка): плоская полупрозрачная заливка
///   без нативного стекла (glass-map.md, раздел 2); на обычной странице ставьте `false`.
/// * Высота — минимум: при крупном системном шрифте подпись переносится и кнопка растёт, а не
///   обрезает текст (на доске `nowrap`, но доска живёт на 1.0).
/// * Нажатие стеклянных видов: подъём 6 % пружиной и свечение от точки касания, как у круглых
///   кнопок; «Уменьшить движение» оставляет только свечение.
/// * [semanticLabel] заменяет [label] для VoiceOver; [semanticIdentifier] — для автотестов.
class Ios27Button extends StatefulWidget {
  const Ios27Button({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.style = Ios27ButtonStyle.glass,
    this.size = Ios27ButtonSize.regular,
    this.block = false,
    this.nested = true,
    this.semanticLabel,
    this.semanticIdentifier,
  }) : assert(label != null || icon != null, 'нужна подпись или значок');

  final String? label;
  final Ios27IconName? icon;
  final VoidCallback? onPressed;
  final Ios27ButtonStyle style;
  final Ios27ButtonSize size;
  final bool block;
  final bool nested;
  final String? semanticLabel;
  final String? semanticIdentifier;

  bool get _glass =>
      style == Ios27ButtonStyle.glass || style == Ios27ButtonStyle.prominent;

  @override
  State<Ios27Button> createState() => _Ios27ButtonState();
}

class _Ios27ButtonState extends State<Ios27Button>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _glow;
  late final CurvedAnimation _glowCurve;
  Offset _touch = const Offset(0.5, 0.5);
  bool _reduceMotion = false;

  bool get _enabled => widget.onPressed != null;
  bool get _feedback => widget._glass && _enabled;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController.unbounded(vsync: this, value: 1);
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _glowCurve = CurvedAnimation(parent: _glow, curve: Ios27Motion.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Ios27Button oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_feedback && (_glow.value > 0 || _scale.value != 1)) {
      _release();
    }
  }

  @override
  void dispose() {
    _glowCurve.dispose();
    _scale.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _spring(Ios27SpringSpec spec, double to) {
    _scale.animateWith(
      SpringSimulation(spec.description, _scale.value, to, _scale.velocity),
    );
  }

  void _press(TapDownDetails details) {
    if (!_feedback) {
      return;
    }
    final box = context.size ?? const Size(1, 1);
    _touch = Offset(
      (details.localPosition.dx / box.width).clamp(0.0, 1.0),
      (details.localPosition.dy / box.height).clamp(0.0, 1.0),
    );
    _glow.forward();
    if (!_reduceMotion) {
      _spring(Ios27Motion.springInteractive, kIos27PressScale);
    }
  }

  void _release() {
    _glow.reverse();
    if (!_reduceMotion || _scale.value != 1) {
      _spring(Ios27Motion.springBouncy, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;
    final size = widget.size;

    return Ios27A11yBuilder(
      builder: (context, a11y) {
        final Color labelColor;
        Color? fill;
        switch (widget.style) {
          case Ios27ButtonStyle.glass:
            labelColor = ios27GlassLabelColor(
              context,
              _enabled ? Ios27GlassTone.normal : Ios27GlassTone.muted,
            );
          case Ios27ButtonStyle.prominent:
            labelColor = ios27GlassLabelColor(
              context,
              _enabled ? Ios27GlassTone.onTint : Ios27GlassTone.muted,
            );
          case Ios27ButtonStyle.primary:
            fill = _enabled ? colors.accentColor : palette.fill4;
            labelColor = _enabled ? colors.onAccent : palette.label3;
          case Ios27ButtonStyle.plain:
            fill = _enabled ? palette.fill3 : palette.fill4;
            labelColor = _enabled ? palette.label : palette.label3;
          case Ios27ButtonStyle.danger:
            fill = _enabled ? palette.fill3 : palette.fill4;
            labelColor = _enabled ? palette.redText : palette.label3;
        }

        // Подпись стекла Medium (500), остальные Semibold (600): `.btn.glass{font-weight:500}`.
        final base = ios27Text(context, Ios27Text.headline, color: labelColor);
        final textStyle =
            widget._glass ? base.copyWith(fontWeight: FontWeight.w500) : base;

        final content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.padding),
            child: Center(
              widthFactor: widget.block ? null : 1,
              // Высота по содержимому: без этого Center в ограниченной по высоте строке/Center
              // раздувает кнопку на всё доступное место.
              heightFactor: 1,
              child: Row(
                mainAxisSize:
                    widget.block ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null)
                    Ios27Icon.spec(
                      widget.icon!,
                      Ios27IconSpecs.button,
                      color: labelColor,
                    ),
                  if (widget.icon != null && widget.label != null)
                    const SizedBox(width: 8),
                  if (widget.label != null)
                    Flexible(
                      child: Text(
                        widget.label!,
                        textAlign: TextAlign.center,
                        style: textStyle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        Widget body;
        if (widget._glass) {
          body = Ios27Glass(
            variant: Ios27GlassVariant.small,
            tint: widget.style == Ios27ButtonStyle.prominent
                ? colors.accentColor
                : null,
            interactive: true,
            nested: widget.nested,
            enabled: _enabled,
            child: Stack(
              children: [
                if (_feedback)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GlowPainter(_glowCurve, () => _touch),
                        ),
                      ),
                    ),
                  ),
                content,
              ],
            ),
          );
          body = AnimatedBuilder(
            animation: _scale,
            builder: (context, child) =>
                Transform.scale(scale: _scale.value, child: child),
            child: body,
          );
        } else {
          body = DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: const StadiumBorder(),
            ),
            child: content,
          );
        }

        body = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? _press : null,
          onTapUp: _enabled ? (_) => _release() : null,
          onTapCancel: _enabled ? _release : null,
          onTap: widget.onPressed,
          child: body,
        );

        return Semantics(
          container: true,
          identifier: widget.semanticIdentifier,
          button: true,
          enabled: _enabled,
          label: widget.semanticLabel ?? widget.label,
          onTap: widget.onPressed,
          child: ExcludeSemantics(child: body),
        );
      },
    );
  }
}

/// Свечение от точки касания (`.glass__hl`, glass.css:119-120): радиальный градиент 22 % белого
/// режимом `plus-lighter` ([BlendMode.plus]).
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.glow, this.touch) : super(repaint: glow);

  final Animation<double> glow;
  final Offset Function() touch;

  @override
  void paint(Canvas canvas, Size size) {
    final value = glow.value;
    if (value <= 0) {
      return;
    }
    final point = touch();
    final center = Offset(point.dx * size.width, point.dy * size.height);
    final radius = size.shortestSide * 1.2;
    final shader = RadialGradient(
      radius: 1,
      colors: [
        Colors.white.withValues(alpha: 0.22 * value),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0, 0.7],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.glow != glow;
}
