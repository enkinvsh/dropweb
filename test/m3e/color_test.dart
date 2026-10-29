import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:flutter_test/flutter_test.dart';

// Сверка порта цвета с эталоном, который дампит tool/canon/dump_schemes.mjs из кода самой
// доски (mcu.js + android.js, color-mix разрешён Chromium). Допуск нулевой: сравниваются
// строки hex целиком, регистр не важен.

void main() {
  final cases =
      (jsonDecode(File('test/m3e/fixtures/schemes.json').readAsStringSync())
          as Map<String, dynamic>)['cases'] as List<dynamic>;

  var compared = 0;
  final failures = <String>[];

  void check(String id, String what, String expected, String actual) {
    compared++;
    if (expected.toLowerCase() != actual.toLowerCase()) {
      failures.add('$id | $what | ожидали $expected, получили $actual');
    }
  }

  test('роли, иконка и главная совпадают с доской hex в hex', () {
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final id = c['id'] as String;
      final seed = c['seed'] as String;
      final filter = c['filter'] as String;
      final dark = c['dark'] as bool;

      final s = scheme(seed, filter, dark: dark);
      final roles = c['roles'] as Map<String, dynamic>;
      expect(roles.keys.toSet(), m3eRoleNames.toSet(),
          reason: '$id: набор ролей');
      for (final r in m3eRoleNames) {
        check(id, 'role $r', roles[r] as String, s.hex(r));
      }

      final icon = c['icon'] as Map<String, dynamic>;
      check(id, 'icon.fg', icon['fg'] as String,
          hexFromArgb(s.icon.fg.toARGB32()));
      check(id, 'icon.bg', icon['bg'] as String,
          hexFromArgb(s.icon.bg.toARGB32()));

      final home = c['home'] as Map<String, dynamic>?;
      if (home != null) {
        expect(home.keys.toSet(), DropwebHomeColors.keys.toSet(),
            reason: '$id: набор --dr-*');
        final h = homeVars(seed, filter, dark: dark);
        for (final k in DropwebHomeColors.keys) {
          final e = home[k] as Map<String, dynamic>;
          final expr = e['expr'] as String?;
          check(id, '--dr-$k${expr == null ? '' : ' [$expr]'}',
              e['hex'] as String, h.hex(k));
        }
      }
    }

    // ignore: avoid_print
    print('Сверено значений: $compared, кейсов: ${cases.length}');
    expect(failures, isEmpty,
        reason: '${failures.length} расхождений:\n${failures.join('\n')}');
  });

  test('разбор заголовка dropweb-theme как parseTheme доски', () {
    final t = parseDropwebTheme('fidelity,#a78bfa,,zzz,9');
    expect(t.filter, 'fidelity');
    expect(t.accent, '#A78BFA');
    expect(t.orb1, '#A78BFA');
    expect(t.orb2, '#A78BFA');
    expect(t.blur, 5);
    final bad = parseDropwebTheme('');
    expect(bad.accent, m3eFallbackSeed);
    expect(bad.blur, 3);
  });

  test('неверный seed даёт ту же схему, что запасной #29FF76', () {
    expect(
      scheme('не цвет', 'fidelity', dark: true).hex('primary'),
      scheme('#29FF76', 'fidelity', dark: true).hex('primary'),
    );
  });
}
