// Лист «Маршрут» (сцена `route` доски, android.js 530–540): «Авто» и страны с флагом и
// пингом, переключатель «Весь трафик через VPN» и вход в «Серверы и группы».
// Выбор страны лист НЕ закрывает: на доске `route()` только меняет маршрут и перерисовывает.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart';
import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_list.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключи строк для паритета с `layout.json` и тестов.
const kM3eRouteAutoKey = ValueKey<String>('m3e.route.auto');
const kM3eRouteTunnelKey = ValueKey<String>('m3e.route.tunnel');
const kM3eRouteServersKey = ValueKey<String>('m3e.route.servers');
const kM3eRouteCountriesKey = ValueKey<String>('m3e.route.countries');
const kM3eRouteMoreKey = ValueKey<String>('m3e.route.more');
ValueKey<String> kM3eRouteRowKey(String id) =>
    ValueKey<String>('m3e.route.row.$id');

/// Порог «медленного» пинга: с него число жёлтое (`msText` доски, `v >= 600`).
const int kM3eRouteSlowMs = 600;

/// Показывает лист «Маршрут».
///
/// [serversBuilder] строит тело шага «Серверы и группы»; лист кладёт его в стек по
/// пункту «Серверы и группы» под заголовком `m3eServersTitle`. Вызывать надо с контекста
/// внутри `M3eThemeScope` (экран, не навигатор): тему лист берёт оттуда.
Future<void> showM3eRouteSheet(
  BuildContext context, {
  required WidgetBuilder serversBuilder,
}) =>
    showM3eSheet<void>(
      context,
      // Пункты листа лежат на тон выше самого листа: поверхность задаёт область,
      // а не каждый пункт.
      builder: (_) => M3eListSurfaceScope(
        surface: M3eListSurface.sheet,
        child: M3eSheetStack(
          root: (_) => M3eRouteSheet(serversBuilder: serversBuilder),
        ),
      ),
    );

/// Корневой экран листа: данные и действия из провайдеров.
class M3eRouteSheet extends ConsumerStatefulWidget {
  const M3eRouteSheet({super.key, required this.serversBuilder});

  final WidgetBuilder serversBuilder;

  @override
  ConsumerState<M3eRouteSheet> createState() => _M3eRouteSheetState();
}

class _M3eRouteSheetState extends ConsumerState<M3eRouteSheet> {
  /// Замер один раз за открытие, как у старого листа: ядро не проверяет состав
  /// `select`-группы само, и без замера выбранная страна минутами без пинга.
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
    if (_probed || data.probe.isEmpty) return;
    _probed = true;
    // Не внутри сборки: замер пишет в провайдеры задержек.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
          ref.read(m3eRouteActionsProvider).probe(data.probe, data.testUrl));
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
    return M3eSheetScaffold(
      title: l.m3eRouteTitle,
      body: M3eRouteBody(
        data: data,
        applying: applying,
        onPick: (row) => unawaited(actions.pick(row)),
        onToggleTunnel: () =>
            unawaited(actions.setFullTunnel(enabled: !data.fullTunnel)),
        onServers: () => M3eSheetStack.of(context).push(
          (c) => M3eSheetScaffold(
            title: l.m3eServersTitle,
            body: widget.serversBuilder(c),
          ),
        ),
      ),
    );
  }
}

/// Тело листа без провайдеров: golden и виджет-тесты подают [M3eRouteData] напрямую.
class M3eRouteBody extends StatelessWidget {
  const M3eRouteBody({
    super.key,
    required this.data,
    required this.onPick,
    required this.onToggleTunnel,
    required this.onServers,
    this.applying = false,
  });

  final M3eRouteData data;

  /// Идёт применение маршрута: нажатия не принимаются, чтобы два `applyWorkMode` не
  /// гонялись друг с другом.
  final bool applying;
  final void Function(M3eRouteRow row) onPick;
  final VoidCallback onToggleTunnel;
  final VoidCallback onServers;

  M3eListTrail? _trailOf(AppLocalizations l, M3eRouteRow row) {
    final ping = row.pingMs;
    final parts = <M3eListTrail>[
      if (ping != null)
        if (ping < 0)
          M3eListTrail.text(l.m3eMsNoAnswer, tone: M3eTrailTone.dead)
        else
          M3eListTrail.text(
            pingText(l, ping),
            tone: ping >= kM3eRouteSlowMs
                ? M3eTrailTone.slow
                : M3eTrailTone.normal,
          ),
      if (row.selected) M3eListTrail.icon(M3eSymbol.check),
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : M3eListTrail.row(parts);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Первый агрегатор без флага — «Авто» доски; остальные остаются со своими именами.
    // Группа с флагом (`🇩🇪 Германия ✨`) — страна, не «Авто».
    final firstAggregate =
        data.rows.indexWhere((r) => r.isAggregate && r.flag == null);

    final countries = <Widget>[
      for (var i = 0; i < data.rows.length; i++)
        // Автотесты через adb ищут режим по `dw_mode_*`, как на старом экране: выбор
        // агрегатора применяет `WorkMode.standard`, выбор страны — `WorkMode.country`
        // (`m3eRouteActionsProvider`), поэтому идентификатор зависит от `isAggregate`.
        Semantics(
          identifier: data.rows[i].isAggregate && data.rows[i].flag == null
              ? 'dw_mode_standard'
              : 'dw_mode_country',
          child: M3eListItem(
            key: i == firstAggregate
                ? kM3eRouteAutoKey
                : kM3eRouteRowKey(data.rows[i].id),
            label: i == firstAggregate ? l.m3eRouteAuto : data.rows[i].label,
            sup: data.rows[i].sup,
            // Флаг — круг на всё поле; эмодзи имени (`⚡ Авто`, `⚪ White`) рисует Twemoji,
            // как флаги; без обоих остаётся символ: молния у агрегатора, сервер у узла.
            lead: data.rows[i].flag != null
                ? M3eListLead.avatar(flag: data.rows[i].flag)
                : data.rows[i].emoji != null
                    ? M3eListLead.avatar(emoji: data.rows[i].emoji)
                    : data.rows[i].isAggregate
                        ? M3eListLead.avatar(icon: M3eSymbol.bolt)
                        : M3eListLead.avatar(icon: M3eSymbol.dns),
            trail: _trailOf(l, data.rows[i]),
            radioChecked: data.rows[i].selected,
            onTap: () => onPick(data.rows[i]),
          ),
        ),
    ];

    return IgnorePointer(
      ignoring: applying,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (countries.isNotEmpty) ...[
            M3eList(
              key: kM3eRouteCountriesKey,
              semanticLabel: l.m3eRouteCountries,
              children: countries,
            ),
            const SizedBox(height: 16),
          ],
          M3eList(
            key: kM3eRouteMoreKey,
            children: [
              // `dw_tunnel` держат автотесты и инструменты старого экрана.
              if (data.fullTunnelAvailable)
                Semantics(
                  identifier: 'dw_tunnel',
                  child: M3eListItem(
                    key: kM3eRouteTunnelKey,
                    label: l.m3eRouteAllTraffic,
                    trail: M3eListTrail.toggle(data.fullTunnel),
                    toggled: data.fullTunnel,
                    onTap: onToggleTunnel,
                  ),
                ),
              M3eListItem(
                key: kM3eRouteServersKey,
                label: l.m3eServersTitle,
                sup: l.m3eRouteGroupsCount(data.groupsCount),
                lead: M3eListLead.avatar(icon: M3eSymbol.hub),
                onTap: onServers,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
