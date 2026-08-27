import 'package:dropweb/common/common.dart';
// Narrowed on purpose: the models barrel carries names the meowzic screens
// already use, and the menu needs exactly one type out of it.
import 'package:dropweb/models/models.dart' show PopupMenuItemData;
import 'package:dropweb/views/meowzic/art_wash.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// One track, wherever a track is listed.
///
/// There were two of these — one on the search tab, one on the container screen
/// — differing in nothing but which widget sat at the right-hand end. They were
/// the same card, the same height, the same art wash and the same two lines of
/// type, because they are the same object to a listener: a thing you tap to
/// hear. Two copies meant every fix had to be found twice, which is the defect
/// the owner reported as "одни и те же косяки на разных страницах".
///
/// [subtitle] is the artist line — an author from the bridge on one screen and
/// Spotify's artist names on the other. It is a plain string here on purpose:
/// this widget must not know which of the two it is drawing.
class MeowzicTrackRow extends StatelessWidget {
  const MeowzicTrackRow({
    super.key,
    required this.title,
    required this.onPressed,
    this.subtitle,
    this.image,
    this.isSelected = false,
    this.trailing,
    this.trailingPadsItself = false,
  });

  final String title;
  final String? subtitle;

  /// Cover art, bled in from the left edge and faded across the card's first
  /// third. Absent art leaves a plain card rather than a grey block.
  final Uri? image;

  /// Whether this is the row the screen is currently doing something about —
  /// playing it, or looking up what to play. Marked with the card's own
  /// selected border and a tinted title rather than a treatment invented for
  /// one list.
  final bool isSelected;

  /// The right-hand end: an overflow menu on the search tab, a running time or
  /// a spinner on a container screen. Null leaves the title running the full
  /// width.
  final Widget? trailing;

  /// Whether [trailing] brings its own tap padding with it.
  ///
  /// An [IconButton] does — it reserves a 48pt target around a 24pt glyph — so
  /// a row ending in one takes 8 on the right and lets the button carry the
  /// rest of the way to an optical 16. Text does not, and takes the full 16.
  /// Both behaviours were in the code before this widget existed; neither is a
  /// rounding error, and collapsing them to one number would misalign one
  /// screen or the other.
  final bool trailingPadsItself;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          radius: Lumina.radiusLg,
          isSelected: isSelected,
          onPressed: onPressed,
          // No ClipRRect here and none is needed — CommonCard is an
          // `OutlinedButton` with `clipBehavior: Clip.antiAlias` and a
          // `RoundedSuperellipseBorder` (lib/widgets/card.dart), so the wash is
          // already clipped to the card's squircle. Adding a clip of our own
          // would only cost a second saveLayer and round the art to the wrong
          // curve.
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image case final uri?) MeowzicArtWash(uri: uri),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  trailingPadsItself ? 8 : 16,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : context.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Empty is treated as absent: the bridge answers with
                          // an empty author rather than a null one, and a blank
                          // second line would push the title off centre for
                          // nothing.
                          if (subtitle case final line?
                              when line.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              line,
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
                    if (trailing case final end?) ...[
                      const SizedBox(width: 8),
                      end,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// A row's overflow menu — the same [CommonPopupBox] the profile cards use,
/// down to the glyph, so a long-press-shaped habit learned on one screen keeps
/// working on the other.
///
/// It stands where the running time used to on the search tab. The time was
/// read-only trivia on a row you can already only do one thing with; the corner
/// is worth more as the way into the things a track is attached to.
///
/// Only "listen" is offered today, and that is the honest whole of it: artist
/// and playlist entries belong here, and they land when a track knows which
/// artist and playlist it came from. An item that opened nothing would be worse
/// than a short menu. The duplication with the row tap is deliberate: a menu
/// that can be opened has to be able to do something, and this is the one thing
/// that works.
class MeowzicTrackMenu extends StatelessWidget {
  const MeowzicTrackMenu({super.key, required this.onListen});

  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) => CommonPopupBox(
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              label: appLocalizations.listen,
              onPressed: onListen,
            ),
          ],
        ),
        targetBuilder: (open) => IconButton(
          onPressed: open,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedMoreVertical,
            size: 24,
          ),
        ),
      );
}
