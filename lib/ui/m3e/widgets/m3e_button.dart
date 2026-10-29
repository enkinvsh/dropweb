import 'package:flutter/material.dart';

import '../symbols.g.dart';
import '../theme/m3e_flex.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_symbol.dart';

/// Вариант кнопки M3E: цвета контейнера и содержимого по токенам канона
/// (FilledButtonTokens, FilledTonalButtonTokens, TextButtonTokens).
enum M3eButtonVariant { filled, tonal, text }

/// Размеры XS/S/M из ButtonXSmallTokens/ButtonSmallTokens/ButtonMediumTokens.
enum M3eButtonSize {
  xs(height: 32, padding: 12, gap: 4, icon: 20, pressedRadius: 8),
  s(height: 40, padding: 16, gap: 8, icon: 20, pressedRadius: 8),
  m(height: 56, padding: 24, gap: 8, icon: 24, pressedRadius: 12);

  const M3eButtonSize({
    required this.height,
    required this.padding,
    required this.gap,
    required this.icon,
    required this.pressedRadius,
  });

  final double height;

  /// Боковой отступ: у XS на доске 12, а не 16 из токена (в replica/buttons.css
  /// `--_pad`), поэтому берём значение доски.
  final double padding;
  final double gap;
  final double icon;

  /// Форма нажатой кнопки (ButtonDefaults.pressedShape), для round и square одна.
  final double pressedRadius;
}

/// Кнопка M3E: капсула, при нажатии форма сжимается до [M3eButtonSize.pressedRadius].
///
/// Минимальная ширина 58 как у ButtonDefaults.MinWidth. [width] фиксирует ширину
/// (пустой экран растягивает до 379), [minWidth] задаёт только нижнюю границу:
/// карточка подписки держит «Обновить» не уже 104, а при крупном шрифте кнопка шире.
///
/// Высота не зажата сверху: масштаб текста приложения доходит до 1,4 (решение владельца
/// 2026-10-29), и подпись в фиксированных 32 dp обрезалась бы.
class M3eButton extends StatefulWidget {
  const M3eButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = M3eButtonVariant.tonal,
    this.size = M3eButtonSize.s,
    this.icon,
    this.width,
    this.minWidth,
    this.flexFont = false,
  });

  final String label;

  /// `null` отключает кнопку: контейнер onSurface 10 %, содержимое onSurface 38 %.
  final VoidCallback? onPressed;
  final M3eButtonVariant variant;
  final M3eButtonSize size;
  final M3eSymbol? icon;
  final double? width;
  final double? minWidth;

  /// Подпись шрифтом Roboto Flex: на главной доски кнопка наследует шрифт карточки
  /// (`.dr-card__fix { font-family: inherit }`), на остальных экранах это Roboto.
  final bool flexFont;

  @override
  State<M3eButton> createState() => _M3eButtonState();
}

class _M3eButtonState extends State<M3eButton> {
  bool _pressed = false;

  TextStyle _labelStyle(Color color) {
    final medium = widget.size == M3eButtonSize.m;
    final role = medium ? M3eType.titleMedium : M3eType.labelLarge;
    if (!widget.flexFont) return m3eTextStyle(role, color: color);
    // Ось opsz равна кеглю, как в M3eFlex: во Flutter её не подбирает сам шрифт.
    return M3eFlex.statKey(color: color).copyWith(
      fontSize: role.size,
      height: role.height,
      letterSpacing: role.tracking,
      fontVariations: [
        const FontVariation('wght', 500),
        const FontVariation('wdth', 100),
        FontVariation('opsz', role.size),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final enabled = widget.onPressed != null;
    final Color container;
    final Color content;
    switch (widget.variant) {
      case M3eButtonVariant.filled:
        container = scheme.role('primary');
        content = scheme.role('onPrimary');
      case M3eButtonVariant.tonal:
        container = scheme.role('secondaryContainer');
        content = scheme.role('onSecondaryContainer');
      case M3eButtonVariant.text:
        container = Colors.transparent;
        content = scheme.role('primary');
    }
    final onSurface = scheme.role('onSurface');
    final fill = enabled
        ? container
        : widget.variant == M3eButtonVariant.text
            ? Colors.transparent
            : onSurface.withValues(alpha: 0.10);
    final ink = enabled ? content : onSurface.withValues(alpha: 0.38);
    final size = widget.size;
    final radius = _pressed ? size.pressedRadius : size.height / 2;

    final children = <Widget>[
      if (widget.icon != null) ...[
        M3eSymbolIcon(widget.icon!, size: size.icon, color: ink),
        SizedBox(width: size.gap),
      ],
      Flexible(
        // Калибровка подписи как у `.md-button__label` доски (translate -0.25 / dy):
        // без неё текст на полпикселя ниже эталона.
        child: Transform.translate(
          offset: Offset(-0.25, size == M3eButtonSize.m ? 0.5 : -0.5),
          child: Text(
            widget.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(ink),
          ),
        ),
      ),
    ];

    return Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.width ?? widget.minWidth ?? 58,
          maxWidth: widget.width ?? double.infinity,
          minHeight: size.height,
        ),
        // Форму сжимает пружина fast spatial доски (348 мс); здесь короткая
        // кривая без перелёта: перелёт на радиусе 8 незаметен, а тест проще.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: radius),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          builder: (context, r, child) => Material(
            color: fill,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.focused)) {
                  return ink.withValues(alpha: 0.10);
                }
                if (states.contains(WidgetState.hovered)) {
                  return ink.withValues(alpha: 0.08);
                }
                return null;
              }),
              child: child,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.padding,
              // Запас по вертикали нужен только при крупном шрифте: при 1,0 высоту
              // держит minHeight, и отступ ничего не сдвигает.
              vertical: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
