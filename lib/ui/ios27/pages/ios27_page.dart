// Страница iOS-редизайна: полноэкранный экран с крупным заголовком, круглой кнопкой «Назад» и мягким краем прокрутки
// (доска `.page`, app.css:136-170, app.js:593-650).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27Text;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Высота панели под строкой состояния (`.page__nav`, app.css:153).
const double kIos27PageNavHeight = 44;

/// Нижний отступ прокрутки (`.page__scroll{padding:92px 0 40px}`, app.css:139).
const double kIos27PageBottomPadding = 40;

/// Ширина полосы у левого края, с которой начинается жест «Назад» (UIKit: ~20 pt).
const double kIos27PageEdgeWidth = 20;

/// Открывает страницу iOS-редизайна на навигаторе [context] и возвращает результат закрытия.
///
/// **Как пользоваться (экраны волны Э).** Вызов берёт любой контекст, в том числе выше области
/// темы (контекст корневого навигатора): страница несёт собственную тему, как лист
/// (`showIos27Sheet`).
///
/// * [builder] строит ТЕЛО страницы (колонка групп под крупным заголовком); прокрутку, заголовок,
///   кнопку «Назад» и край рисует [Ios27Page].
/// * [title] — и крупный заголовок, и маленький заголовок панели. Строка снимается один раз при
///   открытии; если страница должна переименоваться при смене языка, задайте вместо неё
///   [titleBuilder]: он вызывается в контексте самой страницы при каждой сборке, поэтому следует
///   за `Localizations` (страница, уже лежащая в стопке, тоже перечитывает заголовок). Нужен
///   ровно один из двух.
/// * [trailing] — виджет справа в панели (кнопка 44×44).
/// * [onTitleTap] и [titleSemanticsIdentifier] — нажатие на крупный заголовок (настройки: `dw_settings_title`).
/// * [largeTitle] `false` и [collapseAnchor] — страница «О программе»: своя шапка вместо
///   крупного заголовка, маленький заголовок проявляется, когда низ [collapseAnchor] ушёл под панель.
/// * Закрыть программно: `Navigator.of(context).pop(результат)`; системный свайп от левого
///   края и кнопка «Назад» закрывают сами (решение владельца В3).
/// * Переход: въезд справа пружиной `smooth` (735 мс), страница под ней (если это тоже
///   страница [Ios27PageRoute]) уходит на 30 % влево и темнеет до 90 % (app.css:142-150);
///   «Уменьшить движение» — только угасание 100 мс.
Future<T?> pushIos27Page<T>(
  BuildContext context, {
  String? title,
  String Function(BuildContext context)? titleBuilder,
  required WidgetBuilder builder,
  Widget? trailing,
  VoidCallback? onTitleTap,
  String? titleSemanticsIdentifier,
  bool largeTitle = true,
  GlobalKey? collapseAnchor,
}) {
  assert(
    (title == null) != (titleBuilder == null),
    'pushIos27Page: нужен ровно один из title и titleBuilder',
  );
  final navigator = Navigator.of(context);
  return navigator.push<T>(
    Ios27PageRoute<T>(
      builder: (c) => Ios27Page(
        title: titleBuilder != null ? titleBuilder(c) : title!,
        trailing: trailing,
        onTitleTap: onTitleTap,
        titleSemanticsIdentifier: titleSemanticsIdentifier,
        largeTitle: largeTitle,
        collapseAnchor: collapseAnchor,
        child: Builder(builder: builder),
      ),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      reduced: MediaQuery.disableAnimationsOf(context),
    ),
  );
}

/// Положение страницы `0..1` (1 — на месте). Жест пальцем ведёт её линейно, иначе пружина `smooth`.
double _position(
  Animation<double> animation,
  Curve spring, {
  required bool linear,
}) {
  if (linear) {
    return animation.value;
  }
  // На закрытии пружина идёт обратно (`page-out`), как у листа.
  return animation.status == AnimationStatus.reverse
      ? 1 - spring.transform(1 - animation.value)
      : spring.transform(animation.value);
}

/// Маршрут страницы; открывайте через [pushIos27Page].
class Ios27PageRoute<T> extends PageRoute<T> {
  Ios27PageRoute({
    required this.builder,
    required this.themes,
    required this.reduced,
    super.settings,
  });

  final WidgetBuilder builder;
  final CapturedThemes themes;
  final bool reduced;

