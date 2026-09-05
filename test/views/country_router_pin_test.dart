// Замок на БЛОКЕР МАРШРУТИЗАЦИИ (ревью F3, 2026-08-09).
//
// Что ломалось. Экран «Страна» рисует состав ГРУППЫ-РОУТЕРА (цель `MATCH`) и
// классифицирует каждого её члена структурным правилом: «имя совпало с именем
// другой группы ⇒ агрегатор («авто»/каскад), иначе страна». Каноничный шаблон
// Clash/Remnawave, однако, объявляет САМУ СТРАНУ группой:
//
//     🌍 VPN (select, цель MATCH) → [🇩🇪 Германия (url-test),
//                                    🇳🇱 Нидерланды (url-test),
//                                    🇺🇸 США        (url-test)]
//
// То есть КАЖДЫЙ член такого роутера — группа, и правило зовёт агрегатором
// вообще всё. Тап по `🇳🇱 Нидерланды` уводил профиль в WorkMode.standard, а
// Standard СТИРАЛ ключ роутера из `selectedMap` — ровно тот пин, который
// `ProxySelectorSheet` записал тремя строками ранее. Ядро пересобиралось без
// пина, mihomo `select` брал ПЕРВОГО члена → 🇩🇪 Германия. Юзер уверен, что он
// в Нидерландах; трафик выходит в Германии.
//
// Принцип фикса — FAIL-SAFE, а не угадывание. Отличить «авто» от «страны» по
// типу группы / флагу / имени / числу членов нельзя без хардкода — попытка это
// сделать и породила оба бага. Правило остаётся структурным; меняется только
// ЦЕНА ошибки: что бы юзер ни ткнул, его пин сохраняется и маршрут совпадает с
// тапом. Косметическое «режим показывает Стандарт вместо Страна» приемлемо;
// неверный exit-узел — нет.
//
// Побочно фикс обезвреживает гонку `changeProxyDebounce` (600 мс): отложенная
// запись в ядро и персист теперь говорят одно и то же.
//
// Существующий test/views/country_router_group_test.dart фиксирует контракт
// чистых функций ВЫШЕ по потоку (что такое агрегатор). Этот файл закрывает то,
// что тот не покрывал ни одним тестом: получившуюся `selectedMap` — то, куда
// ядро в итоге маршрутизирует.
//
// Cross-links: lib/common/proxy_pin.dart (resolveWorkModeSelectedMap),
// lib/controller.dart (applyWorkMode), lib/views/subscription/modes_content.dart
// (resolveCountryScreenState, _apply), proxy_selector_sheet.dart (правило).

import 'package:dropweb/common/proxy_pin.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/views/subscription/modes_content.dart';
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _router = '🌍 VPN';
const _de = '🇩🇪 Германия';
const _nl = '🇳🇱 Нидерланды';
const _us = '🇺🇸 США';
const _games = '🎮 Games';

/// Каноничный шаблон, в котором СТРАНА САМА ЯВЛЯЕТСЯ ГРУППОЙ: роутер `select`
/// с целью `MATCH`, все три его члена — `url-test`-группы над узлами страны.
/// Именно этот shape ломался.
Map<String, dynamic> _configAllMembersAreGroups() => {
      'proxies': [
        {'name': 'de-1', 'type': 'vless', 'server': 'de1.example', 'port': 443},
        {'name': 'de-2', 'type': 'vless', 'server': 'de2.example', 'port': 443},
        {'name': 'nl-1', 'type': 'vless', 'server': 'nl1.example', 'port': 443},
        {'name': 'nl-2', 'type': 'vless', 'server': 'nl2.example', 'port': 443},
        {'name': 'us-1', 'type': 'vless', 'server': 'us1.example', 'port': 443},
      ],
      'proxy-groups': [
        {
          'name': _router,
          'type': 'select',
          'proxies': [_de, _nl, _us],
        },
        {
          'name': _de,
          'type': 'url-test',
          'proxies': ['de-1', 'de-2'],
        },
        {
          'name': _nl,
          'type': 'url-test',
          'proxies': ['nl-1', 'nl-2'],
        },
        {
          'name': _us,
          'type': 'url-test',
          'proxies': ['us-1'],
        },
      ],
      'rules': ['MATCH,$_router'],
    };

Proxy _proxy(String name) => Proxy(name: name, type: 'Shadowsocks');

Group _routerGroup({bool hidden = false}) => Group(
      type: GroupType.Selector,
      name: _router,
      hidden: hidden,
      all: [_proxy(_de), _proxy(_nl), _proxy(_us)],
    );

