// Лист «Подписка» iOS-редизайна (сцены `sub`, `refresh-fail`, `delete-alert` доски).
//
// Тело листа — `subBody` (app.js:570-578), вид листа `sub` (app.js:726-734), подтверждение
// удаления — app.js:804-805. Данные и действия берутся из нейтральных провайдеров
// `lib/ui/m3e/subscription/` (их же использует Android-редизайн), своей логики здесь нет.
//
// Состав (три группы через `Ios27Gap`):
//  1. «Обновить» (подпись — «4 минуты назад» без слова «Обновлено», как на доске) и
//     «Справочная» (адрес страницы провайдера, сжимается с многоточием, значок «наружу»);
//  2. подписки с логотипом и галочкой у текущей + «Добавить подписку» в ТОМ ЖЕ списке
//     (акцентная строка слева, `row--link`);
//  3. «Удалить подписку» (красная по центру, `row--danger`).
// Продления/пополнения/кабинета нет: iOS — магазинная сборка (`M3eSubModel.renewUrl == null`).

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_step.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/m3e_emoji.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключи частей для паритета с `layout.json` и тестов.
const kIos27SubRefreshKey = ValueKey<String>('ios27.sub.refresh');
const kIos27SubSupportKey = ValueKey<String>('ios27.sub.support');
const kIos27SubAddKey = ValueKey<String>('ios27.sub.add');
const kIos27SubDeleteKey = ValueKey<String>('ios27.sub.delete');
ValueKey<String> kIos27SubListKey(int i) =>
    ValueKey<String>('ios27.sub.list.$i');
ValueKey<String> kIos27SubProfileKey(String id) =>
    ValueKey<String>('ios27.sub.profile.$id');

/// Отступ снизу прокручиваемого тела листа (`.sheet__body` padding-bottom 40, app.css).
const double kIos27SubBodyBottom = 40;

/// Открывает лист подписки (сцена `sub` доски, средний детент).
///
/// [origin] — кнопка дока со стопкой, из которой лист вырастает; без неё лист выезжает снизу.
Future<void> showIos27SubSheet(
  BuildContext context, {
  Ios27ZoomOrigin? origin,
}) =>
    showIos27Sheet<void>(
      context,
      origin: origin,
      title: AppLocalizations.of(context).m3eSubTitle,
      // Тело прокручивается: при крупном шрифте и длинном списке подписок оно выше листа.
      builder: (_) => const SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kIos27SubBodyBottom),
        child: Ios27SubSheetBody(),
      ),
    );

/// Подпись пункта «Обновить»: «только что», «4 минуты назад», «3 часа назад», «2 дня назад».
///
/// Отличается от `m3eUpdatedAgo` (Android) отсутствием слова «Обновлено»: на доске в строке
/// оно ни к чему, строка и так называется «Обновить». `null` — подписка ещё не обновлялась.
String? ios27UpdatedAgo(AppLocalizations l, DateTime? at, DateTime now) {
  if (at == null) return null;
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return l.ios27UpdatedJustNow;
  if (diff.inHours < 1) return l.ios27UpdatedMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.ios27UpdatedHoursAgo(diff.inHours);
  return l.ios27UpdatedDaysAgo(diff.inDays);
}

/// Содержимое листа: данные из `m3eSubModelProvider`, действия из `m3eSubActionsProvider`.
class Ios27SubSheetBody extends ConsumerWidget {
  const Ios27SubSheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(m3eSubModelProvider);
    final refresh = ref.watch(m3eSubRefreshProvider);
    final actions = ref.read(m3eSubActionsProvider);
    final now = ref.watch(m3eSubClockProvider)();

    // Удалили последнюю подписку: листу показывать нечего (на доске он закрывается вместе с
    // алертом, app.js:804-805), главная сама станет пустой.
    ref.listen<bool>(
      m3eSubModelProvider.select((m) => m.profiles.isEmpty),
      (_, empty) {
        if (empty && context.mounted) Navigator.of(context).maybePop();
      },
    );

