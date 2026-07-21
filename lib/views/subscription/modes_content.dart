import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription/common.dart';
import 'package:dropweb/views/subscription/country_deep_view.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
  /// Selecting a country applies [WorkMode.country] through [_apply] (so the
  /// applying-state guard still covers the modes tab) and closes the sheet.
  void _openCountryDeep(Profile profile) {
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
          child: CountryDeepView(
            profileId: profile.id,
            onApply: (country) => _apply(
              WorkMode.country,
              staticCountry: country,
            ),
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
    // Pre-warm country liveness while the user is on the mode cards, so the
    // picker opens onto an already-resolved (junk-free) list instead of
    // filtering visibly after open. Value ignored here — this only kicks off
    // (and keeps alive) the probe.
    ref.watch(countryProbeProvider(profile.id));

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
              // «Серверы и группы» (manual group/server picking) is only
              // meaningful in Standard mode → the chevron is tappable only when
              // Standard is the active mode; otherwise it's shown disabled.
              onChevronTap: profile.workMode == WorkMode.standard
                  ? _openServersAndGroups
                  : null,
              chevronDisabled: profile.workMode != WorkMode.standard,
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
    this.chevronDisabled = false,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onChevronTap;

  /// When true, the chevron is rendered but greyed and non-tappable (the deep
  /// screen is gated until this mode is selected — e.g. «Серверы и группы»
  /// only applies in Standard mode).
  final bool chevronDisabled;

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
            if (onChevronTap != null || chevronDisabled) ...[
              const SizedBox(width: 8),
              _ChevronAffordance(
                onTap: onChevronTap,
                disabled: chevronDisabled,
              ),
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
  const _ChevronAffordance({this.onTap, this.disabled = false});

  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(Lumina.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: disabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