  static final Curve _spring = Ios27SpringCurve(Ios27Motion.springSmooth);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => reduced
      ? const Duration(milliseconds: 100)
      : Ios27Motion.springSmooth.settle;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  /// Жест «Назад» разрешён, только когда страница на месте и закрываться ей можно.
  bool get _canSwipeBack =>
      isCurrent &&
      !isFirst &&
      popDisposition != RoutePopDisposition.doNotPop &&
      navigator != null &&
      !navigator!.userGestureInProgress &&
      controller?.status == AnimationStatus.completed;

  bool _swiping = false;

  // Навигатор, которому сказали о начале жеста, пока жест не закрыт: в `dispose` маршрута
  // `navigator` уже `null`.
  NavigatorState? _gestureNavigator;

  void _swipeStart() {
    _gestureNavigator = navigator;
    navigator!.didStartUserGesture();
    _swiping = true;
  }

  /// Закрывает жест у навигатора ровно один раз (повторный вызов ничего не делает).
  void _stopGesture() {
    final nav = _gestureNavigator;
    _gestureNavigator = null;
    if (nav != null && nav.mounted) {
      nav.didStopUserGesture();
    }
  }

  /// Маршрут убрали из стопки посреди жеста (`removeRoute`, `pushReplacement`, `popUntil`): виджет
  /// полосы исчезает раньше маршрута, и его отмена жеста запускает доводку анимации, которая
  /// до конца не доживёт (контроллер освобождается). Без этого `userGestureInProgress`
  /// навигатора остаётся истинным, и следующие жесты «Назад» молча не стартуют
  /// (`_canSwipeBack` смотрит на него).
  @override
  void dispose() {
    _swiping = false;
    _stopGesture();
    super.dispose();
  }

  void _swipeUpdate(double delta, double width) {
    controller!.value -= delta / width;
  }

