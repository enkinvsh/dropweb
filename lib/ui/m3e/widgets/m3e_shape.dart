import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/tokens.g.dart';

/// Контур формы: список кубиков Безье, каждый — 8 чисел `x0,y0,x1,y1,x2,y2,x3,y3`
/// в единичном квадрате (Y вниз), как `cubics` в canon/dropweb/android.js.
typedef M3eCubics = List<List<double>>;

/// Кубики [polygon] без изменений: `MaterialShapes` уже нормализованы библиотекой.
M3eCubics m3eRawCubics(RoundedPolygon polygon) => [
      for (final c in polygon.cubics) List<double>.of(c.points),
    ];

/// Границы по точкам кривой (16 отсчётов на кубик), как `boundsOf` в shapes.js доски.
///
/// Опорные точки кубика дают завышенный прямоугольник у скруглённых форм, а доска
/// центрирует по реальной кривой, поэтому считаем так же.
Rect m3eCubicsBounds(M3eCubics cubics) {
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final c in cubics) {
    for (var i = 0; i <= 16; i++) {
      final u = i / 16, v = 1 - u;
      final x = v * v * v * c[0] +
          3 * v * v * u * c[2] +
          3 * v * u * u * c[4] +
          u * u * u * c[6];
      final y = v * v * v * c[1] +
          3 * v * v * u * c[3] +
          3 * v * u * u * c[5] +
          u * u * u * c[7];
      l = math.min(l, x);
      r = math.max(r, x);
      t = math.min(t, y);
      b = math.max(b, y);
    }
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// Центрирует контур по реальным границам в (0.5, 0.5), затем масштабирует и
/// поворачивает вокруг центра: `place()` из android.js (200–213).
///
/// [degrees] — по часовой стрелке (ось Y вниз, как в canvas и CSS `rotate`).
M3eCubics m3ePlace(M3eCubics cubics, {double scale = 1, double degrees = 0}) {
  final b = m3eCubicsBounds(cubics);
  final ox = (b.left + b.right) / 2, oy = (b.top + b.bottom) / 2;
  final a = degrees * math.pi / 180;
  final cs = math.cos(a) * scale, sn = math.sin(a) * scale;
  return [
    for (final c in cubics)
      [
        for (var i = 0; i < 8; i += 2) ...[
          0.5 + (c[i] - ox) * cs - (c[i + 1] - oy) * sn,
          0.5 + (c[i] - ox) * sn + (c[i + 1] - oy) * cs,
        ],
      ],
  ];
}

final Map<RoundedPolygon, M3eCubics> _placed = Map.identity();

/// Контур [polygon], вписанный в единичный квадрат (`staticShape` доски без
/// передискретизации). Кэшируется: `MaterialShapes.*` — статические объекты.
M3eCubics m3ePlacedShape(RoundedPolygon polygon) =>
    _placed.putIfAbsent(polygon, () => m3ePlace(m3eRawCubics(polygon)));

/// Единичный контур [cubics] как [Path] (координаты 0..1, без масштаба).
Path m3eUnitPath(M3eCubics cubics) {
  final path = Path()..moveTo(cubics.first[0], cubics.first[1]);
  for (final c in cubics) {
    path.cubicTo(c[2], c[3], c[4], c[5], c[6], c[7]);
  }
  return path..close();
}

/// Делит кубик в точке [t] (де Кастельжо).
List<M3eCubic> _split(List<double> c, double t) {
  final ax = c[0] + (c[2] - c[0]) * t, ay = c[1] + (c[3] - c[1]) * t;
  final bx = c[2] + (c[4] - c[2]) * t, by = c[3] + (c[5] - c[3]) * t;
  final cx = c[4] + (c[6] - c[4]) * t, cy = c[5] + (c[7] - c[5]) * t;
  final dx = ax + (bx - ax) * t, dy = ay + (by - ay) * t;
  final ex = bx + (cx - bx) * t, ey = by + (cy - by) * t;
  final fx = dx + (ex - dx) * t, fy = dy + (ey - dy) * t;
  return [
    [c[0], c[1], ax, ay, dx, dy, fx, fy],
    [fx, fy, ex, ey, cx, cy, c[6], c[7]],
  ];
}

typedef M3eCubic = List<double>;

/// Доводит число кубиков до [n], деля каждый на равные части по индексу (не по длине):
/// иначе у кадров морфа скачет топология и контур дрожит (android.js 168–197).
M3eCubics m3eResample(M3eCubics cubics, int n) {
  final m = cubics.length;
  if (m >= n) return cubics;
  final out = <List<double>>[];
  for (var i = 0; i < m; i++) {
    var k = ((i + 1) * n) ~/ m - (i * n) ~/ m;
    var c = cubics[i];
    for (; k > 1; k--) {
      final parts = _split(c, 1 / k);
      out.add(parts[0]);
      c = parts[1];
    }
    out.add(c);
  }
  return out;
}

/// Сдвиг индексов цели [to], при котором её опорные точки ближе всего к [from]:
/// без него контур при морфе перекручивается (android.js 215–229).
int m3eAlignShift(M3eCubics from, M3eCubics to) {
  final n = to.length;
  var best = 0;
  var bestDist = double.infinity;
  for (var k = 0; k < n; k++) {
    var s = 0.0;
    for (var i = 0; i < n; i += 3) {
      final a = from[i], b = to[(i + k) % n];
      s += math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2);
    }
    if (s < bestDist) {
      bestDist = s;
      best = k;
    }
  }
  return best;
}

