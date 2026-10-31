// Алерт iOS-редизайна: стеклянная карточка по центру, заголовок, текст, капсулы действий (доска `.alert`, app.css:431-470).

import 'dart:math' as math;

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27Text, Ios27TextRole, Ios27Tokens;
import 'package:flutter/material.dart';

/// Ширина карточки (`.alert{width:300px}`).
const double kIos27AlertWidth = 300;

/// Высота капсулы действия (`.btn{height:48px}`).
const double kIos27AlertButtonHeight = 48;

/// Зазор между капсулами (`.alert__actions{gap:8px}`).
const double kIos27AlertActionsGap = 8;

/// Подпись капсулы: `font: 500 17px/22px` (app.css:462). Среди `.t-*` веса 500 нет, поэтому
/// своя роль.
const Ios27TextRole kIos27AlertButtonTextRole =
    Ios27TextRole(size: 17, lineHeight: 22, weight: 500, tracking: 0);

/// Длительность ухода алерта (`glass-alert-out 200ms`, app.css).
const Duration kIos27AlertLeave = Duration(milliseconds: 200);

/// Капсула действия: вложенное стекло высотой 48 с подписью.
///
/// Внутрь кладётся любая кнопка. [TextButtonTheme] ниже задаёт ей вид доски: подпись цвета
/// стекла, высота 48, поля 12. Так старые диалоги приложения, где действия уже `TextButton`,
/// получают iOS-вид без переписывания (шов `CommonDialog`).
class Ios27AlertActionSlot extends StatelessWidget {
  const Ios27AlertActionSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ios27ColorsFor(context);
    final style = TextButton.styleFrom(
      foregroundColor: colors.palette.glassLabel,
      minimumSize: const Size(0, kIos27AlertButtonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: ios27Text(
        context,
        kIos27AlertButtonTextRole,
        color: colors.palette.glassLabel,
      ),
    );
    return SizedBox(
      height: kIos27AlertButtonHeight,
      child: Ios27Glass(
        nested: true,
        child: TextButtonTheme(
          data: TextButtonThemeData(style: style),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

/// Готовая кнопка алерта: подпись в капсуле. [destructive] красит подпись в красный текст
/// на том же сером фоне (на доске `.btn--danger` без красной заливки).
class Ios27AlertButton extends StatelessWidget {
  const Ios27AlertButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = ios27ColorsFor(context);
    return Ios27AlertActionSlot(
      child: TextButton(
        onPressed: onPressed,
        style: destructive
            ? TextButton.styleFrom(foregroundColor: colors.palette.redText)
            : null,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Каркас алерта: заголовок, тело, ряд действий.
///
/// Раскладка с доски: поля `22 16 16`, заголовок и тело с боковыми отступами 6, тело на 8 ниже
/// заголовка, действия на 20 ниже тела. Две капсулы стоят в ряд поровну, одна занимает всю ширину,
/// три и больше идут столбиком.
///
/// Каркас не знает про окружение: цвета берёт из [Ios27Colors], поэтому его нужно открывать под
/// [Ios27ThemeScope]. Маршрут [showIos27Alert] и шов диалога это делают сами.
class Ios27Alert extends StatelessWidget {
  const Ios27Alert({
    super.key,
    this.title,
    required this.body,
    this.actions = const [],
    this.scrollBody = true,
    this.bodyPadding,
  });

  final String? title;

  /// Тело; в нём `DefaultTextStyle` уже задан как `.alert__text` (15/20, второй цвет стекла).
  final Widget body;

  /// Капсулы действий: [Ios27AlertButton] или любой виджет, который сам умеет быть кнопкой
  /// (его обернёт [Ios27AlertActionSlot]).
  final List<Widget> actions;

  /// Тело прокручивается, когда не помещается в экран. Диалог со своим скроллом выключает.
  final bool scrollBody;

  /// Боковые поля тела; по умолчанию 6, как у текста на доске.
  final EdgeInsetsGeometry? bodyPadding;

  @override
  Widget build(BuildContext context) {
    final colors = ios27ColorsFor(context);
    final media = MediaQuery.of(context);
    // Ширина считается от области между боковыми safe area (iPhone Duo), как и положение
    // карточки в маршруте [Ios27AlertRoute].
    final width = math.min(
      kIos27AlertWidth,
      media.size.width -
          media.padding.left -
          media.padding.right -
          2 * Ios27Tokens.margin,
    );
    final zoom = Ios27ZoomScope.maybeOf(context);
    final titleText = title;
    final Widget bodyBox = DefaultTextStyle(
      style: ios27Text(context, Ios27Text.subhead,
          color: colors.palette.glassLabel2),
      child: Padding(
        padding: bodyPadding ?? const EdgeInsets.symmetric(horizontal: 6),
        child: body,
      ),
    );

    final Widget? titleBox = titleText == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              titleText,
              // Слева, вровень с текстом: `.alert__title` без выравнивания по центру.
              textAlign: TextAlign.start,
              style: ios27Text(
                context,
                Ios27Text.headline,
                color: colors.palette.glassLabel,
              ),
            ),
          );
    final bodyGap = Padding(
      padding: EdgeInsets.only(top: titleBox != null ? 8 : 0),
      child: bodyBox,
    );

    final column = Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scrollBody)
            // Заголовок прокручивается вместе с текстом, как в UIAlertController: при крупном
            // шрифте он иначе съедает высоту, и капсулы действий уходят за край.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [if (titleBox != null) titleBox, bodyGap],
                ),
              ),
            )
          else ...[
            // Диалог со своей прокруткой тела: заголовок стоит на месте.
            if (titleBox != null) titleBox,
            Flexible(child: bodyGap),
          ],
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _ActionsLayout(actions: actions, innerWidth: width - 32),
            ),
        ],
      ),
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: titleText != null,
      label: titleText,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          // Высота считается от места, которое реально осталось: у карточки в обложке старых
          // диалогов `viewInsets` уже убраны из MediaQuery, а доступную область сужает отступ
          // под клавиатуру выше. Берём меньшее из двух, иначе карточка с клавиатурой растёт под
          // строку состояния.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final room = math.min(
                constraints.maxHeight,
                media.size.height - media.viewInsets.bottom,
              );
              final maxHeight = (room - 96).clamp(160.0, 9999.0);
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                // Алерт из кнопки растёт из неё (motion.js zoomIn): стекло и содержимое рисует
                // зум-кадр; без источника это обычное стекло карточки.
                child: zoom == null
                    ? Ios27Glass(
                        variant: Ios27GlassVariant.lg,
                        shape:
                            const Ios27GlassShape.rounded(Ios27Tokens.rAlert),
                        child: column,
                      )
                    : Ios27ZoomGlass(
                        timeline: zoom,
                        variant: Ios27GlassVariant.lg,
                        radius: Ios27Tokens.rAlert,
                        child: column,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActionsLayout extends StatelessWidget {
  const _ActionsLayout({required this.actions, required this.innerWidth});

  final List<Widget> actions;

  /// Ширина области действий (карточка без полей 16 с двух сторон).
  final double innerWidth;

  /// Подпись капсулы, если её можно прочитать из виджета: [Ios27AlertButton] или `TextButton`
  /// с `Text` внутри (так устроены действия старых диалогов). Иначе `null`.
  static String? _labelOf(Widget w) {
    if (w is Ios27AlertButton) {
      return w.label;
    }
    if (w is Ios27AlertActionSlot) {
      return _labelOf(w.child);
    }
    if (w is TextButton) {
      return _labelOf(w.child ?? const SizedBox.shrink());
    }
    if (w is Text) {
      return w.data;
    }
    return null;
  }

  /// Помещаются ли две капсулы в ряд: подпись в одну строку плюс поля 12 с двух сторон должны
  /// влезть в половину ширины. Мерим по тексту с тем же шрифтом и системным масштабом, как
  /// UIAlertController раскладывает кнопки столбиком, когда в ряд не выходит.
  bool _fitSideBySide(BuildContext context, int count) {
    final slot = (innerWidth - kIos27AlertActionsGap * (count - 1)) / count;
    final style = ios27Text(context, kIos27AlertButtonTextRole);
    final scaler = MediaQuery.textScalerOf(context);
    for (final a in actions) {
      final label = _labelOf(a);
      if (label == null) {
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final needed = painter.width + 24;
      painter.dispose();
      if (needed > slot) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final slots = [
      for (final a in actions)
        a is Ios27AlertButton || a is Ios27AlertActionSlot
            ? a
            : Ios27AlertActionSlot(child: a),
    ];
    if (slots.length == 2 && _fitSideBySide(context, 2)) {
      return Row(
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) const SizedBox(width: kIos27AlertActionsGap),
            Expanded(child: slots[i]),
          ],
        ],
      );
    }
    if (slots.length == 1) {
      return slots.first;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(height: kIos27AlertActionsGap),
          slots[i],
        ],
      ],
    );
  }
}