    final current = model.current;
    final refreshing = model.refreshing ||
        (current != null && refresh.updatingId == current.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(
          key: kIos27SubListKey(0),
          children: [
            Ios27ListRow(
              key: kIos27SubRefreshKey,
              title: l.m3eRefresh,
              detail: refreshing
                  ? l.loadingEllipsis
                  : ios27UpdatedAgo(l, model.updatedAt, now),
              leading: const Ios27Avatar.icon(Ios27IconName.refresh),
              // Пока идёт обновление, строка не нажимается: повторный тап игнорирует и
              // провайдер, но серой её видно.
              enabled: !refreshing && current != null,
              onTap: current == null
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
              Ios27ListRow(
                key: kIos27SubSupportKey,
                title: l.m3eSubSupport,
                detail: model.supportHost,
                // Адрес сжимается с многоточием, а название остаётся целым
                // (`.row:has(.host)`, app.css).
                detailShrinks: true,
                leading: const Ios27Avatar.icon(Ios27IconName.chat),
                accessory: Ios27RowAccessory.external,
                onTap: () {
                  actions.openLink(model.supportUrl!);
                  actions.notify(l.m3eToastSupport, M3eToastKind.out);
                },
              ),
          ],
        ),
        const Ios27Gap(),
        Ios27List(
          key: kIos27SubListKey(1),
          children: [
            for (final p in model.profiles)
              _profileRow(
                ref,
                p,
                selected: p.id == model.currentId,
                onTap: () => actions.select(p.id),
              ),
            Ios27ListRow(
              key: kIos27SubAddKey,
              title: l.addSubscription,
              tone: Ios27RowTone.link,
              onTap: () => unawaited(pushIos27AddStep(context)),
            ),
          ],
        ),
        const Ios27Gap(),
        Ios27List(
          key: kIos27SubListKey(2),
          children: [
            Ios27ListRow(
              key: kIos27SubDeleteKey,
              title: l.m3eSubDelete,
              tone: Ios27RowTone.danger,
              onTap: current == null
                  ? null
                  : () => unawaited(_confirmDelete(context, ref, current)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    M3eSubProfile profile,
  ) async {
    final actions = ref.read(m3eSubActionsProvider);
    final ok = await showIos27DeleteSubscription(context, profile.name);
    if (ok != true) return;
    await actions.delete(profile.id);
  }
}

/// Подтверждение удаления подписки (алерт доски, app.js:804-805): заголовок с именем,
/// пояснение, «Отмена» и красное «Удалить». `true` — удалить.
///
/// Алерт идёт на корневой навигатор поверх листа, поэтому лист остаётся под затемнением.
Future<bool?> showIos27DeleteSubscription(BuildContext context, String name) =>
    showIos27Alert<bool>(
      context,
      builder: (alertContext) {
        final l = AppLocalizations.of(alertContext);
        return Center(
          child: Ios27Alert(
            title: l.m3eDeleteTitle(name),
            body: Text(l.m3eDeleteBody),
            actions: [
              Ios27AlertButton(
                label: l.cancel,
                onPressed: () => Navigator.of(alertContext).pop(false),
              ),
              Ios27AlertButton(
                label: l.delete,
                destructive: true,
                onPressed: () => Navigator.of(alertContext).pop(true),
              ),
            ],
          ),
        );
      },
    );

/// Строка подписки: аватар (логотип провайдера → эмодзи имени → инициалы), имя, галочка у
/// текущей.
///
/// Приоритет аватара: настоящий логотип из заголовка `dropweb-logo`, в цвете и как есть
/// (решение владельца 30.10: «значок провайдера должен подтягиваться из лого в заголовке»;
/// вырезанный белый знак по `cutMark` доски владелец не узнавал, поэтому от него отказались).
/// Нет логотипа или он не загрузился (`m3eSubLogoProvider` отдаёт `null`) — ведущий эмодзи имени
/// (флаг или эмодзи, из названия он убирается, как у групп узлов, D6), иначе плитка с инициалами.
/// Пока логотип грузится, показывается запасной вид, затем он сменяется картинкой. С логотипом
/// и с инициалами имя остаётся целиком.
///
/// Это функция, а не виджет: `Ios27List` рисует разделители по отступу своих прямых детей
/// `Ios27ListRow` (62 при аватаре слева), а обёртка скрыла бы строку от списка.
Ios27ListRow _profileRow(
  WidgetRef ref,
  M3eSubProfile profile, {
  required bool selected,
  required VoidCallback onTap,
}) {
  final url = profile.logoUrl;
  final logo =
      url == null ? null : ref.watch(m3eSubLogoProvider(url)).valueOrNull;
  final flag = _leadFlag(profile.name);
  final lead = flag ?? extractLeadEmoji(profile.name);

  Widget avatar;
  var title = profile.name;
  if (logo != null) {
    final svg = logo.svg;
    final image = logo.image;
    avatar = Ios27Avatar.logoImage(
      svg != null ? Ios27AvatarLogo.svg(svg) : Ios27AvatarLogo.raster(image!),
    );
  } else if (lead != null) {
    avatar = flag != null ? Ios27Avatar.flag(flag) : Ios27Avatar.emoji(lead);
    title = _stripLead(profile.name, lead);
  } else {
    avatar = Ios27Avatar.logo(initials: profile.initials);
  }

  return Ios27ListRow(
    key: kIos27SubProfileKey(profile.id),
    title: title,
    leading: avatar,
    accessory: selected ? Ios27RowAccessory.check : Ios27RowAccessory.none,
    onTap: onTap,
  );
}

/// Флаг страны в начале имени (пара региональных индикаторов) или `null`.
///
/// `extractLeadEmoji` флаги не ловит (их рисует отдельный режим аватара), поэтому имя вида
/// «🇩🇪 Берлин» разбирается здесь.
String? _leadFlag(String name) {
  final trimmed = name.trimLeft();
  final runes = trimmed.runes.take(2).toList();
  if (runes.length < 2) return null;
  final flag = String.fromCharCodes(runes);
  return Ios27Avatar.isFlagEmoji(flag) ? flag : null;
}

/// Имя без ведущего [lead] и пробелов за ним; если ничего не осталось — имя целиком.
String _stripLead(String name, String lead) {
  final rest = name.trimLeft().substring(lead.length).trimLeft();
  return rest.isEmpty ? name : rest;
}
