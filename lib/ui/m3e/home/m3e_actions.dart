// Действия M3E-главной: «Настройки», «Подписка» и «Маршрут» открывают M3E-экраны;
// включение VPN и обновление подписки переиспользуют логику старых экранов.
// Старые входы (`openToolsSheet`, `SubscriptionPage.open`, лист «Серверы и группы»)
// остаются в коде для планшета, ТВ и других платформ, но с Android-телефона отсюда
// недостижимы.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:dropweb/ui/m3e/screens/m3e_appearance.dart';
import 'package:dropweb/ui/m3e/screens/m3e_dialogs.dart';
import 'package:dropweb/ui/m3e/screens/m3e_route_sheet.dart';
import 'package:dropweb/ui/m3e/screens/m3e_servers_groups.dart';
import 'package:dropweb/ui/m3e/screens/m3e_settings.dart';
import 'package:dropweb/ui/m3e/screens/m3e_subscription_sheet.dart';
import 'package:dropweb/ui/m3e/screens/m3e_update_sheet.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_page.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart'
    show toggleVpn;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Запуск VPN: общий путь старой кнопки. Подменяется в тестах, чтобы не трогать
/// окно раскрытия и `globalState`.
final m3eStartVpnProvider = Provider<
    Future<bool> Function(BuildContext context,
        {required bool currentlyRunning})>(
  (ref) => toggleVpn,
);

/// Включает или выключает VPN тем же путём, что старая кнопка (согласие на VPN,
/// отклик, звук, запрос уведомлений). Пока приложение не готово или идёт
/// подключение, ничего не делает: отменить подключение в приложении нечем.
///
/// Если запуск запрошен, главная начинает следить за его исходом ([M3eStartFailure]):
/// отмена окна раскрытия сюда не доходит и ошибкой не считается.
Future<void> m3eToggleVpn(BuildContext context, WidgetRef ref) async {
  final ready = ref.read(startButtonSelectorStateProvider).isInit;
  if (!ready || ref.read(m3eConnectingProvider)) return;
  final started = await ref.read(m3eStartVpnProvider)(
    context,
    currentlyRunning: ref.read(runTimeProvider) != null,
  );
  if (started) ref.read(m3eStartFailureProvider.notifier).requested();
}

/// «Настройки»: страница M3E. «Язык» она открывает сама; «Оформление» и «О программе»
/// кладутся поверх неё теми же страницами-маршрутами. Контекст может быть вне
/// `M3eThemeScope` (пустая главная): `pushM3ePage` оборачивает страницы сам.
void m3eOpenSettings(BuildContext context, WidgetRef ref) => unawaited(
      pushM3ePage<void>(
        context,
        (_) => M3eSettingsPage(
          onAppearance: () => unawaited(
            pushM3ePage<void>(context, (_) => const M3eAppearancePage()),
          ),
          onAbout: () =>
              unawaited(pushM3ePage<void>(context, (_) => const M3eAbout())),
          onCheckUpdate: () => unawaited(m3eCheckForUpdate(context)),
        ),
      ),
    );

/// «Подписка»: лист M3E с шагом «Добавить подписку» и подтверждением удаления.
/// Вызывать с контекста внутри `M3eThemeScope` (главная).
void m3eOpenSubscriptions(BuildContext context) => unawaited(
      showM3eSubscriptionSheet(
        context,
        addBuilder: (_) => const M3eAddSubscriptionView(),
        confirmDelete: (c, name) => showM3eDeleteSubscription(c, name: name),
      ),
    );

/// «Маршрут»: лист M3E; шаг «Серверы и группы» кладётся в его стек.
void m3eOpenRoute(BuildContext context) => unawaited(
      showM3eRouteSheet(
        context,
        serversBuilder: (_) => const M3eServersGroupsView(),
      ),
    );

/// «Обновить»: перезагрузка текущей подписки тем же путём, что в листе «Подписка»:
/// плашка «Подписка обновлена» (check) или плашка с причиной (alert). Старый
/// `refreshProfiles` при ошибке открывал Lumina-диалог поверх M3E, а при успехе молчал.
Future<void> m3eRefreshProfile(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(currentProfileProvider);
  if (profile == null) return;
  final l = AppLocalizations.of(context);
  await ref.read(m3eSubRefreshProvider.notifier).refresh(
        profile.id,
        okText: l.m3eToastRefreshed,
        failText: l.m3eToastRefreshFail,
      );
}

/// Ссылка из объявления провайдера: открывает общий помощник приложения.
void m3eOpenLink(Uri uri) => globalState.openUrl(uri.toString());

/// Набор действий главной одним объектом, чтобы тест подменял их провайдером.
class M3eHomeActions {
  const M3eHomeActions({
    required this.toggleVpn,
    required this.openSettings,
    required this.openSubscriptions,
    required this.openRoute,
    required this.refresh,
    required this.openLink,
  });

  /// Действия, которые настоящие экраны вызывают в приложении.
  static const M3eHomeActions app = M3eHomeActions(
    toggleVpn: m3eToggleVpn,
    openSettings: m3eOpenSettings,
    openSubscriptions: _openSubscriptions,
    openRoute: _openRoute,
    refresh: m3eRefreshProfile,
    openLink: m3eOpenLink,
  );

  final Future<void> Function(BuildContext context, WidgetRef ref) toggleVpn;
  final void Function(BuildContext context, WidgetRef ref) openSettings;
  final void Function(BuildContext context, WidgetRef ref) openSubscriptions;
  final void Function(BuildContext context, WidgetRef ref) openRoute;
  final Future<void> Function(BuildContext context, WidgetRef ref) refresh;
  final void Function(Uri uri) openLink;
}

void _openSubscriptions(BuildContext context, WidgetRef ref) =>
    m3eOpenSubscriptions(context);

void _openRoute(BuildContext context, WidgetRef ref) => m3eOpenRoute(context);

/// Действия главной; тесты подменяют `overrideWithValue`.
final m3eHomeActionsProvider =
    Provider<M3eHomeActions>((ref) => M3eHomeActions.app);
