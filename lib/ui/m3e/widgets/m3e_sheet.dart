import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../../../l10n/l10n.dart';
import '../symbols.g.dart';
import '../theme/m3e_colors_for.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_symbol.dart';

/// Показывает модальный нижний лист M3E поверх root-навигатора.
///
/// Лист доски (`.dr-sheet` в android.css): верхние углы 28, ручка 32×4 в строке 48,
/// не выше экрана минус 72 dp, затемнение scrim 32 %. Закрывается по scrim, системной
/// кнопке «Назад» и свайпом вниз за ручку или заголовок. [builder] обычно возвращает
/// [M3eSheetScaffold] или [M3eSheetStack] с [M3eSheetScaffold] внутри; закрыть изнутри можно
/// `Navigator.of(context).pop(value)`.
///
/// Тема M3E ([M3eColors]) и `Theme` переносятся в маршрут явно: маршрут живёт в
/// root-навигаторе, который стоит выше `M3eThemeScope` экрана.
Future<T?> showM3eSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  M3eColors? colors,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(
    _M3eSheetRoute<T>(
      builder: builder,
      // Контекст корневого навигатора стоит выше M3eThemeScope: без явных цветов
      // `M3eColors.of` там падал, и автопредложение обновления не показывалось.
      colors: colors ?? m3eColorsFor(context),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      reduced: MediaQuery.disableAnimationsOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      dismissible: dismissible,
    ),
  );
}

/// Порог закрытия свайпом: у доски перетаскивания нет, взяты значения Compose
/// `ModalBottomSheet` (positionalThreshold 56 dp, velocityThreshold 125 dp/с).
const double kM3eSheetDismissDistance = 56;
const double kM3eSheetDismissVelocity = 125;

/// Отступ листа от верха экрана (`max-height: calc(100% - 72px)`).
const double kM3eSheetTopGap = 72;

class _M3eSheetRoute<T> extends PopupRoute<T> {
  _M3eSheetRoute({
    required this.builder,
    required this.colors,
    required this.themes,
    required this.reduced,
    required this.barrierLabel,
    required this.dismissible,
  });

  /// `false` — лист нельзя убрать касанием затемнения и свайпом (обязательное
  /// обновление: у него нет «Позже»).
  final bool dismissible;
  final WidgetBuilder builder;
  final M3eColors colors;
  final CapturedThemes themes;
  final bool reduced;

  @override
  final String barrierLabel;

  // Затемнение рисует сам лист (ключ `m3e.scrim`), чтобы оно шло по кривой листа.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  // Вход 400 мс emphasized-decelerate, выход 200 мс accelerate (`dr-sheet-in/out`);
  // при отключённых анимациях только прозрачность 150 мс.
  @override
  Duration get transitionDuration =>
      reduced ? M3eDuration.short3 : M3eDuration.medium4;

  @override
  Duration get reverseTransitionDuration =>
      reduced ? M3eDuration.short3 : M3eDuration.short4;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      themes.wrap(
        M3eColors(
          scheme: colors.scheme,
          home: colors.home,
          brightness: colors.brightness,
          // Режим «без анимаций» берётся при показе: root-навигатор стоит выше экрана,
          // который его переопределил, и сам об этом не знает.
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: Material(
              type: MaterialType.transparency,
              child: _SheetHost(route: this),
            ),
          ),
        ),
      );
}

/// Жест перетаскивания, который лист отдаёт ручке и заголовку.
class _DragScope extends InheritedWidget {
  const _DragScope({
    required this.onUpdate,
    required this.onEnd,
    required super.child,
  });

  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  static _DragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DragScope>();

  @override
  bool updateShouldNotify(_DragScope old) => false;
}

class _DragArea extends StatelessWidget {
  const _DragArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final drag = _DragScope.maybeOf(context);
    if (drag == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => drag.onUpdate(d.delta.dy),
      onVerticalDragEnd: (d) => drag.onEnd(d.velocity.pixelsPerSecond.dy),
      child: child,
    );
  }
}

