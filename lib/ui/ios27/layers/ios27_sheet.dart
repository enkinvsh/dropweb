// Лист iOS-редизайна: стеклянная карточка у нижнего края, ручка, шапка с круглыми кнопками (доска `.sheet`, app.css:272-330).

import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27Text, Ios27Tokens;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

/// Высота `.sheet--medium` (app.css:289): лист фиксированной высоты.
const double kIos27SheetMediumHeight = 560;

/// Поле листа от краёв экрана (`left/right/bottom: 8px`).
const double kIos27SheetMargin = 8;

/// Высота шапки (`.sheet__bar`).
const double kIos27SheetHeaderHeight = 64;

/// Сколько сверху занимает шапка вместе с зазором: на столько тело, которое едет под стекло
/// шапки, должно отступить сверху (`.sheet__body{padding-top:68px}`).
const double kIos27SheetHeaderInset = 68;

/// Размер круглой кнопки шапки (`circle-btn`, 44).
const double kIos27SheetButtonSize = 44;

/// Начальное смещение выезда листа (`translateY(600px)`).
const double kIos27SheetTravel = 600;

/// Высота листа.
enum Ios27SheetDetent {
  /// Как на доске: 560, а если экран ниже, то сколько влезет.
  medium,

  /// По содержимому, но не выше `medium`. Для старых листов приложения, высота которых
  /// разная.
  fit,
}

/// Данные листа для потомков: на них опираются шапка и экраны волны Э.
///
/// [headerInset] нужен телу под стеклом шапки: верхний отступ прокручиваемого содержимого,
/// чтобы первая строка не пряталась под кнопками.
class Ios27SheetScope extends InheritedWidget {
  const Ios27SheetScope({
    super.key,
    required this.detent,
    required this.dismissible,
    required this.dragUpdate,
    required this.dragEnd,
    required super.child,
  });

  final Ios27SheetDetent detent;
  final bool dismissible;

  /// Жесты смахивания вниз для шапки: ручка и шапка тянут весь лист.
  final GestureDragUpdateCallback dragUpdate;
  final GestureDragEndCallback dragEnd;

  double get headerInset => kIos27SheetHeaderInset;

  static Ios27SheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Ios27SheetScope>();

  @override
  bool updateShouldNotify(Ios27SheetScope oldWidget) =>
      detent != oldWidget.detent || dismissible != oldWidget.dismissible;
}

/// Открывает нижний лист iOS-редизайна и возвращает результат закрытия.
///
/// **Как пользоваться (экраны волны Э).** Вызов берёт любой контекст, в том числе выше области
/// темы. Лист кладётся в корневой навигатор и несёт собственную тему, поэтому тёмная/светлая
/// схема и акцент приходят сами.
///
/// * [builder] строит содержимое. Если заданы [title], [leading] или [actions], результат
///   оборачивается в [Ios27SheetScaffold] с шапкой; иначе [builder] сам возвращает
///   [Ios27SheetScaffold] (так делает шов `AdaptiveSheetScaffold`).
/// * [detent]: [Ios27SheetDetent.medium] 560 как на доске, [Ios27SheetDetent.fit] по содержимому.
/// * [dismissible] `false` отключает закрытие тапом по затемнению, смахиванием вниз и системным
///   «назад» на первой странице (урок 25). Кнопка «закрыть» в шапке остаётся: убрать её можно
///   `showClose` в [Ios27SheetScaffold].
/// * Второй уровень (маршрут → серверы → группа): из любого места листа вызовите
///   `Ios27SheetNavigator.push(context, builder: …)`. Новая страница выезжает справа, старая
///   уходит влево на 30 % ширины, в шапке новой появляется кнопка «Назад». Закрыть страницу
///   можно `Ios27SheetNavigator.pop(context, результат)`.
/// * Тело под стеклом шапки: `bodyUnderHeader: true`, верхний отступ списка берите из
///   `Ios27SheetScope.maybeOf(context)?.headerInset` (68).
/// * Клавиатуру лист учитывает сам, один раз: поднимается над ней и убирает `viewInsets` у
///   содержимого. Внутри листа не добавляйте отступ под клавиатуру повторно.
/// * [variant] класс стекла листа: `md` у обычных листов (`glass--md`), `lg` у листа цвета
///   (`glass--lg`, плотнее). Тип влияет только на материал, раскладка одна.
/// * Заголовок шапки не масштабируется системным размером шрифта (высота шапки фиксирована),
///   тело масштабируется как обычно.
/// * [origin]: стеклянная кнопка, из которой лист вырастает и в которую втягивается при закрытии
///   (`Ios27ZoomSource.originFor`). Пока лист открыт, кнопка на своём месте не рисуется. Без
///   [origin] (открытие по ссылке, из фона) и при «Уменьшении движения» лист въезжает снизу.
Future<T?> showIos27Sheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  Ios27SheetDetent detent = Ios27SheetDetent.medium,
  Widget? leading,
  List<Widget> actions = const [],
  bool dismissible = true,
  bool bodyUnderHeader = false,
  VoidCallback? onTitleTap,
  Ios27GlassVariant variant = Ios27GlassVariant.md,
  Ios27ZoomOrigin? origin,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final reduced = MediaQuery.disableAnimationsOf(context);
  final wrap = title != null || leading != null || actions.isNotEmpty;
  return navigator.push<T>(
    Ios27SheetRoute<T>(
      builder: wrap
          ? (c) => Ios27SheetScaffold(
                title: title ?? '',
                leading: leading,
                actions: actions,
                bodyUnderHeader: bodyUnderHeader,
                onTitleTap: onTitleTap,
                body: Builder(builder: builder),
              )
          : builder,
      detent: detent,
      dismissible: dismissible,
      variant: variant,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      reduced: reduced,
      // Без движения зума нет, и кнопка остаётся на месте (app.js:958-963).
      origin: reduced ? null : origin,
    ),
  );
}