Group _countryGroup(String name) => Group(
      type: GroupType.URLTest,
      name: name,
      all: [_proxy('${name}-node')],
    );

/// Состав групп ядра для конфига выше: роутер + три страны-группы.
List<Group> _coreGroups({bool routerHidden = false}) => [
      _routerGroup(hidden: routerHidden),
      _countryGroup(_de),
      _countryGroup(_nl),
      _countryGroup(_us),
    ];

/// Полный путь тапа по члену роутера — БЕЗ виджета, но через РОВНО те же
/// чистые функции, которые зовёт продовый код:
///   1. [resolveCountryScreenState] — какой роутер рисуем;
///   2. [aggregateGroupNames] + [isAggregateMember] — агрегатор или страна;
///   3. `ProxySelectorSheet.onTap` → `updateCurrentSelectedMap` пишет пин;
///   4. `modes_content._apply` → `applyWorkMode` → [resolveWorkModeSelectedMap].
/// Возвращает `selectedMap`, с которой в итоге пересобирается ядро.
({Map<String, String> selectedMap, bool isAggregate, dynamic mode}) _tap(
  String memberName, {
  Map<String, String> before = const {},
  List<Group>? groups,
  Map<String, dynamic>? config,
}) {
  final cfg = config ?? _configAllMembersAreGroups();
  final coreGroups = groups ?? _coreGroups();

  final screen = resolveCountryScreenState(cfg, coreGroups);
  expect(screen.status, CountryScreenStatus.ready,
      reason: 'экран обязан дорисоваться до списка стран');
  final routerName = screen.group!.name;

  final isAggregate = isAggregateMember(
    proxyName: memberName,
    routerName: routerName,
    allGroupNames: aggregateGroupNames(coreGroups),
  );

  // Шаг 3: лист ВСЕГДА пишет пин в роутер (updateCurrentSelectedMap).
  final afterSheet = Map<String, String>.from(before)..[routerName] = memberName;

  // Шаг 4: экран «Страна» применяет режим и ПЕРЕДАЁТ ткнутое имя как routerPin.
  final mode = isAggregate ? WorkMode.standard : WorkMode.country;
  final selectedMap = resolveWorkModeSelectedMap(
    current: afterSheet,
    mode: mode,
    ownedRouter: routerName,
    // Standard не биндит страну; для country это имя бы разрешил
    // countryTargetName — здесь он не участвует, ветка проверяется отдельно.
    countryTarget: isAggregate ? null : memberName,
    smartGroups: [routerName],
    smartAvailable: false,
    routerPin: memberName,
  );
  return (selectedMap: selectedMap, isAggregate: isAggregate, mode: mode);
}

