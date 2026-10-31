// Зум-переход слоя из кнопки (доска motion.js: zoomIn 111-133, zoomOut 139-161; app.js:951-963, 1060-1122).
//
// Лист или алерт, открытый стеклянной кнопкой, вырастает из неё и втягивается обратно. Пока слой
// открыт, сама кнопка на своём месте не рисуется: она и есть слой (app.css:303-312 `.is-src`).

import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Motion;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Кнопки главной, из которых растут слои.
enum Ios27ZoomId {
  /// Кнопка «Подписка» (стопка) слева в доке.
  subscriptions,

  /// Кнопка «Маршрут» (глобус) справа в доке.
  route,

  /// Кнопка питания: из неё растёт окно «Перед подключением».
  power,
}

/// Откуда вырастает слой: прямоугольник кнопки в глобальных координатах, её радиус и значок.
///
/// Значок переливается в растущее стекло (размывается и гаснет), поэтому слою нужна его копия:
/// кнопка на время зума скрыта. [setSourceOpacity] слой ведёт сам: 0 на открытии, возврат в
/// последней четверти втягивания.
@immutable
class Ios27ZoomOrigin {
  const Ios27ZoomOrigin({
    required this.rect,
    required this.radius,
    this.icon,
    this.setSourceOpacity,
  });

  final Rect rect;
  final double radius;
  final Widget? icon;

  /// Задаёт прозрачность кнопки-источника; `null` — кнопку не прячем.
  ///
  /// Функция, а не уведомитель: кнопка может быть снята с экрана раньше слоя, и тогда вызов
  /// молча ничего не делает.
  final ValueChanged<double>? setSourceOpacity;
}

/// Длительность раскрытия: пружина `snappy` (motion.js:117).
Duration get ios27ZoomOpenDuration => Ios27Motion.springSnappy.settle;

/// Длительность втягивания: 0.75 от `smooth` (motion.js:148 `duration * 0.75`).
Duration get ios27ZoomCloseDuration => Duration(
      microseconds:
          (Ios27Motion.springSmooth.settle.inMicroseconds * 0.75).round(),
    );

/// Значения зума на один кадр. Каждое поле выводится из доли пружины, как keyframes доски.
@immutable
class Ios27ZoomValues {
  const Ios27ZoomValues({
    required this.distance,
    required this.contentT,
    required this.contentOpacity,
    required this.iconOpacity,
    required this.iconScale,
    required this.iconBlur,
    required this.glassOpacity,
  });

  /// Раскрытие, `p` — доля пружины `snappy`.
  ///
  /// Содержимое проявляется с доли 0.15 до 0.55, значок гаснет к доле 0.35 (motion.js:123-125).
  factory Ios27ZoomValues.opening(double p) {
    final c = p.clamp(0.0, 1.0);
    final icon = (c / 0.35).clamp(0.0, 1.0);
    return Ios27ZoomValues(
      distance: p,
      contentT: c,
      contentOpacity: ((c - 0.15) / 0.40).clamp(0.0, 1.0),
      iconOpacity: 1 - icon,
      iconScale: lerpDouble(1, 1.6, icon)!,
      iconBlur: 6 * icon,
      glassOpacity: 1,
    );
  }

  /// Втягивание, `q` — доля пружины `smooth`, [startDistance] — раскрытие в момент закрытия
  /// (1 у полностью открытого слоя, меньше, если закрыли с середины открытия).
  ///
  /// Содержимое гаснет к доле 0.25, значок возвращается после 0.4, стекло гаснет с 0.75
  /// (motion.js:151-156).
  factory Ios27ZoomValues.closing(double q, {required double startDistance}) {
    final c = q.clamp(0.0, 1.0);
    return Ios27ZoomValues(
      distance: startDistance * (1 - q),
      contentT: 1 - c,
      contentOpacity: (1 - c / 0.25).clamp(0.0, 1.0),
      iconOpacity: ((c - 0.4) / 0.6).clamp(0.0, 1.0),
      iconScale: lerpDouble(1.6, 1, c)!,
      iconBlur: lerpDouble(6, 0, c)!,
      glassOpacity: c <= 0.75 ? 1.0 : (1 - (c - 0.75) / 0.25).clamp(0.0, 1.0),
    );
  }

