// Лист «Маршрут» iOS-редизайна: сцены `route`, `servers` и третий уровень `group:i` доски
// (app.js: sheet() 763-769, routeBody 672-706).
//
// Данные и действия берём у M3E без правок (`m3eRouteDataProvider`, `m3eRouteActionsProvider`,
// `m3eServerGroupsProvider`, `m3eServersActionsProvider`): правила «Авто / страны / остальное»,
// скрытие «First Available», замер пинга и запись выбора в ядро одни на обе платформы.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart' show pingText;
import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_servers_groups.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Порог «медленного» пинга: с него число оранжевое (`v >= 600`, app.js:297).
const int kIos27RouteSlowMs = 600;

/// Отступ снизу прокручиваемого тела листа (`.sheet__body` padding-bottom 40).
const double kIos27RouteBodyBottom = 40;

/// Ключи строк для тестов и паритета.
const kIos27RouteAutoKey = ValueKey<String>('ios27.route.auto');
const kIos27RouteTunnelKey = ValueKey<String>('ios27.route.tunnel');
const kIos27RouteServersKey = ValueKey<String>('ios27.route.servers');
ValueKey<String> kIos27RouteRowKey(String id) =>
    ValueKey<String>('ios27.route.row.$id');
ValueKey<String> kIos27RouteGroupKey(int index) =>
    ValueKey<String>('ios27.route.group.$index');
ValueKey<String> kIos27RouteNodeKey(int index) =>
    ValueKey<String>('ios27.route.node.$index');

/// Идентификатор строки «Серверы и группы» для подсветки при переходе вглубь.
const String _kServersHighlight = 'servers';

/// Открывает лист выбора маршрута.
///
/// Выбор страны лист НЕ закрывает (на доске `route()` только перерисовывает). «Серверы и
/// группы» и узлы группы ложатся страницами в тот же лист через [Ios27SheetNavigator].
///
/// [origin] — кнопка-глобус дока, из которой лист вырастает (app.js 1263); без неё лист
/// выезжает снизу.
Future<void> showIos27RouteSheet(
  BuildContext context, {
  Ios27ZoomOrigin? origin,
}) =>
    showIos27Sheet<void>(
      context,
      origin: origin,
      // Шапку рисует сама страница (`Ios27SheetScaffold` внутри): так же устроены вложенные
      // уровни, и заголовок не задваивается.
      builder: (_) => const Ios27RouteSheetPage(),
    );

/// Ведущий флаг: пара региональных индикаторов (`FLAG_LEAD` доски, app.js:395). `extractLeadEmoji`
/// пару не берёт, поэтому флаг ищем отдельно, как это делает Android (`_flagLead`).
final RegExp _flagLead = RegExp(r'^(\p{RI}{2})\s*', unicode: true);

/// Аватар строки по ведущему флагу или эмодзи имени; без них плитки нет (`lead()` доски, app.js:398).
Widget? _leadForName(String name) {
  final flag = _flagLead.firstMatch(name)?.group(1);
  if (flag != null) {
    return Ios27Avatar.flag(flag);
  }
  final emoji = extractLeadEmoji(name);
  return emoji == null ? null : Ios27Avatar.emoji(emoji);
}

/// Пинг в виде значения строки; `null`, пока узел не замерен (`ms()` доски без значения).
({String text, Ios27RowDetailTone tone})? _pingDetail(
  AppLocalizations l,
  int? ms,
) {
  if (ms == null || ms == 0) {
    return null;
  }
  if (ms < 0) {
    return (text: l.m3eMsNoAnswer, tone: Ios27RowDetailTone.dead);
  }
  return (
    text: pingText(l, ms),
    tone: ms >= kIos27RouteSlowMs
        ? Ios27RowDetailTone.slow
        : Ios27RowDetailTone.normal,
  );
}

/// Прокручиваемое тело страницы листа: 68 от верха листа даёт шапка, внизу 40.
class _SheetScroll extends StatelessWidget {
  const _SheetScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kIos27RouteBodyBottom),
        child: child,
      );
}

// ---------- Главный уровень ----------

/// Корневая страница листа: данные и действия из провайдеров, замер пинга при открытии.
class Ios27RouteSheetPage extends ConsumerStatefulWidget {
  const Ios27RouteSheetPage({super.key});

  @override
  ConsumerState<Ios27RouteSheetPage> createState() =>
      _Ios27RouteSheetPageState();
}