  /// Конец жеста: дальше пол-экрана или бросок вправо закрывают страницу, иначе она возвращается.
  void _swipeEnd(double velocity) {
    final c = controller!;
    final fling = velocity.abs() > 700;
    final pop = fling ? velocity > 0 : c.value < 0.5;
    final nav = navigator!;
    _swiping = false;
    if (pop) {
      nav.pop();
      if (c.isAnimating) {
        c.animateBack(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Ios27Motion.easeOut,
        );
      }
    } else {
      c.animateTo(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Ios27Motion.easeOut,
      );
    }
    // Жест считается идущим, пока страница доезжает: иначе положение скакнуло бы с линейного
    // на пружинное.
    if (c.isAnimating) {
      late AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          c.removeStatusListener(listener);
          _stopGesture();
        }
      };
      c.addStatusListener(listener);
    } else {
      _stopGesture();
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      themes.wrap(
        Ios27ThemeScope(
          // MediaQuery читаем НИЖЕ скоупа, иначе вернётся масштаб текста предка (ThemeManager)
          // вместо системного Dynamic Type.
          child: Builder(
            builder: (scopeContext) => MediaQuery(
              data: MediaQuery.of(scopeContext)
                  .copyWith(disableAnimations: reduced),
              child: Material(
                type: MaterialType.transparency,
                child: _SwipeBackEdge(
                  route: this,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // «Уменьшить движение» (app.css:609): сдвиги выключены, страница лишь проявляется.
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final gesture = navigator?.userGestureInProgress ?? false;
        final p = _position(animation, _spring, linear: gesture);
        final s = _position(secondaryAnimation, _spring, linear: gesture);
        // Страница под новой уходит влево на `slideUnderFraction` (30 %) и темнеет до 90 %.
        Widget result = FractionalTranslation(
          translation: Offset((rtl ? -1 : 1) * ((1 - p) - 0.3 * s), 0),
          child: child,
        );
        if (s > 0.001) {
          final k = 1 - 0.1 * s.clamp(0.0, 1.0);
          result = ColorFiltered(
            colorFilter: ColorFilter.matrix(<double>[
              k, 0, 0, 0, 0, //
              0, k, 0, 0, 0, //
              0, 0, k, 0, 0, //
              0, 0, 0, 1, 0, //
            ]),
            child: result,
          );
        }
        return result;
      },
    );
  }
}

/// Полоса у левого края, по которой страницу смахивают вправо.
class _SwipeBackEdge extends StatelessWidget {
  const _SwipeBackEdge({required this.route, required this.child});

  final Ios27PageRoute<dynamic> route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: kIos27PageEdgeWidth,
          child: GestureDetector(
            key: const ValueKey<String>('page.swipeBack'),
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            onHorizontalDragStart: (_) {
              if (route._canSwipeBack) {
                route._swipeStart();
              }
            },
            onHorizontalDragUpdate: (d) {
              if (route._swiping) {
                route._swipeUpdate(sign * d.delta.dx, width);
              }
            },
            onHorizontalDragEnd: (d) {
              if (route._swiping) {
                route._swipeEnd(sign * d.velocity.pixelsPerSecond.dx);
              }
            },
            onHorizontalDragCancel: () {
              if (route._swiping) {
                route._swipeEnd(0);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Страница с панелью: круглая стеклянная кнопка «Назад», маленький заголовок по центру, мягкий
/// край прокрутки и прокручиваемое тело с крупным заголовком (доска `page()`, app.js:593-639).
///
/// Ключи частей совпадают с именами элементов `layout.json` доски: `page`, `page.nav`,
/// `page.back`, `page.small`, `page.title`, чтобы тесты и экраны могли мерить их по эталону.
///
/// * [title] — текст заголовка; [largeTitle] `false` убирает крупный заголовок (страница
///   «О программе» начинается со своей шапки): тогда маленький заголовок появляется, только если
///   задан [collapseAnchor] (`about__name` доски, app.js:644-651), иначе остаётся скрытым.
/// * [child] — тело под заголовком (группы списка); [bottomPadding] — отступ под ним (плюс низ экрана).
/// * [collapseAnchor] — ключ виджета, низ которого, уйдя под панель, проявляет маленький заголовок.
/// * [trailing] — виджет справа в панели; [onBack] заменяет `Navigator.maybePop`.
/// * Верхний отступ берёт у системы (`MediaQuery.padding.top`; на доске строка состояния 48).
///
/// Панель стоит над прокруткой, а не в ней (UINavigationBar); край под ней (`.page__edge`)
/// виден, когда прокрутка больше 0,5 px; при Reduce Transparency он плотная полоса 92 высотой
/// (app.css:652). Размытие края доски (blur 6 за градиентом) не повторяется: сырой
/// `BackdropFilter` запрещён правилами, а градиент 60 % → 0 даёт тот же видимый эффект.
class Ios27Page extends StatefulWidget {
  const Ios27Page({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTitleTap,
    this.titleSemanticsIdentifier,
    this.onBack,
    this.largeTitle = true,
    this.collapseAnchor,
    this.scrollController,
    this.bottomPadding = kIos27PageBottomPadding,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTitleTap;

  /// `Semantics.identifier` крупного заголовка (настройки: `dw_settings_title`).
  final String? titleSemanticsIdentifier;
  final VoidCallback? onBack;
  final bool largeTitle;
  final GlobalKey? collapseAnchor;
  final ScrollController? scrollController;
  final double bottomPadding;

  @override
  State<Ios27Page> createState() => _Ios27PageState();
}

class _Ios27PageState extends State<Ios27Page> {
  static const double _titlePaddingBottom = 12;

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _scrollKey = GlobalKey();
  ScrollController? _own;
  bool _scrolled = false;
  bool _collapsed = false;

  ScrollController get _controller =>
      widget.scrollController ?? (_own ??= ScrollController());

  @override
  void initState() {
    super.initState();
    // Первый расчёт после раскладки: низ заголовка известен только по готовому RenderBox.
    WidgetsBinding.instance.addPostFrameCallback((_) => _look());
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// Вызывает [_look] не посреди раскладки: `ScrollEndNotification` приходит и из `performLayout`
  /// (viewport поправил положение, когда высота содержимого изменилась во время инерции), а там
  /// чтение `RenderBox.size` заголовка и `setState` ломают debug-проверки. В кадре, до его
  /// конца, расчёт переносится на post-frame.
  void _lookSafely() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _look());
      return;
    }
    _look();
  }

  /// `navLook` доски (app.js:645-651): край виден при прокрутке > 0,5; маленький заголовок
  /// проявляется, когда низ крупного (без нижнего поля 12) ушёл под панель.
  void _look() {
    if (!mounted) {
      return;
    }
    final c = _controller;
    final y = c.hasClients ? c.offset : 0.0;
    final scrolled = y > 0.5;
    var collapsed = false;
    final anchorKey =
        widget.collapseAnchor ?? (widget.largeTitle ? _titleKey : null);
    final box = anchorKey?.currentContext?.findRenderObject();
    final host = _scrollKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && host is RenderBox) {
      final bottomInPage =
          box.localToGlobal(Offset(0, box.size.height), ancestor: host).dy;
      final trimmed = bottomInPage -
          (identical(anchorKey, _titleKey) ? _titlePaddingBottom : 0);
      final safeTop = MediaQuery.paddingOf(context).top;
      collapsed = trimmed <= safeTop + kIos27PageNavHeight;
    }
    if (scrolled != _scrolled || collapsed != _collapsed) {
      setState(() {
        _scrolled = scrolled;
        _collapsed = collapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = Ios27Colors.of(context).palette;
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final navBottom = safeTop + kIos27PageNavHeight;
    // Боковые safe area: на iPhone Duo система уводит Dynamic Island и строку состояния в
    // вертикальную колонку вдоль торцевого края (HIG «Designing for iPhone Duo»). Фон, край
    // прокрутки и область жеста остаются на весь экран, а содержимое и кнопки панели стоят внутри.
    final safeLeft = media.padding.left;
    final safeRight = media.padding.right;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final safeStart = rtl ? safeRight : safeLeft;
    final safeEnd = rtl ? safeLeft : safeRight;
    final fade = media.disableAnimations
        ? const Duration(milliseconds: 100)
        : const Duration(milliseconds: 150);

    Widget title = Padding(
      key: _titleKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, _titlePaddingBottom),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          widget.title,
          style: ios27Text(context, Ios27Text.large),
        ),
      ),
    );
    if (widget.onTitleTap != null) {
      title = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTitleTap,
        child: title,
      );
    }
    title = Semantics(
      header: true,
      container: widget.titleSemanticsIdentifier != null,
      identifier: widget.titleSemanticsIdentifier,
      child: KeyedSubtree(
        key: const ValueKey<String>('page.title'),
        child: title,
      ),
    );

    return ColoredBox(
      key: const ValueKey<String>('page'),
      color: palette.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.depth == 0) {
                  _lookSafely();
                }
                return false;
              },
              child: SingleChildScrollView(
                key: _scrollKey,
                controller: _controller,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  left: safeLeft,
                  top: navBottom,
                  right: safeRight,
                  bottom: widget.bottomPadding + media.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.largeTitle) title,
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
          // Край прокрутки: под панелью, над содержимым.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolled ? 1 : 0,
                duration: fade,
                curve: Ios27Motion.easeOut,
                child: Ios27A11yBuilder(
                  builder: (context, a11y) => _PageEdge(
                    key: const ValueKey<String>('page.edge'),
                    color: palette.bg,
                    solid: a11y.reduceTransparency,
                    safeTop: safeTop,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey<String>('page.nav'),
            left: 0,
            right: 0,
            top: safeTop,
            height: kIos27PageNavHeight,
            child: Stack(
              children: [
                // Маленький заголовок: поля 76 под кнопки с обеих сторон; высота панели
                // фиксирована, поэтому системный размер шрифта его не раздувает.
                Positioned(
                  left: 76 + safeLeft,
                  right: 76 + safeRight,
                  top: 0,
                  bottom: 0,
                  child: KeyedSubtree(
                    key: const ValueKey<String>('page.small'),
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _collapsed ? 1 : 0,
                        duration: fade,
                        curve: Ios27Motion.easeOut,
                        child: MediaQuery.withNoTextScaling(
                          child: Center(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: ios27Text(context, Ios27Text.headline),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 16 + safeStart,
                  top: 0,
                  child: Ios27CircleButton.icon(
                    key: const ValueKey<String>('page.back'),
                    icon: Ios27IconName.left,
                    semanticLabel: l.m3eA11yBack,
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (widget.trailing != null)
                  PositionedDirectional(
                    end: 16 + safeEnd,
                    top: 0,
                    bottom: 0,
                    child: Center(child: widget.trailing),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Мягкий край: градиент цвета фона 60 % → 0 с маской `#000 40% → прозрачно` (app.css:161-166);
/// при Reduce Transparency плотная полоса 92 высотой (app.css:652).
class _PageEdge extends StatelessWidget {
  const _PageEdge({
    super.key,
    required this.color,
    required this.solid,
    required this.safeTop,
  });

  final Color color;
  final bool solid;
  final double safeTop;

  @override
  Widget build(BuildContext context) {
    // Высоты доски (112 и 92) отсчитаны от строки состояния 48; в приложении она другая.
    final height = (solid ? 92.0 : 112.0) - 48 + safeTop;
    if (solid) {
      return SizedBox(height: height, child: ColoredBox(color: color));
    }
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.6),
              color.withValues(alpha: 0.6),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.4, 1],
          ),
        ),
      ),
    );
  }
}