/// Маршрут листа; открывайте через [showIos27Sheet].
///
/// Затемнение рисует сам лист: оно гаснет вместе со смахиванием, чего штатный барьер не умеет.
class Ios27SheetRoute<T> extends PopupRoute<T> {
  Ios27SheetRoute({
    required this.builder,
    required this.detent,
    required this.dismissible,
    required this.themes,
    required this.reduced,
    this.variant = Ios27GlassVariant.md,
    this.origin,
  });

  final WidgetBuilder builder;
  final Ios27SheetDetent detent;
  final bool dismissible;
  final Ios27GlassVariant variant;
  final CapturedThemes themes;
  final bool reduced;

  /// Кнопка, из которой растёт лист; `null` — въезд снизу.
  final Ios27ZoomOrigin? origin;

  /// Время зума; создаётся при установке маршрута, если есть [origin].
  Ios27ZoomTimeline? timeline;

  static final Curve _spring = Ios27SpringCurve(Ios27Motion.springSmooth);

  /// Положение выезда `0..1` по пружине; на закрытии та же пружина идёт обратно (`to 600`).
  static double progress(Animation<double> animation) =>
      animation.status == AnimationStatus.reverse
          ? 1 - _spring.transform(1 - animation.value)
          : _spring.transform(animation.value);

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced
      ? const Duration(milliseconds: 100)
      : origin != null
          ? ios27ZoomOpenDuration
          : Ios27Motion.springSmooth.settle;

  @override
  Duration get reverseTransitionDuration => reduced
      ? const Duration(milliseconds: 100)
      : origin != null
          ? ios27ZoomCloseDuration
          : Ios27Motion.springSmooth.settle;

  @override
  void install() {
    super.install();
    final from = origin;
    if (from != null) {
      timeline = Ios27ZoomTimeline(origin: from, animation: animation!);
    }
  }

  @override
  bool didPop(T? result) {
    final zoom = timeline;
    if (zoom != null) {
      // Втягивание считается от нуля и идёт полную длину, даже если лист закрыли с середины
      // открытия: `zoomOut` стартует «из того места, где слой сейчас» (motion.js:136).
      zoom.beginClose();
      final c = controller;
      if (c != null && c.value < 1) c.value = 1;
    }
    return super.didPop(result);
  }

