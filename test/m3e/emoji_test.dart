import 'package:dropweb/ui/m3e/m3e_emoji.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractLeadEmoji', () {
    test('простые эмодзи и вариационный селектор', () {
      expect(extractLeadEmoji('⚪ White'), '⚪');
      expect(extractLeadEmoji('⚡ Авто'), '⚡');
      expect(extractLeadEmoji('📶 First Available'), '📶');
      expect(extractLeadEmoji('⚡\uFE0F Fastest'), '⚡\uFE0F');
    });

    test('составные: ZWJ, keycap, тон кожи', () {
      expect(extractLeadEmoji('🏳️‍🌈 Прайд'), '🏳️‍🌈');
      expect(extractLeadEmoji('👨‍👩‍👧 Семья'), '👨‍👩‍👧');
      expect(extractLeadEmoji('1️⃣ Первый'), '1️⃣');
      expect(extractLeadEmoji('👍🏽 ок'), '👍🏽');
    });

    test('не эмодзи: буквы, цифры, знаки, флаг', () {
      expect(extractLeadEmoji('White'), isNull);
      expect(extractLeadEmoji('· резерв'), isNull);
      expect(extractLeadEmoji('1 узел'), isNull);
      expect(extractLeadEmoji('#1'), isNull);
      expect(extractLeadEmoji('🇩🇪 Германия'), isNull);
      expect(extractLeadEmoji(''), isNull);
    });

    test('эмодзи не в начале не берётся', () {
      expect(extractLeadEmoji('Германия ✨'), isNull);
    });
  });

  group('stripLeadEmoji', () {
    test('убирает эмодзи и пробел за ним', () {
      expect(stripLeadEmoji('⚪ White · резерв'), 'White · резерв');
      expect(stripLeadEmoji('🏳️‍🌈  Прайд'), 'Прайд');
    });

    test('без эмодзи или если ничего не осталось — имя как есть', () {
      expect(stripLeadEmoji('White'), 'White');
      expect(stripLeadEmoji('⚪'), '⚪');
      expect(stripLeadEmoji('Германия ✨'), 'Германия ✨');
    });
  });
}
