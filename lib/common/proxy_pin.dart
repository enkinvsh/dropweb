import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';

import 'work_mode_patch.dart'
    show workModeCountryGroupPrefix, workModeSmartGroupName;

/// Whether a saved `selectedMap` value was written by the app's work-mode
/// wiring instead of being picked by the user.
///
/// `applyWorkMode` owns every entry pointing at the injected «Умный» / «Страна
/// <flag>» group: those express the active mode, so they must outlive a core
/// failover — forgetting one would silently unwire the mode until the user
/// re-applies it.
bool isWorkModeOwnedSelection(String selectedName) =>
    selectedName == workModeSmartGroupName ||
    selectedName.startsWith('$workModeCountryGroupPrefix ');

/// Итоговая `selectedMap` профиля после применения режима [mode]. PURE: [current]
/// не мутируется.
///
/// Извлечено из `AppController.applyWorkMode`, чтобы результат — то, КУДА ядро
/// в итоге маршрутизирует — можно было зафиксировать тестом, а не только
/// промежуточную классификацию члена роутера.
///
/// [ownedRouter] — единственный ключ, которым владеет work mode (первичный
/// роутер, цель `MATCH`); null ⇒ владеть нечем. [smartGroups] / [smartAvailable]
/// — вход режима «Умный», [countryTarget] — уже разрешённая цель «Страны».
///
/// [routerPin] — то, что юзер ТОЛЬКО ЧТО ткнул в списке членов роутера.
/// В [WorkMode.standard] он ВОССТАНАВЛИВАЕТСЯ после снятия ключа роутера.
/// Причина (регрессия 2026-08-09): экран «Страна» рисует состав роутера, и член,
/// чьё имя совпало с именем какой-то группы, классифицируется как агрегатор →
/// профиль уходит в Standard. Но каноничный шаблон Clash/Remnawave объявляет
/// САМУ СТРАНУ группой (`🇳🇱 Нидерланды`, type: url-test), поэтому такая
/// классификация может ошибиться. Раньше ошибка стирала свежий пин, и ядро
/// уводило трафик в ПЕРВОГО члена роутера — юзер думал, что он в Нидерландах,
/// а выходил в Германии. Отличать «авто» от «страны» надёжно нельзя без
/// хардкода, поэтому мы делаем ошибку БЕЗВРЕДНОЙ: что бы юзер ни ткнул, его пин
/// сохраняется и маршрут совпадает с тапом. Побочный эффект — попутно чинится
/// гонка `changeProxyDebounce` (600 мс): отложенная запись в ядро и персист
/// теперь говорят одно и то же.
///
/// null ⇒ прежнее поведение (ключ роутера просто снимается) — так ведут себя
/// все вызовы, которые пином не располагают (карточка «Стандарт», revalidate).
Map<String, String> resolveWorkModeSelectedMap({
  required SelectedMap current,
  required WorkMode mode,
  required String? ownedRouter,
  required String? countryTarget,
  required List<String> smartGroups,
  required bool smartAvailable,
  String? routerPin,
}) {
  // Снимаем ключи, которыми владеет work mode. Два механизма:
  //  * по VALUE — старая схема (значения «Умный» / «Страна *»), в т.ч. ключи
  //    от прежнего fork-Б, где страна биндилась во ВСЕ rule-группы;
  //  * по KEY — новая схема пишет в роутер ИМЯ УЗЛА, которое от ручного пина
  //    юзера по значению не отличить, поэтому чистим ключ роутера явно.
  //    Без этого выход из «Страны» оставлял бы узел приколотым в Standard.
  final selectedMap = Map<String, String>.from(current)
    ..removeWhere((_, v) => isWorkModeOwnedSelection(v))
    ..remove(GroupName.GLOBAL.name);
  if (ownedRouter != null) {
    selectedMap.remove(ownedRouter);
  }

  switch (mode) {
    case WorkMode.smart:
      // Only bind when «Умный» will actually be injected AS A MEMBER of each
      // group (smartAvailable). The core honors a forced `selected` only among
      // a group's own members, so binding without the injected member would be
      // inert (D2); binding when smart is unavailable would dangle.
      if (smartAvailable) {
        for (final group in smartGroups) {
          selectedMap[group] = workModeSmartGroupName;
        }
      }
      break;
    case WorkMode.country:
      // Вариант А: единственный ключ — первичный роутер (цель MATCH). Патч
      // гарантировал, что countryTarget — его прямой член (select), либо
      // схлопнул состав роутера до него (не-select). Пер-сервисные группы
      // (YouTube / Discord / Telegram) сохраняют маршрут провайдера.
      if (ownedRouter != null && countryTarget != null) {
        selectedMap[ownedRouter] = countryTarget;
      }
      break;
    case WorkMode.standard:
      // FAIL-SAFE. Ключ роутера снят выше — но если юзер прямо сейчас ткнул
      // члена роутера, его выбор обязан пережить применение режима. Иначе
      // ошибка классификации («страна-группа принята за агрегатор») молча
      // уводит трафик в ПЕРВОГО члена роутера. Пин восстанавливаем ПОСЛЕ
      // снятия, поэтому старый ключ режима им честно перетирается.
      if (ownedRouter != null && routerPin != null && routerPin.isNotEmpty) {
        selectedMap[ownedRouter] = routerPin;
      }
      break;
  }
  return selectedMap;
}

/// Group names whose saved pin the core has already abandoned.
///
/// A computed group (url-test / fallback / smart) drops its pinned member the
/// moment that member fails its health check: mihomo clears its own `selected`,
/// fails over to the next healthy member and reports `fixed: ""`. The profile
/// keeps the pin, so every later setup force-applies it again
/// (`patchSelectGroup` → `ForceSet`) and the UI keeps rendering a member the
/// core abandoned — the «залипание на мёртвом каскаде» symptom. Naming those
/// groups lets the caller forget the pin and follow the core again.
///
/// Deliberately left alone: selector groups (there the saved pin IS the routing
/// decision and mihomo reports no `fixed` at all), work-mode keys, empty pins,
/// and groups missing from the core snapshot.
Set<String> staleSelectedGroupNames({
  required List<Group> groups,
  required SelectedMap selectedMap,
}) {
  final stale = <String>{};
  for (final group in groups) {
    if (!group.type.isComputedSelected) continue;
    final pinned = selectedMap[group.name] ?? '';
    if (pinned.isEmpty || isWorkModeOwnedSelection(pinned)) continue;
    if (group.fixed.isEmpty) stale.add(group.name);
  }
  return stale;
}
