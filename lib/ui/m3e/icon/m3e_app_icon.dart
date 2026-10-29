import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../color/color.dart';
import 'app_icon.g.dart';

/// Значок dropweb в круге для экрана «О программе»: знак цветом [M3eIconColors.fg] на плашке
/// [M3eIconColors.bg]. Цвета берутся из `scheme(...).icon`, поэтому значок следует за
/// провайдером так же, как тематическая иконка лаунчера.
///
/// Рисуется из SVG-шаблона (`app_icon.g.dart`), а не из PNG: масштабируется без потерь и
/// не зависит от платформы.
class M3eAppIcon extends StatelessWidget {
  const M3eAppIcon({super.key, required this.colors, this.size = 96});

  final M3eIconColors colors;
  final double size;

  static String _hex(Color c) => hexFromArgb(c.toARGB32());

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SvgPicture.string(
          m3eAppIconSvg(fg: _hex(colors.fg), bg: _hex(colors.bg)),
          width: size,
          height: size,
          excludeFromSemantics: true,
        ),
      );
}
