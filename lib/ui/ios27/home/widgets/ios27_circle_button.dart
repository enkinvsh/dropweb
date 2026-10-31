// Круглая стеклянная кнопка и общая реакция на нажатие стекла доски.
//
// Доска: `.circle-btn` (app.css:52, 44×44, значок 22), `.glass--interactive:active`
// (glass.css:264-278), свечение `.glass__hl` (glass.css:117-123), Reduce Motion
// (glass.css:302-306). Из этого виджета собираются кнопка настроек, кнопки дока и кнопка
// питания: у всех одна механика нажатия, отличаются размер, тон и значок.

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27SpringSpec;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Подъём стекла под пальцем: `--g-scale: 1.06` (glass.css:270).
const double kIos27PressScale = 1.06;

/// Тон подписи на стекле: какой токен доски даёт цвет значку.
enum Ios27GlassTone {
  /// `--glass-label`: обычное стекло (glass.css, при Increase Contrast — чёрный/белый).
  normal,

  /// `--glass-label-2`: занятая кнопка, `.is-busy` (app.css:94).
  secondary,

  /// `--label-3`: погасшая или отключённая кнопка (`.glass:disabled`, glass.css:262;
  /// `glass--inactive`).
  muted,

  /// Подпись на цветном стекле: `--on-accent` при Reduce Transparency (glass.css:298), иначе
  /// белая (светлое стекло под тоном).
  onTint,
}

/// Цвет значка/подписи на стекле для [tone].
///
/// Читает палитру из [Ios27Colors]; Reduce Transparency берёт из [Ios27A11y]. Зови из
/// `build` под [Ios27A11yBuilder], иначе смена настройки не перерисует значок.
Color ios27GlassLabelColor(BuildContext context, Ios27GlassTone tone) {
  final colors = Ios27Colors.of(context);
  final palette = colors.palette;
  switch (tone) {
    case Ios27GlassTone.normal:
      if (colors.highContrast) {
        // glass.css:283-288: при Increase Contrast подпись полностью чёрная/белая.
        return colors.dark ? Colors.white : Colors.black;
      }
      return palette.glassLabel;
    case Ios27GlassTone.secondary:
      return palette.glassLabel2;
    case Ios27GlassTone.muted:
      return palette.label3;
    case Ios27GlassTone.onTint:
      return Ios27A11y.reduceTransparency ? colors.onAccent : Colors.white;
  }
}

/// Круглая стеклянная кнопка с реакцией нажатия доски: подъём 6 % пружиной и свечение от точки
/// касания.
///
/// Размер задаёт [diameter]; позицию задаёт родитель (виджет не позиционирует себя сам).
/// Содержимое — либо [child], либо значок через [Ios27CircleButton.icon].
///
/// Реакция нажатия рисуется во Flutter, потому что нативный вид стекла проницаем для касаний
/// (`hitTestBehavior: transparent`, glass-map.md, раздел 7). Только при [interactive] и
/// заданном [onPressed]: у `glass--inactive` и отключённой кнопки её нет, как на доске.
/// «Уменьшить движение»: подъёма нет, свечение остаётся (glass.css:302-304).
class Ios27CircleButton extends StatefulWidget {
  const Ios27CircleButton({
    super.key,
    required Widget this.child,
    this.diameter = 44,
    this.onPressed,
    this.variant = Ios27GlassVariant.small,
    this.tint,
    this.interactive = true,
    this.nested = false,
    this.semanticLabel,
    this.semanticIdentifier,
    this.toggled,
    this.away = false,
  })  : icon = null,
        iconSpec = null,
        iconTone = Ios27GlassTone.normal;

  /// Кнопка со значком [icon] размера и штриха [iconSpec] (по умолчанию 22/2, `.circle-btn`).
  const Ios27CircleButton.icon({
    super.key,
    required Ios27IconName this.icon,
    this.iconSpec = Ios27IconSpecs.standard,
    this.iconTone = Ios27GlassTone.normal,
    this.diameter = 44,
    this.onPressed,
    this.variant = Ios27GlassVariant.small,
    this.tint,
    this.interactive = true,
    this.nested = false,
    this.semanticLabel,
    this.semanticIdentifier,
    this.toggled,
    this.away = false,
  }) : child = null;

  final Widget? child;
  final Ios27IconName? icon;
  final Ios27IconSpec? iconSpec;