  @override
  void dispose() {
    timeline?.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      themes.wrap(
        Ios27ThemeScope(
          // MediaQuery читаем НИЖЕ скоупа: копия из контекста маршрута вернула бы масштаб
          // предка (ThemeManager) поверх системного Dynamic Type, который выставил скоуп.
          child: Builder(
            builder: (scopeContext) => MediaQuery(
              data: MediaQuery.of(scopeContext)
                  .copyWith(disableAnimations: reduced),
              child: Material(
                type: MaterialType.transparency,
                child: _withZoom(
                  _SheetHost(
                    route: this,
                    animation: animation,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _withZoom(Widget child) {
    final zoom = timeline;
    return zoom == null ? child : Ios27ZoomScope(timeline: zoom, child: child);
  }
}

class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.route, required this.animation});

  final Ios27SheetRoute<dynamic> route;
  final Animation<double> animation;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost>
    with SingleTickerProviderStateMixin {
  /// Смещение листа вниз от смахивания. Значение контроллера и есть смещение: тот же
  /// контроллер потом возвращает лист пружиной.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  final GlobalKey _frameKey = GlobalKey();

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails details) {
    // Вверх лист не тянется: край у экрана, резинка там не нужна.
    _offset.value = math.max(0, _offset.value + details.delta.dy);
  }

  void _dragEnd(DragEndDetails details) {
    final height =
        _frameKey.currentContext?.size?.height ?? kIos27SheetMediumHeight;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final far = _offset.value > height * 0.25;
    if (widget.route.dismissible && (far || velocity > 700)) {
      widget.route.navigator?.pop();
      return;
    }
    // Возврат пружиной с текущей скоростью пальца, чтобы лист не «прилипал».
    _offset.animateWith(
      SpringSimulation(
        Ios27Motion.springSnappy.description,
        _offset.value,
        0,
        math.max(0, velocity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final media = MediaQuery.of(context);
    final colors = ios27ColorsFor(context);
    final keyboard = media.viewInsets.bottom;
    final reduced = route.reduced;

    // Свободная высота: от верхней границы safe area до листа над клавиатурой.
    final available = math.max(
      0.0,
      media.size.height - keyboard - media.padding.top - 2 * kIos27SheetMargin,
    );
    final cap = math.min(kIos27SheetMediumHeight, available);

    // Клавиатуру считает рамка, один раз: потомкам viewInsets не отдаём (урок 26). Боковые
    // safe area рамка тоже учитывает сама (см. ниже `Positioned`), поэтому содержимое их второй
    // раз не получает.
    final content = MediaQuery(
      data: media
          .removePadding(removeLeft: true, removeRight: true)
          .removeViewInsets(removeBottom: true),
      child: Ios27SheetScope(
        detent: route.detent,
        dismissible: route.dismissible,
        dragUpdate: _dragUpdate,
        dragEnd: _dragEnd,
        child: _SheetPages(
          dismissible: route.dismissible,
          reduced: reduced,
          child: Builder(builder: route.builder),
        ),
      ),
    );

    final grabber = Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 22,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _dragUpdate,
        onVerticalDragEnd: _dragEnd,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              key: const ValueKey<String>('ios27.sheet.grabber'),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: colors.palette.fill1,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
    final inner = Stack(
      fit: StackFit.passthrough,
      children: [content, grabber],
    );

    // Лист с источником растёт из кнопки: стекло и содержимое ведёт рамка зума. Дерево выбрано на
    // весь срок маршрута, поэтому содержимое не теряет состояние на стыке открытия и покоя.
    final timeline = route.timeline;
    const frameKey = ValueKey<String>('ios27.sheet.frame');
    final framed = timeline == null
        ? Ios27Glass(
            key: frameKey,
            variant: route.variant,
            shape: const Ios27GlassShape.rounded(Ios27Tokens.rAlert),
            child: inner,
          )
        : Ios27ZoomGlass(
            timeline: timeline,
            variant: route.variant,
            radius: Ios27Tokens.rAlert,
            glassKey: frameKey,
            child: inner,
          );

    final Widget sized = route.detent == Ios27SheetDetent.medium
        ? SizedBox(height: cap, child: framed)
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: cap), child: framed);

    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _offset]),
      builder: (context, _) {
        final dim = colors.palette.dim;
        final share =
            (_offset.value / (cap + kIos27SheetMargin)).clamp(0.0, 1.0);
        final double scrimAlpha;
        final double dy;
        Widget sheet;
        if (timeline != null) {
          // Затемнение 400 мс ease-out от начала раскрытия и обратно при закрытии (app.css `dim`).
          final ms = timeline.timeFraction *
              (timeline.closing
                  ? ios27ZoomCloseDuration.inMilliseconds
                  : ios27ZoomOpenDuration.inMilliseconds);
          final fade =
              Ios27Motion.easeOut.transform((ms / 400).clamp(0.0, 1.0));
          scrimAlpha =
              (dim.a * (timeline.closing ? 1 - fade : fade) * (1 - share))
                  .clamp(0.0, 1.0);
          dy = _offset.value;
          sheet = Transform.translate(offset: Offset(0, dy), child: sized);
        } else {
          final a = reduced
              ? widget.animation.value
              : Ios27SheetRoute.progress(widget.animation);
          scrimAlpha =
              (dim.a * a.clamp(0.0, 1.0) * (1 - share)).clamp(0.0, 1.0);
          dy = reduced ? 0.0 : _offset.value + kIos27SheetTravel * (1 - a);
          sheet = Transform.translate(offset: Offset(0, dy), child: sized);
          if (reduced) {
            sheet = Opacity(opacity: a.clamp(0.0, 1.0), child: sheet);
          }
        }
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: route.dismissible ? () => route.navigator?.pop() : null,
                child: ColoredBox(color: dim.withValues(alpha: scrimAlpha)),
              ),
            ),
            // Лист стоит внутри боковых safe area: на iPhone Duo торцевая колонка Dynamic
            // Island не должна закрывать ни стекло, ни кнопку «закрыть» в шапке (как у
            // UIKit-листов). Затемнение выше остаётся на весь экран.
            Positioned(
              left: kIos27SheetMargin + media.padding.left,
              right: kIos27SheetMargin + media.padding.right,
              bottom: kIos27SheetMargin + keyboard,
              child: KeyedSubtree(key: _frameKey, child: sheet),
            ),
          ],
        );
      },
    );
  }
}

