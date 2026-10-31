// Лист «Добавить подписку» iOS-редизайна (доска addForm, app.js:657-664; отдельный лист с пустого экрана, app.js:718-725).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_view.dart';
import 'package:flutter/widgets.dart';

/// Открывает лист добавления подписки; [initialUrl] подставляется в поле ссылки.
///
/// После успешной отправки лист закрывается и запускается импорт; неверная ссылка оставляет
/// форму открытой с текстом ошибки.
Future<void> showIos27AddSheet(BuildContext context, {String? initialUrl}) =>
    showIos27Sheet<void>(
      context,
      title: AppLocalizations.of(context).addSubscription,
      builder: (_) => Ios27AddView(initialUrl: initialUrl),
    );
