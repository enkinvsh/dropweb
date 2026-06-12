import 'package:emoji_regex/emoji_regex.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter/material.dart';

import '../state.dart';

/// Splits [text] into spans so emoji runs render with the bundled Twemoji
/// font. Windows lacks system emoji coverage (e.g. country-flag glyphs), so
/// emoji must use [FontFamily.twEmoji] which ships in the app. Non-emoji runs
/// keep [style] verbatim; emoji runs reuse it with the Twemoji family swapped
/// in. Shared by [EmojiText] and any rich-span builder (e.g. announcements)
/// that needs the same fallback without duplicating the emoji regex.
List<TextSpan> buildEmojiSpans(String text, {TextStyle? style}) {
  final spans = <TextSpan>[];
  final matches = emojiRegex().allMatches(text);

  var lastMatchEnd = 0;
  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style?.copyWith(
          fontFamily: FontFamily.twEmoji.value,
        ),
      ),
    );
    lastMatchEnd = match.end;
  }
  if (lastMatchEnd < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ),
    );
  }

  return spans;
}

class TooltipText extends StatelessWidget {

  const TooltipText({
    super.key,
    required this.text,
  });
  final Text text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, container) {
        final maxWidth = container.maxWidth;
        final size = globalState.measure.computeTextSize(
          text,
        );
        if (maxWidth < size.width) {
          return Tooltip(
            preferBelow: false,
            message: text.data,
            child: text,
          );
        }
        return text;
      },
    );
}

class EmojiText extends StatelessWidget {

  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => RichText(
      textScaler: MediaQuery.of(context).textScaler,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        children: buildEmojiSpans(text, style: style),
      ),
    );
}
