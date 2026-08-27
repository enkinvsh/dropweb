import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/navigator.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/agreement_sheet.dart';
import 'package:dropweb/views/meowzic/art_wash.dart';
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
/// `dropweb-music`, and the cell shows while the tunnel is up or while a
/// session is parked waiting for it.
///
/// One cell, three faces: an entry point at rest, a mini player while
/// something is loaded, and a parked track naming whatever stopped it — the
/// tunnel or the bridge. All three are the same height so the grid never
/// jumps. The cover art is a background wash rather than a leading square, so
/// the text starts at the same x in every face and nothing shifts sideways
/// when playback starts.
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
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => _open(context, ref);
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        radius: Lumina.radiusLg,
        onPressed: open,
        // Observing the handler through a notifier rather than calling
        // meowzicAudio() keeps this read-only: touching the getter would
        // spin up the media service for every user on every dashboard
        // build, including those who never open music.
        child: ValueListenableBuilder<MeowzicAudioHandler?>(
          valueListenable: meowzicHandlerListenable,
          builder: (context, handler, _) {
            if (handler == null) return _Idle(onOpen: open);
            return StreamBuilder<MediaItem?>(
              stream: handler.mediaItem,
              builder: (context, snapshot) {
                final item = snapshot.data;
                if (item == null) return _Idle(onOpen: open);
                return ValueListenableBuilder<MeowzicStall>(
                  valueListenable: handler.stallListenable,
                  builder: (context, stall, __) => stall == MeowzicStall.none
                      ? _Playing(handler: handler, item: item)
                      : _Stalled(
                          handler: handler,
                          item: item,
                          stall: stall,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The card body every face is built on: the art wash underneath, the row of
/// content on top, both filling the cell.
///
/// No [ClipRRect] here and none is needed — [CommonCard] is an
/// `OutlinedButton` with `clipBehavior: Clip.antiAlias` and a
/// `RoundedSuperellipseBorder` (lib/widgets/card.dart), so the wash is already
/// clipped to the card's squircle. Adding a clip of our own would only cost a
/// second saveLayer and round the art to the wrong curve.
class _Face extends StatelessWidget {
  const _Face({required this.child, this.artUri});

  final Widget child;
  final Uri? artUri;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          if (artUri case final uri?) MeowzicArtWash(uri: uri),
          // 16 on the left is what the rest of the dashboard uses
          // (`baseInfoEdgeInsets` is 16 horizontal — see
          // `change_server_button.dart`), so the title lines up with the cards
          // above it. 8 on the right because _GhostControl carries its own 9px
          // of tap padding around the glyph: 8 + 9 puts the last glyph
          // optically level with that 16, which a matching 16 would not.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: child,
          ),
        ],
      );
}

/// A transport affordance with every bit of chrome stripped off it: no fill,
/// no border, no tinted box — just the white glyph and a square of tap area
/// around it. Disabled reads as a dimmer glyph rather than a missing one.
class _GhostControl extends StatelessWidget {
  const _GhostControl({
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.tapSize = 40,
    this.tooltip,
  });

  final List<List<dynamic>> icon;
  final VoidCallback? onPressed;
  final double size;
  final double tapSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: Size(tapSize, tapSize),
          fixedSize: Size(tapSize, tapSize),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: HugeIcon(
          icon: icon,
          size: size,
          color: onPressed == null
              ? context.colorScheme.onSurface.opacity38
              : context.colorScheme.onSurface,
        ),
      );
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _Face(
        // Nothing is loaded, so there is no art and no placeholder standing in
        // for it: the word already says what the card is.
        child: Row(
          children: [
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
            const SizedBox(width: 8),
            _GhostControl(
              icon: HugeIcons.strokeRoundedArrowRight01,
              onPressed: onOpen,
              size: 24,
              tapSize: 44,
            ),
          ],
        ),
      );
}

/// The parked face: the track is still loaded, but whatever it was reading
/// from is gone. Names which one on the second line instead of leaving a play
/// button that would do nothing.
class _Stalled extends StatelessWidget {
  const _Stalled({
    required this.handler,
    required this.item,
    required this.stall,
  });

  final MeowzicAudioHandler handler;
  final MediaItem item;
  final MeowzicStall stall;

  @override
  Widget build(BuildContext context) => _Face(
        artUri: item.artUri,
        child: Row(
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    switch (stall) {
                      MeowzicStall.none => '',
                      MeowzicStall.needVpn =>
                        appLocalizations.meowzicNeedVpnShort,
                      MeowzicStall.bridgeError =>
                        appLocalizations.meowzicBridgeErrorShort,
                    },
                    // Stays semantic red while the transport glyphs went
                    // white: this line is a diagnosis, not a control.
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Routed through handler.play so the stall override decides what a
            // press means — here it asks for the tunnel back, not for audio.
            _GhostControl(
              icon: HugeIcons.strokeRoundedPlay,
              onPressed: handler.play,
              size: 28,
              tapSize: 44,
              tooltip: appLocalizations.meowzicReconnect,
            ),
          ],
        ),
      );
}

class _Playing extends StatelessWidget {
  const _Playing({required this.handler, required this.item});

  final MeowzicAudioHandler handler;
  final MediaItem item;

  @override
  Widget build(BuildContext context) => _Face(
        artUri: item.artUri,
        child: Row(
          children: [
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
            const SizedBox(width: 8),
            // A like control (HugeIcons.strokeRoundedFavourite) belongs at the
            // head of this row, and it lands the day Spotify authentication
            // does. A like has to be written to the listener's own Spotify
            // account to mean anything, and there is no account here yet — so
            // nothing is drawn rather than a heart that lies.
            StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                // Reuse the handler's own verdict instead of re-deriving it:
                // _toState only publishes skip controls while the queue holds
                // more than one entry, so this is exactly its "there is
                // somewhere to skip to".
                final controls = state?.controls ?? const <MediaControl>[];
                final canSkip = controls.any(
                  (control) => control.action == MediaAction.skipToNext,
                );
                // Drawn even when they cannot fire. The notification shade
                // hides them because it only has three slots; the card has the
                // room, and a play button that jumps sideways mid-track is
                // worse than a pair of dim arrows.
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GhostControl(
                      icon: HugeIcons.strokeRoundedPrevious,
                      onPressed: canSkip ? handler.skipToPrevious : null,
                    ),
                    _GhostControl(
                      icon: playing
                          ? HugeIcons.strokeRoundedPause
                          : HugeIcons.strokeRoundedPlay,
                      onPressed: playing ? handler.pause : handler.play,
                      size: 28,
                      tapSize: 44,
                    ),
                    _GhostControl(
                      icon: HugeIcons.strokeRoundedNext,
                      onPressed: canSkip ? handler.skipToNext : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}