/// Обложка для старых диалогов приложения: те же `title`/`child`/`actions`, что у `CommonDialog`,
/// но вид алерта iOS. Шов `CommonDialog(useIos27:)` отдаёт сюда содержимое.
///
/// Свою тему-область ставит только когда её над диалогом нет, чтобы не перебить уже заданную.
class Ios27AlertSkin extends StatelessWidget {
  const Ios27AlertSkin({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.padding,
    this.overrideScroll = false,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool overrideScroll;

  @override
  Widget build(BuildContext context) {
    final alert = _SkinBody(
      title: title,
      actions: actions,
      padding: padding,
      overrideScroll: overrideScroll,
      child: child,
    );
    return Ios27Colors.maybeOf(context) == null
        ? Ios27ThemeScope(child: alert)
        : alert;
  }
}

class _SkinBody extends StatelessWidget {
  const _SkinBody({
    required this.title,
    required this.child,
    required this.actions,
    required this.padding,
    required this.overrideScroll,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool overrideScroll;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    // Красная кнопка старых диалогов берёт `colorScheme.error` (`--red`), а на доске
    // деструктивная подпись `--red-text`: он темнее и читается на сером фоне капсулы.
    final redText = ios27ColorsFor(context).palette.redText;
    // Клавиатуру считает сам алерт, один раз: поднимаем карточку и убираем inset у потомков
    // (урок 26: иначе поля внутри отступят второй раз).
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(error: redText),
      ),
      child: AnimatedPadding(
        duration: Ios27Motion.fade,
        curve: Ios27Motion.easeOut,
        padding: EdgeInsets.only(bottom: insets),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Center(
            child: Ios27Alert(
              title: title,
              scrollBody: !overrideScroll,
              bodyPadding: padding,
              actions: actions ?? const [],
              body: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Показывает [builder] как алерт доски: затемнение `--dim`, въезд пружиной (масштаб 1.08 → 1 с
/// появлением), уход за 200 мс (масштаб до 0.96 с угасанием).
///
/// Маршрут кладётся в корневой навигатор и несёт собственную [Ios27ThemeScope], поэтому его можно
/// открывать любым контекстом, в том числе выше области темы. Тему из контекста вызова
/// (`InheritedTheme`) и «Уменьшение движения» он забирает при открытии: корневой навигатор может
/// стоять выше `MediaQuery`/`Theme`, на которые опирается содержимое.
///
/// [dismissible] `false` запрещает закрытие тапом по затемнению и системным «назад» (урок 25);
/// закрыть можно только кнопкой изнутри.
///
/// [origin] — кнопка, из которой алерт вырастает и в которую втягивается при закрытии
/// (app.js 1263 `origin = {rect: srcBox(el)}`); без него остаётся въезд масштабом 1.08 → 1.
Future<T?> showIos27Alert<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  Ios27ZoomOrigin? origin,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final reduced = MediaQuery.disableAnimationsOf(context);
  return navigator.push<T>(
    Ios27AlertRoute<T>(
      builder: builder,
      dismissible: dismissible,
      // «Уменьшение движения» заменяет зум на угасание (motion.js reduce()).
      origin: reduced ? null : origin,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      reduced: reduced,
      dim: ios27ColorsFor(context).palette.dim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Маршрут алерта; открывайте через [showIos27Alert] (или `showCommonDialog` в шве состояния).
class Ios27AlertRoute<T> extends PopupRoute<T> {
  Ios27AlertRoute({
    required this.builder,
    required this.dismissible,
    required this.themes,
    required this.reduced,
    required this.dim,
    required this.barrierLabel,
    this.origin,
  });

  final WidgetBuilder builder;
  final bool dismissible;
  final CapturedThemes themes;
  final bool reduced;
  final Color dim;

  /// Кнопка-источник зума; `null` — прежний въезд.
  final Ios27ZoomOrigin? origin;

  /// Время зума; создаётся при установке маршрута, если есть [origin].
  Ios27ZoomTimeline? timeline;

  @override
  final String barrierLabel;

  static final Curve _enter = Ios27SpringCurve(Ios27Motion.springSmooth);

  @override
  Color get barrierColor => dim;

  @override
  bool get barrierDismissible => dismissible;

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
          : kIos27AlertLeave;

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
      // Втягивание идёт полную длину от места, где алерт сейчас (motion.js:136).
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
          // MediaQuery читаем НИЖЕ скоупа, иначе вернётся масштаб текста предка (ThemeManager)
          // вместо системного Dynamic Type.
          child: Builder(
            builder: (scopeContext) {
              final media = MediaQuery.of(scopeContext);
              return MediaQuery(
                data: media.copyWith(disableAnimations: reduced),
                // Затемнение остаётся на весь экран (его рисует барьер маршрута), а карточка
                // стоит по центру между боковыми safe area: на iPhone Duo торцевая колонка
                // Dynamic Island не должна закрывать край алерта. Отступы остаются в
                // `MediaQuery`: ширину карточки [Ios27Alert] считает из них же.
                child: Padding(
                  padding: EdgeInsets.only(
                    left: media.padding.left,
                    right: media.padding.right,
                  ),
                  child: _withZoom(
                    PopScope(
                      canPop: dismissible,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _withZoom(Widget child) {
    final zoom = timeline;
    return zoom == null ? child : Ios27ZoomScope(timeline: zoom, child: child);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced) {
      return FadeTransition(opacity: animation, child: child);
    }
    // С источником движение целиком у зум-кадра внутри алерта; обёртка только мешала бы.
    if (timeline != null) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final leaving = animation.status == AnimationStatus.reverse;
        final double scale;
        final double opacity;
        if (leaving) {
          // Уход идёт по ease-out от текущей точки к нулю: на доске это 200 мс, а не пружина.
          final eased = 1 - Ios27Motion.easeOut.transform(1 - animation.value);
          scale = 0.96 + 0.04 * eased;
          opacity = eased;
        } else {
          final spring = _enter.transform(animation.value);
          scale = 1.08 - 0.08 * spring;
          opacity = spring.clamp(0.0, 1.0);
        }
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
