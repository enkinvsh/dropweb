import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
// ВНИМАНИЕ: `detectPrimaryRouter` определён ДВАЖДЫ. Нужен именно этот —
// `work_mode_patch.dart:253`, `String? detectPrimaryRouter(Map<String, dynamic>)`,
// тот же, что использует `applyWorkMode`. Одноимённая функция в
// `smart_pool_patch.dart:267` берёт `(Object? proxyGroups, Object? rules)` и к
// экрану «Страна» отношения не имеет — импортировать её сюда нельзя.
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription/common.dart';
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Экран «Страна»: разрешение состояния ──────────────────────────────────

/// Что именно экран «Страна» может показать ПРЯМО СЕЙЧАС. Каждая ветка — своя
/// реальная ситуация со своим честным текстом: экран не имеет права выдавать
/// «нет профиля» (профиль есть) или «страны не определены, обновите подписку»
/// (подписка ни при чём) там, где проблема совсем в другом.
enum CountryScreenStatus {
  /// Конфиг профиля не прочитался (`getProfileConfig` бросил). Это ошибка
  /// чтения, а НЕ отсутствие профиля и НЕ отсутствие стран.
  configUnavailable,

  /// Конфиг прочитан, но основной группы маршрутизации (цели `MATCH`) в нём
  /// нет: выбирать страну структурно не через что.
  noRouter,

  /// Роутер известен, но ядро ещё не отдало его состав — узкое окно холодного
  /// старта, пока профиль не догрузился. Это ЗАГРУЗКА, а не пустой список и не
  /// «серверы недоступны»: с выключенным VPN ядро состав групп СОХРАНЯЕТ.
  routerLoading,

  /// Роутер и его состав на руках — рисуем список его членов.
  ready,
}

/// Разрешённое состояние экрана «Страна»: [status] плюс сама группа-роутер,
/// не-null РОВНО для [CountryScreenStatus.ready].
class CountryScreenState {
  const CountryScreenState(this.status, this.group);

  final CountryScreenStatus status;
  final Group? group;
}

/// Чистая функция разрешения экрана «Страна» из сырого конфига профиля [cfg]
/// (null ⇒ не прочитался) и текущего состава групп ядра [groups].
///
/// Роутер ищется тем же [detectPrimaryRouter], которым `applyWorkMode`
/// выбирает единственный ключ `selectedMap` — так экран и движок режимов не
/// могут разъехаться в том, какая группа «основная».
CountryScreenState resolveCountryScreenState(
  Map<String, dynamic>? cfg,
  List<Group> groups,
) {
  if (cfg == null) {
    return const CountryScreenState(
      CountryScreenStatus.configUnavailable,
      null,
    );
  }
  final routerName = detectPrimaryRouter(cfg);
  if (routerName == null) {
    return const CountryScreenState(CountryScreenStatus.noRouter, null);
  }
  final group = groups.getGroup(routerName);
  if (group == null) {
    return const CountryScreenState(CountryScreenStatus.routerLoading, null);
  }
  return CountryScreenState(CountryScreenStatus.ready, group);
}

// ── Work modes content ────────────────────────────────────────────────────

class ModesContent extends ConsumerStatefulWidget {
  const ModesContent();

  @override
  ConsumerState<ModesContent> createState() => _ModesContentState();
}

