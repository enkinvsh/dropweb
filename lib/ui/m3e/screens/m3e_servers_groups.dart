// Экран «Серверы и группы» и шаг «группа → узлы» внутри листа «Маршрут» (сцена `servers`
// доски, `routeGroups()` и `routeGroup()` в android.js). Здесь только тела шагов:
// лист и стек шагов (`M3eSheetStack`) принадлежат экрану маршрута.
//
// Единственная точка знания о провайдерах приложения — адаптеры в начале файла;
// golden-тесты подменяют их целиком и не трогают `globalState`.

import 'dart:async';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/proxies/common.dart' show delayTest;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../m3e_emoji.dart';
import '../symbols.g.dart';
import '../theme/m3e_theme_scope.dart';
import '../widgets/m3e_list.dart';
import '../widgets/m3e_sheet.dart';

// ---------- Модели ----------

/// Узел группы: имя и протокол (подпись второй строкой).
@immutable
class M3eServerNode {
  const M3eServerNode({required this.name, required this.type});

  final String name;
  final String type;

  @override
  bool operator ==(Object other) =>
      other is M3eServerNode && other.name == name && other.type == type;

  @override
  int get hashCode => Object.hash(name, type);
}

/// Группа ядра в виде, нужном экрану. Решения о выборе уже приняты адаптером
/// (`Group.resolveSelectedName` и `getCurrentSelectedName`), экран ничего не вычисляет.
@immutable
class M3eServerGroup {
  const M3eServerGroup({
    required this.name,
    required this.nodes,
    this.testUrl,
    this.selectedName = '',
    this.selectedLabel = '',
  });

  final String name;

  /// Адрес замера: ключ в `delayDataSource`, без него пинг пишется в чужую ячейку.
  final String? testUrl;
  final List<M3eServerNode> nodes;

  /// Имя узла, через который группа идёт сейчас; пусто, когда единого узла нет
  /// (умная группа без закрепления). Пригодно для замера и сравнения.
  final String selectedName;

  /// Подпись выбранного для показа: у умной группы без закрепления это метка «авто».
  final String selectedLabel;

  @override
  bool operator ==(Object other) =>
      other is M3eServerGroup &&
      other.name == name &&
      other.testUrl == testUrl &&
      other.selectedName == selectedName &&
      other.selectedLabel == selectedLabel &&
      listEquals(other.nodes, nodes);

  @override
  int get hashCode => Object.hash(
        name,
        testUrl,
        selectedName,
        selectedLabel,
        Object.hashAll(nodes),
      );
}

/// Ключ ячейки задержки: имя узла и адрес замера.
typedef M3eDelayKey = ({String name, String? testUrl});

// ---------- Адаптеры ----------

/// Группы текущего профиля без скрытых (`currentGroupsStateProvider` их уже отбросил).
final m3eServerGroupsProvider = Provider<List<M3eServerGroup>>((ref) {
  final groups = ref.watch(currentGroupsStateProvider).value;
  return [
    for (final g in groups)
      () {
        // Имя выбранного читаем отдельным провайдером: он же обновляется при выборе узла.
        final proxyName = ref.watch(getProxyNameProvider(g.name)) ?? '';
        return M3eServerGroup(
          name: g.name,
          testUrl: g.testUrl,
          nodes: [
            for (final p in g.all) M3eServerNode(name: p.name, type: p.type),
          ],
          selectedName: g.resolveSelectedName(proxyName),
          selectedLabel: g.getCurrentSelectedName(proxyName),
        );
      }(),
  ];
});

/// Одна группа по имени; `null`, если её убрали (смена профиля при открытом листе).
final m3eServerGroupProvider = Provider.family<M3eServerGroup?, String>((
  ref,
  name,
) {
  final groups = ref.watch(m3eServerGroupsProvider);
  for (final g in groups) {
    if (g.name == name) return g;
  }
  return null;
});

/// Задержка узла в мс: `null` и 0 — не замерено, отрицательная — нет ответа.
final m3eNodeDelayProvider = Provider.family<int?, M3eDelayKey>(
  (ref, key) => ref.watch(
    getDelayProvider(proxyName: key.name, testUrl: key.testUrl),
  ),
);

