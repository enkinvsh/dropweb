// Лист «Подписка» (сцены `sub` и `refresh-fail` доски, android.js 557–569 и 941–960):
// «Обновить» с подписью «Обновлено N назад», «Справочная», список подписок с выбором
// текущей, «Добавить подписку» и «Удалить подписку». Лист живёт на общих деталях
// (`M3eSheetStack`, `M3eList`), а данные и действия берёт из провайдеров
// `lib/ui/m3e/subscription/`.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_list.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключи для паритета с `layout.json` и тестов.
const kM3eSubRefreshKey = ValueKey<String>('m3e.sub.refresh');
const kM3eSubSupportKey = ValueKey<String>('m3e.sub.support');
const kM3eSubHeadKey = ValueKey<String>('m3e.sub.head');
const kM3eSubAddKey = ValueKey<String>('m3e.sub.add');
const kM3eSubDeleteKey = ValueKey<String>('m3e.sub.delete');
const kM3eSubRenewKey = ValueKey<String>('m3e.sub.extra.renew');
const kM3eSubTopUpKey = ValueKey<String>('m3e.sub.extra.topup');
ValueKey<String> kM3eSubListKey(int i) => ValueKey<String>('m3e.sub.list.$i');
ValueKey<String> kM3eSubProfileKey(String id) =>
    ValueKey<String>('m3e.sub.profile.$id');

/// Показывает лист «Подписка».
///
/// [addBuilder] строит шаг «Добавить подписку»: лист кладёт его в стек по пункту «Добавить
/// подписку», строитель возвращает целый `M3eSheetScaffold` со своим заголовком.
/// [confirmDelete] спрашивает подтверждение удаления подписки с именем `name`; `true`
/// удаляет, `false` ничего не меняет. Вызывать надо с контекста внутри `M3eThemeScope`
/// (экран, не навигатор): тему лист берёт оттуда.
Future<void> showM3eSubscriptionSheet(
  BuildContext context, {
  required WidgetBuilder addBuilder,
  required Future<bool> Function(BuildContext context, String name)
      confirmDelete,
}) =>
    showM3eSheet<void>(
      context,
      // Пункты лежат на тон выше самого листа: поверхность задаёт область.
      builder: (_) => M3eListSurfaceScope(
        surface: M3eListSurface.sheet,
        child: M3eSheetStack(
          root: (_) => M3eSubscriptionSheet(
            addBuilder: addBuilder,
            confirmDelete: confirmDelete,
          ),
        ),
      ),
    );

/// Корневой экран листа: модель и действия из провайдеров.
class M3eSubscriptionSheet extends ConsumerWidget {
  const M3eSubscriptionSheet({
    super.key,
    required this.addBuilder,
    required this.confirmDelete,
  });

  final WidgetBuilder addBuilder;
  final Future<bool> Function(BuildContext context, String name) confirmDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(m3eSubModelProvider);
    final refresh = ref.watch(m3eSubRefreshProvider);
    final actions = ref.read(m3eSubActionsProvider);
    final now = ref.watch(m3eSubClockProvider)();

    // Удалили последнюю подписку: показывать в листе нечего, главная сама станет пустой.
    ref.listen<bool>(
      m3eSubModelProvider.select((m) => m.profiles.isEmpty),
      (_, empty) {
        if (empty && context.mounted) Navigator.of(context).maybePop();
      },
    );

    final current = model.current;
    final refreshing = model.refreshing ||
        (current != null && refresh.updatingId == current.id);

    // Логотипы провайдеров (как `avatar()` доски). Пока файл не пришёл, не загрузился или
    // не разобрался, остаются инициалы.
    M3eListLead avatarOf(M3eSubProfile p) {
      final url = p.logoUrl;
      final logo =
          url == null ? null : ref.watch(m3eSubLogoProvider(url)).valueOrNull;
      if (logo?.svg != null) return M3eListLead.avatar(logoSvg: logo!.svg);
      if (logo?.image != null) return M3eListLead.avatar(logo: logo!.image);
      return M3eListLead.avatar(text: p.initials);
    }