  /// Тон значка (см. [Ios27GlassTone]); для [child] не используется.
  final Ios27GlassTone iconTone;

  /// Сторона квадрата и диаметр круга, логические пиксели.
  final double diameter;

  /// `null` — кнопка отключена: не нажимается и не отвечает на касание.
  final VoidCallback? onPressed;

  /// Класс стекла: `small` — обычная кнопка, `inactive` — погасшая (`glass--inactive`).
  final Ios27GlassVariant variant;

  /// Непрозрачный акцент (`glass--tint`) или `null`.
  final Color? tint;

  /// `glass--interactive`: нужна ли реакция нажатия.
  final bool interactive;

  /// Стекло внутри стекла (кнопка листа, `sheet__btn`).
  final bool nested;

  /// Подпись для VoiceOver (`aria-label` доски); тексты приходят от вызывающего.
  final String? semanticLabel;

  /// Стабильный идентификатор для автотестов (`dw_connect`, `dw_exit`).
  final String? semanticIdentifier;

  /// Состояние переключателя для VoiceOver (кнопка питания: включено ли соединение).
  final bool? toggled;

  /// Кнопка ушла под лист: стекло и значок гаснут (см. [Ios27Glass.away]). Нажатия блокирует
  /// родитель, сама кнопка их не гасит.
  final bool away;

  @override
  State<Ios27CircleButton> createState() => _Ios27CircleButtonState();
}

class _Ios27CircleButtonState extends State<Ios27CircleButton>
    with TickerProviderStateMixin {
  // Масштаб живёт в неограниченном контроллере: пружина с отскоком выходит за 1.0 и ниже.
  late final AnimationController _scale;

  // Свечение: нарастает 120 мс, гаснет 240 мс (glass.css:272, :77), кривая ease-out.
  late final AnimationController _glow;
  late final CurvedAnimation _glowCurve;

  // Точка касания в долях квадрата кнопки (`--g-x`, `--g-y`); без касания — центр.
  Offset _touch = const Offset(0.5, 0.5);
  bool _reduceMotion = false;

  bool get _feedback => widget.interactive && widget.onPressed != null;

  // Контроллеры создаются сразу, а не лениво: у отключённой кнопки их никто не трогает, и
  // ленивое создание в dispose() упало бы на уже неактивном дереве.
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
  void didUpdateWidget(Ios27CircleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Кнопку отключили посреди нажатия: вернуть в покой, иначе она застрянет приподнятой.
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
    final size = widget.diameter;
    _touch = Offset(
      (details.localPosition.dx / size).clamp(0.0, 1.0),
      (details.localPosition.dy / size).clamp(0.0, 1.0),
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

  Widget _content(BuildContext context) {
    final child = widget.child;
    if (child != null) {
      return Center(child: child);
    }
    return Center(
      child: Ios27Icon.spec(
        widget.icon!,
        widget.iconSpec!,
        color: ios27GlassLabelColor(context, widget.iconTone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.diameter;
    return Ios27A11yBuilder(
      builder: (context, _) {
        final glass = Ios27Glass(
          variant: widget.variant,
          tint: widget.tint,
          interactive: widget.interactive,
          nested: widget.nested,
          away: widget.away,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_feedback)
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GlowPainter(_glowCurve, () => _touch),
                      ),
                    ),
                  ),
                _content(context),
              ],
            ),
          ),
        );

        final pressable = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onPressed == null ? null : _press,
          onTapUp: widget.onPressed == null ? null : (_) => _release(),
          onTapCancel: widget.onPressed == null ? null : _release,
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: glass,
          ),
        );

        return Semantics(
          container: true,
          identifier: widget.semanticIdentifier,
          button: true,
          enabled: widget.onPressed != null,
          toggled: widget.toggled,
          label: widget.semanticLabel,
          onTap: widget.onPressed,
          child: ExcludeSemantics(child: pressable),
        );
      },
    );
  }
}

/// Свечение изнутри от точки касания: `.glass__hl` (glass.css:119-120).
///
/// Радиальный градиент `120% 120%` с белым 22 % в центре до прозрачного на 70 %,
/// режим `plus-lighter` (= [BlendMode.plus]). Клипует его форма стекла в [Ios27Glass].
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
    // Эллипс 120 % × 120 % коробки, прозрачность достигается на 70 % радиуса.
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