  /// Раскрытие формы: 0 — прямоугольник кнопки, 1 — место слоя. На пружине `snappy` бывает
  /// чуть больше 1 (перелёт).
  final double distance;

  /// Масштаб содержимого между `s = min(1, ширина кнопки / ширина слоя)` и 1: 0 — `s`, 1 — полный.
  final double contentT;
  final double contentOpacity;
  final double iconOpacity;
  final double iconScale;

  /// Размытие значка, px (`blur(6px)` на доске).
  final double iconBlur;

  /// Стекло гаснет в конце втягивания (`--g-o` 1 → 0 с доли 0.75).
  final double glassOpacity;

  /// Стекло слоя пора убирать: с доли 0.75 втягивания, когда `--g-o` на доске начинает
  /// падать. Само стекло уходит своим `away` ([Ios27Glass.away]), а не долей [glassOpacity]:
  /// доля нужна только как порог.
  bool get glassGone => glassOpacity < 1;

  /// Слой стоит на своём месте и не движется: можно принимать нажатия.
  bool get settled => distance >= 0.999 && contentT >= 1 && contentOpacity >= 1;

  @override
  bool operator ==(Object other) =>
      other is Ios27ZoomValues &&
      other.distance == distance &&
      other.contentT == contentT &&
      other.contentOpacity == contentOpacity &&
      other.iconOpacity == iconOpacity &&
      other.iconScale == iconScale &&
      other.iconBlur == iconBlur &&
      other.glassOpacity == glassOpacity;

  @override
  int get hashCode => Object.hash(
        distance,
        contentT,
        contentOpacity,
        iconOpacity,
        iconScale,
        iconBlur,
        glassOpacity,
      );
}

/// Время зума одного слоя. Двигает его анимация маршрута: вперёд раскрытие, назад втягивание.
///
/// Закрытие считает долю пути заново от текущего места (`zoomOut` стартует «из того места, где
/// слой сейчас», motion.js:136), поэтому маршрут при закрытии просит [beginClose]: время
/// втягивания тогда идёт от 0, а раскрытие в этот момент запоминается.
class Ios27ZoomTimeline {
  Ios27ZoomTimeline({required this.origin, required this.animation}) {
    origin.setSourceOpacity?.call(0);
    animation.addListener(_syncSource);
  }

  final Ios27ZoomOrigin origin;
  final Animation<double> animation;

  static final Curve _open = Ios27SpringCurve(Ios27Motion.springSnappy);
  static final Curve _close = Ios27SpringCurve(Ios27Motion.springSmooth);

  bool _closing = false;
  double _startDistance = 1;

  bool get closing => _closing;

  /// Долю пути маршрута, `0..1` по времени: раскрытие вперёд, втягивание от 0.
  double get timeFraction => _closing ? 1 - animation.value : animation.value;

  Ios27ZoomValues get values {
    final t = timeFraction.clamp(0.0, 1.0);
    return _closing
        ? Ios27ZoomValues.closing(
            _close.transform(t),
            startDistance: _startDistance,
          )
        : Ios27ZoomValues.opening(_open.transform(t));
  }

  /// Маршрут начал закрываться: фиксируем раскрытие, с которого стартует втягивание.
  void beginClose() {
    if (_closing) return;
    _startDistance =
        _open.transform(animation.value.clamp(0.0, 1.0)).clamp(0.0, 1.2);
    _closing = true;
  }

  // Кнопка возвращается в последней четверти втягивания: стекло слоя гаснет с 0.75 длины, а
  // раньше значок кнопки двоился со значком слоя (app.css:306-309: задержка 0.56 smooth,
  // длина 0.19 smooth при втягивании 0.75 smooth, то есть доли 0.747..1 по времени).
  void _syncSource() {
    final set = origin.setSourceOpacity;
    if (set == null) return;
    if (!_closing) {
      set(0);
      return;
    }
    set(((timeFraction - 0.747) / 0.253).clamp(0.0, 1.0));
  }

  /// Вызывает маршрут при уничтожении: кнопка вернётся в любом случае.
  void dispose() {
    animation.removeListener(_syncSource);
    origin.setSourceOpacity?.call(1);
  }
}

/// Отдаёт слою его [Ios27ZoomTimeline]; `null` — слой открыт без источника (въезд снизу).
class Ios27ZoomScope extends InheritedWidget {
  const Ios27ZoomScope({
    super.key,
    required this.timeline,
    required super.child,
  });

