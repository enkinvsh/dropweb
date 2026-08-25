import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/navigator.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/agreement_sheet.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/meowzic_page.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// One cell, two faces: an entry point at rest, a mini player while
/// something is loaded. Both are the same height so the grid never jumps
/// when playback starts or ends.
class MeowzicStrip extends ConsumerWidget {
  const MeowzicStrip({super.key});

  /// Opens meowzic, asking for consent the first time.
  ///
  /// Consent is requested here rather than at launch or from settings, so
  /// nothing is installed until somebody deliberately asks for music.
  /// Declining leaves everything as it was and the next tap asks again.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final accepted = ref.read(appSettingProvider).meowzicAccepted;
    if (!accepted) {
      final agreed = await showMeowzicAgreement(context);
      if (!agreed) return;
      ref
          .read(appSettingProvider.notifier)
          .updateState((state) => state.copyWith(meowzicAccepted: true));
    }
    if (!context.mounted) return;
    await BaseNavigator.push(context, const MeowzicPage());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          onPressed: () => _open(context, ref),
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 6, bottom: 6),
            // Observing the handler through a notifier rather than calling
            // meowzicAudio() keeps this read-only: touching the getter would
            // spin up the media service for every user on every dashboard
            // build, including those who never open music.
            child: ValueListenableBuilder<MeowzicAudioHandler?>(
              valueListenable: meowzicHandlerListenable,
              builder: (context, handler, _) {
                if (handler == null) return const _Idle();
                return StreamBuilder<MediaItem?>(
                  stream: handler.mediaItem,
                  builder: (context, snapshot) {
                    final item = snapshot.data;
                    if (item == null) return const _Idle();
                    return _Playing(handler: handler, item: item);
                  },
                );
              },
            ),
          ),
        ),
      );
}

/// Leading square shared by both faces, so the row does not shift sideways
/// when playback starts.
class _Badge extends StatelessWidget {
  const _Badge({this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final art = artUri;
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
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
      child: art == null
          ? Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMusicNote01,
                size: 22,
                color: context.colorScheme.primary,
              ),
            )
          : Image.network(
              art.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMusicNote01,
                  size: 22,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const _Badge(),
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
      );
}

class _Playing extends StatelessWidget {
  const _Playing({required this.handler, required this.item});

  final MeowzicAudioHandler handler;
  final MediaItem item;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Badge(artUri: item.artUri),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.artist case final artist?) ...[
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          StreamBuilder<PlaybackState>(
            stream: handler.playbackState,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton.filled(
                onPressed: playing ? handler.pause : handler.play,
                icon: HugeIcon(
                  icon: playing
                      ? HugeIcons.strokeRoundedPause
                      : HugeIcons.strokeRoundedPlay,
                  size: 22,
                  color: context.colorScheme.onPrimary,
                ),
              );
            },
          ),
        ],
      );
}
