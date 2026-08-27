import 'package:flutter/material.dart';

/// How deep a scrollable dissolves into the background at its bottom edge.
const meowzicListFade = 40.0;

/// Bottom padding of a meowzic scrollable.
///
/// Deliberately clear of [meowzicListFade] on both counts: the final card has
/// to come to rest above the fade rather than inside it, and it should not be
/// crowded against the gesture bar once it gets there.
const meowzicListBottomPadding = 56.0;

/// The house insets for a meowzic scrollable — 16 either side, clear of the
/// gesture bar below, nothing on top because whatever sits above it already
/// spaced itself.
const meowzicListPadding =
    EdgeInsets.fromLTRB(16, 0, 16, meowzicListBottomPadding);

/// How close to the end a scroll has to stop before the next page is fetched.
///
/// Roughly three rows: near enough that the page is usually there by the time
/// the thumb moves again, far enough that merely reaching the bottom of a short
/// album does not fire a request.
const meowzicLoadMoreThreshold = 240.0;

/// Dissolves whatever scrolls inside it where it meets the bottom of the
/// viewport.
///
/// A bare list guillotines whichever row the bottom edge lands on. On a flat
/// list that reads as scrolling; on these cards it reads as a rendering fault,
/// because a squircle carrying cover art suddenly ends in a straight line with
/// the gesture pill sitting on top of it.
///
/// Masked, not scrimmed. The mesh behind every meowzic screen is a live
/// gradient, so a fade painted down to `Lumina.void_` would sit on it as a dark
/// band; taking the alpha down instead lets the mesh through untouched. That is
/// the same call `MeowzicArtWash` makes horizontally, for the same reason.
///
/// [meowzicListFade] is a count of logical pixels turned into a stop against
/// the measured viewport, so the fade stays the same physical depth on a tall
/// phone and a short one. [meowzicListBottomPadding] is deliberately larger: at
/// full scroll the fade has to be lying on empty padding, or the last card
/// would come to rest half transparent — which would be a worse bug than the
/// one this fixes.
///
/// Shared rather than copied. This block existed twice, once on the search tab
/// and once on the container screen, and the second copy was made by pasting
/// the first — which is exactly how one defect turns into two sites to find.
/// The library grid wraps the same widget, so all three scrollables end the
/// same way.
class MeowzicFade extends StatelessWidget {
  const MeowzicFade({super.key, required this.child});

  /// The scrollable to fade. Any of them — a [ListView], a [GridView], a
  /// [CustomScrollView] with more than one section.
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // A viewport too short to hold the fade and something to read would
          // be all fade; leave those alone rather than dim the whole list.
          final fade = constraints.maxHeight <= meowzicListFade * 3
              ? 0.0
              : meowzicListFade / constraints.maxHeight;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 1 - fade, 1.0],
            ).createShader(rect),
            child: child,
          );
        },
      );
}