/// Стопка страниц листа: корневая страница и страницы второго уровня.
///
/// Переход как на доске (`slide()` и `clipNav()`, motion.js:277-313): новая страница едет справа
/// поверх, нижняя уходит влево на 30 % ширины и тускнеет до 0.6. Каждая страница обрезана своей
/// частью листа, поэтому прозрачные страницы не просвечивают друг сквозь друга. Движение рисует
/// [Ios27SheetScaffold] каждой страницы: тело едет, а шапка остаётся на месте и перетекает
/// отдельно (`crossBar`, app.js:826-855). При «Уменьшении движения» страницы не едут, а
/// проявляются за 100 мс.
class _SheetPages extends StatefulWidget {
  const _SheetPages({
    required this.child,
    required this.dismissible,
    required this.reduced,
  });

  /// Корневая страница (уже вместе с [Ios27SheetScope]).
  final Widget child;
  final bool dismissible;
  final bool reduced;

  @override
  State<_SheetPages> createState() => _SheetPagesState();
}

/// Строка, с которой ушли вглубь листа: подсвечена, пока страница уезжает (`is-selected`), и
/// гаснет, когда возвращаешься (`is-deselect`), app.css:205-213.
typedef _RowMark = ({Object id, bool deselect});

class _PageEntry {
  _PageEntry(this.builder, this.completer, {this.pushedFrom});

  final WidgetBuilder builder;
  final Completer<Object?> completer;

  /// Строка предыдущей страницы, нажатием на которую открыта эта страница.
  final Object? pushedFrom;

  /// Страница меняет обёртки (сдвиг, прозрачность) на время перехода и снимает их по его концу.
  /// Без глобального ключа на этой смене её состояние пересоздавалось бы: терялись бы прокрутка,
  /// ввод в поле и повторялся `initState` (замер пинга уходил дважды).
  final GlobalKey key = GlobalKey();

  /// Подсветка строк этой страницы.
  final ValueNotifier<_RowMark?> mark = ValueNotifier<_RowMark?>(null);
}

/// Что делает страница в текущем переходе.
enum _PageKind { idle, top, under, hidden }

/// Положение страницы в переходе на этот кадр.
class _PageRole {
  const _PageRole({
    required this.kind,
    this.u = 1,
    this.hMs = 0,
    this.hFraction = 1,
    this.push = true,
    this.reduced = false,
  });

  const _PageRole.idle()
      : kind = _PageKind.idle,
        u = 1,
        hMs = 0,
        hFraction = 1,
        push = true,
        reduced = false;

  final _PageKind kind;

  /// Доля пути «верхней» страницы: 0 — за правым краем, 1 — на месте. На возврате идёт от 1 к 0.
  final double u;

  /// Часы шапки: миллисекунды и доля от начала перехода (не зависят от направления).
  final double hMs;
  final double hFraction;
  final bool push;
  final bool reduced;

  bool get idle => kind == _PageKind.idle;

  /// Страница, которую в конце перехода видно: при заходе вглубь верхняя, при возврате нижняя.
  /// Её кнопки и заголовок «новые» для шапки.
  bool get isNew =>
      idle ||
      (push && kind == _PageKind.top) ||
      (!push && kind == _PageKind.under);
}

