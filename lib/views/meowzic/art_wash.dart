import 'package:dropweb/common/common.dart';
import 'package:flutter/material.dart';

/// The cover treatment shared by the dashboard entry card and the meowzic
/// track rows: the art bled in from the left edge of the card and faded out
/// across its first third — the background the owner asked for in place of a
/// leading square.
class MeowzicArtWash extends StatelessWidget {
  const MeowzicArtWash({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        // The mask spans the WHOLE card while the art it masks is only a third
        // of it. That gap is deliberate. When the two edges coincide, the clip
        // that bounds the art lands exactly on the mask layer's own boundary
        // and survives as a one-pixel seam — the layer edge is the one place
        // the shader cannot finish the job. Held a third in, the clip edge sits
        // deep inside the layer where the mask has already taken the alpha to
        // zero, and there is nothing left to leak.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            // Eased out rather than ramped straight down. A linear ramp spends
            // as much alpha on its last step as on its first, so the eye
            // catches the moment it reaches zero and reads it as an edge.
            // These stops drop hard early and then crawl, so the art is
            // already faint long before it ends and there is no seam to see.
            colors: [
              Colors.white,
              Colors.white,
              Colors.white.opacity60,
              Colors.white.opacity30,
              Colors.white.opacity10,
              Colors.white.opacity0,
              Colors.white.opacity0,
            ],
            // Card fractions, not region fractions: the art ends at 0.34 and
            // the alpha is already zero at 0.32, so the fade completes just
            // short of the art's own edge and the rest of the card is masked
            // out flat.
            stops: const [0.0, 0.06, 0.14, 0.21, 0.28, 0.32, 1.0],
          ).createShader(rect),
          // Pinned to the left edge, one third of the card wide. That width is
          // load-bearing: a Stack child spans the full 4.5:1 card, and
          // BoxFit.cover on a square cover then smears one horizontal slice of
          // it across all of that — which is why the first attempt read as a
          // flat slab of colour rather than artwork.
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.34,
              heightFactor: 1,
              // Painted into a SQUARE that is then oversized past this region
              // and clipped back to it. Thumbnails arrive as a square sleeve
              // sitting inside a wider frame, so pouring one straight into a
              // region wider than it is tall keeps that frame's dead side
              // margins — which showed up against the card's rounded left edge
              // as a flat strip with a hard vertical seam. Covering a square
              // lands on the sleeve itself whatever the frame ratio, and the
              // 1.4 then eats into the sleeve's own margins so nothing empty
              // can reach the card's edge.
              //
              // Sized rather than scaled with a paint-time Transform, so the
              // zoom is a layout fact rather than something the paint pass can
              // drop.
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) => OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: SizedBox.square(
                      dimension: constraints.maxWidth * 1.4,
                      // Darkened through Image's own colour blend rather than a
                      // Container on top, which would cost an extra saveLayer.
                      // This is not decoration: the title runs straight across
                      // the art and covers are often bright photos, so the text
                      // needs something to sit on. Do not brighten it.
                      child: Image.network(
                        uri.toString(),
                        fit: BoxFit.cover,
                        color: Lumina.void_.opacity50,
                        colorBlendMode: BlendMode.srcATop,
                        // A broken image leaves a plain card, not a grey block.
                        // The old leading cover needed a note glyph because it
                        // occupied space; a background occupies none, so it
                        // just goes away.
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
