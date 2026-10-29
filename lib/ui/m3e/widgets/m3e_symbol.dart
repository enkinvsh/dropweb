import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../symbols.g.dart';

/// Значок Material Symbols Rounded из сгенерированной таблицы контуров.
///
/// Рисуется как SVG с перекраской через [BlendMode.srcIn]: так же, как `ic()` в
/// canon/dropweb/android.js. Шрифт символов весит 5,2 МБ, а приложению нужны 57 глифов.
class M3eSymbolIcon extends StatelessWidget {
  const M3eSymbolIcon(
    this.symbol, {
    super.key,
    this.fill = false,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final M3eSymbol symbol;

  /// Залитый вариант (FILL 1) вместо контурного.
  final bool fill;
  final double size;

  /// Без явного цвета берётся цвет ближайшей `IconTheme`.
  final Color? color;

  /// Без подписи значок скрыт от доступности: он декоративный.
  final String? semanticLabel;

  /// SVG собираем один раз на пару символ/заливка: контуры по 1–2 КБ, а сборка строки
  /// на каждом build заставила бы flutter_svg разбирать её заново.
  static final Map<(M3eSymbol, bool), String> _svgCache = {};

  static String _svg(M3eSymbol symbol, bool fill) =>
      _svgCache.putIfAbsent((symbol, fill), () {
        final paths = kM3eSymbolPaths[symbol]!;
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960">'
            '<path d="${fill ? paths.f : paths.o}"/></svg>';
      });

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final picture = SvgPicture.string(
      _svg(symbol, fill),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    if (semanticLabel == null) {
      return ExcludeSemantics(child: picture);
    }
    return Semantics(label: semanticLabel, image: true, child: picture);
  }
}