/// Действия экрана. Поля-функции, чтобы тесты подменяли их без ядра.
class M3eServersActions {
  const M3eServersActions({
    required this.selectNode,
    required this.probe,
  });

  /// Выбрать узел в группе тем же путём, что старый экран: карта выбора и отложенная
  /// запись в ядро.
  final void Function(String groupName, String nodeName) selectNode;

  /// Замер узлов. Адрес замера обязателен тем же, что у группы, иначе результат
  /// ляжет в другой ключ и экран его не увидит.
  final Future<void> Function(List<M3eServerNode> nodes, String? testUrl) probe;
}

final m3eServersActionsProvider = Provider<M3eServersActions>(
  (ref) => M3eServersActions(
    selectNode: (group, node) {
      globalState.appController
        ..updateCurrentSelectedMap(group, node)
        ..changeProxyDebounce(group, node);
    },
    probe: (nodes, testUrl) => delayTest(
      [for (final n in nodes) Proxy(name: n.name, type: n.type)],
      testUrl,
    ),
  ),
);

// ---------- Разбор имени ----------

/// Ведущий флаг: пара региональных индикаторов (`LEAD` в android.js).
final RegExp _flagLead = RegExp(r'^(\p{RI}{2})\s*', unicode: true);

/// Имя без ведущего флага/эмодзи; если после него ничего нет, имя целиком.
String m3eServerTitle(String name) {
  final m = _flagLead.firstMatch(name);
  if (m == null) return stripLeadEmoji(name);
  final rest = name.substring(m.end);
  return rest.isEmpty ? name : rest;
}

/// Аватар: флаг (круг на всё поле), эмодзи (составные тоже: ZWJ, keycap) или символ.
M3eListLead _leadFor(String name, M3eSymbol fallback) {
  final flag = _flagLead.firstMatch(name)?.group(1);
  if (flag != null) return M3eListLead.avatar(flag: flag);
  final emoji = extractLeadEmoji(name);
  return emoji != null
      ? M3eListLead.avatar(emoji: emoji)
      : M3eListLead.avatar(icon: fallback);
}

/// Хвост с задержкой: `null`, пока не замерено; «нет ответа» красным; от 600 мс янтарным.
M3eListTrail? _delayTrail(AppLocalizations l, int? delay) {
  if (delay == null || delay == 0) return null;
  if (delay < 0) {
    return M3eListTrail.text(l.m3eMsNoAnswer, tone: M3eTrailTone.dead);
  }
  return M3eListTrail.text(
    l.m3eValueMs(delay),
    tone: delay >= 600 ? M3eTrailTone.slow : M3eTrailTone.normal,
  );
}

/// Ключ списка и пунктов совпадает с остальными экранами M3E (`m3e.list.item.N`).
const Key kM3eServersListKey = ValueKey<String>('m3e.list');
Key m3eServersItemKey(int index) => ValueKey<String>('m3e.list.item.$index');

// ---------- Шаг 1: группы ----------

/// Тело шага «Серверы и группы»: группа, её выбранный узел и его задержка.
/// Нажатие открывает шаг узлов группы внутри того же листа.
class M3eServersGroupsView extends ConsumerStatefulWidget {
  const M3eServersGroupsView({super.key});

  @override
  ConsumerState<M3eServersGroupsView> createState() =>
      _M3eServersGroupsViewState();
}

class _M3eServersGroupsViewState extends ConsumerState<M3eServersGroupsView> {
  @override
  void initState() {
    super.initState();
    // Замер один раз после первого кадра и вне build. Меряем только выбранный
    // узел каждой группы, как старый экран: остальные не нужны для этой подписи.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _probeSelected();
    });
  }

  void _probeSelected() {
    final groups = ref.read(m3eServerGroupsProvider);
    final actions = ref.read(m3eServersActionsProvider);
    // Одинаковый адрес замера — один вызов; один узел в разных группах — один раз.
    final byUrl = <String?, Map<String, M3eServerNode>>{};
    for (final g in groups) {
      if (g.selectedName.isEmpty) continue;
      final node = g.nodes.where((n) => n.name == g.selectedName).firstOrNull;
      if (node == null) continue;
      byUrl.putIfAbsent(g.testUrl, () => {})[node.name] = node;
    }
    for (final e in byUrl.entries) {
      unawaited(actions.probe(e.value.values.toList(), e.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = ref.watch(m3eServerGroupsProvider);
    final scheme = M3eColors.of(context).scheme;

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
        child: Text(
          l.nullProfileDesc,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.role('onSurfaceVariant'),
              ),
        ),
      );
    }

    return M3eListSurfaceScope(
      surface: M3eListSurface.sheet,
      child: M3eList(
        key: kM3eServersListKey,
        semanticLabel: l.m3eServersTitle,
        children: [
          for (var i = 0; i < groups.length; i++)
            _GroupItem(group: groups[i], itemKey: m3eServersItemKey(i)),
        ],
      ),
    );
  }
}

