import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../color/color.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/m3e_theme_source.dart';
import '../theme/tokens.g.dart';
import 'm3e_sheet.dart';

/// Показывает старый нижний лист (`showSheet`) в рамке листа M3E.
///
/// Рамка — [showM3eSheet]: surfaceContainerLow, ручка, затемнение M3E, свайп вниз, подъём
/// над клавиатурой. Содержимое остаётся старым, но обёрнуто в `Theme` M3E: поля ввода,
/// переключатели и текст берут роли схемы, а не тёмный Lumina.
///
/// Старые листы идут с контекста, выше которого `M3eThemeScope` может не быть (страницы
/// разработчика, корневой навигатор), поэтому цвета при отсутствии области считаются
/// здесь же из [m3eThemeSourceProvider].
Future<T?> showM3eSheetSkin<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) =>
    showM3eSheet<T>(
      context,
      colors: _colorsFor(context),
      builder: (_) => _SkinTheme(child: Builder(builder: builder)),
    );

/// Цвета из ближайшей области M3E, а без неё из источника темы приложения и яркости
/// системы (как `M3eThemeScope`).
M3eColors _colorsFor(BuildContext context) {
  final existing = context.getInheritedWidgetOfExactType<M3eColors>();
  if (existing != null) return existing;
  final source = ProviderScope.containerOf(context, listen: false)
      .read(m3eThemeSourceProvider);
  final brightness = MediaQuery.platformBrightnessOf(context);
  final dark = brightness == Brightness.dark;
  return M3eColors(
    scheme: scheme(source.seed, source.filter, dark: dark),
    home: homeVars(source.seed, source.filter, dark: dark),
    brightness: brightness,
    // Маршрут листа копирует из M3eColors только поля, потомок не нужен.
    child: const SizedBox.shrink(),
  );
}

/// `Theme` M3E поверх содержимого: маршрут листа перенёс бы тему вызывающего контекста,
/// то есть старую.
class _SkinTheme extends StatelessWidget {
  const _SkinTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    return Theme(
      data: m3eThemeData(colors.scheme, brightness: colors.brightness),
      child: child,
    );
  }
}

/// Каркас старого листа внутри рамки M3E: заголовок title-large с действиями справа и
/// закреплённое тело.
///
/// В отличие от `M3eSheetScaffold` тело не заворачивается в `SingleChildScrollView`:
/// старые тела (`ListView`, `Column` с собственной прокруткой) сами решают, что
/// прокручивать, а при бесконечной высоте они бы упали. Ручку рисует рамка листа.
class M3eSheetSkinScaffold extends StatelessWidget {
  const M3eSheetSkinScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.onTitleTap,
  });

  final String title;
  final Widget body;

  /// Кнопки из `AppBar.actions` старого листа.
  final List<Widget> actions;

  /// Нажатие на заголовок: разблокировка режима разработчика (5 быстрых касаний).
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final hasScope = context.getInheritedWidgetOfExactType<M3eColors>() != null;
    final content = _Content(
      title: title,
      body: body,
      actions: actions,
      onTitleTap: onTitleTap,
    );
    return hasScope ? content : M3eThemeScope(child: content);
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.body,
    required this.actions,
    required this.onTitleTap,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = M3eColors.of(context).scheme.onSurface;
    Widget heading = Semantics(
      header: true,
      namesRoute: true,
      child: Text(
        title,
        key: const ValueKey<String>('m3e.sheet.title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: m3eTextStyle(M3eType.titleLarge, color: onSurface),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, actions.isEmpty ? 24 : 12, 8),
            child: Row(
              children: [
                Expanded(child: heading),
                ...actions,
              ],
            ),
          ),
        ),
        Flexible(child: body),
      ],
    );
  }
}