class _Ios27RouteSheetPageState extends ConsumerState<Ios27RouteSheetPage> {
  /// Замер один раз за открытие: ядро само не проверяет состав `select`-группы, и без замера
  /// выбранная страна минутами остаётся без пинга.
  bool _probed = false;
  ProviderSubscription<M3eRouteData>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<M3eRouteData>(
      m3eRouteDataProvider,
      (_, next) => _probe(next),
      fireImmediately: true,
    );
  }

  void _probe(M3eRouteData data) {
    if (_probed || data.probe.isEmpty) {
      return;
    }
    _probed = true;
    // Не внутри сборки: замер пишет в провайдеры задержек.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(m3eRouteActionsProvider).probe(data.probe, data.testUrl),
      );
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(m3eRouteDataProvider);
    final applying = ref.watch(m3eRouteApplyingProvider);
    final actions = ref.read(m3eRouteActionsProvider);
    return Ios27SheetScaffold(
      title: l.m3eRouteTitle,
      body: _SheetScroll(
        child: Ios27RouteBody(
          data: data,
          applying: applying,
          onPick: (row) => unawaited(actions.pick(row)),
          onToggleTunnel: () =>
              unawaited(actions.setFullTunnel(enabled: !data.fullTunnel)),
          onServers: () => unawaited(
            Ios27SheetNavigator.push<void>(
              context,
              highlight: _kServersHighlight,
              builder: (_) => Ios27SheetScaffold(
                title: l.m3eServersTitle,
                body: const _SheetScroll(child: Ios27ServersGroupsView()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Тело главного уровня без провайдеров: golden и виджет-тесты подают [M3eRouteData] напрямую.
class Ios27RouteBody extends StatelessWidget {
  const Ios27RouteBody({
    super.key,
    required this.data,
    required this.onPick,
    required this.onToggleTunnel,
    required this.onServers,
    this.applying = false,
  });

  final M3eRouteData data;

  /// Идёт применение маршрута: нажатия не принимаются, чтобы два `applyWorkMode` не гонялись
  /// друг с другом.
  final bool applying;
  final void Function(M3eRouteRow row) onPick;
  final VoidCallback onToggleTunnel;
  final VoidCallback onServers;

  Widget _rowFor(
    AppLocalizations l,
    M3eRouteRow row, {
    required bool isAuto,
  }) {
    final ping = _pingDetail(l, row.pingMs);
    final Widget? leading;
    if (row.flag != null) {
      leading = Ios27Avatar.flag(row.flag!);
    } else if (isAuto || (row.isAggregate && row.emoji == null)) {
      // «Авто» на доске — значок молнии, а не эмодзи из имени.
      leading = const Ios27Avatar.icon(Ios27IconName.zap);
    } else if (row.emoji != null) {
      leading = Ios27Avatar.emoji(row.emoji!);
    } else {
      leading = null;
    }
    return Ios27ListRow(
      key: isAuto ? kIos27RouteAutoKey : kIos27RouteRowKey(row.id),
      // Автотесты через adb ищут режим по `dw_mode_*`, как на Android: выбор агрегатора
      // применяет `WorkMode.standard`, выбор страны — `WorkMode.country`.
      semanticIdentifier: row.isAggregate && row.flag == null
          ? 'dw_mode_standard'
          : 'dw_mode_country',
      leading: leading,
      title: isAuto ? l.m3eRouteAuto : row.label,
      subtitle: row.sup,
      detail: ping?.text,
      detailTone: ping?.tone ?? Ios27RowDetailTone.normal,
      accessory:
          row.selected ? Ios27RowAccessory.check : Ios27RowAccessory.none,
      onTap: () => onPick(row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Первый агрегатор без флага — «Авто» доски; группа с флагом (`🇩🇪 Германия ✨`) страна.
    final firstAggregate =
        data.rows.indexWhere((r) => r.isAggregate && r.flag == null);
    return IgnorePointer(
      ignoring: applying,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.rows.isNotEmpty) ...[
            Ios27List(
              children: [
                for (var i = 0; i < data.rows.length; i++)
                  _rowFor(l, data.rows[i], isAuto: i == firstAggregate),
              ],
            ),
            const Ios27Gap(),
          ],
          if (data.fullTunnelAvailable) ...[
            Ios27List(
              children: [
                Ios27ListRow(
                  key: kIos27RouteTunnelKey,
                  // `dw_tunnel` держат автотесты и инструменты старого экрана.
                  semanticIdentifier: 'dw_tunnel',
                  title: l.m3eRouteAllTraffic,
                  trailing: Ios27Toggle(
                    key: const ValueKey<String>('sheet.switch'),
                    value: data.fullTunnel,
                    onChanged: (_) => onToggleTunnel(),
                  ),
                  onTap: onToggleTunnel,
                ),
              ],
            ),
            const Ios27Gap(),
          ],
          Ios27List(
            children: [
              // Строка, из которой вошли глубже, остаётся подсвеченной на время перехода и
              // гаснет при возврате (app.js 936-948, `is-selected` / `is-deselect`).
              Ios27SheetPushHighlight(
                id: _kServersHighlight,
                child: Ios27ListRow(
                  key: kIos27RouteServersKey,
                  leading: const Ios27Avatar.icon(Ios27IconName.layers),
                  title: l.m3eServersTitle,
                  detail: '${data.groupsCount}',
                  accessory: Ios27RowAccessory.chevron,
                  onTap: onServers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Второй уровень: серверы и группы ----------

/// Тело шага «Серверы и группы»: группа, её имя без флага и пинг выбранного узла.
class Ios27ServersGroupsView extends ConsumerStatefulWidget {
  const Ios27ServersGroupsView({super.key});

  @override
  ConsumerState<Ios27ServersGroupsView> createState() =>
      _Ios27ServersGroupsViewState();
}

class _Ios27ServersGroupsViewState
    extends ConsumerState<Ios27ServersGroupsView> {
  @override
  void initState() {
    super.initState();
    // Замер один раз после первого кадра и вне build. Меряем только выбранный узел каждой
    // группы, как старый экран: остальные для этой подписи не нужны.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _probeSelected();
      }
    });
  }

  void _probeSelected() {
    final groups = ref.read(m3eServerGroupsProvider);
    final actions = ref.read(m3eServersActionsProvider);
    // Одинаковый адрес замера — один вызов; один узел в разных группах — один раз.
    final byUrl = <String?, Map<String, M3eServerNode>>{};
    for (final g in groups) {
      if (g.selectedName.isEmpty) {
        continue;
      }
      final node = g.nodes.where((n) => n.name == g.selectedName).firstOrNull;
      if (node == null) {
        continue;
      }
      byUrl.putIfAbsent(g.testUrl, () => {})[node.name] = node;
    }
    for (final e in byUrl.entries) {
      unawaited(actions.probe(e.value.values.toList(), e.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(m3eServerGroupsProvider);
    if (groups.isEmpty) {
      return const _EmptyNote();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(
          children: [
            for (var i = 0; i < groups.length; i++)
              _GroupRow(
                key: kIos27RouteGroupKey(i),
                group: groups[i],
              ),
          ],
        ),
      ],
    );
  }
}

/// Пустой профиль: подсказка по центру (как `nullProfileDesc` на Android).
class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
        child: Text(
          AppLocalizations.of(context).nullProfileDesc,
          textAlign: TextAlign.center,
          style: ios27Text(
            context,
            Ios27Text.subhead,
            color: ios27ColorsFor(context).palette.label2,
          ),
        ),
      );
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({super.key, required this.group});

  final M3eServerGroup group;

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
    final ping = _pingDetail(l, delay);
    return Ios27SheetPushHighlight(
      id: group.name,
      child: Ios27ListRow(
        leading: _leadForName(group.name),
        title: m3eServerTitle(group.name),
        detail: ping?.text,
        detailTone: ping?.tone ?? Ios27RowDetailTone.normal,
        accessory: Ios27RowAccessory.chevron,
        onTap: () => unawaited(
          Ios27SheetNavigator.push<void>(
            context,
            highlight: group.name,
            builder: (_) => Ios27ServerNodesPage(groupName: group.name),
          ),
        ),
      ),
    );
  }
}

// ---------- Третий уровень: узлы группы ----------

/// Страница узлов группы (`group:i`): заголовок — имя группы без флага, внутри список узлов.
class Ios27ServerNodesPage extends StatelessWidget {
  const Ios27ServerNodesPage({super.key, required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) => Ios27SheetScaffold(
        title: m3eServerTitle(groupName),
        body: _SheetScroll(child: Ios27ServerNodesView(groupName: groupName)),
      );
}

/// Тело шага узлов. Выбор узла пишет его в ядро, лист остаётся на этом уровне, галочка переезжает.
/// При открытии один раз замеряет все узлы группы.
class Ios27ServerNodesView extends ConsumerStatefulWidget {
  const Ios27ServerNodesView({super.key, required this.groupName});

  final String groupName;

  @override
  ConsumerState<Ios27ServerNodesView> createState() =>
      _Ios27ServerNodesViewState();
}

class _Ios27ServerNodesViewState extends ConsumerState<Ios27ServerNodesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final g = ref.read(m3eServerGroupProvider(widget.groupName));
      if (g == null || g.nodes.isEmpty) {
        return;
      }
      unawaited(ref.read(m3eServersActionsProvider).probe(g.nodes, g.testUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(m3eServerGroupProvider(widget.groupName));
    if (group == null) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(
          children: [
            for (var i = 0; i < group.nodes.length; i++)
              _NodeRow(
                key: kIos27RouteNodeKey(i),
                group: group,
                node: group.nodes[i],
              ),
          ],
        ),
      ],
    );
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({super.key, required this.group, required this.node});

  final M3eServerGroup group;
  final M3eServerNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = group.selectedName == node.name;
    final delay = ref.watch(
      m3eNodeDelayProvider((name: node.name, testUrl: group.testUrl)),
    );
    final ping = _pingDetail(l, delay);
    return Ios27ListRow(
      leading: _leadForName(node.name),
      title: m3eServerTitle(node.name),
      detail: ping?.text,
      detailTone: ping?.tone ?? Ios27RowDetailTone.normal,
      accessory: selected ? Ios27RowAccessory.check : Ios27RowAccessory.none,
      // Лист остаётся на уровне узлов, галочка переезжает на выбранный (доска: `node` только
      // меняет `st.sel` и перерисовывает, app.js:1206).
      onTap: () =>
          ref.read(m3eServersActionsProvider).selectNode(group.name, node.name),
    );
  }
}
