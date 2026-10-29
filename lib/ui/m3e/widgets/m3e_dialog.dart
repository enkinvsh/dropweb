import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../color/color.dart' show M3eScheme;
import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_symbol.dart';

/// Кнопка диалога: подпись, значение, которое вернёт [showM3eDialog], и вид.
class M3eDialogAction<T> {
  const M3eDialogAction(this.label, this.value, {this.danger = false});

  final String label;
  final T value;

  /// Разрушительное действие: цвет error, но та же текстовая кнопка (`dr-danger`).
  final bool danger;
}

/// Текстовая ссылка под текстом диалога: открывает страницу, диалог не закрывает.
///
/// Нужна там, где полный текст живёт на странице (политика конфиденциальности), а в диалоге
/// только короткое раскрытие.
class M3eDialogLink {
  const M3eDialogLink(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

/// Показывает диалог M3E по центру экрана и возвращает [M3eDialogAction.value]
/// нажатой кнопки; `null`, если диалог закрыт по scrim или кнопкой «Назад».
///
/// Диалог доски (`.dr-dialog`): ширина 312, поля 24, угол 28, значок 24 по центру в цвете
/// secondary, заголовок headline-small по центру, текст по началу строки, кнопки справа:
/// отказ слева, подтверждение последним. Поэтому [actions] передавайте в порядке слева направо.
///
/// [colors] нужен, когда [context] стоит выше `M3eThemeScope` (корневой маршрут старого
/// экрана): цвета передаёт вызывающий. [selectableText] делает текст выделяемым.
/// [link] рисуется под текстом и не закрывает диалог.
Future<T?> showM3eDialog<T>(
  BuildContext context, {
  required M3eSymbol icon,
  required String title,
  required String text,
  required List<M3eDialogAction<T>> actions,
  M3eColors? colors,
  bool selectableText = false,
  M3eDialogLink? link,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(
    _M3eDialogRoute<T>(
      icon: icon,
      title: title,
      text: text,
      actions: actions,
      colors: colors ?? M3eColors.of(context),
      selectableText: selectableText,
      link: link,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      reduced: MediaQuery.disableAnimationsOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Пружина как кривая: значение пружины за [duration] от 0 к 1, у `t == 1` ровно 1.
///
/// Пружина доски (`dr-pop-in`) задана длительностью и таблицей `linear()`; кривая из
/// `SpringSimulation` с теми же параметрами даёт тот же перелёт без таблицы.
class _SpringCurve extends Curve {
  _SpringCurve(M3eSpringSpec spec, this.duration)
      : _sim = SpringSimulation(spec.description, 0, 1, 0);

  final Duration duration;
  final SpringSimulation _sim;

  @override
  double transformInternal(double t) =>
      _sim.x(t * duration.inMicroseconds / Duration.microsecondsPerSecond);
}

/// Длительность пружины default spatial на доске (`--md-sys-motion-spring-default-spatial-duration`).
const Duration _kEnter = Duration(milliseconds: 412);

class _M3eDialogRoute<T> extends PopupRoute<T> {
  _M3eDialogRoute({
    required this.icon,
    required this.title,
    required this.text,
    required this.actions,
    required this.colors,
    required this.selectableText,
    required this.link,
    required this.themes,
    required this.reduced,
    required this.barrierLabel,
  });

  final M3eSymbol icon;
  final String title;
  final String text;
  final List<M3eDialogAction<T>> actions;
  final M3eColors colors;
  final bool selectableText;
  final M3eDialogLink? link;
  final CapturedThemes themes;
  final bool reduced;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  // Вход пружиной default spatial, выход затуханием 150 мс (`dr-pop-in`, `dr-fade-out`);
  // при отключённых анимациях оба раза только прозрачность 150 мс.
  @override
  Duration get transitionDuration => reduced ? M3eDuration.short3 : _kEnter;

  @override
  Duration get reverseTransitionDuration => M3eDuration.short3;

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
          child: Material(
            type: MaterialType.transparency,
            child: _DialogHost<T>(route: this),
          ),
        ),
      );
}

class _DialogHost<T> extends StatefulWidget {
  const _DialogHost({required this.route});

  final _M3eDialogRoute<T> route;

  @override
  State<_DialogHost<T>> createState() => _DialogHostState<T>();
}

class _DialogHostState<T> extends State<_DialogHost<T>> {
  late final CurvedAnimation _pop = CurvedAnimation(
    parent: widget.route.animation!,
    curve: widget.route.reduced
        ? Curves.linear
        : _SpringCurve(M3eSpring.defaultSpatial, _kEnter),
    reverseCurve: Curves.linear,
  );

  // Затемнение входит за первую половину пружины (~200 мс), уходит за 150 мс.
  late final CurvedAnimation _scrim = CurvedAnimation(
    parent: widget.route.animation!,
    curve: widget.route.reduced ? Curves.linear : const Interval(0, 0.5),
    reverseCurve: Curves.linear,
  );

  @override
  void dispose() {
    _pop.dispose();
    _scrim.dispose();
    super.dispose();
  }

  void _close([T? value]) {
    if (widget.route.isCurrent) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final route = widget.route;
    final dialog = M3eDialogFrame(
      icon: route.icon,
      title: route.title,
      body: _body(route, scheme),
      actions: [
        for (var i = 0; i < route.actions.length; i++)
          _DialogButton(
            key: ValueKey<String>('m3e.dialog.action.$i'),
            label: route.actions[i].label,
            danger: route.actions[i].danger,
            onPressed: () => _close(route.actions[i].value),
          ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scrim,
            builder: (context, child) => Semantics(
              button: true,
              label: route.barrierLabel,
              onTap: _close,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey<String>('m3e.dialog.scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: ColoredBox(
                  color: scheme.scrim.withValues(
                    alpha: 0.32 * _scrim.value.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _pop,
            child: dialog,
            builder: (context, child) {
              final v = _pop.value;
              final leaving =
                  route.animation!.status == AnimationStatus.reverse;
              final scale = route.reduced || leaving ? 1.0 : 0.85 + 0.15 * v;
              return Opacity(
                key: const ValueKey<String>('m3e.dialog.fade'),
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(
                  key: const ValueKey<String>('m3e.dialog.motion'),
                  scale: scale,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Рамка диалога доски (`.dr-dialog`): ширина 312, поля 24, угол 28, значок 24 по центру
/// в цвете secondary, заголовок headline-small, текст, кнопки справа.
///
/// Значок, заголовок и кнопки закреплены, прокручивается только [body]: при длинном тексте
/// или шрифте 2,0 кнопки не уезжают за экран, а у «Согласен» на VPN это условие закона.
/// Рамку используют и `showM3eDialog`, и скин старых диалогов (`M3eDialogSkin`).
class M3eDialogFrame extends StatelessWidget {
  const M3eDialogFrame({
    super.key,
    required this.body,
    required this.actions,
    this.icon,
    this.title,
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 24),
    this.scrollBody = true,
    this.maxHeight,
  });

  /// Без значка заголовок встаёт по началу строки, как в M3 без значка.
  final M3eSymbol? icon;
  final String? title;
  final Widget body;
  final List<Widget> actions;

  /// Поля вокруг [body]. Старые диалоги со списками на всю ширину передают нули по бокам.
  final EdgeInsets bodyPadding;

  /// `false` — [body] прокручивается сам (список, поле ввода с собственным скроллом).
  final bool scrollBody;

  /// Потолок высоты; по умолчанию высота окна минус по 48 сверху и снизу.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final media = MediaQuery.of(context);
    final width = math.min(312.0, media.size.width - 48);
    final hasTitle = title != null && title!.isNotEmpty;
    final centered = icon != null;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Material(
        key: const ValueKey<String>('m3e.dialog'),
        color: scheme.surfaceContainerHigh,
        shadowColor: scheme.shadow.withValues(alpha: 0.45),
        elevation: M3eElevation.level3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3eShape.extraLarge),
        ),
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight ?? media.size.height - 96,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon != null) ...[
                    Center(
                      child: ExcludeSemantics(
                        child: M3eSymbolIcon(
                          icon!,
                          size: 24,
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (hasTitle) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(
                          title!,
                          key: const ValueKey<String>('m3e.dialog.title'),
                          textAlign:
                              centered ? TextAlign.center : TextAlign.start,
                          style: m3eTextStyle(
                            M3eType.headlineSmall,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Flexible(
                    child: scrollBody
                        ? SingleChildScrollView(
                            key: const ValueKey<String>('m3e.dialog.body'),
                            padding: bodyPadding,
                            child: body,
                          )
                        : Padding(padding: bodyPadding, child: body),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Стиль текстовой кнопки диалога для старых `TextButton`: S (высота 40, поля 16),
/// подпись label-large, цвет primary. Совпадает с кнопками `showM3eDialog`.
ButtonStyle m3eDialogTextButtonStyle(M3eScheme scheme) => ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: M3eState.disabledContent)
            : scheme.primary,
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return scheme.primary.withValues(alpha: M3eState.pressed);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: M3eState.hover);
        }
        return null;
      }),
      textStyle: WidgetStatePropertyAll(m3eTextStyle(M3eType.labelLarge)),
      minimumSize: const WidgetStatePropertyAll(Size(58, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );

/// Тело диалога: текст и, если задана, ссылка под ним.
Widget _body(_M3eDialogRoute<dynamic> route, M3eScheme scheme) {
  final text = _bodyText(route, scheme);
  final link = route.link;
  if (link == null) return text;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      text,
      const SizedBox(height: 4),
      _DialogLink(link: link, scheme: scheme),
    ],
  );
}

/// Ссылка в теле диалога: подчёркнутая подпись цветом primary, зона нажатия высотой 40.
/// Поля слева нет, чтобы подпись стояла на одной вертикали с текстом.
class _DialogLink extends StatelessWidget {
  const _DialogLink({required this.link, required this.scheme});

  final M3eDialogLink link;
  final M3eScheme scheme;

  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        button: true,
        child: InkWell(
          key: const ValueKey<String>('m3e.dialog.link'),
          onTap: link.onPressed,
          borderRadius: BorderRadius.circular(8),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: M3eState.pressed);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: M3eState.hover);
            }
            return null;
          }),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text(
                link.label,
                style: m3eTextStyle(M3eType.bodyMedium, color: scheme.primary)
                    .copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Текст диалога. Юридическое раскрытие VPN должно выделяться и копироваться, как в старом
/// диалоге (`SelectableText`), поэтому выбор вынесен в параметр.
Widget _bodyText(_M3eDialogRoute<dynamic> route, M3eScheme scheme) {
  final style =
      m3eTextStyle(M3eType.bodyMedium, color: scheme.onSurfaceVariant);
  const key = ValueKey<String>('m3e.dialog.text');
  return route.selectableText
      ? SelectableText(route.text, key: key, style: style)
      : Text(route.text, key: key, style: style);
}

/// Текстовая кнопка диалога: S (высота 40, поля 16), подпись label-large, цвет primary
/// или error. Своя, а не `M3eButton`, потому что у той нет вида «danger».
class _DialogButton extends StatefulWidget {
  const _DialogButton({
    super.key,
    required this.label,
    required this.danger,
    required this.onPressed,
  });

  final String label;
  final bool danger;
  final VoidCallback onPressed;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final ink = widget.danger ? scheme.error : scheme.primary;
    // Форма нажатой кнопки сжимается до 8, как у M3eButton размера S.
    final radius = _pressed ? 8.0 : 20.0;
    return Semantics(
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 58, minHeight: 40),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: radius),
          duration: M3eDuration.short3,
          curve: Curves.easeOutCubic,
          builder: (context, r, child) => Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r),
            ),
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.focused)) {
                  return ink.withValues(alpha: M3eState.pressed);
                }
                if (states.contains(WidgetState.hovered)) {
                  return ink.withValues(alpha: M3eState.hover);
                }
                return null;
              }),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: m3eTextStyle(M3eType.labelLarge, color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