  final Ios27ZoomTimeline timeline;

  static Ios27ZoomTimeline? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Ios27ZoomScope>()?.timeline;

  @override
  bool updateShouldNotify(Ios27ZoomScope oldWidget) =>
      timeline != oldWidget.timeline;
}

/// Кнопка, из которой растёт слой. Прячется, пока слой открыт.
///
/// Оборачивает кнопку на главной. Слой находит источник через [originFor] в момент открытия.
///
/// Прозрачность доходит до стёкол кнопки через [Ios27GlassFadeScope] и гасит только то, что
/// рисует Flutter (значок, свечение, подложку заглушки). Саму кнопку слоем прозрачности
/// накрывать нельзя: на iOS под ним лежит нативный вид стекла, а его полупрозрачный предок
/// рисуется неправильно. Нативный материал источника в это время уже убран `away` главной
/// (любой маршрут над ней), поэтому отдельного хода ему не нужно. Ребёнок обязан строиться на
/// [Ios27Glass]: всё остальное прозрачность источника не получит.
class Ios27ZoomSource extends StatefulWidget {
  const Ios27ZoomSource({
    super.key,
    required this.id,
    required this.child,
    this.icon,
  });

  final Ios27ZoomId id;

  /// Значок для растущего стекла; строится в контексте кнопки, чтобы тема совпала.
  final WidgetBuilder? icon;
  final Widget child;

  static final Map<Ios27ZoomId, _Ios27ZoomSourceState> _live = {};

  /// Источник [id] для слоя, открываемого сейчас. `null`, если кнопки нет на экране или над ней
  /// уже что-то лежит: тогда слой въезжает снизу, как при открытии по ссылке или из фона.
  static Ios27ZoomOrigin? originFor(Ios27ZoomId id) => _live[id]?._origin();

  @override
  State<Ios27ZoomSource> createState() => _Ios27ZoomSourceState();
}

class _Ios27ZoomSourceState extends State<Ios27ZoomSource> {
  final ValueNotifier<double> _opacity = ValueNotifier<double>(1);

  @override
  void initState() {
    super.initState();
    Ios27ZoomSource._live[widget.id] = this;
  }

  @override
  void didUpdateWidget(Ios27ZoomSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      if (Ios27ZoomSource._live[oldWidget.id] == this) {
        Ios27ZoomSource._live.remove(oldWidget.id);
      }
      Ios27ZoomSource._live[widget.id] = this;
    }
  }

  @override
  void dispose() {
    if (Ios27ZoomSource._live[widget.id] == this) {
      Ios27ZoomSource._live.remove(widget.id);
    }
    _opacity.dispose();
    super.dispose();
  }

  Ios27ZoomOrigin? _origin() {
    if (!mounted) return null;
    final route = ModalRoute.of(context);
    // Над главной уже лежит слой или страница: кнопки не видно, растить слой не из чего.
    if (route != null && !route.isCurrent) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty) return null;
    return Ios27ZoomOrigin(
      rect: rect,
      radius: math.min(rect.width, rect.height) / 2,
      icon: widget.icon?.call(context),
      setSourceOpacity: _setOpacity,
    );
  }

  // Слой может пережить кнопку (экран главной снят раньше навигатора): тогда писать некуда.
  void _setOpacity(double value) {
    if (mounted) _opacity.value = value;
  }

  @override
  Widget build(BuildContext context) =>
      Ios27GlassFadeScope(opacity: _opacity, child: widget.child);
}

/// Стекло слоя с зумом: стекло растёт из прямоугольника кнопки в место слоя, содержимое
/// проявляется внутри, значок кнопки переливается в стекло.
///
/// Содержимое всегда лежит на конечном размере и не перекомпонуется на кадрах зума (на доске
/// `pin()`, motion.js:60-77): его только масштабируют вместе с формой от левого верхнего угла и
/// обрезают по ней.
///
/// Дерево не меняется между открытием, покоем и закрытием, иначе содержимое теряло бы состояние.
class Ios27ZoomGlass extends StatelessWidget {
  const Ios27ZoomGlass({
    super.key,
    required this.timeline,
    required this.variant,
    required this.radius,
    required this.child,
    this.glassKey,
  });

