// G2: цвета iOS-колонки доски против Dart-токенов.
//
// Эталон `test/ios27/ref/colors.json` снимает T1 с доски (Chromium), плоская схема:
//   { "<сцена>-<тема>-p<N>": { "--var": "#RRGGBB" | "#RRGGBBAA" }, "<сцена>-<тема>-a<K>": { ... } }
// сцены home-off / home-on, тема light / dark, p0..p5 = индекс в PROVIDERS доски (цвета провайдера из
// заголовка `dropweb-theme`), a0..a7 = индекс в PRESETS доски, применённый как свой акцент
// (`PRESETS[k].light` строкой, орбы остаются провайдерскими).
//
// Считаем те же свойства из `tokens.g.dart` (палитра темы) и `accent.dart` (акцент, орбы) и сверяем.
//
// Допуск:
//  - 0 для обычных токенов;
//  - ±1 на канал только для свойств, выведенных через `color-mix` (множество `_colorMix`). В корне
//    iOS-колонки таких свойств нет: все `color-mix` доски лежат на элементах (стекло, фон, строки),
//    поэтому множество пустое, а проверка допуска остаётся на случай их появления в эталоне.
//
// Потери canvas. Если T1 читает цвет через пиксель canvas, полупрозрачные значения искажаются: canvas
// хранит 8-битную премультиплицированную альфу (`#3C3C432E` -> `#3D3D432E`, `#1AA34C1F` -> `#19A54A1F`).
// Точное значение даёт строка `rgba(...)` из getComputedStyle. Такое искажение принимается как
// «совпало через canvas» и считается отдельно, чтобы T1 мог перейти на точное чтение.
//
// Нет эталона: тест падает с понятным сообщением (ждёт T1), а не пропускается.

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';

/// Путь к эталону; переменная окружения нужна только чтобы прогнать сам тест на пробном файле.
final String _refPath =
    Platform.environment['IOS27_COLORS_JSON'] ?? 'test/ios27/ref/colors.json';

/// Свойства, выведенные через `color-mix` (допуск ±1 на канал). В корне iOS-колонки их нет.
const Set<String> _colorMix = <String>{};

/// Свойства акцента: считаются в accent.dart, а не берутся из палитры.
const Set<String> _accentVars = {
  '--accent',
  '--on-accent',
  '--accent-soft',
  '--orb1',
  '--orb2',
};

final RegExp _keyRe = RegExp(r'^(.+)-(light|dark)-([pa])(\d+)$');
final RegExp _hexRe = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$');

/// `#RRGGBB` / `#RRGGBBAA` доски в ARGB (без альфы значит непрозрачный).
int _parse(String name, String hex) {
  final m = _hexRe.firstMatch(hex);
  if (m == null) {
    fail('$name: значение "$hex" не похоже на #RRGGBB или #RRGGBBAA');
  }
  final rgb = int.parse(m.group(1)!, radix: 16);
  final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
  return (a << 24) | rgb;
}

