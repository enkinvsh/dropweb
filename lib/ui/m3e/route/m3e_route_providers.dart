// Данные и действия листа «Маршрут» M3E. Единственное место, где лист знает про провайдеры
// приложения; golden-тесты подменяют `m3eRouteDataProvider` и `m3eRouteActionsProvider`
// целиком и не трогают `globalState`.
//
// Логика выбора — та же, что у старого экрана подписки (`SubscriptionPage._apply`,
// `_CountrySheet`): запись выбора в ядро + `applyWorkMode`. Старый файл приватный,
// поэтому здесь своя копия провайдера роутера, а не импорт.

import 'dart:async';

import 'package:dropweb/common/country.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/m3e_emoji.dart';
import 'package:dropweb/views/proxies/common.dart' show delayTest;
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart'
    show aggregateGroupNames, isAggregateMember;
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:dropweb/ui/m3e/m3e_emoji.dart' show extractLeadEmoji;

/// Строка листа: «Авто» (агрегатор роутера) или страна/узел.
class M3eRouteRow {
  const M3eRouteRow({
    required this.id,
    required this.label,
    this.sup,
    this.flag,
    this.emoji,
    this.isAggregate = false,
    this.pingMs,
    this.selected = false,
  });

  /// Имя члена роутера в ядре: по нему пишется выбор.
  final String id;
  final String label;

  /// Подпись второй строкой: у «Авто» — узел, который группа выбрала сейчас.
  final String? sup;

  /// Флаг-эмодзи из начала имени; без него в аватаре значок.
  final String? flag;

  /// Эмодзи из начала имени агрегатора без флага (`⚡` у `⚡ Авто`); без него в аватаре значок.
  final String? emoji;
  final bool isAggregate;

  /// `null` — ещё не измерен, ничего не показываем; отрицательный — нет ответа.
  final int? pingMs;
  final bool selected;
}

/// Всё, что рисует лист.
class M3eRouteData {
  const M3eRouteData({
    this.rows = const [],
    this.routerName,
    this.fullTunnelAvailable = false,
    this.fullTunnel = false,
    this.groupsCount = 0,
    this.probe = const [],
    this.testUrl,
  });

  final List<M3eRouteRow> rows;

  /// Основной роутер профиля; `null`, пока конфиг не прочитан или роутера нет.
  final String? routerName;
  final bool fullTunnelAvailable;
  final bool fullTunnel;

  /// Число видимых групп для пункта «Серверы и группы».
  final int groupsCount;

  /// Члены роутера, которые надо один раз измерить при открытии листа.
  final List<Proxy> probe;
  final String? testUrl;
}

/// Роутер профиля и доступность «Весь трафик»: читает конфиг профиля, как приватный
/// `_routeDataProvider` старого экрана (те же ключи пересборки).
final m3eRouteInfoProvider = FutureProvider.autoDispose
    .family<({bool fullTunnelAvailable, String? routerName}), String>(
  (ref, profileId) async {
    ref.watch(
      profilesProvider.select((profiles) {
        final p = profiles.getProfile(profileId);
        return (p?.lastUpdateDate, p?.providerHeaders.length);
      }),
    );
    final config = await globalState.getProfileConfig(profileId);
    return (
      fullTunnelAvailable: fullTunnelAvailable(config),
      routerName: detectPrimaryRouter(config),
    );
  },
);

/// Применяется смена маршрута или туннеля. Пока `true`, лист не принимает нажатия:
/// два `applyWorkMode` подряд гоняются друг с другом.
final m3eRouteApplyingProvider = StateProvider<bool>((ref) => false);