  final Ios27ZoomTimeline timeline;
  final Ios27GlassVariant variant;

  /// Радиус слоя на своём месте.
  final double radius;
  final Key? glassKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: timeline.animation,
        // Содержимое листа лежит на конечном размере и на кадрах зума не меняется, меняются
        // только сдвиг, масштаб и прозрачность над ним. Граница перерисовки записывает его один
        // раз; без неё список строк и текст перерисовывались целиком на каждом кадре раскрытия
        // (замер `lag_probe_test.dart`: всплеск 200–270 `paintChild` на кадр, пока содержимое
        // проявляется). Картинка не меняется: слой лишь запоминает уже нарисованное.
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          final v = timeline.values;
          final origin = timeline.origin;
          final r = math.max(
            0.0,
            lerpDouble(origin.radius, radius, v.distance.clamp(0.0, 1.0))!,
          );
          final icon = origin.icon;
          return Ios27ZoomFrame(
            from: origin.rect,
            values: v,
            radius: r,
            // Стекло слоя гаснет в конце втягивания, но не `Opacity`: над нативным видом
            // полупрозрачного предка быть не может. Материал убирает `away` самого стекла.
            glass: Ios27Glass(
              key: glassKey,
              variant: variant,
              // В нативный вид радиус уходит сообщением `updateParams` на каждый кадр, где он
              // изменился; на iPhone каждое такое сообщение — перенастройка `UIGlassEffect`.
              // Шаг полпикселя вдвое сокращает поток и не виден: ошибка до 0.25 dp, меньше
              // физического пикселя. Обрезка содержимого ниже берёт точный радиус.
              shape: Ios27GlassShape.rounded(_glassRadius(r, radius)),
              away: v.glassGone,
            ),
            icon: icon == null
                ? null
                : Opacity(
                    opacity: v.iconOpacity,
                    child: Transform.scale(
                      scale: v.iconScale,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: v.iconBlur,
                          sigmaY: v.iconBlur,
                          tileMode: TileMode.decal,
                        ),
                        child: Center(child: icon),
                      ),
                    ),
                  ),
            content: child!,
          );
        },
      );
}

/// Радиус нативного стекла слоя: с шагом [kIos27ZoomGlassRadiusStep], конечный — точно.
///
/// Конечный радиус отдаётся без округления, чтобы покой совпадал со стеклом без зума байт в байт.
double _glassRadius(double r, double end) => (r - end).abs() < 1e-6
    ? end
    : (r / kIos27ZoomGlassRadiusStep).round() * kIos27ZoomGlassRadiusStep;

/// Шаг квантования радиуса стекла слоя на кадрах зума, dp.
const double kIos27ZoomGlassRadiusStep = 0.5;

/// Места рамки зума.
enum Ios27ZoomSlot { glass, content, icon }

/// Рамка зума: размер берёт у содержимого (конечный), стекло и значок кладёт в растущий
/// прямоугольник между кнопкой и местом слоя.
class Ios27ZoomFrame
    extends SlottedMultiChildRenderObjectWidget<Ios27ZoomSlot, RenderBox> {
  const Ios27ZoomFrame({
    super.key,
    required this.from,
    required this.values,
    required this.radius,
    required this.glass,
    required this.content,
    this.icon,
  });

  /// Прямоугольник кнопки в глобальных координатах.
  final Rect from;
  final Ios27ZoomValues values;

  /// Радиус формы на этом кадре, для обрезки содержимого.
  final double radius;
  final Widget glass;
  final Widget content;
  final Widget? icon;

  @override
  Iterable<Ios27ZoomSlot> get slots => Ios27ZoomSlot.values;

  @override
  Widget? childForSlot(Ios27ZoomSlot slot) => switch (slot) {
        Ios27ZoomSlot.glass => glass,
        Ios27ZoomSlot.content => content,
        Ios27ZoomSlot.icon => icon,
      };

  @override
  SlottedContainerRenderObjectMixin<Ios27ZoomSlot, RenderBox>
      createRenderObject(
    BuildContext context,
  ) =>
          _RenderZoomFrame(from: from, values: values, radius: radius);

  @override
  void updateRenderObject(
    BuildContext context,
    // ignore: library_private_types_in_public_api
    covariant _RenderZoomFrame renderObject,
  ) {
    renderObject
      ..from = from
      ..values = values
      ..radius = radius;
  }
}