class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.route});

  final _M3eSheetRoute<dynamic> route;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost>
    with SingleTickerProviderStateMixin {
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: widget.route.animation!,
    curve:
        widget.route.reduced ? Curves.linear : M3eEasing.emphasizedDecelerate,
    reverseCurve:
        widget.route.reduced ? Curves.linear : M3eEasing.emphasizedAccelerate,
  );

  /// Смещение вниз от перетаскивания в dp. После закрытия не сбрасывается: лист
  /// доезжает вниз с того места, где его отпустили, а не прыгает вверх.
  double _drag = 0;
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    // Не lazy: иначе первое обращение случится в dispose, когда тикер уже не создать.
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _drag = _settle.value));
  }

  @override
  void dispose() {
    _settle.dispose();
    _curve.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.route.isCurrent) Navigator.of(context).pop();
  }

  void _onDrag(double dy) {
    if (!widget.route.dismissible) return;
    _settle.stop();
    setState(() => _drag = (_drag + dy).clamp(0, double.infinity));
  }

  void _onDragEnd(double velocity) {
    if (!widget.route.dismissible) return;
    if (_drag > kM3eSheetDismissDistance ||
        velocity > kM3eSheetDismissVelocity) {
      _close();
      return;
    }
    if (_drag == 0) return;
    if (widget.route.reduced) {
      setState(() => _drag = 0);
      return;
    }
    _settle.value = _drag;
    _settle.animateWith(
      SpringSimulation(M3eSpring.defaultSpatial.description, _drag, 0, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final media = MediaQuery.of(context);
    final reduced = widget.route.reduced;

    final sheet = _DragScope(
      onUpdate: _onDrag,
      onEnd: _onDragEnd,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Material(
          key: const ValueKey<String>('m3e.sheet'),
          color: scheme.surfaceContainerLow,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          elevation: M3eElevation.level1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: M3eShapeAsymmetric.extraLargeTop.borderRadius,
          ),
          // Лист заходит под жестовую полосу, а содержимое отступает от неё; клавиатура
          // (она перекрывает полосу) поднимает содержимое выше, поэтому берём большее из двух.
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  math.max(media.viewPadding.bottom, media.viewInsets.bottom),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _DragArea(child: _Handle()),
                Flexible(child: Builder(builder: widget.route.builder)),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final a = _curve.value.clamp(0.0, 1.0);
        final h = media.size.height;
        final dragShare = (_drag / h).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: widget.route.barrierLabel,
                onTap: widget.route.dismissible ? _close : null,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey<String>('m3e.scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.route.dismissible ? _close : null,
                  child: ColoredBox(
                    color: scheme.scrim.withValues(
                      alpha: 0.32 * a * (1 - dragShare),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: h - kM3eSheetTopGap,
                ),
                child: reduced
                    ? Opacity(opacity: a, child: child)
                    : FractionalTranslation(
                        translation: Offset(0, 1 - a),
                        child: child,
                      ),
              ),
            ),
          ],
        );
      },
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: sheet,
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    final onVariant = M3eColors.of(context).scheme.onSurfaceVariant;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Center(
        child: ExcludeSemantics(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: onVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран внутри листа: заголовок, прокручиваемое тело и необязательный [footer].
///
/// Повтор `.dr-sheet__head` и `.dr-sheet__view`: заголовок title-large (Onest) в одну
/// строку с многоточием, под ним тело с полями 8/16/16. [footer] стоит в конце той же
/// прокручиваемой области через 24 dp, как `.dr-sheet__actions` доски (кнопки «Добавить»,
/// «Позже / Установить»).
///
/// Внутри [M3eSheetStack] кнопка «Назад» появляется сама, когда в стеке больше одного
/// экрана, и снимает верхний экран; без стека задайте [canBack] и [onBack].
class M3eSheetScaffold extends StatelessWidget {
  const M3eSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.canBack,
    this.onBack,
    this.footer,
    this.horizontalPadding = 16,
  });

  final String title;
  final Widget body;

  /// `null` — автоматически по глубине [M3eSheetStack]; `true` и `false` задают явно.
  final bool? canBack;

  /// По умолчанию `pop` стека, вне стека закрытие листа.
  final VoidCallback? onBack;
  final Widget? footer;

  /// Боковые поля тела; лист обновления на доске держит 24.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final stack = M3eSheetStack.maybeOf(context);
    final back = canBack ?? (stack != null && stack.depth > 1);
    final onBackTap = onBack ??
        (stack != null && stack.depth > 1
            ? stack.pop
            : () => Navigator.of(context).maybePop());
    final dir = _StackScope.maybeOf(context)?.direction ?? _AxisDir.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DragArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsets.fromLTRB(back ? 8 : 24, 0, 24, 8),
              child: Row(
                children: [
                  if (back) ...[
                    _SheetBackButton(onPressed: onBackTap),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        title,
                        key: const ValueKey<String>('m3e.sheet.title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: m3eTextStyle(
                          M3eType.titleLarge,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Flexible(
          child: _AxisIn(
            direction: dir,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  body,
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: footer,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Кнопка-значок 40 «Назад» (`iconBtn('pop', 'arrow_back')` доски): без заливки,
/// значок onSurfaceVariant.
class _SheetBackButton extends StatelessWidget {
  const _SheetBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = M3eColors.of(context).scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      label: AppLocalizations.of(context).m3eA11yBack,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        key: const ValueKey<String>('m3e.sheet.back'),
        dimension: 40,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            splashFactory: InkRipple.splashFactory,
            highlightColor: Colors.transparent,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return color.withValues(alpha: M3eState.pressed);
              }
              if (states.contains(WidgetState.focused)) {
                return color.withValues(alpha: M3eState.focus);
              }
              if (states.contains(WidgetState.hovered)) {
                return color.withValues(alpha: M3eState.hover);
              }
              return null;
            }),
            child: Center(
              child: M3eSymbolIcon(M3eSymbol.arrowBack, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── Стек экранов внутри листа ─────────────

enum _AxisDir { none, forward, back }

/// Управление стеком экранов листа: `M3eSheetStack.of(context)`.
abstract interface class M3eSheetStackController {
  /// Сколько экранов в стеке; на корневом 1.
  int get depth;

  /// Открывает экран поверх текущего (вход справа). Строитель должен вернуть
  /// [M3eSheetScaffold].
  void push(WidgetBuilder page);

  /// Снимает верхний экран (вход предыдущего слева); на корневом ничего не делает.
  void pop();
}

class _StackScope extends InheritedWidget {
  const _StackScope({
    required this.controller,
    required this.depth,
    required this.direction,
    required super.child,
  });

  final M3eSheetStackController controller;
  final int depth;
  final _AxisDir direction;

  static _StackScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StackScope>();

  @override
  bool updateShouldNotify(_StackScope old) =>
      depth != old.depth || direction != old.direction;
}

/// Стек экранов в одном листе: `push` и `pop` меняют содержимое без нового листа.
///
/// Показывается только верхний экран, прежний выбрасывается, как у `sheetHtml()` доски:
/// высота листа сразу подстраивается, а тело нового экрана выезжает по оси X
/// (30 dp, 300 мс emphasized-decelerate, при отключённых анимациях без движения).
/// Системная «Назад» сначала снимает верхний экран и только на корневом закрывает лист.
class M3eSheetStack extends StatefulWidget {
  const M3eSheetStack({super.key, required this.root});

  /// Корневой экран.
  final WidgetBuilder root;

  static M3eSheetStackController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'Нет M3eSheetStack выше по дереву');
    return controller!;
  }

  static M3eSheetStackController? maybeOf(BuildContext context) =>
      _StackScope.maybeOf(context)?.controller;

  @override
  State<M3eSheetStack> createState() => _M3eSheetStackState();
}

class _M3eSheetStackState extends State<M3eSheetStack>
    implements M3eSheetStackController {
  /// Экран и его уникальный номер: по номеру новый экран получает новое состояние,
  /// и анимация входа проигрывается заново.
  late final List<(int, WidgetBuilder)> _pages = [(0, widget.root)];
  int _nextId = 1;
  _AxisDir _dir = _AxisDir.none;

  @override
  int get depth => _pages.length;

  @override
  void push(WidgetBuilder page) {
    setState(() {
      _pages.add((_nextId++, page));
      _dir = _AxisDir.forward;
    });
  }

  @override
  void pop() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeLast();
      _dir = _AxisDir.back;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (id, page) = _pages.last;
    return PopScope(
      canPop: _pages.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pop();
      },
      child: _StackScope(
        controller: this,
        depth: _pages.length,
        direction: _dir,
        child: KeyedSubtree(
          key: ValueKey<int>(id),
          child: Builder(builder: page),
        ),
      ),
    );
  }
}

/// Вход тела экрана по оси X: прозрачность 0→1 и сдвиг 30 dp (`dr-axis-fwd/back`).
class _AxisIn extends StatefulWidget {
  const _AxisIn({required this.direction, required this.child});

  final _AxisDir direction;
  final Widget child;

  @override
  State<_AxisIn> createState() => _AxisInState();
}

class _AxisInState extends State<_AxisIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: M3eDuration.medium2,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: M3eEasing.emphasizedDecelerate,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Один раз при создании экрана: MediaQuery в initState читать нельзя.
    if (_started) return;
    _started = true;
    if (widget.direction != _AxisDir.none &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.direction == _AxisDir.back ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        key: const ValueKey<String>('m3e.sheet.axis.fade'),
        opacity: _curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          key: const ValueKey<String>('m3e.sheet.axis'),
          offset: Offset(sign * 30 * (1 - _curve.value), 0),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
