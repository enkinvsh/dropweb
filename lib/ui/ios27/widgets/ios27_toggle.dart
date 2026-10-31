// Переключатель iOS 27: трек 64×28, ручка 38×24, под пальцем ручка раздувается линзой (доска `.switch`, app.css:251-269).

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27SpringSpec;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Ширина трека (`.switch{width:64px}`).
const double kIos27ToggleWidth = 64;

/// Высота трека (`height:28px`).
const double kIos27ToggleHeight = 28;

/// Размер ручки в покое (`::before{width:38px;height:24px}`) и её отступ от края трека (2).
const double kIos27ToggleKnobWidth = 38;
const double kIos27ToggleKnobHeight = 24;
const double kIos27ToggleInset = 2;

/// Сдвиг ручки во включённом положении (`translate:22px`).
const double kIos27ToggleTravel = 22;

/// Переключатель с физикой доски.
///
/// * Трек `--fill-1`, во включённом состоянии `--accent`; цвет меняется за 250 мс ease-out.
/// * Ручка едет пружиной `snappy`, под пальцем растёт ×1,5 × 1,55 пружиной `interactive` и
///   возвращается пружиной `bouncy` (app.css:255-266).
/// * Под пальцем ручка прозрачная линза с кромкой (`#FFFFFF33` светлая / `#FFFFFF1A` тёмная);
///   размытие линзы (backdrop-filter доски) не повторяется: сырой `BackdropFilter` запрещён.
///   При Reduce Transparency ручка под пальцем остаётся белой (app.css:661).
/// * «Уменьшить движение»: ручка прыгает без пружины, линза не раздувается (app.css:612).
/// * [onChanged] `null` — переключатель отключён (половинная яркость).
/// * Ширина и высота фиксированы (64×28), позицию задаёт родитель. Размер системного шрифта на него не влияет.
///
/// Для VoiceOver это одна кнопка-переключатель: `toggled`, [semanticLabel], [semanticIdentifier].
class Ios27Toggle extends StatefulWidget {
  const Ios27Toggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.semanticIdentifier,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final String? semanticIdentifier;

  @override
  State<Ios27Toggle> createState() => _Ios27ToggleState();
}

class _Ios27ToggleState extends State<Ios27Toggle>
    with TickerProviderStateMixin {
  // Положение ручки в px `0..22`; пружина с отскоком выходит за границы, поэтому без пределов.
  late final AnimationController _x;

  // Раздутие ручки под пальцем `0..1` (и дальше при отскоке).
  late final AnimationController _press;

  bool _reduceMotion = false;

  // Палец сейчас на переключателе. По значению `_press` судить нельзя: быстрый тап отпускает
  // раньше, чем пружина успела сдвинуться с нуля, и возврат раздутой ручки пропал бы.
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _x = AnimationController.unbounded(
      vsync: this,
      value: widget.value ? kIos27ToggleTravel : 0,
    );
    _press = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Ios27Toggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final to = widget.value ? kIos27ToggleTravel : 0.0;
      if (_reduceMotion) {
        _x
          ..stop()
          ..value = to;
      } else {
        _drive(_x, Ios27Motion.springSnappy, to);
      }
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _press.dispose();
    super.dispose();
  }

  void _drive(AnimationController c, Ios27SpringSpec spec, double to) {
    c.animateWith(SpringSimulation(spec.description, c.value, to, c.velocity));
  }

  bool get _enabled => widget.onChanged != null;

  void _down(TapDownDetails _) {
    if (!_enabled || _reduceMotion) {
      return;
    }
    _pressed = true;
    _drive(_press, Ios27Motion.springInteractive, 1);
  }

  void _up() {
    if (_pressed) {
      _pressed = false;
      _drive(_press, Ios27Motion.springBouncy, 0);
    }
  }

  void _tap() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;
    final dark = colors.dark;
    return Ios27A11yBuilder(
      builder: (context, a11y) {
        final track = TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: widget.value ? colors.accentColor : palette.fill1,
          ),
          duration: const Duration(milliseconds: 250),
          curve: Ios27Motion.easeOut,
          builder: (context, color, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(kIos27ToggleHeight / 2),
            ),
            child: child,
          ),
          child: SizedBox(
            width: kIos27ToggleWidth,
            height: kIos27ToggleHeight,
            child: AnimatedBuilder(
              animation: Listenable.merge([_x, _press]),
              builder: (context, _) {
                final p = _press.value;
                final lens = p.clamp(0.0, 1.0);
                final opaque = a11y.reduceTransparency;
                // Заливка ручки: белая в покое; линза под пальцем прозрачная (светлая
                // #FFFFFF33, тёмная #FFFFFF1A), при Reduce Transparency остаётся белой.
                final fill = opaque
                    ? Colors.white
                    : Color.lerp(
                        Colors.white,
                        dark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x33FFFFFF),
                        lens,
                      )!;
                final rest = BoxShadow(
                  color: const Color(0x26000000).withValues(
                    alpha: 0.15 * (1 - lens),
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                );
                final rim = <BoxShadow>[
                  // Кромка линзы: контур `0 0 0 1px` и тень `0 4px 12px` под пальцем.
                  if (lens > 0)
                    BoxShadow(
                      color: (dark
                              ? const Color(0xFF8C8C8C)
                              : const Color(0xFFD9D9D9))
                          .withValues(alpha: lens),
                      spreadRadius: 1,
                    ),
                  if (lens > 0)
                    BoxShadow(
                      color: const Color(0x1F000000).withValues(
                        alpha: 0.12 * lens,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: kIos27ToggleInset + _x.value,
                      top: kIos27ToggleInset,
                      child: Transform.scale(
                        scaleX: 1 + 0.5 * p,
                        scaleY: 1 + 0.55 * p,
                        child: DecoratedBox(
                          key: const ValueKey<String>('toggle.knob'),
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [rest, ...rim],
                          ),
                          child: const SizedBox(
                            width: kIos27ToggleKnobWidth,
                            height: kIos27ToggleKnobHeight,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        return Semantics(
          container: true,
          identifier: widget.semanticIdentifier,
          label: widget.semanticLabel,
          toggled: widget.value,
          enabled: _enabled,
          onTap: _enabled ? _tap : null,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _enabled ? _down : null,
                onTapUp: _enabled ? (_) => _up() : null,
                onTapCancel: _enabled ? _up : null,
                onTap: _enabled ? _tap : null,
                child: track,
              ),
            ),
          ),
        );
      },
    );
  }
}