class _SheetPagesState extends State<_SheetPages>
    with TickerProviderStateMixin {
  static final Curve _spring = Ios27SpringCurve(Ios27Motion.springSmooth);

  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
    duration: widget.reduced
        ? const Duration(milliseconds: 100)
        : Ios27Motion.springSmooth.settle,
  )..addStatusListener(_onStatus);

  /// Часы шапки: время от начала перехода вперёд в обе стороны. Заголовки гаснут и проявляются
  /// по времени, а не по доле пути (`crossBar` ведёт их WAAPI-анимациями со своими длительностями).
  late final AnimationController _h = AnimationController(
    vsync: this,
    value: 1,
    duration: _c.duration,
  );

  late final Listenable listenable = Listenable.merge([_c, _h]);

  late final _PageEntry _root = _PageEntry(
    (_) => widget.child,
    Completer<Object?>(),
  );
  final List<_PageEntry> _pages = [];
  _PageEntry? _leaving;
  bool _push = true;

  @override
  void initState() {
    super.initState();
    _pages.add(_root);
  }

  @override
  void dispose() {
    _c.dispose();
    _h.dispose();
    for (final p in [..._pages, if (_leaving != null) _leaving!]) {
      if (!p.completer.isCompleted) p.completer.complete(null);
      p.mark.dispose();
    }
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _leaving != null) {
      _leaving!.mark.dispose();
      setState(() => _leaving = null);
    }
  }

  int get depth => _pages.length;

  Future<T?> push<T>(WidgetBuilder builder, {Object? highlight}) {
    final entry = _PageEntry(
      builder,
      Completer<Object?>(),
      pushedFrom: highlight,
    );
    if (highlight != null) {
      _pages.last.mark.value = (id: highlight, deselect: false);
    }
    _push = true;
    setState(() => _pages.add(entry));
    _c.forward(from: 0);
    _h.forward(from: 0);
    return entry.completer.future.then((v) => v as T?);
  }

  void pop([Object? result]) {
    if (_pages.length <= 1 || _leaving != null) return;
    final entry = _pages.removeLast();
    final from = entry.pushedFrom;
    if (from != null) _pages.last.mark.value = (id: from, deselect: true);
    _push = false;
    setState(() => _leaving = entry);
    if (!entry.completer.isCompleted) entry.completer.complete(result);
    _c.reverse(from: _c.value == 0 ? 1 : _c.value);
    _h.forward(from: 0);
  }

  double get _progress {
    if (widget.reduced) return _c.value;
    return _c.status == AnimationStatus.reverse
        ? 1 - _spring.transform(1 - _c.value)
        : _spring.transform(_c.value);
  }

  /// Роль страницы в текущем переходе.
  _PageRole roleOf(_PageEntry entry) {
    if (!_c.isAnimating && !_h.isAnimating) return const _PageRole.idle();
    final top = _leaving ?? _pages.last;
    final under = _leaving != null
        ? _pages.last
        : (_pages.length > 1 ? _pages[_pages.length - 2] : null);
    final kind = identical(entry, top)
        ? _PageKind.top
        : identical(entry, under)
            ? _PageKind.under
            : _PageKind.hidden;
    return _PageRole(
      kind: kind,
      u: _progress.clamp(0.0, 1.0),
      hMs: _h.value * (_h.duration?.inMilliseconds ?? 0),
      hFraction: _h.value,
      push: _push,
      reduced: widget.reduced,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._pages, if (_leaving != null) _leaving!];
    return _PagesScope(
      state: this,
      depth: _pages.length,
      child: PopScope(
        canPop: _pages.length <= 1 && widget.dismissible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _pages.length > 1) pop();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final animating = _c.isAnimating;
            final children = <Widget>[];
            for (var i = 0; i < all.length; i++) {
              final entry = all[i];
              final isTop = i == all.length - 1;
              final isUnder = i == all.length - 2;
              final visible = isTop || (animating && isUnder);
              final page = KeyedSubtree(
                key: entry.key,
                child: _PageInfo(
                  state: this,
                  entry: entry,
                  index: i,
                  child: Builder(builder: entry.builder),
                ),
              );
              // Скрытые страницы остаются в дереве, чтобы не терять состояние (прокрутку,
              // ввод), но без тикеров и без вклада в размер.
              children.add(
                Offstage(
                  key: ObjectKey(entry),
                  offstage: !visible,
                  child: TickerMode(enabled: visible, child: page),
                ),
              );
            }
            return Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.hardEdge,
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class _PagesScope extends InheritedWidget {
  const _PagesScope({
    required this.state,
    required this.depth,
    required super.child,
  });

  final _SheetPagesState state;
  final int depth;

  @override
  bool updateShouldNotify(_PagesScope oldWidget) =>
      depth != oldWidget.depth || state != oldWidget.state;
}

/// Страница стопки для её же [Ios27SheetScaffold]: номер, запись и источник переходов.
class _PageInfo extends InheritedWidget {
  const _PageInfo({
    required this.state,
    required this.entry,
    required this.index,
    required super.child,
  });

  final _SheetPagesState state;
  final _PageEntry entry;
  final int index;

  static _PageInfo? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PageInfo>();

  @override
  bool updateShouldNotify(_PageInfo oldWidget) => index != oldWidget.index;
}

/// Страницы внутри листа: второй уровень «маршрут → серверы → группа» без нового листа.
abstract final class Ios27SheetNavigator {
  /// Глубина стопки: 1 на корневой странице.
  static int depthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PagesScope>()?.depth ?? 1;

  /// Кладёт [builder] страницей поверх текущей. Результат приходит по `pop(context, result)`;
  /// если лист закрыли целиком, придёт `null`. Страница строит свою шапку через
  /// [Ios27SheetScaffold]; кнопка «Назад» появится сама.
  ///
  /// [highlight] — идентификатор строки ([Ios27SheetPushHighlight]), нажатием на которую открыта
  /// страница: пока страница уезжает, строка подсвечена, на возврате подсветка гаснет за 600 мс
  /// (`is-selected`, `is-deselect`, app.js:943-944).
  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    Object? highlight,
  }) {
    final scope = context.getInheritedWidgetOfExactType<_PagesScope>();
    assert(scope != null, 'Ios27SheetNavigator.push вне листа iOS');
    return scope!.state.push<T>(builder, highlight: highlight);
  }

  /// Закрывает верхнюю страницу; на корневой закрывает сам лист.
  static void pop(BuildContext context, [Object? result]) {
    final scope = context.getInheritedWidgetOfExactType<_PagesScope>();
    if (scope != null && scope.state.depth > 1) {
      scope.state.pop(result);
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(result);
  }
}

/// Строка страницы листа, с которой можно уйти вглубь: подсвечивается так же, как на доске.
///
/// Подсветка рисуется позади строки (`--sel` с долей `fill-4`): сразу при заходе вглубь, на
/// возврате гаснет за 600 мс по `ease`, как `deselectRow` у UITableView. Идентификатор [id]
/// тот же, что передан в [Ios27SheetNavigator.push].
class Ios27SheetPushHighlight extends StatefulWidget {
  const Ios27SheetPushHighlight({
    super.key,
    required this.id,
    required this.child,
  });

  final Object id;
  final Widget child;

  @override
  State<Ios27SheetPushHighlight> createState() =>
      _Ios27SheetPushHighlightState();
}

class _Ios27SheetPushHighlightState extends State<Ios27SheetPushHighlight>
    with SingleTickerProviderStateMixin {
  /// Доля подсветки: 1 — полная, 0 — нет.
  late final AnimationController _sel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  ValueNotifier<_RowMark?>? _mark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _PageInfo.maybeOf(context)?.entry.mark;
    if (identical(next, _mark)) return;
    _mark?.removeListener(_onMark);
    _mark = next?..addListener(_onMark);
  }

  @override
  void dispose() {
    _mark?.removeListener(_onMark);
    _sel.dispose();
    super.dispose();
  }

  void _onMark() {
    final m = _mark?.value;
    if (m == null || m.id != widget.id) return;
    _sel.value = 1;
    if (m.deselect) {
      unawaited(_sel.animateTo(0, curve: Curves.ease));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fill = ios27ColorsFor(context).palette.fill4;
    return AnimatedBuilder(
      animation: _sel,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: fill.withValues(alpha: fill.a * _sel.value),
        ),
        child: child,
      ),
    );
  }
}

