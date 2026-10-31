// Маршрут страницы с заголовком, который перечитывает язык приложения.
//
// Тонкая обёртка над `pushIos27Page(titleBuilder: …)`: выбор языка меняет локаль, пока страница
// «Язык» ещё на экране, а «Настройки» под ней остаются в стопке; заголовок, снятый при открытии,
// остался бы на прежнем языке до следующего захода.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:flutter/widgets.dart';

/// Открывает страницу [Ios27Page]; заголовок [title] считается по текущей локали при каждой сборке.
///
/// Всё остальное (переход, жест «Назад», перенос тем) как у `pushIos27Page`.
Future<T?> pushIos27LocalizedPage<T>(
  BuildContext context, {
  required String Function(AppLocalizations l) title,
  required WidgetBuilder builder,
  VoidCallback? onTitleTap,
  String? titleSemanticsIdentifier,
}) =>
    pushIos27Page<T>(
      context,
      titleBuilder: (c) => title(AppLocalizations.of(c)),
      builder: builder,
      onTitleTap: onTitleTap,
      titleSemanticsIdentifier: titleSemanticsIdentifier,
    );
