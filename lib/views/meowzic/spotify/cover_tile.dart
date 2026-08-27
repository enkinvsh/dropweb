import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// One Spotify container, drawn as its cover with its name under it.
///
/// Shared rather than private to the library grid, because an artist's releases
/// are the same thing: a cover, a name, and a tap that opens the container. A
/// second tile for that section would have been a second place to fix the day
/// one of them looks wrong — which is the complaint this pass answers.
class SpotifyCoverTile extends StatelessWidget {
  const SpotifyCoverTile({
    super.key,
    required this.item,
    required this.onPressed,
  });

  final SpotifyLibraryItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
        // [Lumina.radiusLg] is 26 and is the house curve — the same one
        // [MeowzicTrackRow] passes. Left to itself [CommonCard] falls back to 12,
        // which is its own default and NOT this app's; that is how the first
        // cut of this grid shipped visibly squarer than every other card on
        // screen. Always pass it.
        radius: Lumina.radiusLg,
        onPressed: onPressed,
        // The card's own `padding` is declared and never applied — see
        // `widgets/card.dart`, where the button's padding is pinned to zero —
        // so the inset is placed here rather than passed to a parameter that
        // silently does nothing.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centred inside the flexible space rather than sized to it: when
              // a long title takes a second line the square gives up height
              // instead of the text being clipped, and the tile stays whole.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _CoverArt(item: item),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.subtitle case final subtitle?) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
      );
}

/// The cover itself, round for artists and squircle for everything else.
///
/// A shape, not a second card: Spotify draws artists as circles everywhere and
/// a grid mixing the two reads wrong when they all share one silhouette. The
/// card around it is the same in both cases.
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.item});

  final SpotifyLibraryItem item;

  /// Typed as hugeicons types its own constants — a path list, not an
  /// [IconData]. The set is drawn rather than a font.
  List<List<dynamic>> get _fallbackIcon => switch (item.kind) {
        SpotifyLibraryKind.artist => HugeIcons.strokeRoundedUserCircle,
        SpotifyLibraryKind.album => HugeIcons.strokeRoundedCd,
        SpotifyLibraryKind.likedSongs => HugeIcons.strokeRoundedFavourite,
        SpotifyLibraryKind.playlist => HugeIcons.strokeRoundedPlayList,
      };

  /// What stands in when there is no art, and what shows while it loads.
  ///
  /// The same widget for both states on purpose: a placeholder that differs
  /// from the error state makes a slow connection look like a broken library.
  Widget _placeholder(BuildContext context) => ColoredBox(
        color: context.colorScheme.onSurface.opacity10,
        child: Center(
          child: HugeIcon(
            icon: _fallbackIcon,
            size: 32,
            color: context.colorScheme.onSurface.opacity38,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget art;
    if (item.image case final uri?) {
      // Decoded at the size it is drawn at, the way the dashboard logo already
      // does it. A grid holds a dozen of these at once, and full-resolution
      // bitmaps for 170pt squares is how a list of covers turns into a memory
      // problem on a mid-range phone.
      final cacheWidth =
          (_tileArtWidth * MediaQuery.devicePixelRatioOf(context)).round();
      art = CachedNetworkImage(
        imageUrl: uri.toString(),
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheWidth,
        placeholder: (context, _) => _placeholder(context),
        errorWidget: (context, _, __) => _placeholder(context),
      );
    } else {
      art = _placeholder(context);
    }

    return item.kind == SpotifyLibraryKind.artist
        ? ClipOval(child: art)
        : ClipRRect(
            borderRadius: BorderRadius.circular(Lumina.radiusMd),
            child: art,
          );
  }
}

/// Roughly how wide a tile's cover is drawn, in logical pixels, on the phones
/// this ships to. Used only to pick a decode size — the layout is the grid's.
const _tileArtWidth = 180.0;