/// Обрезка страницы на время перехода (`clipNav`, motion.js:277-290): прямоугольник листа со
/// скруглением листа со стороны его краёв.
class _NavClipper extends CustomClipper<Path> {
  const _NavClipper({required this.under, required this.k});

  /// Нижняя страница: [k] — насколько она ушла. Верхняя: [k] — сколько ей осталось ехать.
  final bool under;
  final double k;

  @override
  Path getClip(Size size) {
    final w = size.width;
    const r = Ios27Tokens.rAlert;
    final rect = under
        ? RRect.fromLTRBAndCorners(
            0.3 * w * k,
            0,
            w - 0.7 * w * k,
            size.height,
            topLeft: const Radius.circular(r),
            topRight: Radius.circular(r * (1 - k)),
            bottomRight: Radius.circular(r * (1 - k)),
            bottomLeft: const Radius.circular(r),
          )
        : RRect.fromLTRBAndCorners(
            0,
            0,
            w - w * k,
            size.height,
            topLeft: Radius.circular(r * (1 - k)),
            topRight: const Radius.circular(r),
            bottomRight: const Radius.circular(r),
            bottomLeft: Radius.circular(r * (1 - k)),
          );
    return Path()..addRRect(rect);
  }

  @override
  bool shouldReclip(_NavClipper oldClipper) =>
      under != oldClipper.under || k != oldClipper.k;
}