M3eCubics m3eShift(M3eCubics cubics, int k) =>
    k == 0 ? cubics : [...cubics.sublist(k), ...cubics.sublist(0, k)];

/// Линейная интерполяция контуров одинакового размера; [p] может выходить за 0..1
/// (перелёт пружины).
M3eCubics m3eLerp(M3eCubics a, M3eCubics b, double p) => [
      for (var i = 0; i < a.length; i++)
        [
          for (var j = 0; j < 8; j++) a[i][j] + (b[i][j] - a[i][j]) * p,
        ],
    ];

/// Значение пружины Compose (масса 1) из 0 в 1 через [t] секунд: android.js 240–244.
/// Для демпфирования ≥ 1 берётся критический случай.
double m3eSpringValue(M3eSpringSpec spec, double t) {
  final w0 = math.sqrt(spec.stiffness);
  final z = spec.damping;
  if (z >= 1) return 1 - (1 + w0 * t) * math.exp(-w0 * t);
  final wd = w0 * math.sqrt(1 - z * z);
  return 1 -
      math.exp(-z * w0 * t) *
          (math.cos(wd * t) + (z * w0 / wd) * math.sin(wd * t));
}

/// Кривая по пружине: время 0..1 растягивается на [seconds]. Значения выходят за 1
/// у недодемпфированных пружин, на концах ровно 0 и 1 (это гарантирует `Curve`).
class M3eSpringCurve extends Curve {
  const M3eSpringCurve(this.spec, this.seconds);

  final M3eSpringSpec spec;
  final double seconds;

  @override
  double transformInternal(double t) => m3eSpringValue(spec, t * seconds);
}

/// Статичная форма `MaterialShapes` цветом [color] в квадрате [size].
///
/// Контур вписан как `place()` доски (центр по границам кривой, масштаб 1), [rotation]
/// в градусах по часовой. Не анимируется: ни одного тикера.
class M3eShapeView extends StatelessWidget {
  const M3eShapeView(
    this.shape, {
    super.key,
    required this.color,
    required this.size,
    this.rotation = 0,
  });

  final RoundedPolygon shape;
  final Color color;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final cubics = rotation == 0
        ? m3ePlacedShape(shape)
        : m3ePlace(m3eRawCubics(shape), degrees: rotation);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: M3ePathPainter(cubics, color)),
      ),
    );
  }
}

/// Заливает единичный контур цветом на весь размер холста.
class M3ePathPainter extends CustomPainter {
  M3ePathPainter(this.cubics, this.color, {super.repaint});

  final M3eCubics cubics;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width, size.height)
      ..drawPath(m3eUnitPath(cubics), Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(M3ePathPainter old) =>
      !identical(old.cubics, cubics) || old.color != color;
}