String _fmt(int argb) {
  final a = argb >>> 24;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return a == 0xFF
      ? '#$rgb'.toUpperCase()
      : '#$rgb${a.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

/// Что вернёт чтение через canvas для точного значения [argb]: канал туда-обратно через
/// 8-битное премультиплицированное хранение.
int _canvasRoundTrip(int argb) {
  final a = argb >>> 24;
  if (a == 0xFF) return argb;
  if (a == 0) return 0;
  int ch(int v) =>
      ((v * a / 255).round() * 255 / a).round().clamp(0, 255).toInt();
  return (a << 24) |
      (ch((argb >> 16) & 0xFF) << 16) |
      (ch((argb >> 8) & 0xFF) << 8) |
      ch(argb & 0xFF);
}

bool _withinOne(int x, int y) {
  for (final shift in [24, 16, 8, 0]) {
    if ((((x >> shift) & 0xFF) - ((y >> shift) & 0xFF)).abs() > 1) return false;
  }
  return true;
}

/// Тема провайдера, к которому относится запись `a<K>`: у них орбы остаются провайдерскими.
/// Опознаётся по `--orb1`/`--orb2` самой записи; без орбов в записи берётся первый провайдер.
Ios27ProviderTheme _providerFor(Map<String, int> ref) {
  final o1 = ref['--orb1'];
  final o2 = ref['--orb2'];
  if (o1 == null && o2 == null) {
    return Ios27ProviderTheme.fromHeader(kBoardProviders.first.theme);
  }
  for (final p in kBoardProviders) {
    final t = Ios27ProviderTheme.fromHeader(p.theme);
    final a = t.apply();
    if ((o1 == null || a.orb1.toARGB32() == o1) &&
        (o2 == null || a.orb2.toARGB32() == o2)) {
      return t;
    }
  }
  fail(
    'запись a<K>: орбы ${o1 == null ? "—" : _fmt(o1)} / ${o2 == null ? "—" : _fmt(o2)} '
    'не принадлежат ни одному из ${kBoardProviders.length} провайдеров доски',
  );
}

/// Свойства, которые мы умеем посчитать для записи.
Map<String, int> _expected({
  required bool dark,
  required String kind,
  required int index,
  required Map<String, int> ref,
}) {
  final Ios27ProviderTheme theme;
  if (kind == 'p') {
    if (index >= kBoardProviders.length) {
      fail(
          'p$index: в PROVIDERS доски только ${kBoardProviders.length} провайдеров');
    }
    theme = Ios27ProviderTheme.fromHeader(kBoardProviders[index].theme);
  } else {
    if (index >= kIos27AccentPresets.length) {
      fail(
          'a$index: в PRESETS доски только ${kIos27AccentPresets.length} цветов');
    }
    theme = _providerFor(ref).withOwn(accent: kIos27AccentPresets[index].light);
  }
  return {
    ...Ios27Tokens.palette(dark: dark).toVars(),
    ...theme.apply().toVars(dark: dark),
  };
}

void main() {
  final file = File(_refPath);
  if (!file.existsSync()) {
    test('G2: эталон test/ios27/ref/colors.json существует', () {
      fail(
        'Нет $_refPath: эталон снимает T1 (shoot-скрипт доски). G2 ждёт T1 и запускается после него. '
        'Тест намеренно падает, а не пропускается, чтобы отсутствие эталона не прошло за зелёное.',
      );
    });
    return;
  }

  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = <String, Map<String, int>>{
    for (final e in json.entries)
      e.key: {
        for (final v in (e.value as Map<String, dynamic>).entries)
          v.key: _parse('${e.key} ${v.key}', v.value as String),
      },
  };

  var exact = 0;
  var viaCanvas = 0;
  var viaMix = 0;
  final canvasNames = <String>{};

  group('G2: цвета колонки iOS', () {
    test('эталон не пуст и все ключи названы по схеме', () {
      expect(entries, isNotEmpty);
      final bad = entries.keys.where((k) => !_keyRe.hasMatch(k)).toList();
      expect(bad, isEmpty, reason: 'ключи вне схемы <сцена>-<тема>-p<N>|a<K>');
    });

    test('эталон покрывает p0..p5 и a0..a7 в обеих темах для каждой сцены', () {
      final scenes = <String>{
        for (final k in entries.keys)
          if (_keyRe.firstMatch(k) case final m?) m.group(1)!,
      };
      final missing = <String>[];
      for (final scene in scenes) {
        for (final theme in ['light', 'dark']) {
          for (var i = 0; i < kBoardProviders.length; i++) {
            if (!entries.containsKey('$scene-$theme-p$i')) {
              missing.add('$scene-$theme-p$i');
            }
          }
          for (var i = 0; i < kIos27AccentPresets.length; i++) {
            if (!entries.containsKey('$scene-$theme-a$i')) {
              missing.add('$scene-$theme-a$i');
            }
          }
        }
      }
      expect(missing, isEmpty, reason: 'в эталоне нет записей');
    });

    test('эталон содержит все токены, которые мы считаем, и ничего лишнего',
        () {
      final ours = <String>{
        ...Ios27Tokens.palette(dark: false).toVars().keys,
        ..._accentVars,
      };
      final unknown = <String>{};
      final absent = <String>{};
      for (final e in entries.entries) {
        unknown.addAll(e.value.keys.where((n) => !ours.contains(n)));
        absent.addAll(ours.where((n) => !e.value.containsKey(n)));
      }
      expect(unknown, isEmpty,
          reason: 'свойства эталона, которых нет в tokens.g.dart/accent.dart');
      expect(absent, isEmpty,
          reason: 'токены, которых нет в эталоне: сверить нечем');
    });

    for (final key in entries.keys) {
      final m = _keyRe.firstMatch(key);
      if (m == null) continue;
      test(key, () {
        final dark = m.group(2) == 'dark';
        final ref = entries[key]!;
        final want = _expected(
          dark: dark,
          kind: m.group(3)!,
          index: int.parse(m.group(4)!),
          ref: ref,
        );
        final problems = <String>[];
        for (final r in ref.entries) {
          final name = r.key;
          final exp = want[name];
          if (exp == null) {
            continue; // неизвестные свойства ловит отдельный тест выше
          }
          final got = r.value;
          if (got == exp) {
            exact++;
          } else if (_colorMix.contains(name) && _withinOne(got, exp)) {
            viaMix++;
          } else if ((exp >>> 24) != 0xFF && got == _canvasRoundTrip(exp)) {
            viaCanvas++;
            canvasNames.add(name);
          } else {
            problems.add('$name: эталон ${_fmt(got)}, Dart ${_fmt(exp)}');
          }
        }
        expect(problems, isEmpty, reason: key);
      });
    }

    tearDownAll(() {
      // ignore: avoid_print
      print(
        'G2: точных совпадений $exact, через потерю canvas $viaCanvas'
        '${canvasNames.isEmpty ? '' : ' (${(canvasNames.toList()..sort()).join(', ')})'}, '
        'в допуске ±1 для color-mix $viaMix. Свойств color-mix в корне: ${_colorMix.length}.',
      );
    });
  });
}