class _GroupItem extends ConsumerWidget {
  const _GroupItem({required this.group, required this.itemKey});

  final M3eServerGroup group;
  final Key itemKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final delay = group.selectedName.isEmpty
        ? null
        : ref.watch(
            m3eNodeDelayProvider(
              (name: group.selectedName, testUrl: group.testUrl),
            ),
          );
    return M3eListItem(
      key: itemKey,
      lead: _leadFor(group.name, M3eSymbol.hub),
      label: m3eServerTitle(group.name),
      sup: group.selectedLabel.isEmpty ? l.m3eStatNone : group.selectedLabel,
      trail: _delayTrail(l, delay),
      onTap: () => M3eSheetStack.of(context).push(
        (_) => M3eServerNodesPage(groupName: group.name),
      ),
    );
  }
}

// ---------- Шаг 2: узлы группы ----------

/// Страница шага «узлы группы»: заголовок — имя группы без ведущего флага, внутри
/// радиосписок. Строитель для `M3eSheetStack.push`.
class M3eServerNodesPage extends ConsumerWidget {
  const M3eServerNodesPage({super.key, required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => M3eSheetScaffold(
        title: m3eServerTitle(groupName),
        body: M3eServerNodesView(groupName: groupName),
      );
}

/// Тело шага узлов: радиогруппа узлов. Выбор вызывает смену узла и возвращает
/// на шаг назад. При открытии один раз замеряет все узлы группы.
class M3eServerNodesView extends ConsumerStatefulWidget {
  const M3eServerNodesView({super.key, required this.groupName});

  final String groupName;

  @override
  ConsumerState<M3eServerNodesView> createState() => _M3eServerNodesViewState();
}

class _M3eServerNodesViewState extends ConsumerState<M3eServerNodesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final g = ref.read(m3eServerGroupProvider(widget.groupName));
      if (g == null || g.nodes.isEmpty) return;
      unawaited(ref.read(m3eServersActionsProvider).probe(g.nodes, g.testUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = ref.watch(m3eServerGroupProvider(widget.groupName));
    if (group == null) return const SizedBox.shrink();

    return M3eListSurfaceScope(
      surface: M3eListSurface.sheet,
      child: M3eList(
        key: kM3eServersListKey,
        semanticLabel: m3eServerTitle(group.name),
        children: [
          for (var i = 0; i < group.nodes.length; i++)
            _NodeItem(
              key: m3eServersItemKey(i),
              group: group,
              node: group.nodes[i],
              l: l,
            ),
        ],
      ),
    );
  }
}

class _NodeItem extends ConsumerWidget {
  const _NodeItem({
    super.key,
    required this.group,
    required this.node,
    required this.l,
  });

  final M3eServerGroup group;
  final M3eServerNode node;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = group.selectedName == node.name;
    final delay = ref.watch(
      m3eNodeDelayProvider((name: node.name, testUrl: group.testUrl)),
    );
    final ms = _delayTrail(l, delay);
    // «Задержка + галочка» у выбранного, как `ms(v, sel)` на доске.
    final trail = selected
        ? M3eListTrail.row([
            if (ms != null) ms,
            M3eListTrail.icon(M3eSymbol.check),
          ])
        : ms;
    return M3eListItem(
      lead: _leadFor(node.name, M3eSymbol.dns),
      label: m3eServerTitle(node.name),
      sup: node.type,
      trail: trail,
      radioChecked: selected,
      onTap: () {
        ref.read(m3eServersActionsProvider).selectNode(group.name, node.name);
        M3eSheetStack.maybeOf(context)?.pop();
      },
    );
  }
}