/// Данные листа из групп и профиля приложения.
final m3eRouteDataProvider = Provider.autoDispose<M3eRouteData>((ref) {
  final profile = ref.watch(currentProfileProvider);
  final groupsCount =
      ref.watch(currentGroupsStateProvider.select((s) => s.value.length));
  if (profile == null) return M3eRouteData(groupsCount: groupsCount);

  final info = ref.watch(m3eRouteInfoProvider(profile.id)).valueOrNull;
  final routerName = info?.routerName;
  // Нефильтрованный список: скрытый агрегатор всё равно агрегатор (регрессия 2026-08-09).
  final groups = ref.watch(groupsProvider);
  final router = routerName == null ? null : groups.getGroup(routerName);
  if (router == null) {
    return M3eRouteData(
      routerName: routerName,
      fullTunnelAvailable: info?.fullTunnelAvailable ?? false,
      fullTunnel: profile.fullTunnel,
      groupsCount: groupsCount,
    );
  }

  final groupNames = aggregateGroupNames(groups);
  final selectedName = router
      .resolveSelectedName(ref.watch(getProxyNameProvider(router.name)) ?? '');

  int? pingOf(String name) {
    final delay =
        ref.watch(getDelayProvider(proxyName: name, testUrl: router.testUrl));
    // Ноль — не измерено; отрицательный — таймаут.
    return (delay == null || delay == 0) ? null : delay;
  }

  // Порядок как на доске: «Авто», затем страны, затем остальное в порядке роутера.
  // Ни один член не прячется: список всегда `router.all`.
  final auto = <M3eRouteRow>[];
  final countries = <M3eRouteRow>[];
  final others = <M3eRouteRow>[];
  for (final proxy in router.all) {
    final aggregate = isAggregateMember(
      proxyName: proxy.name,
      routerName: router.name,
      allGroupNames: groupNames,
    );
    final flag = extractCountryFlag(proxy.name);
    final emoji = flag == null ? extractLeadEmoji(proxy.name) : null;
    final label = _plainName(proxy.name);
    final selected = proxy.name == selectedName;
    final ping = pingOf(proxy.name);
    if (flag != null) {
      // Страна с флагом остаётся страной, даже если в ядре это группа: панель
      // провайдера отдаёт `🇩🇪 Германия ✨` как url-test с `filter`, и без флага
      // в аватаре и с подписью узла она выглядела группой (жалоба владельца
      // 2026-10-29). `isAggregate` сохраняется для выбора: старый экран «Страна»
      // для такого члена тоже ставит `WorkMode.standard`, а не `country`.
      countries.add(
        M3eRouteRow(
          id: proxy.name,
          label: label,
          flag: flag,
          isAggregate: aggregate,
          pingMs: ping,
          selected: selected,
        ),
      );
    } else if (aggregate) {
      // Подпись «Авто» — конечный узел: вложенные группы (`⚡ Fastest`) не показываем,
      // идём по выбору групп до листа. Остальные агрегаторы без флага (`📶 First
      // Available`) скрыты: владелец их не хочет видеть; выбранный скрытый агрегатор
      // просто не отмечает ни одну строку.
      if (auto.isNotEmpty) continue;
      final chosen = _leafOf(
        proxy.name,
        groups,
        (n) => ref.watch(getProxyNameProvider(n)) ?? '',
      );
      auto.add(
        M3eRouteRow(
          id: proxy.name,
          label: label,
          sup: chosen.isEmpty ? null : _plainName(chosen),
          emoji: emoji,
          isAggregate: true,
          pingMs: ping,
          selected: selected,
        ),
      );
    } else {
      others.add(
        M3eRouteRow(
          id: proxy.name,
          label: label,
          // Эмодзи узла (`⚪ White`) — в аватаре, из подписи убрано.
          emoji: emoji,
          pingMs: ping,
          selected: selected,
        ),
      );
    }
  }

  return M3eRouteData(
    rows: [...auto, ...countries, ...others],
    routerName: router.name,
    fullTunnelAvailable: info?.fullTunnelAvailable ?? false,
    fullTunnel: profile.fullTunnel,
    groupsCount: groupsCount,
    probe: router.all,
    testUrl: router.testUrl,
  );
});

/// Имя для подписи: без флага, а если флага нет — без ведущего эмодзи (оно в аватаре).
String _plainName(String name) {
  final noFlag = stripCountryFlag(name);
  if (noFlag != name) return noFlag.isEmpty ? name : noFlag;
  return stripLeadEmoji(name);
}

/// Конечный узел цепочки выбора: от [start] по `resolveSelectedName` вложенных групп,
/// пока имя указывает на группу. Посещённые имена запоминаются: цикл в конфиге не
/// должен подвесить сборку (тогда берём последнее имя до повтора).
String _leafOf(
  String start,
  List<Group> groups,
  String Function(String groupName) pinned,
) {
  var name = start;
  final seen = <String>{};
  var leaf = '';
  while (seen.add(name)) {
    final group = groups.getGroup(name);
    if (group == null) return name == start ? leaf : name;
    final next = group.resolveSelectedName(pinned(group.name));
    if (next.isEmpty) return leaf;
    leaf = next;
    name = next;
  }
  return leaf;
}

/// Действия листа. Набор одним объектом, чтобы тест подменял их без `globalState`.
class M3eRouteActions {
  const M3eRouteActions({
    required this.pick,
    required this.setFullTunnel,
    required this.probe,
  });

  /// Выбор строки: запись в ядро и смена режима.
  final Future<void> Function(M3eRouteRow row) pick;
  final Future<void> Function({required bool enabled}) setFullTunnel;

  /// Однократный замер задержки при открытии листа.
  final Future<void> Function(List<Proxy> proxies, String? testUrl) probe;
}

/// Выполняет [body] под флагом `m3eRouteApplyingProvider`; повторный вход игнорируется.
Future<void> _guarded(Ref ref, Future<void> Function() body) async {
  final flag = ref.read(m3eRouteApplyingProvider.notifier);
  if (flag.state) return;
  flag.state = true;
  try {
    await body();
  } finally {
    flag.state = false;
  }
}

final m3eRouteActionsProvider = Provider<M3eRouteActions>(
  (ref) => M3eRouteActions(
    pick: (row) => _guarded(ref, () async {
      final routerName = ref.read(m3eRouteDataProvider).routerName;
      if (routerName == null) return;
      final controller = globalState.appController
        ..updateCurrentSelectedMap(routerName, row.id)
        ..changeProxyDebounce(routerName, row.id);
      // Агрегатор («Авто») возвращает режим «Стандарт», страна — «Страна»;
      // `routerPin` держит выбор, чтобы роутер не откатился к первому члену.
      await controller.applyWorkMode(
        row.isAggregate ? WorkMode.standard : WorkMode.country,
        staticCountry: row.isAggregate ? null : row.id,
        routerPin: row.id,
      );
    }),
    setFullTunnel: ({required enabled}) => _guarded(
      ref,
      () => globalState.appController.setFullTunnel(enabled: enabled),
    ),
    probe: delayTest,
  ),
);
