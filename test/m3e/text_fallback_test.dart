import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/ui/m3e/theme/m3e_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final twemoji = FontFamily.twEmoji.value;

  group('m3eFontFallbackFor', () {
    test('Android: системное текстовое семейство стоит раньше Twemoji', () {
      final list = m3eFontFallbackFor(android: true);
      expect(list, [m3eAndroidTextFamily, twemoji]);
      // Twemoji держит глифы цифр и пробела, поэтому первым он цифры «съедает».
      expect(
          list.indexOf(m3eAndroidTextFamily), lessThan(list.indexOf(twemoji)));
    });

    test('остальные платформы: только Twemoji', () {
      expect(m3eFontFallbackFor(android: false), [twemoji]);
    });
  });
}