class _ModesContentState extends ConsumerState<ModesContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Applying a work mode is fast (a config rebuild). We disable the stack
  /// briefly so a double-tap can't race two applies.
  bool _applying = false;

  Future<void> _apply(
    WorkMode mode, {
    String? staticCountry,
  }) async {
    setState(() => _applying = true);
    try {
      await globalState.appController.applyWorkMode(
        mode,
        staticCountry: staticCountry,
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Deep screen for «Стандарт»: the existing proxies/groups UI
  /// ([RulesProxiesView]) in a sheet — reuses the exact wiring the old
  /// bottom row used.
  void _openServersAndGroups() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.serversAndGroups,
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: const RulesProxiesView(),
        ),
      ),
    );
  }

  /// Country picker: a popup modal sheet (same presentation as «Серверы и
  /// группы» — [showSheet] + [AdaptiveSheetScaffold], NOT a full-page push).
  ///
  /// Телом идёт [ProxySelectorSheet] по ГРУППЕ-РОУТЕРУ (цель `MATCH`) — тот же
  /// виджет, что рисует «Серверы и группы», поэтому список стран это буквально
  /// состав роутера, а не отдельно вычисленный параллельный список. Агрегатор
  /// внутри роутера («Авто») возвращает профиль в [WorkMode.standard], листовая
  /// нода пинит [WorkMode.country] — оба через [_apply], так что guard
  /// `_applying` по-прежнему накрывает вкладку режимов.
  ///
  /// Конфиг читается ДО открытия шита (единственный настоящий `await`), а
  /// состав роутера подтягивается реактивно внутри — холодный старт сам доедет
  /// до списка без действий юзера.
  Future<void> _openCountryDeep(Profile profile) async {
    Map<String, dynamic>? config;
    try {
      config = await globalState.getProfileConfig(profile.id);
    } catch (e) {
      commonPrint.log('country screen: failed to read profile config: $e');
    }
    // `await` выше пересекает кадр: виджет мог быть размонтирован.
    if (!mounted) return;
    final resolvedConfig = config;
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.workModeCountry,
        // Adaptive: shrinkWrap content hugs the sheet to its height (few
        // countries → short, bottom-anchored sheet) capped at 85% where it
        // scrolls.
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          // Своя точка подписки: шит живёт в оверлее Navigator'а, `ref`
          // состояния перестраивал бы вкладку режимов, а не содержимое шита.
          child: Consumer(
            builder: (_, ref, __) {
              final state = resolveCountryScreenState(
                resolvedConfig,
                ref.watch(currentGroupsStateProvider).value,
              );
              switch (state.status) {
                case CountryScreenStatus.configUnavailable:
                  return NullStatus(
                    label: appLocalizations.genericErrorMessage,
                  );
                case CountryScreenStatus.noRouter:
                  // Строка литералом: l10n здесь генерит IDE-плагин Flutter
                  // Intl (pubspec `flutter_intl`), а не build_runner —
                  // перегенерация 89-килобайтного `lib/l10n/l10n.dart` чужим
                  // тулом несоразмерна одной строке.
                  return const NullStatus(
                    label: 'Не удалось определить основную группу '
                        'маршрутизации подписки.',
                  );
                case CountryScreenStatus.routerLoading:
                  return const Center(child: CircularProgressIndicator());
                case CountryScreenStatus.ready:
                  return ProxySelectorSheet(
                    group: state.group!,
                    onSelected: (proxy, {required isAggregate}) => _apply(
                      isAggregate ? WorkMode.standard : WorkMode.country,
                      staticCountry: isAggregate ? null : proxy.name,
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }
    final dataAsync = ref.watch(modeProfileDataProvider(profile.id));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // The profile EXISTS (guarded above) — a config-load failure here is a
      // real error, NOT «no profile». Surface a mapped/generic error instead of
      // the old nullProfileDesc lie (same class of lie the country picker fix
      // removes). No redesign: still a plain NullStatus panel.
      error: (e, __) => NullStatus(
        label: ErrorMapper.mapError('$e') ?? appLocalizations.genericErrorMessage,
      ),
      data: (_) {
        final stack = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // «Стандарт»: tap applies standard; chevron → «Серверы и группы».
            _ModeCard(
              icon: HugeIcons.strokeRoundedShield01,
              title: appLocalizations.workModeStandard,
              description: appLocalizations.workModeStandardDesc,
              isSelected: profile.workMode == WorkMode.standard,
              onTap: () => _apply(WorkMode.standard),
              // Открывается ВСЕГДА, в любом режиме — не только в «Стандарт».
              // Это единственное место в UI, где видно, КУДА ядро реально
              // маршрутизирует: в режиме «Страна» здесь и виден пин на выбранной
              // стране, иначе состояние режима наблюдать нечем. Открытие листа
              // `workMode` НЕ меняет — режим переключает только тап по карточке.
              onChevronTap: _openServersAndGroups,
            ),
            const SizedBox(height: 16),
            // «Умный» (Smart) is temporarily removed from the modes list and
            // will be reintroduced later. The WorkMode.smart code path stays
            // intact (work_mode_patch / detectPrimaryRouter / controller), only
            // the card is hidden for now.
            // «Страна»: selection requires a country → both card tap and
            // chevron open the deep country picker.
            _ModeCard(
              icon: HugeIcons.strokeRoundedGlobe02,
              title: appLocalizations.workModeCountry,
              description: appLocalizations.workModeCountryDesc,
              isSelected: profile.workMode == WorkMode.country,
              onTap: () => _openCountryDeep(profile),
              onChevronTap: () => _openCountryDeep(profile),
            ),
          ],
        );

        return IgnorePointer(
          ignoring: _applying,
          child: DisabledMask(status: _applying, child: stack),
        );
      },
    );
  }
}

/// A single work-mode card following the «case + deep» pattern. Composes
/// [CommonCard] (flagship radius + selected glow) with a leading [HugeIcon],
/// title/description, and — when the mode has a deep screen — a trailing
/// chevron affordance ([onChevronTap]) styled
/// like the [ListItem] chevron. Tapping the card fires [onTap] (select mode);
/// tapping the chevron fires [onChevronTap] (open deep).
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.onChevronTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onChevronTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = CommonCard(
      isSelected: isSelected,
      radius: Lumina.radiusLg,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: context.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onChevronTap != null) ...[
              const SizedBox(width: 8),
              _ChevronAffordance(onTap: onChevronTap),
            ],
          ],
        ),
      ),
    );

    return card;
  }
}

/// Trailing «провалиться в deep-экран» affordance. A nested [InkWell] so the
/// chevron tap wins the gesture arena over the card's own [CommonCard.onPressed]
/// (lets «Стандарт» distinguish select-mode from open-deep). Mirrors the
/// [ListItem] chevron visual (arrow-right glyph, onSurfaceVariant).
class _ChevronAffordance extends StatelessWidget {
  const _ChevronAffordance({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Lumina.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
