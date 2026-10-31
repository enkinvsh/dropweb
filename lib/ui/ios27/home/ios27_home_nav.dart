// Навигация iOS-главной: единственное место, где главная знает про экраны листов и страниц.
//
// Точки входа даёт каждый экран сам (`lib/ui/ios27/screens/**`), главная только вызывает их.
// Так экраны можно дописывать и менять, не трогая главную, а её тесты подменяют эти вызовы.

import 'dart:async';

import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_sheet.dart';
import 'package:dropweb/ui/ios27/screens/route/ios27_route_sheet.dart';
import 'package:dropweb/ui/ios27/screens/settings/ios27_settings_page.dart';
import 'package:dropweb/ui/ios27/screens/sub/ios27_sub_sheet.dart';
import 'package:flutter/widgets.dart';

/// Открывает настройки (страница справа, app.js:446 `navSettings`).
void openIos27HomeSettings(BuildContext context) =>
    unawaited(openIos27Settings(context));

/// Открывает лист «Подписка»; он вырастает из кнопки дока (app.js 1263).
void openIos27HomeSubscriptions(BuildContext context) => unawaited(
      showIos27SubSheet(
        context,
        origin: Ios27ZoomSource.originFor(Ios27ZoomId.subscriptions),
      ),
    );

/// Открывает лист «Маршрут»; он вырастает из кнопки-глобуса дока.
void openIos27HomeRoute(BuildContext context) => unawaited(
      showIos27RouteSheet(
        context,
        origin: Ios27ZoomSource.originFor(Ios27ZoomId.route),
      ),
    );

/// Открывает лист «Добавить подписку»; [initialUrl] подставляется в поле ссылки.
void openIos27HomeAdd(BuildContext context, {String? initialUrl}) =>
    unawaited(showIos27AddSheet(context, initialUrl: initialUrl));
