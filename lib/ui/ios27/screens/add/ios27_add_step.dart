// Шаг «Добавить подписку» внутри листа «Подписка»: та же форма вторым уровнем (доска addForm/addSubmit, app.js:657-670).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_view.dart';
import 'package:flutter/widgets.dart';

/// Кладёт форму «Добавить подписку» страницей второго уровня поверх текущей страницы листа.
///
/// [sheetContext] — контекст внутри листа (`Ios27SheetNavigator.push` ищет по нему стопку). Кнопка
/// «Назад» в шапке появляется сама. После успешной отправки закрывается весь лист, как на Android.
Future<void> pushIos27AddStep(BuildContext sheetContext) =>
    Ios27SheetNavigator.push<void>(
      sheetContext,
      builder: (context) => Ios27SheetScaffold(
        title: AppLocalizations.of(context).addSubscription,
        body: const Ios27AddView(step: true),
      ),
    );
