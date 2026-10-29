import 'package:flutter/material.dart';

import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_dialog.dart';

/// Цвет затемнения под диалогом: `scrim` схемы с непрозрачностью 0,32, как у
/// `showM3eDialog`. `scrim` в схеме M3 всегда чёрный (тон 0), поэтому цвет задан константой:
/// маршрут старых диалогов строится вне дерева темы и схемы под рукой не имеет.
const Color kM3eDialogBarrierColor = Color(0x52000000);

/// Старый диалог (`CommonDialog`) в рамке M3E-диалога.
///
/// Старые диалоги идут через корневой навигатор, поэтому `M3eColors` выше них нет: скин
/// ставит `M3eThemeScope` сам. Вместе с ним приходит и `Theme` M3E, так что вложенные
/// поля ввода, переключатели и текст берут цвета схемы, а не тёмного Lumina.
///
/// Заголовок и кнопки закреплены, прокручивается только содержимое ([overrideScroll]
/// `true` — содержимое прокручивается само, как в старом диалоге). Положение по центру
/// с отступом от клавиатуры: в старых диалогах есть поля ввода.
class M3eDialogSkin extends StatelessWidget {
  const M3eDialogSkin({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding,
    this.overrideScroll = false,
  });

  final String title;
  final Widget? child;
  final List<Widget>? actions;

  /// Поля содержимого вместо стандартных 24 по бокам (`contentPadding` старого диалога).
  final EdgeInsets? padding;
  final bool overrideScroll;

  @override
  Widget build(BuildContext context) {
    final content = _SkinBody(
      title: title,
      actions: actions ?? const [],
      padding: padding,
      overrideScroll: overrideScroll,
      child: child,
    );
    final hasScope = context.getInheritedWidgetOfExactType<M3eColors>() != null;
    return hasScope ? content : M3eThemeScope(child: content);
  }
}

class _SkinBody extends StatelessWidget {
  const _SkinBody({
    required this.title,
    required this.actions,
    required this.padding,
    required this.overrideScroll,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final media = MediaQuery.of(context);
    // Высота окна без клавиатуры и без полей по 48: диалог с полем ввода остаётся целиком.
    final maxHeight =
        (media.size.height - media.viewInsets.bottom - 96).clamp(160.0, 9999.0);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedPadding(
        duration: M3eDuration.short3,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(
          child: TextButtonTheme(
            data: TextButtonThemeData(style: m3eDialogTextButtonStyle(scheme)),
            child: M3eDialogFrame(
              title: title,
              maxHeight: maxHeight,
              scrollBody: !overrideScroll,
              bodyPadding:
                  padding ?? const EdgeInsets.symmetric(horizontal: 24),
              actions: actions,
              body: DefaultTextStyle(
                style: m3eTextStyle(
                  M3eType.bodyMedium,
                  color: scheme.onSurfaceVariant,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Текст сообщения старого диалога без цветов из тёмной темы Lumina.
///
/// Вызовы `showMessage` и `showErrorMessage` часто кладут в `TextSpan` стиль окружающей
/// темы (`Theme.of(context).textTheme.titleMedium`, `colorScheme.onSurface`): на тёмном
/// диалоге он светлый, а на светлой плашке M3E оказался бы почти невидим. Цвет и фон
/// убираются, размер, насыщенность, гарнитура и подчёркивание остаются; цвет тогда берётся
/// из `DefaultTextStyle` скина.
InlineSpan m3eDialogMessageSpan(InlineSpan span) {
  if (span is! TextSpan) return span;
  final style = span.style;
  return TextSpan(
    text: span.text,
    children: span.children?.map(m3eDialogMessageSpan).toList(),
    style: style == null
        ? null
        : TextStyle(
            inherit: style.inherit,
            fontSize: style.fontSize,
            fontWeight: style.fontWeight,
            fontStyle: style.fontStyle,
            letterSpacing: style.letterSpacing,
            wordSpacing: style.wordSpacing,
            textBaseline: style.textBaseline,
            height: style.height,
            leadingDistribution: style.leadingDistribution,
            locale: style.locale,
            fontFamily: style.fontFamily,
            fontFamilyFallback: style.fontFamilyFallback,
            fontFeatures: style.fontFeatures,
            fontVariations: style.fontVariations,
            decoration: style.decoration,
            decorationStyle: style.decorationStyle,
            decorationThickness: style.decorationThickness,
          ),
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}
