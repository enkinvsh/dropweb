// Эталон для всех ожиданий: `accentVars` и палитры, вырезанные из app.js доски (коммит df156ea1,
// строки 84-140) и выполненные в Node. Значения не выведены из Dart-кода, поэтому ловят расхождение порта.

import 'dart:ui' show Color;

import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/color/color.dart' show m3eFallbackSeed;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';

/// FNV-1a 32 бита: свёртка по всей сетке в 120 цветов, чтобы не таскать 480 значений в тест.
int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// `#RRGGBB` без альфы из ARGB.
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
        .toUpperCase();

/// Строка в том же формате, что собирает эталонный скрипт: `вход светлый тёмный on-светлый on-тёмный`.
String _row(String hex) {
  final v = ios27AccentVars(hex);
  return '$hex ${_hex(v.accent(dark: false))} ${_hex(v.accent(dark: true))} '
      '${_hex(v.onAccent(dark: false))} ${_hex(v.onAccent(dark: true))}';
}

void main() {
  group('PRESETS', () {
    test('восемь системных цветов в порядке доски', () {
      expect(
        kIos27AccentPresets.map((p) => p.id),
        [
          'blue',
          'purple',
          'pink',
          'red',
          'orange',
          'yellow',
          'green',
          'graphite'
        ],
      );
      expect(
        kIos27AccentPresets.map((p) => p.name),
        [
          'Синий',
          'Фиолетовый',
          'Розовый',
          'Красный',
          'Оранжевый',
          'Жёлтый',
          'Зелёный',
          'Графитовый'
        ],
      );
    });

    test('light, dark и ic как на доске', () {
      final byId = {for (final p in kIos27AccentPresets) p.id: p};
      expect([byId['blue']!.light, byId['blue']!.dark, byId['blue']!.ic],
          ['#0088FF', '#0091FF', null]);
      expect([byId['purple']!.light, byId['purple']!.dark],
          ['#CB30E0', '#DB34F2']);
      expect([byId['pink']!.light, byId['pink']!.dark], ['#FF2D55', '#FF375F']);
      expect([byId['red']!.light, byId['red']!.dark], ['#FF383C', '#FF4245']);
      expect([byId['orange']!.light, byId['orange']!.dark, byId['orange']!.ic],
          ['#FF8D28', '#FF9230', '#C55300']);
      expect([byId['yellow']!.light, byId['yellow']!.dark, byId['yellow']!.ic],
          ['#FFCC00', '#FFD600', '#A16A00']);
      expect([byId['green']!.light, byId['green']!.dark, byId['green']!.ic],
          ['#34C759', '#30D158', '#008932']);
      expect([
        byId['graphite']!.light,
        byId['graphite']!.dark,
        byId['graphite']!.ic
      ], [
        '#8E8E93',
        '#8E8E93',
        null
      ]);
    });

    test('ic только у оранжевого, жёлтого и зелёного', () {
      expect(
        kIos27AccentPresets.where((p) => p.ic != null).map((p) => p.id),
        ['orange', 'yellow', 'green'],
      );
    });
  });

  group('GRID и SLOTS', () {
    test('сетка 12 × 10 = 120 цветов', () {
      expect(kIos27ColorGrid, hasLength(120));
      expect(kIos27ColorGridColumns, 12);
      expect(
          kIos27ColorGrid.every((h) => RegExp(r'^#[0-9A-F]{6}$').hasMatch(h)),
          isTrue);
    });

    test('углы и концы строк', () {
      expect(kIos27ColorGrid[0], '#FEFFFE');
      expect(kIos27ColorGrid[11], '#000000');
      expect(kIos27ColorGrid[12], '#00374A');
      expect(kIos27ColorGrid[119], '#DEEED4');
    });

    test('три слота с подписями доски', () {
      expect(
          Ios27ColorSlot.values.map((s) => s.name), ['accent', 'orb1', 'orb2']);
      expect(Ios27ColorSlot.values.map((s) => s.label),
          ['Кнопки', 'Фон сверху', 'Фон снизу']);
    });

    test('автоконтраст по всей сетке совпадает с JS доски (свёртка FNV-1a)',
        () {
      final lines = kIos27ColorGrid.map(_row).join('\n');
      expect(_fnv(lines).toRadixString(16), 'fa71623c');
    });
  });

  group('автоконтраст (строковая ветка)', () {
    test('неоновый #29FF76: светлая тема затемняется до 3.2:1, тёмная остаётся',
        () {
      final v = ios27AccentVars('#29FF76');
      expect(_hex(v.accent(dark: false)), '#1AA34C');
      expect(_hex(v.accent(dark: true)), '#29FF76');
      expect(_hex(v.onAccent(dark: false)), '#FFFFFF');
      expect(_hex(v.onAccent(dark: true)), '#000000');
      expect(v.soft(dark: false).toARGB32(), 0x1F1AA34C);
      expect(v.soft(dark: true).toARGB32(), 0x2929FF76);
      expect(ios27Contrast(v.light, Ios27Rgb.white), greaterThanOrEqualTo(3.2));
    });

    test('цвета провайдеров доски', () {
      const expected = {
        '#38BDF8': '#38BDF8 #2D97C6 #38BDF8 #FFFFFF #000000',
        '#A78BFA': '#A78BFA #967DE1 #A78BFA #FFFFFF #000000',
        '#EF4444': '#EF4444 #EF4444 #EF4444 #FFFFFF #FFFFFF',
        '#F59E0B': '#F59E0B #C47E09 #F59E0B #FFFFFF #000000',
        '#64748B': '#64748B #64748B #67778D #FFFFFF #FFFFFF',
      };
      for (final e in expected.entries) {
        expect(_row(e.key), e.value, reason: e.key);
      }
    });

    test('светлый акцент (жёлтый) темнеет, текст на нём в тёмной теме чёрный',
        () {
      expect(_row('#FFCC00'), '#FFCC00 #AD8B00 #FFCC00 #FFFFFF #000000');
    });

    test(
        'уже тёмный акцент в светлой теме не трогается, в тёмной осветляется до 4.5:1',
        () {
      final v = ios27AccentVars('#000000');
      expect(_hex(v.accent(dark: false)), '#000000');
      expect(_hex(v.accent(dark: true)), '#757575');
      expect(ios27Contrast(v.dark, Ios27Rgb.black), greaterThanOrEqualTo(4.5));
    });

    test('белый и почти белый затемняются в светлой теме', () {
      expect(_row('#FFFFFF'), '#FFFFFF #8F8F8F #FFFFFF #FFFFFF #000000');
      expect(_row('#FEFFFE'), '#FEFFFE #8E8F8E #FEFFFE #FFFFFF #000000');
    });

    test(
        'системные цвета Apple остаются как есть, графит с белым текстом в обеих темах',
        () {
      expect(_row('#0088FF'), '#0088FF #0088FF #0088FF #FFFFFF #FFFFFF');
      expect(_row('#8E8E93'), '#8E8E93 #8E8E93 #8E8E93 #FFFFFF #FFFFFF');
    });

    test('пресеты как собственный цвет (светлое значение пресета)', () {
      expect(_row('#FF8D28'), '#FF8D28 #D67622 #FF8D28 #FFFFFF #000000');
      expect(_row('#34C759'), '#34C759 #2BA349 #34C759 #FFFFFF #000000');
    });

    test('--accent-soft: 1F в светлой и 29 в тёмной', () {
      final v = ios27AccentVars('#A78BFA');
      expect(v.soft(dark: false).toARGB32(), 0x1F967DE1);
      expect(v.soft(dark: true).toARGB32(), 0x29A78BFA);
    });

    test('toVars отдаёт три свойства доски', () {
      final m = ios27AccentVars('#29FF76').toVars(dark: true);
      expect(m.keys, ['--accent', '--on-accent', '--accent-soft']);
      expect(m['--accent'], 0xFF29FF76);
      expect(m['--on-accent'], 0xFF000000);
      expect(m['--accent-soft'], 0x2929FF76);
    });
  });

  group('объектная ветка accentVars (мёртвый код доски, но портирован)', () {
    test('берёт ic для светлой темы и dark для тёмной, без подгонки', () {
      final orange = kIos27AccentPresets.firstWhere((p) => p.id == 'orange');
      final v = ios27AccentVarsFromPreset(orange);
      expect(_hex(v.accent(dark: false)), '#C55300');
      expect(_hex(v.accent(dark: true)), '#FF9230');
      expect(_hex(v.onAccent(dark: false)), '#FFFFFF');
      expect(_hex(v.onAccent(dark: true)), '#000000');
      expect(v.soft(dark: false).toARGB32(), 0x1FC55300);
      expect(v.soft(dark: true).toARGB32(), 0x29FF9230);
    });

    test('без ic берёт light', () {
      final blue = kIos27AccentPresets.firstWhere((p) => p.id == 'blue');
      final v = ios27AccentVarsFromPreset(blue);
      expect(_hex(v.accent(dark: false)), '#0088FF');
      expect(_hex(v.accent(dark: true)), '#0091FF');
    });

    test('все пресеты как на доске', () {
      const expected = {
        'blue': ['#0088FF', '#0091FF', '#FFFFFF', '#FFFFFF'],
        'purple': ['#CB30E0', '#DB34F2', '#FFFFFF', '#FFFFFF'],
        'pink': ['#FF2D55', '#FF375F', '#FFFFFF', '#FFFFFF'],
        'red': ['#FF383C', '#FF4245', '#FFFFFF', '#FFFFFF'],
        'orange': ['#C55300', '#FF9230', '#FFFFFF', '#000000'],
        'yellow': ['#A16A00', '#FFD600', '#FFFFFF', '#000000'],
        'green': ['#008932', '#30D158', '#FFFFFF', '#000000'],
        'graphite': ['#8E8E93', '#8E8E93', '#FFFFFF', '#FFFFFF'],
      };
      for (final p in kIos27AccentPresets) {
        final v = ios27AccentVarsFromPreset(p);
        expect(
          [
            _hex(v.accent(dark: false)),
            _hex(v.accent(dark: true)),
            _hex(v.onAccent(dark: false)),
            _hex(v.onAccent(dark: true)),
          ],
          expected[p.id],
          reason: p.id,
        );
      }
    });
  });

  group('тема провайдера', () {
    test('по умолчанию акцент #29FF76 и это не один из пресетов', () {
      expect(Ios27ProviderTheme.defaults.accent, '#29FF76');
      expect(Ios27ProviderTheme.defaults.accent, m3eFallbackSeed);
      expect(
        kIos27AccentPresets
            .any((p) => p.light == '#29FF76' || p.dark == '#29FF76'),
        isFalse,
      );
      // Совпадает с первым провайдером доски: `theme = parseTheme(PROVIDERS[0].theme)`.
      final first = Ios27ProviderTheme.fromHeader(kBoardProviders.first.theme);
      expect(first.accent, Ios27ProviderTheme.defaults.accent);
    });

    test('parseDropwebTheme: шесть провайдеров доски', () {
      const expected = [
        ['#29FF76', '#000000', '#2BFF7A', 4.0],
        ['#38BDF8', '#6366F1', '#22D3EE', 3.0],
        ['#A78BFA', '#EC4899', '#6366F1', 4.0],
        ['#EF4444', '#F59E0B', '#BE185D', 3.0],
        ['#F59E0B', '#EF4444', '#FACC15', 4.0],
        ['#64748B', '#0EA5E9', '#94A3B8', 2.0],
      ];
      for (var i = 0; i < kBoardProviders.length; i++) {
        final t = Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);
        expect([t.accent, t.orb1, t.orb2, t.blur], expected[i],
            reason: kBoardProviders[i].name);
      }
    });

    test('пустой орб следует за акцентом, blur зажат в 1..5', () {
      final t = Ios27ProviderTheme.fromHeader('fidelity,#38BDF8,,,9');
      expect([t.accent, t.orb1, t.orb2, t.blur],
          ['#38BDF8', '#38BDF8', '#38BDF8', 5.0]);
      final u = Ios27ProviderTheme.fromHeader('fidelity,zzz');
      expect(u.accent, '#29FF76');
      expect(u.blur, 3.0);
    });

    test('свои цвета оставляют провайдерское размытие', () {
      final theme = Ios27ProviderTheme.fromHeader(kBoardProviders[2].theme);
      final own = theme.withOwn(accent: '#FF2D55');
      expect([own.accent, own.orb1, own.orb2, own.blur],
          ['#FF2D55', '#EC4899', '#6366F1', 4.0]);
      expect(own.slot(Ios27ColorSlot.accent), '#FF2D55');
      expect(own.slot(Ios27ColorSlot.orb2), '#6366F1');
    });

    test('apply: пять свойств applyAccent', () {
      final a = Ios27ProviderTheme.fromHeader(kBoardProviders[0].theme).apply();
      final dark = a.toVars(dark: true);
      expect(dark['--accent'], 0xFF29FF76);
      expect(dark['--orb1'], 0xFF000000);
      expect(dark['--orb2'], 0xFF2BFF7A);
      final light = a.toVars(dark: false);
      expect(light['--accent'], 0xFF1AA34C);
      expect(light['--accent-soft'], 0x1F1AA34C);
    });
  });

  group('значки строк всегда серые', () {
    test('берутся из палитры, а не из акцента', () {
      for (final dark in [false, true]) {
        final p = Ios27Tokens.palette(dark: dark);
        expect(Ios27RowIconColors.tile(p), p.fill3);
        expect(Ios27RowIconColors.glyph(p), p.label);
        expect(Ios27RowIconColors.trailing(p), p.label3);
      }
    });
  });

  group('Ios27Rgb', () {
    test('разбор и печать', () {
      expect(Ios27Rgb.fromHex('#1aa34c').hex, '#1AA34C');
      // Восьмизначный hex доски: альфа игнорируется (slice(1, 7)).
      expect(Ios27Rgb.fromHex('#29FF76CC').hex, '#29FF76');
      // Мусор даёт чёрный, как `NaN & 255` в JS.
      expect(Ios27Rgb.fromHex('#zzzzzz').hex, '#000000');
    });

    test('контраст чёрного к белому равен 21', () {
      expect(ios27Contrast(Ios27Rgb.black, Ios27Rgb.white), closeTo(21, 1e-9));
    });
  });
}
