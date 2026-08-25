import 'package:dropweb/common/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Entry point for meowzic — music served through the tunnel.
///
/// This is a dashboard grid cell, not a bar pinned to the bottom of the
/// screen. The bottom edge is already taken twice: by the swipe-up MENU
/// handle and by the floating connect lens, which paints *over* the scroll
/// area and has `bottomReserve` cleared for it (see `dashboard.dart`). A
/// pinned bar would fight both; the free space sits between the last card
/// and the lens, which is exactly where the grid puts this.
///
/// Visibility is decided in `_isAllowedWidget`: the panel must advertise
/// `dropweb-music` and the tunnel must be up. Music only reaches the bridge
/// through the tunnel, so an entry point while disconnected would lead
/// nowhere.
///
/// Playing state (cover, track, play/pause in this same cell) and the tap
/// target land with the player itself; the card is deliberately inert until
/// there is a screen to open.
class MeowzicStrip extends StatelessWidget {
  const MeowzicStrip({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 6, bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.primary.withValues(alpha: 0.15),
                        context.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMusicNote01,
                    size: 22,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'meowzic',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 22,
                    color: context.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
