import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/proxies/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Sponge rule: aggregate vs country ─────────────────────────────────────

/// Имена ВСЕХ групп ядра — вход для [isAggregateMember].
///
/// Множество принципиально НЕФИЛЬТРОВАННОЕ (`groupsProvider`, не
/// `currentGroupsStateProvider`). Регрессия 2026-08-09: фильтрованный провайдер
/// выкидывает `hidden == true`, а живая подписка объявляет группу-агрегатор
/// скрытой (`hidden: true` в её `proxy-groups`), из-за чего скрытый агрегатор
/// всегда классифицировался как страна.
///
/// `GLOBAL` тоже НЕ исключается: это настоящая группа ядра, и член роутера с
/// таким именем был бы агрегатором, а не страной. Исключить его — значит
/// воспроизвести ровно тот же класс бага. Подписка не может объявить страну с
/// именем `GLOBAL`, не столкнувшись со встроенной группой ядра.
///
/// Скрытость влияет только на то, что РИСУЕТСЯ («Серверы и группы» правомерно
/// прячет скрытые группы) — но не на то, ЧЕМ ЯВЛЯЕТСЯ узел.
Set<String> aggregateGroupNames(List<Group> groups) =>
    groups.map((g) => g.name).toSet();

/// Член роутера, чьё имя совпадает с именем ДРУГОЙ группы, — это агрегатор
/// («авто»/каскад), а не страна. Листовая нода — страна.
bool isAggregateMember({
  required String proxyName,
  required String routerName,
  required Set<String> allGroupNames,
}) =>
    proxyName != routerName && allGroupNames.contains(proxyName);

// ── Proxy selector sheet ──────────────────────────────────────────────────

class ProxySelectorSheet extends ConsumerStatefulWidget {
  final Group group;

  /// Вызывается ПОСЛЕ штатной записи выбора (`updateCurrentSelectedMap` +
  /// `changeProxyDebounce`). Нужен экрану «Страна», которому кроме выбора надо
  /// проставить work mode. null ⇒ поведение группового экрана без изменений.
  final void Function(Proxy proxy, {required bool isAggregate})? onSelected;

  /// Мерить задержку ВСЕХ членов [group] один раз при открытии листа.
  ///
  /// Opt-in и по умолчанию ВЫКЛЮЧЕН: «Серверы и группы» уже гоняет свой
  /// `_pingSelectedProxies` перед открытием этого листа, и второй прогон был бы
  /// дублем. Включает его только экран «Страна», где роутер — `select` без
  /// `url`/`interval`: ядро его состав как группу не health-check'ает, поэтому
  /// без этого прогона выбранная страна показывает `n/a` минутами.
  final bool pingOnOpen;

  const ProxySelectorSheet({
    super.key,
    required this.group,
    this.onSelected,
    this.pingOnOpen = false,
  });

  @override
  ConsumerState<ProxySelectorSheet> createState() => _ProxySelectorSheetState();
}

class _ProxySelectorSheetState extends ConsumerState<ProxySelectorSheet> {
  /// Один прогон на одно открытие листа. Флаг живёт в [State], а не в билде:
  /// лист перестраивается на каждый тик `groupsProvider`, и без него замер
  /// уходил бы в сеть на каждую перестройку. Взводится ДО запуска, так что он
  /// же не даёт стартовать второй пачке поверх ещё летящей.
  bool _autoPinged = false;

  /// Замер задержки членов роутера — ТОЛЬКО чтобы заполнить бейджи.
  ///
  /// Список строк не зависит от результата: он всегда `group.all`. Провалившийся
  /// или вообще не доехавший замер оставляет пустой бейдж (или `n/a`) — и ни
  /// одной спрятанной строки. Ровно на этом обжёгся удалённый `countryProbe`:
  /// он мерил И фильтровал, и на непрогретом ядре выкидывал весь список.
  ///
  /// [Group.testUrl] обязателен: бейдж читает
  /// `getDelayProvider(proxyName:, testUrl: group.testUrl)`, и замер под
  /// дефолтным URL записал бы задержку под ДРУГИМ ключом — числа бы не
  /// появились никогда.
  void _pingMembers() {
    final group = widget.group;
    if (group.all.isEmpty) return;
    // Fire-and-forget: лист открывается мгновенно и остаётся кликабельным,
    // бейджи подтягиваются по мере ответов.
    unawaited(delayTest(group.all, group.testUrl));
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    if (widget.pingOnOpen && !_autoPinged) {
      _autoPinged = true;
      // Из билда в сеть не ходим: `delayTest` пишет в провайдеры задержек, а
      // запись провайдера во время фазы билда — ошибка Riverpod. Тот же приём,
      // что у `_pingSelectedProxies` в «Серверах и группах».
      WidgetsBinding.instance.addPostFrameCallback((_) => _pingMembers());
    }

    final proxyName = ref.watch(getProxyNameProvider(group.name)) ?? '';
    // Tick the member the core actually routes through: once it drops a dead
    // pin, that pin is no longer the selection.
    final selectedName = group.resolveSelectedName(proxyName);
    final groupNames = aggregateGroupNames(ref.watch(groupsProvider));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: group.all.length,
        itemBuilder: (context, index) {
          final proxy = group.all[index];
          final isSelected = proxy.name == selectedName;
          final isAggregate = isAggregateMember(
            proxyName: proxy.name,
            routerName: group.name,
            allGroupNames: groupNames,
          );
          return ProxySelectorRow(
            proxy: proxy,
            testUrl: group.testUrl,
            isSelected: isSelected,
            onTap: () {
              final appController = globalState.appController;
              appController.updateCurrentSelectedMap(
                group.name,
                proxy.name,
              );
              appController.changeProxyDebounce(
                group.name,
                proxy.name,
              );
              widget.onSelected?.call(proxy, isAggregate: isAggregate);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

class ProxySelectorRow extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const ProxySelectorRow({
    super.key,
    required this.proxy,
    required this.testUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: testUrl,
    ));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        // Продукт dark-only. Заливка невыбранной строки — канонический стеклянный
        // токен: полупрозрачная, чтобы динамическая (акцент-зависимая) подложка
        // листа и меш продолжали просвечивать. Непрозрачный Lumina.surface* здесь
        // не подходит — он бы срезал это просвечивание.
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: Lumina.glassOpacity),
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lumina.radiusLg),
              border: Border.all(
                // glassHoverOpacity == 0.06 — точное значение прежней рамки.
                // Не менять на glassBorderOpacity (0.08): это сдвинуло бы вид.
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : Colors.white
                        .withValues(alpha: Lumina.glassHoverOpacity),
              ),
            ),
            child: Row(
              children: [
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiText(
                        proxy.name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        proxy.type,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (utils.delayBadgeLabel(delay) != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          utils.getDelayColor(delay)?.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      utils.delayBadgeLabel(delay)!,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: utils.getDelayColor(delay),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