class _RenderZoomFrame extends RenderBox
    with SlottedContainerRenderObjectMixin<Ios27ZoomSlot, RenderBox> {
  _RenderZoomFrame({
    required Rect from,
    required Ios27ZoomValues values,
    required double radius,
  })  : _from = from,
        _values = values,
        _radius = radius;

  Rect _from;
  set from(Rect value) {
    if (_from == value) return;
    _from = value;
    markNeedsLayout();
  }

  Ios27ZoomValues _values;
  set values(Ios27ZoomValues value) {
    if (_values == value) return;
    _values = value;
    markNeedsLayout();
  }

  double _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  RenderBox? get _glass => childForSlot(Ios27ZoomSlot.glass);
  RenderBox? get _content => childForSlot(Ios27ZoomSlot.content);
  RenderBox? get _icon => childForSlot(Ios27ZoomSlot.icon);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  bool get isRepaintBoundary => false;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _content?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _content?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _content?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _content?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final content = _content;
    if (content == null) return constraints.smallest;
    return constraints.constrain(content.getDryLayout(constraints.loosen()));
  }

  Size _animatedSize() {
    final d = _values.distance;
    return Size(
      math.max(0, lerpDouble(_from.width, size.width, d)!),
      math.max(0, lerpDouble(_from.height, size.height, d)!),
    );
  }

  @override
  void performLayout() {
    final content = _content!;
    // Содержимое получает те же ограничения, что в стекле без зума (Stack их ослаблял).
    // ignore: cascade_invocations
    content.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(content.size);
    final animated = _animatedSize();
    _glass?.layout(BoxConstraints.tight(animated));
    _icon?.layout(BoxConstraints.tight(animated));
  }

  Offset _topLeft() => Offset.lerp(
        _from.topLeft - localToGlobal(Offset.zero),
        Offset.zero,
        _values.distance,
      )!;

  @override
  void paint(PaintingContext context, Offset offset) {
    final content = _content!;
    final v = _values;
    final animated = _animatedSize();
    // Положение берём в paint: глобальные координаты рамки известны только после раскладки
    // родителей.
    final topLeft = _topLeft();

    final glass = _glass;
    if (glass != null) context.paintChild(glass, offset + topLeft);

    if (v.contentOpacity > 0) {
      final rect = topLeft & animated;
      final path = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
      ).getOuterPath(rect);
      context.pushClipPath(needsCompositing, offset, rect, path, (c, o) {
        void paintContent(PaintingContext cc, Offset oo) {
          final s = math.min(1.0, _from.width / math.max(1.0, size.width));
          final scale = lerpDouble(s, 1, v.contentT)!;
          if (v.contentT >= 1 && topLeft == Offset.zero) {
            cc.paintChild(content, oo);
            return;
          }
          final m = Matrix4.translationValues(topLeft.dx, topLeft.dy, 0)
            ..scaleByDouble(scale, scale, 1, 1);
          cc.pushTransform(needsCompositing, oo, m, (c3, o3) {
            c3.paintChild(content, o3);
          });
        }

        if (v.contentOpacity >= 1) {
          paintContent(c, o);
        } else {
          c.pushOpacity(
            o,
            (v.contentOpacity * 255).round(),
            paintContent,
          );
        }
      }, clipBehavior: Clip.antiAlias);
    }

    final icon = _icon;
    if (icon != null) context.paintChild(icon, offset + topLeft);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Пока слой растёт, нажимать нечего: содержимое масштабируется и прозрачно.
    if (!_values.settled) return false;
    return _content!.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final content = _content;
    if (content != null) visitor(content);
  }

  // Дети рисуются со сдвигом и масштабом, которых нет в раскладке; без этого `localToGlobal`
  // детей, фокус и семантика видели бы слой на конечном месте уже в первом кадре зума.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final topLeft = _topLeft();
    transform.translateByDouble(topLeft.dx, topLeft.dy, 0, 1);
    if (identical(child, _content)) {
      final s = math.min(1.0, _from.width / math.max(1.0, size.width));
      final scale = lerpDouble(s, 1, _values.contentT)!;
      transform.scaleByDouble(scale, scale, 1, 1);
    }
  }
}
