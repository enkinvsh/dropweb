import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../symbols.g.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_symbol.dart';

/// Кнопка настроек вверху главной и пустого экрана: отступ от строки состояния и размер.
/// Общие для экранов и тоста: плашка уведомления встаёт на одну линию с этой кнопкой,
/// поэтому её положение считается от этих же чисел, а не повторяет их.
const double kM3eNavButtonTop = 4;
const double kM3eNavButtonSize = 44;

/// Круглая тональная кнопка-значок 44 или 48: настройки, подписка, маршрут.
///
/// Повтор `.md-icon-button--tonal` главной доски (`.dr-nav-btn`, `.dr-dock` в android.css):
/// заливка secondary-container (`home.card`), содержимое `home.ink`, значок 24, тень
/// level1. Нажатие морфит круг в скруглённый квадрат с углом 8 пружиной fast spatial,
/// как `:active` в `.md-icon-button`.
///
/// Ключ (`m3e.navBtn`, `m3e.subsBtn`, `m3e.routeBtn`) задаёт вызывающий через `key:`.
class M3eTonalIconButton extends StatefulWidget {
  const M3eTonalIconButton({
    super.key,
    required this.size,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.muted = false,
    this.semanticIdentifier,
  }) : assert(size == 44 || size == 48, 'доска знает только размеры 44 и 48');

  /// 44 для настроек, 48 для боковых кнопок нижнего ряда.
  final double size;

  /// Значок или знак подписки. Цвет и размер 24 берутся из `IconTheme`, который
  /// кнопка ставит сама.
  final Widget icon;

  /// Подпись для диктора: у кнопки нет текста.
  final String semanticLabel;

  /// `null` отключает кнопку. [muted] её не отключает.
  final VoidCallback? onPressed;

  /// Вид неактивного, но нажимаемого: маршрут при закрытой подписке. Выбрать страну
  /// заранее можно, поэтому кнопка только тускнеет (`.dr-dock.is-muted`).
  final bool muted;

  /// Идентификатор для автотестов через adb (`resource-id` в uiautomator). Ставится на
  /// сам узел кнопки: снаружи его не передать, обёртка `Semantics` вливалась бы в
  /// объемлющий узел-контейнер и id оказывался бы не на кнопке.
  final String? semanticIdentifier;

  @override
  State<M3eTonalIconButton> createState() => _M3eTonalIconButtonState();
}

class _M3eTonalIconButtonState extends State<M3eTonalIconButton>
    with SingleTickerProviderStateMixin {
  /// Радиус нажатой кнопки `--_pressed` для размера S.
  static const double _pressedRadius = 8;

  /// Z-тень Flutter темнее CSS-тени level1 доски (0,07 при блюре 0,5 px), у которой
  /// на кнопке виден лишь волосок. Множитель подобран по листу сравнения с эталоном.
  static const double _shadowAlpha = 0.2;

  /// 0 — круг, 1 — нажата. Пружина с перелётом выходит за 0..1, поэтому без границ.
  late final AnimationController _morph = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    final target = pressed ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _morph.value = target;
      return;
    }
    _morph.animateWith(
      SpringSimulation(
        M3eSpring.fastSpatial.description,
        _morph.value,
        target,
        _morph.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final enabled = widget.onPressed != null;

    final Color container;
    final Color content;
    if (!enabled) {
      container = scheme.onSurface.withValues(alpha: 0.12);
      content = scheme.onSurface.withValues(alpha: M3eState.disabledContent);
    } else if (widget.muted) {
      container = scheme.onSurface.withValues(alpha: 0.08);
      content = scheme.onSurface.withValues(alpha: 0.5);
    } else {
      container = colors.home.card;
      content = colors.home.ink;
    }
    // Под прозрачной заливкой тень была бы видна насквозь, а в CSS box-shadow внутрь
    // рамки не рисуется. Кнопка без заливки поэтому лежит без тени.
    final elevation = enabled && !widget.muted ? M3eElevation.level1 : 0.0;
    final half = widget.size / 2;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      identifier: widget.semanticIdentifier,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _morph,
          builder: (context, child) {
            final radius = (half + (_pressedRadius - half) * _morph.value)
                .clamp(0.0, half);
            final shape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            );
            return Material(
              color: container,
              shadowColor: scheme.shadow.withValues(alpha: _shadowAlpha),
              elevation: elevation,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: widget.onPressed,
                onHighlightChanged: _setPressed,
                // Волна доски: круг из точки касания, без блёсток InkSparkle.
                splashFactory: InkRipple.splashFactory,
                splashColor: content.withValues(alpha: M3eState.pressed),
                highlightColor: Colors.transparent,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return content.withValues(alpha: M3eState.pressed);
                  }
                  if (states.contains(WidgetState.focused)) {
                    return content.withValues(alpha: M3eState.focus);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return content.withValues(alpha: M3eState.hover);
                  }
                  return null;
                }),
                child: child,
              ),
            );
          },
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: content, size: 24),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// Знак подписки на левой кнопке: символ `stacks`, потому что подписок бывает несколько.
///
/// Логотип провайдера на кнопку не ставится (решение владельца 2026-10-29): знак один
/// для всех провайдеров. Цвет берётся от `IconTheme`, который ставит кнопка.
class M3eSubMark extends StatelessWidget {
  const M3eSubMark({super.key});

  @override
  Widget build(BuildContext context) => const M3eSymbolIcon(M3eSymbol.stacks);
}
