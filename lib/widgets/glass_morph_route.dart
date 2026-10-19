import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:dropweb/common/common.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        AdaptiveGlass,
        GlassQuality,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;

// Один кусок стекла «источник -> панель» в духе iOS 26: стекло не отрывается
// каплей, а само растёт из источника по пружине, содержимое источника
// растворяется, содержимое панели проявляется внутри того же стекла. Так
// открываются и шит подписки (из карточки или из пункта меню), и меню MENU.

/// Счётчик «источник спрятан». Несколько маршрутов могут держать источник
/// скрытым одновременно: при передаче меню -> шит старый маршрут уходит уже
/// после того, как новый взял источник, и пилюля не мигает.
class GlassMorphHide extends ChangeNotifier implements ValueListenable<bool> {
  int _holds = 0;
  bool _disposed = false;

  @override
  bool get value => _holds > 0;

  void hold() {
    _holds++;
    if (_holds == 1 && !_disposed) notifyListeners();
  }

  void release() {
    if (_holds == 0) return;
    _holds--;
    if (_holds == 0 && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Откуда растёт шит: прямоугольник источника, его вид и стекло.
class GlassMorphOrigin {
  const GlassMorphOrigin({
    required this.rect,
    required this.ghost,
    required this.radius,
    required this.settings,
    this.hide,
    this.ghostAlignment = Alignment.topLeft,
    this.returnTo,
  });

  /// Куда стекло возвращается при закрытии, если не туда, откуда выросло.
  /// Шит, выросший из панели меню, при закрытии сворачивается в пилюлю MENU:
  /// иначе пустая панель меню зависала бы на месте и исчезала одним кадром.
  final GlassMorphOrigin? returnTo;

  /// Глобальный прямоугольник источника (читается каждый кадр).
  final Rect? Function() rect;

  /// Как источник выглядит: растворяется, пока проявляется содержимое шита.
  final Widget ghost;

  final Alignment ghostAlignment;

  /// Радиус и настройки стекла источника: стекло шита стартует с них.
  final double radius;
  final LiquidGlassSettings settings;

  /// Прячет сам источник, пока на его месте стекло маршрута.
  final GlassMorphHide? hide;
}

/// Кусок стекла, который растёт из [source] в [target].
class GlassMorphSpec {
  const GlassMorphSpec({
    required this.target,
    required this.content,
    required this.fromRadius,
    required this.toRadius,
    required this.fromSettings,
    required this.toSettings,
    this.source,
    this.ghost,
    this.ghostAlignment = Alignment.topLeft,
    this.hideSource,
    this.closeOrigin,
    this.dragToDismiss = false,
    this.showHandle = false,
    this.fitContent = false,
    this.maxHeightFraction = 0.85,
    this.openSpring = const SpringDescription(
      mass: 1,
      stiffness: 170,
      damping: 22,
    ),
    this.closeSpring = const SpringDescription(
      mass: 1,
      stiffness: 200,
      damping: 25,
    ),
    this.contentFadeStart = 0.22,
    this.contentFadeEnd = 0.62,
    this.ghostFadeEnd = 0.30,
  });

  /// Глобальный прямоугольник источника; читается каждый кадр, чтобы закрытие
  /// садилось на источник, даже если экран под ним сдвинулся. Без источника
  /// панель выезжает снизу: тот же шит, только без исходной формы.
  final Rect? Function()? source;

  /// Конечный прямоугольник панели в координатах оверлея.
  final Rect Function(Size overlay) target;

  /// Содержимое панели (рисуется в конечной раскладке, стекло его открывает).
  final WidgetBuilder content;

  /// Как выглядит источник: растворяется в начале пути.
  final Widget? ghost;

  /// Где внутри растущего стекла стоит [ghost]: у карточки это верхний левый
  /// угол, у пилюли меню (стекло растёт вверх) — центр нижнего края.
  final Alignment ghostAlignment;

  /// Пока держит, источник прячет себя: его место занимает стекло маршрута.
  final GlassMorphHide? hideSource;

  /// Если задан, закрытие летит не в [source], а сюда (см.
  /// [GlassMorphOrigin.returnTo]). Подменяется только когда шит стоит
  /// полностью открытым: на полпути прыгнуть в другой прямоугольник нельзя.
  final GlassMorphOrigin? closeOrigin;

  /// Шит закрывается жестом вниз (за ручку и за любое место, где нет
  /// прокрутки), отпускание за порогом или со скоростью отправляет его обратно
  /// в источник.
  final bool dragToDismiss;

  /// Ручка сверху панели; проявляется вместе с содержимым.
  final bool showHandle;

  /// Высота шита подгоняется под содержимое: оно сообщает свою высоту через
  /// [GlassMorphScope] (шаги, ошибки, новые строки), стекло плавно тянется к
  /// ней. Высота из [target] — только стартовая оценка. Нижний край и поля
  /// берутся из [target], потолок — [maxHeightFraction] экрана над клавиатурой.
  final bool fitContent;
  final double maxHeightFraction;

  final double fromRadius;
  final double toRadius;
  final LiquidGlassSettings fromSettings;
  final LiquidGlassSettings toSettings;
  final SpringDescription openSpring;
  final SpringDescription closeSpring;
  final double contentFadeStart;
  final double contentFadeEnd;

  /// Прогресс, к которому [ghost] гаснет полностью. Для пилюли меню окно
  /// гашения не должно пересекаться с проявлением строк: иначе слабая строка
  /// «Подписка» ложится поверх надписи MENU.
  final double ghostFadeEnd;
}

/// Канал, по которому содержимое шита сообщает хосту свою высоту.
class GlassMorphScope extends InheritedWidget {
  const GlassMorphScope({
    super.key,
    required this.onContentHeight,
    required super.child,
  });

  final ValueChanged<double> onContentHeight;

  static ValueChanged<double>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GlassMorphScope>()?.onContentHeight;

  @override
  bool updateShouldNotify(GlassMorphScope oldWidget) => false;
}

Future<T?> showGlassMorph<T>(BuildContext context, GlassMorphSpec spec) {
  // Источник прячем здесь, а не в initState хоста: уведомление слушателей во
  // время build чужого дерева недопустимо.
  spec.hideSource?.hold();
  return Navigator.of(context, rootNavigator: true).push(
    _GlassMorphRoute<T>(spec),
  );
}

/// Закрывает именно маршрут морфа [route]. Пункт меню мог успеть открыть
/// поверх него свой диалог (у «Поддержки» это подтверждение внешней ссылки):
/// `pop()` снял бы этот диалог вместо меню, и ссылка молча не открывалась бы.
/// Под диалогом меню убирается без анимации — его всё равно не видно.
void dismissGlassMorph(NavigatorState navigator, Route<dynamic> route) {
  if (!route.isActive) return;
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

class _GlassMorphRoute<T> extends PopupRoute<T> {
  _GlassMorphRoute(this.spec);

  final GlassMorphSpec spec;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 600);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 520);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => 'Dismiss';

  // Отрисовка живёт на пружине хоста, а не на контроллере маршрута: контроллер
  // только держит маршрут в дереве. Закрытие посреди открытия укоротило бы
  // реверс до доли времени и оборвало бы пружину, поэтому перед реверсом
  // возвращаем контроллер на единицу.
  @override
  bool didPop(T? result) {
    controller?.value = 1;
    return super.didPop(result);
  }

  @override
  void dispose() {
    spec.hideSource?.release();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      _MorphHost(
        spec: spec,
        route: this,
        onDismiss: () {
          if (isCurrent) Navigator.of(context).pop();
        },
      );
}

class _MorphHost extends StatefulWidget {
  const _MorphHost({
    required this.spec,
    required this.route,
    required this.onDismiss,
  });

  final GlassMorphSpec spec;
  final _GlassMorphRoute<dynamic> route;
  final VoidCallback onDismiss;

  @override
  State<_MorphHost> createState() => _MorphHostState();
}

class _MorphHostState extends State<_MorphHost> with TickerProviderStateMixin {
  // Прогресс открытия: 0 — источник, 1 — панель; пружина может выйти за 1.
  late final AnimationController _t =
      AnimationController.unbounded(vsync: this);

  // Смещение панели вниз от пальца, в пикселях.
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this);

  // Возврат панели на место после недотянутого жеста.
  static const SpringDescription _settleSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 28,
  );

  // Системное «убрать анимации»: стекло сразу стоит на месте, остаётся только
  // короткое проявление содержимого.
  late final bool _reduceMotion = WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  // Высота шита по содержимому (с зазором под панелью), пружина тянет её к
  // новому значению. Пока [_fitStarted] ложно, берётся стартовая оценка.
  late final AnimationController _fit =
      AnimationController.unbounded(vsync: this);
  bool _fitStarted = false;
  double? _fitBase;
  double _fitTarget = 0;
  double _margin = 0;

  bool _closing = false;

  // Источник, в который стекло летит при закрытии, если он не совпадает с
  // исходным.
  GlassMorphOrigin? _back;

  /// Содержимое сообщило высоту: тянем стекло к ней. Зовётся после кадра, не
  /// во время layout.
  void _onContentHeight(double height) {
    if (!mounted || _closing || !widget.spec.fitContent) return;
    final want = height + _margin;
    if ((want - _fitTarget).abs() < 0.5) return;
    final current = _fitStarted ? _fit.value : (_fitBase ?? want);
    final velocity = _fitStarted ? _fit.velocity : 0.0;
    _fitTarget = want;
    _fitStarted = true;
    if (_reduceMotion) {
      _fit.value = want;
      return;
    }
    _fit.value = current;
    _fit.animateWith(SpringSimulation(_settleSpring, current, want, velocity));
  }

  @override
  void initState() {
    super.initState();
    widget.route.animation!.addStatusListener(_onRouteStatus);
    if (_reduceMotion) {
      _t.animateTo(
        1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _t.animateWith(SpringSimulation(widget.spec.openSpring, 0, 1, 0));
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || _closing) return;
    _closing = true;
    // Подмена источника незаметна только на полностью открытом шите: там
    // призрак прозрачен, а прямоугольник и радиус равны конечным.
    if (_t.value > 0.98) _back = widget.spec.closeOrigin;
    if (_reduceMotion) {
      _t.animateTo(
        0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeIn,
      );
      _drag.animateTo(
        0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeIn,
      );
      return;
    }
    // Закрытие подхватывает пружину с текущей скоростью, поэтому прерванное
    // открытие не дёргается. Смещение от пальца возвращается той же пружиной:
    // стекло летит в источник прямо из того места, где его отпустили.
    final spring = widget.spec.closeSpring;
    _t.animateWith(SpringSimulation(spring, _t.value, 0, _t.velocity));
    if (_drag.value != 0) {
      _drag.animateWith(
          SpringSimulation(spring, _drag.value, 0, _drag.velocity));
    }
  }

  @override
  void dispose() {
    widget.route.animation?.removeStatusListener(_onRouteStatus);
    _t.dispose();
    _drag.dispose();
    _fit.dispose();
    super.dispose();
  }

  bool get _canDrag =>
      widget.spec.dragToDismiss && !_closing && _t.value > 0.95;

  void _onDragStart(DragStartDetails _) {
    if (_canDrag) _drag.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_canDrag) return;
    final dy = d.delta.dy;
    // Вверх шит не уезжает: небольшая «резина» вместо жёсткого упора.
    final next = _drag.value + (dy < 0 && _drag.value <= 0 ? dy * 0.15 : dy);
    _drag.value = next.clamp(-16.0, double.infinity).toDouble();
  }

  void _onDragEnd(DragEndDetails d, double height) {
    if (_closing) return;
    final velocity = d.primaryVelocity ?? 0;
    if (_drag.value > height * 0.25 || velocity > 700) {
      widget.onDismiss();
      return;
    }
    if (_reduceMotion) {
      _drag.animateTo(
        0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
      return;
    }
    _drag
        .animateWith(SpringSimulation(_settleSpring, _drag.value, 0, velocity));
  }

  static double _smooth(double x, double a, double b) {
    final v = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  static Rect? _toOverlay(BuildContext context, Rect? global) {
    if (global == null) return null;
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.attached) return global;
    return Rect.fromPoints(
      overlay.globalToLocal(global.topLeft),
      overlay.globalToLocal(global.bottomRight),
    );
  }

  // lerp пакета, а не ручной конструктор: переносит все поля (свет, fresnel,
  // ambient), иначе обводка считалась бы по значениям по умолчанию.
  LiquidGlassSettings _settings(double p) => LiquidGlassSettings.lerp(
        _back?.settings ?? widget.spec.fromSettings,
        widget.spec.toSettings,
        p,
      );

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: Listenable.merge([_t, _drag, _fit]),
          builder: (context, _) {
            final base = spec.target(size);
            _margin = size.height - base.bottom;
            final Rect to;
            if (spec.fitContent) {
              // Высота идёт от содержимого, нижний край поднят над клавиатурой.
              final start = _fitBase ??= size.height - base.top;
              if (_fitTarget == 0) _fitTarget = start;
              final wanted = _fitStarted ? _fit.value : start;
              final height = math.min(
                wanted,
                (size.height - keyboard) * spec.maxHeightFraction,
              );
              final bottom = base.bottom - keyboard;
              to = Rect.fromLTRB(
                base.left,
                bottom - (height - _margin),
                base.right,
                bottom,
              );
            } else {
              to = base.shift(Offset(0, -keyboard));
            }
            final raw = _t.value;
            final p = raw.clamp(0.0, 1.0);
            // Без источника панель выезжает снизу за край экрана.
            final back = _back;
            final from = _toOverlay(
                  context,
                  (back?.rect ?? spec.source)?.call(),
                ) ??
                to.shift(Offset(0, to.height + 24));
            final rect = (_reduceMotion ? to : Rect.lerp(from, to, raw)!)
                .shift(Offset(0, _drag.value));
            final radius =
                lerpDouble(back?.radius ?? spec.fromRadius, spec.toRadius, p)!;
            final ghost = back?.ghost ?? spec.ghost;
            final ghostAlignment = back?.ghostAlignment ?? spec.ghostAlignment;
            final ghostOpacity = 1 - _smooth(p, 0, spec.ghostFadeEnd);
            final contentOpacity =
                _smooth(p, spec.contentFadeStart, spec.contentFadeEnd);
            // Скрим светлеет по мере того, как шит утягивают вниз.
            final dragFade =
                1 - (_drag.value / to.height).clamp(0.0, 1.0) * 0.8;
            final scrim = Lumina.scrimSoft.withValues(
              alpha: Lumina.scrimSoft.a * p * dragFade,
            );

            final glass = AdaptiveGlass(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: radius),
              settings: _settings(p),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Содержимое едет вместе со стеклом: верхний левый угол
                  // приколот к углу прямоугольника, высота конечная, а
                  // «лишнее» снизу срезает клип стекла. Так заголовок шита
                  // сидит там же, где был заголовок карточки, а строки
                  // открываются по мере роста стекла.
                  if (contentOpacity > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: to.width,
                      height: to.height,
                      child: IgnorePointer(
                        ignoring: _closing || contentOpacity < 0.9,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Material(
                            type: MaterialType.transparency,
                            child: GlassMorphScope(
                              onContentHeight: _onContentHeight,
                              // Подъём над клавиатурой уже сделан положением
                              // стекла: содержимому отдаём раскладку без неё.
                              // Нижний safe-area отступ над открытой
                              // клавиатурой не нужен (жестовую панель
                              // закрывает она).
                              child: Builder(
                                builder: (context) {
                                  final media = MediaQuery.of(context);
                                  return MediaQuery(
                                    data: media.copyWith(
                                      viewInsets:
                                          media.viewInsets.copyWith(bottom: 0),
                                      padding: media.padding.copyWith(
                                        bottom: keyboard > 0
                                            ? 0
                                            : media.padding.bottom,
                                      ),
                                    ),
                                    child: Builder(builder: spec.content),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (ghost != null && ghostOpacity > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: ghostOpacity,
                          child: Align(
                            alignment: ghostAlignment,
                            child: SizedBox(
                              width: from.width,
                              height: from.height,
                              child: ghost,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Обводка постоянной толщины поверх шейдерного рима пакета:
                  // тот рисует волосок 0.5px, зависящий от угла света, и на
                  // углах и боках он худеет и гаснет.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _smooth(p, 0, 0.25),
                        child: CustomPaint(painter: _RimPainter(radius)),
                      ),
                    ),
                  ),
                  if (spec.showHandle && contentOpacity > 0)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.colorScheme.onSurface.opacity30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Зона ручки забирает жест у прокручиваемого содержимого:
                  // шит можно потянуть вниз, даже если список не на нуле.
                  if (spec.dragToDismiss)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 32,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: _onDragStart,
                        onVerticalDragUpdate: _onDragUpdate,
                        onVerticalDragEnd: (d) => _onDragEnd(d, to.height),
                      ),
                    ),
                ],
              ),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closing ? null : widget.onDismiss,
                    child: ColoredBox(color: scrim),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  // Тот же AdaptiveGlass, что у шита пакета: он сам клипует
                  // содержимое по SDF-контуру, а обводка рисуется шейдером по
                  // тому же контуру. GlassCard + свой ClipRSuperellipse давали
                  // два чуть разных суперэллипса и обводка на боках худела.
                  child: spec.dragToDismiss
                      ? GestureDetector(
                          onVerticalDragStart: _onDragStart,
                          onVerticalDragUpdate: _onDragUpdate,
                          onVerticalDragEnd: (d) => _onDragEnd(d, to.height),
                          child: glass,
                        )
                      : glass,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Обводка стекла: линия постоянной [width], целиком внутри контура (клип
/// стекла её не обрезает). Яркость идёт диагональным градиентом от верхнего
/// левого угла к нижнему правому, но никогда не падает ниже нижней границы,
/// поэтому на боках и в углах линия не пропадает.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.radius);

  final double radius;

  static const double width = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final r =
        math.max(0.0, math.min(radius - width / 2, rect.shortestSide / 2));
    final path = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(r),
    ).getOuterPath(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Lumina.lensHighlight.opacity60,
          Lumina.lensHighlight.opacity30,
          Lumina.lensHighlight.opacity30,
          Lumina.lensHighlight.opacity50,
        ],
        stops: const [0, 0.38, 0.62, 1],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius;
}

/// Физика списка внутри шита. Высота шита считается по константам и может
/// промахнуться на пару пикселей: список тогда «прокручивается» на эти пиксели,
/// забирает вертикальный жест у шита и растягивается под пальцем (stretch
/// overscroll на Android) вместо того, чтобы потянуть шит вниз. Малый запас
/// (меньше [slack]) считаем «контент помещается»: прокрутка выключена, жест
/// достаётся стеклу. Настоящий избыток (крупный шрифт) прокручивается как обычно.
class SheetFitPhysics extends ClampingScrollPhysics {
  const SheetFitPhysics({super.parent});

  static const double slack = 24;

  @override
  SheetFitPhysics applyTo(ScrollPhysics? ancestor) =>
      SheetFitPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.maxScrollExtent - position.minScrollExtent > slack;
}

/// Нижняя граница шита по высоте контента [height] (как у GlassModalSheet:
/// поля 8, низ 8).
Rect glassSheetTarget(Size overlay, double height) => Rect.fromLTRB(
      8,
      overlay.height - height,
      overlay.width - 8,
      overlay.height - 8,
    );

/// Прямоугольник меню над пилюлей: центр по пилюле, нижний край на её нижнем.
Rect glassMenuTarget(Size overlay, Rect pill, double width, double height) {
  final left = (pill.center.dx - width / 2)
      .clamp(8.0, math.max(8.0, overlay.width - width - 8))
      .toDouble();
  return Rect.fromLTWH(left, pill.bottom - height, width, height);
}