/// Сдвиг заголовка при перетекании шапки (`TITLE_SHIFT`, app.js:832).
const double _kTitleShift = 80;

/// Страница листа: шапка (кнопки и заголовок) и тело.
///
/// Раскладка с доски: шапка 64, слева круглая «Назад» на вложенных страницах (на корневой место
/// пусто), справа [actions] и круглая «Закрыть», заголовок по центру в одну строку с
/// многоточием. Тело начинается на 4 ниже шапки; при [bodyUnderHeader] тело занимает весь лист, а
/// шапка лежит поверх (отступ сверху берите из [Ios27SheetScope.headerInset]).
///
/// На переходе между страницами тело едет и обрезается (`slide`, `clipNav`), а шапка стоит на
/// месте и перетекает по `crossBar`: прежний заголовок уходит на 80 к прежней странице и гаснет за
/// 140 мс, новый приходит оттуда же с 90 мс задержки за 220 мс; кнопки, которые есть в обоих
/// состояниях, не двигаются, «Назад» появляется и пропадает угасанием.
///
/// Заголовок не масштабируется системным размером шрифта: высота шапки фиксирована.
class Ios27SheetScaffold extends StatelessWidget {
  const Ios27SheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions = const [],
    this.showClose = true,
    this.bodyUnderHeader = false,
    this.onTitleTap,
  });

  final String title;
  final Widget body;

  /// Левая кнопка вместо «Назад». На корневой странице без неё слева пусто.
  final Widget? leading;

  /// Кнопки справа, слева от «Закрыть».
  final List<Widget> actions;

  /// Круглая кнопка «Закрыть» справа.
  final bool showClose;

  final bool bodyUnderHeader;

  /// Нажатие на заголовок (5 быстрых касаний разблокируют режим разработчика в настройках).
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final info = _PageInfo.maybeOf(context);
    if (info == null) {
      return _compose(context, const _PageRole.idle(), 0, body);
    }
    return AnimatedBuilder(
      animation: info.state.listenable,
      child: body,
      builder: (context, child) => _compose(
        context,
        info.state.roleOf(info.entry),
        info.index,
        child!,
      ),
    );
  }

  Widget _compose(
    BuildContext context,
    _PageRole role,
    int index,
    Widget content,
  ) {
    final column = bodyUnderHeader
        ? content
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: kIos27SheetHeaderHeight),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: content,
                ),
              ),
            ],
          );

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        _bodyLayer(role, column),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kIos27SheetHeaderHeight,
          child: _header(context, role, index),
        ),
      ],
    );
  }

  /// Тело в переходе: сдвиг, прозрачность и обрезка. Состав обёрток один на все кадры, чтобы
  /// содержимое не пересоздавалось.
  Widget _bodyLayer(_PageRole role, Widget column) {
    var dx = 0.0;
    var opacity = 1.0;
    var clip = false;
    var under = false;
    var k = 0.0;
    switch (role.kind) {
      case _PageKind.idle:
      case _PageKind.hidden:
        break;
      case _PageKind.top:
        if (role.reduced) {
          opacity = role.u;
        } else {
          dx = 1 - role.u;
          clip = true;
          k = 1 - role.u;
        }
      case _PageKind.under:
        if (!role.reduced) {
          dx = -Ios27Motion.slideUnderFraction * role.u;
          opacity = 1 - (1 - Ios27Motion.slideUnderOpacity) * role.u;
          clip = true;
          under = true;
          k = role.u;
        }
    }
    return Opacity(
      opacity: opacity,
      child: FractionalTranslation(
        translation: Offset(dx, 0),
        child: ClipPath(
          clipper: _NavClipper(under: under, k: k),
          clipBehavior: clip ? Clip.antiAlias : Clip.none,
          child: column,
        ),
      ),
    );
  }

  Widget _header(BuildContext context, _PageRole role, int index) {
    final scope = Ios27SheetScope.maybeOf(context);
    final colors = ios27ColorsFor(context);
    final l10n = AppLocalizations.of(context);
    final isNew = role.isNew;
    final dir = role.push ? 1.0 : -1.0;
    final ms = role.hMs;

    // Заголовки: прежний гаснет за 140 мс и уходит к прежней странице, новый проявляется за
    // 220 мс после паузы 90 мс. Без паузы на кадре 60 мс оба читались бы один поверх другого.
    final double titleOpacity;
    final double titleDx;
    if (role.idle) {
      titleOpacity = 1;
      titleDx = 0;
    } else if (role.reduced) {
      titleOpacity = isNew ? role.hFraction : 1 - role.hFraction;
      titleDx = 0;
    } else {
      final moved =
          Ios27SpringCurve(Ios27Motion.springSmooth).transform(role.hFraction);
      if (isNew) {
        titleOpacity =
            Curves.easeOut.transform(((ms - 90) / 220).clamp(0.0, 1.0));
        titleDx = dir * _kTitleShift * (1 - moved);
      } else {
        titleOpacity = 1 - Curves.easeOut.transform((ms / 140).clamp(0.0, 1.0));
        titleDx = -dir * _kTitleShift * moved;
      }
    }

    // «Назад»: есть в обоих состояниях — стоит на месте, только в одном — угасает за 180 мс.
    double backOpacity({required bool customLeading}) {
      if (role.idle) return 1;
      final fade = Curves.easeOut.transform((ms / 180).clamp(0.0, 1.0));
      if (customLeading) return isNew ? 1 : 0;
      if (isNew) {
        final oldIndex = role.push ? index - 1 : index + 1;
        return oldIndex > 0 ? 1 : fade;
      }
      final newIndex = role.push ? index + 1 : index - 1;
      return newIndex > 0 ? 0 : 1 - fade;
    }

    final customLeading = leading != null;
    final left = leading ??
        (index > 0
            ? Ios27SheetCircleButton(
                key: const ValueKey<String>('ios27.sheet.back'),
                icon: Ios27IconName.left,
                label: l10n.m3eA11yBack,
                onPressed: () => Ios27SheetNavigator.pop(context),
              )
            : null);
    final rightCount = actions.length + (showClose ? 1 : 0);
    // Заголовок центрируется между кнопками: поля равны, чтобы он не уезжал вбок.
    final side = 16.0 + math.max(rightCount, 1) * (kIos27SheetButtonSize + 8);
    final titleInset = math.max(76.0, side);

    Widget heading = Semantics(
      header: true,
      namesRoute: index == 0,
      child: MediaQuery.withNoTextScaling(
        child: Text(
          title,
          key: const ValueKey<String>('ios27.sheet.title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: ios27Text(
            context,
            Ios27Text.headline,
            color: colors.palette.glassLabel,
          ),
        ),
      ),
    );
    if (onTitleTap != null) {
      heading = Semantics(
        identifier: 'dw_settings_title',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTitleTap,
          child: heading,
        ),
      );
    }

    final bar = SizedBox(
      height: kIos27SheetHeaderHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: scope?.dragUpdate,
        onVerticalDragEnd: scope?.dragEnd,
        child: Stack(
          children: [
            Positioned(
              left: titleInset,
              right: titleInset,
              top: 25,
              height: 22,
              child: Opacity(
                opacity: titleOpacity,
                child: Transform.translate(
                  offset: Offset(titleDx, 0),
                  child: heading,
                ),
              ),
            ),
            if (left != null)
              Positioned(
                left: 16,
                top: 14,
                child: Opacity(
                    opacity: backOpacity(customLeading: customLeading),
                    child: left),
              ),
            if (rightCount > 0)
              Positioned(
                right: 16,
                top: 14,
                // Общие кнопки справа не двигаются: рисует их новая страница, прежняя прячет.
                child: Opacity(
                  opacity: isNew ? 1 : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final a in actions) ...[a, const SizedBox(width: 8)],
                      if (showClose)
                        Ios27SheetCircleButton(
                          key: const ValueKey<String>('ios27.sheet.close'),
                          icon: Ios27IconName.x,
                          label: l10n.close,
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Уходящая шапка не принимает нажатий и не читается программой чтения экрана.
    final settledOrNew = role.idle || isNew;
    return ExcludeSemantics(
      excluding: !settledOrNew,
      child: IgnorePointer(ignoring: !settledOrNew, child: bar),
    );
  }
}

/// Круглая стеклянная кнопка шапки листа: «Закрыть» и «Назад» (`circle-btn`, 44, значок 18 с
/// обводкой 2.4). Вложенное стекло: кнопка сидит на стекле листа.
class Ios27SheetCircleButton extends StatelessWidget {
  const Ios27SheetCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Ios27IconName icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ios27ColorsFor(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: kIos27SheetButtonSize,
          height: kIos27SheetButtonSize,
          child: Ios27Glass(
            nested: true,
            child: Center(
              child: Ios27Icon.spec(
                icon,
                Ios27IconSpecs.sheetButton,
                color: colors.palette.glassLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