    return M3eSheetScaffold(
      title: l.m3eSubTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3eList(
            key: kM3eSubListKey(0),
            children: [
              M3eListItem(
                key: kM3eSubRefreshKey,
                label: l.m3eRefresh,
                sup: refreshing
                    ? l.loadingEllipsis
                    : m3eUpdatedAgo(l, model.updatedAt, now),
                lead: M3eListLead.icon(M3eSymbol.refresh),
                onTap: (refreshing || current == null)
                    ? null
                    : () => unawaited(
                          ref.read(m3eSubRefreshProvider.notifier).refresh(
                                current.id,
                                okText: l.m3eToastRefreshed,
                                failText: l.m3eToastRefreshFail,
                              ),
                        ),
              ),
              if (model.supportUrl != null)
                M3eListItem(
                  key: kM3eSubSupportKey,
                  label: l.m3eSubSupport,
                  sup: model.supportHost,
                  lead: M3eListLead.icon(M3eSymbol.supportAgent),
                  trail: M3eListTrail.icon(M3eSymbol.openInNew),
                  onTap: () {
                    actions.openLink(model.supportUrl!);
                    actions.notify(l.m3eToastSupport, M3eToastKind.out);
                  },
                ),
            ],
          ),
          if (model.hasExtras) ...[
            const SizedBox(height: 16),
            M3eList(
              key: const ValueKey<String>('m3e.sub.list.extras'),
              children: [
                if (model.renewUrl != null)
                  M3eListItem(
                    key: kM3eSubRenewKey,
                    label: l.renew,
                    lead: M3eListLead.icon(M3eSymbol.update),
                    trail: M3eListTrail.icon(M3eSymbol.openInNew),
                    onTap: () => actions.openLink(model.renewUrl!),
                  ),
                if (model.topUpUrl != null)
                  M3eListItem(
                    key: kM3eSubTopUpKey,
                    label: l.topUpTraffic,
                    lead: M3eListLead.icon(M3eSymbol.dataUsage),
                    trail: M3eListTrail.icon(M3eSymbol.openInNew),
                    onTap: () => actions.openLink(model.topUpUrl!),
                  ),
              ],
            ),
          ],
          M3eListHeader(l.m3eSubAll, key: kM3eSubHeadKey),
          M3eList(
            key: kM3eSubListKey(1),
            semanticLabel: l.m3eSubListLabel,
            children: [
              for (final p in model.profiles)
                M3eListItem(
                  key: kM3eSubProfileKey(p.id),
                  label: p.name,
                  sup: p.host,
                  lead: avatarOf(p),
                  trail: p.id == model.currentId
                      ? M3eListTrail.icon(M3eSymbol.check)
                      : null,
                  radioChecked: p.id == model.currentId,
                  onTap: () => actions.select(p.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          M3eList(
            key: kM3eSubListKey(2),
            children: [
              M3eListItem(
                key: kM3eSubAddKey,
                label: l.addSubscription,
                lead: M3eListLead.avatar(icon: M3eSymbol.add, accent: true),
                tone: M3eListItemTone.accent,
                onTap: () => M3eSheetStack.of(context).push(addBuilder),
              ),
            ],
          ),
          const SizedBox(height: 16),
          M3eList(
            key: kM3eSubListKey(3),
            children: [
              M3eListItem(
                key: kM3eSubDeleteKey,
                label: l.m3eSubDelete,
                lead: M3eListLead.icon(M3eSymbol.delete),
                tone: M3eListItemTone.danger,
                onTap: current == null
                    ? null
                    : () => unawaited(_delete(context, ref, current)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    M3eSubProfile profile,
  ) async {
    final actions = ref.read(m3eSubActionsProvider);
    final ok = await confirmDelete(context, profile.name);
    if (!ok) return;
    await actions.delete(profile.id);
  }
}
