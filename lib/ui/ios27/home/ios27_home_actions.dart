// Действия iOS-главной одним объектом, чтобы тест подменял их провайдером.
//
// Логика включения VPN и обновления подписки общая с Android-главной (`m3eToggleVpn`,
// `m3eRefreshProfile`): согласие на VPN, отклик, запрос уведомлений уже собраны там и покрыты
// тестами. Навигация своя: `M3eHomeActions.app` открывал бы M3E-экраны, на iOS это
// недопустимо, поэтому здесь [openIos27HomeSettings] и соседи.

import 'package:dropweb/ui/ios27/home/ios27_home_nav.dart';
import 'package:dropweb/ui/m3e/home/m3e_actions.dart'
    show m3eOpenLink, m3eRefreshProfile, m3eToggleVpn;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Что главная умеет делать по нажатиям.
class Ios27HomeActions {
  const Ios27HomeActions({
    required this.toggleVpn,
    required this.refresh,
    required this.openLink,
    required this.openSettings,
    required this.openSubscriptions,
    required this.openRoute,
  });

  /// Действия настоящего приложения.
  static const Ios27HomeActions app = Ios27HomeActions(
    toggleVpn: m3eToggleVpn,
    refresh: m3eRefreshProfile,
    openLink: m3eOpenLink,
    openSettings: _openSettings,
    openSubscriptions: _openSubscriptions,
    openRoute: _openRoute,
  );

  /// Включить или выключить VPN.
  final Future<void> Function(BuildContext context, WidgetRef ref) toggleVpn;

  /// «Обновить» на карточке при закончившейся подписке или трафике.
  final Future<void> Function(BuildContext context, WidgetRef ref) refresh;

  /// Ссылка из объявления провайдера.
  final void Function(Uri uri) openLink;

  final void Function(BuildContext context) openSettings;
  final void Function(BuildContext context) openSubscriptions;
  final void Function(BuildContext context) openRoute;
}

void _openSettings(BuildContext context) => openIos27HomeSettings(context);

void _openSubscriptions(BuildContext context) =>
    openIos27HomeSubscriptions(context);

void _openRoute(BuildContext context) => openIos27HomeRoute(context);

/// Действия главной; тесты подменяют `overrideWithValue`.
final ios27HomeActionsProvider =
    Provider<Ios27HomeActions>((ref) => Ios27HomeActions.app);