void main() {
  group('БЛОКЕР: роутер, все члены которого — группы', () {
    test(
        'каждый член такого роутера классифицируется как агрегатор — правило '
        'структурно и ошибиться МОЖЕТ', () {
      final names = aggregateGroupNames(_coreGroups());
      for (final member in [_de, _nl, _us]) {
        expect(
          isAggregateMember(
            proxyName: member,
            routerName: _router,
            allGroupNames: names,
          ),
          isTrue,
          reason: '$member объявлен группой ⇒ правило зовёт его агрегатором',
        );
      }
    });

    test(
        'ФИКС: тап по 🇳🇱 Нидерланды СОХРАНЯЕТ пин, хотя режим уходит в '
        'Standard — трафик идёт туда, куда ткнули', () {
      final result = _tap(_nl);

      expect(result.isAggregate, isTrue,
          reason: 'подтверждаем, что это именно ошибочно-агрегаторная ветка');
      expect(result.mode, WorkMode.standard);
      // ГЛАВНОЕ. Раньше здесь было null → mihomo брал ПЕРВОГО члена (🇩🇪).
      expect(
        result.selectedMap[_router],
        _nl,
        reason: 'пин, поставленный тапом, обязан пережить применение Standard',
      );
      expect(result.selectedMap[_router], isNot(_de),
          reason: 'молчаливый увод в первого члена роутера — тот самый блокер');
    });

    test('пин сохраняется для ЛЮБОГО члена, а не только для второго', () {
      for (final member in [_de, _nl, _us]) {
        expect(_tap(member).selectedMap[_router], member);
      }
    });

    test('ручные выборы юзера в прочих группах тап не трогает', () {
      final result = _tap(_nl, before: const {_games: 'nl-2'});

      expect(result.selectedMap, {_router: _nl, _games: 'nl-2'});
    });
  });

  group('resolveWorkModeSelectedMap: контракт routerPin', () {
    test('standard + routerPin ⇒ selectedMap[router] == routerPin', () {
      final map = resolveWorkModeSelectedMap(
        current: const {_router: 'Страна 🇩🇪', _games: 'nl-2'},
        mode: WorkMode.standard,
        ownedRouter: _router,
        countryTarget: null,
        smartGroups: const [_router],
        smartAvailable: false,
        routerPin: _nl,
      );

      expect(map, {_router: _nl, _games: 'nl-2'});
    });

    test(
        'ОБРАТНАЯ СОВМЕСТИМОСТЬ: standard без routerPin ⇒ ключ роутера снят '
        '(поведение вызывающих, у которых пина нет)', () {
      final map = resolveWorkModeSelectedMap(
        current: const {_router: 'Страна 🇩🇪', _games: 'nl-2'},
        mode: WorkMode.standard,
        ownedRouter: _router,
        countryTarget: null,
        smartGroups: const [_router],
        smartAvailable: false,
      );

      expect(map, {_games: 'nl-2'});
      expect(map.containsKey(_router), isFalse);
    });

    test('пустой routerPin ведёт себя как null — пустое имя не пиним', () {
      final map = resolveWorkModeSelectedMap(
        current: const {_router: _de},
        mode: WorkMode.standard,
        ownedRouter: _router,
        countryTarget: null,
        smartGroups: const [_router],
        smartAvailable: false,
        routerPin: '',
      );

      expect(map, isEmpty);
    });

    test('country игнорирует routerPin — цель режима сильнее свежего тапа', () {
      final map = resolveWorkModeSelectedMap(
        current: const {_router: _de},
        mode: WorkMode.country,
        ownedRouter: _router,
        countryTarget: 'Страна 🇳🇱',
        smartGroups: const [_router],
        smartAvailable: false,
        routerPin: _nl,
      );

      expect(map, {_router: 'Страна 🇳🇱'});
    });

    test('smart игнорирует routerPin и биндит «Умный» только когда он доступен',
        () {
      expect(
        resolveWorkModeSelectedMap(
          current: const {_router: _de},
          mode: WorkMode.smart,
          ownedRouter: _router,
          countryTarget: null,
          smartGroups: const [_router],
          smartAvailable: true,
          routerPin: _nl,
        ),
        {_router: 'Умный'},
      );
      expect(
        resolveWorkModeSelectedMap(
          current: const {_router: _de},
          mode: WorkMode.smart,
          ownedRouter: _router,
          countryTarget: null,
          smartGroups: const [_router],
          smartAvailable: false,
          routerPin: _nl,
        ),
        isEmpty,
      );
    });

    test('ownedRouter == null ⇒ пин писать некуда, режим ничего не ломает', () {
      final map = resolveWorkModeSelectedMap(
        current: const {_games: 'nl-2'},
        mode: WorkMode.standard,
        ownedRouter: null,
        countryTarget: null,
        smartGroups: const [],
        smartAvailable: false,
        routerPin: _nl,
      );

      expect(map, {_games: 'nl-2'});
    });
  });

  // ── F1-C1: скрытый роутер ────────────────────────────────────────────────
  //
  // `modes_content` брал состав групп из `currentGroupsStateProvider`, который
  // выкидывает `hidden == true` и `GLOBAL`. Провайдер, спрятавший свою
  // MATCH-группу, получал `getGroup → null → routerLoading` — ВЕЧНЫЙ СПИННЕР
  // без единой строки диагностики. Вход заменён на нефильтрованный
  // `groupsProvider`; здесь зафиксирован сам контракт.
  group('F1-C1: скрытый роутер всё равно резолвится', () {
    test('роутер с hidden: true ⇒ ready, а не вечный routerLoading', () {
      final state = resolveCountryScreenState(
        _configAllMembersAreGroups(),
        _coreGroups(routerHidden: true),
      );

      expect(state.status, CountryScreenStatus.ready);
      expect(state.group, isNotNull);
      expect(state.group!.name, _router);
      expect(state.status, isNot(CountryScreenStatus.routerLoading),
          reason: 'скрытость влияет на то, что РИСУЕТСЯ, а не на то, ЧТО ЭТО');
    });

    test('тап внутри скрытого роутера так же сохраняет пин', () {
      final result = _tap(_nl, groups: _coreGroups(routerHidden: true));

      expect(result.selectedMap[_router], _nl);
    });
  });
}
