import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';

// Сверка порта с цветами, которые снял сам браузер (test/m3e/ref/colors.json,
// tool/canon/shoot_board.mjs): проба `color: var(--x)` -> canvas 1x1 -> hex.
// Роли схемы обязаны совпасть hex в hex; --dr-* допускают ±1 на канал из-за
// округления OKLab -> sRGB (допуски из плана, не расширять).

const _roleVarPrefix = '--md-sys-color-';

String _kebab(String s) =>
    s.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');

/// Максимальное расхождение по каналам между двумя `#rrggbb`.
int _maxChannelDiff(String a, String b) {
  final x = argbFromHexOrNull(a)!;
  final y = argbFromHexOrNull(b)!;
  var d = 0;
  for (final shift in [16, 8, 0]) {
    final diff = (((x >> shift) & 0xFF) - ((y >> shift) & 0xFF)).abs();
    if (diff > d) d = diff;
  }
  return d;
}

void main() {
  final ref = jsonDecode(File('test/m3e/ref/colors.json').readAsStringSync())
      as Map<String, dynamic>;

  test('цвета браузера: роли hex в hex, --dr-* в пределах ±1', () {
    var rolesChecked = 0;
    var drChecked = 0;
    var drExact = 0;
    final drOffByOne = <String>[];
    final failures = <String>[];

    final expectedDr = {for (final k in DropwebHomeColors.keys) '--dr-$k'};
    final expectedRoles = {
      for (final r in m3eRoleNames) '$_roleVarPrefix${_kebab(r)}'
    };

    for (final entry in ref.entries) {
      final key = entry.key;
      final vars = (entry.value as Map<String, dynamic>).cast<String, String>();
      final m = RegExp(r'^home-(off|on)-(light|dark)-p(\d)$').firstMatch(key);
      if (m == null) {
        failures.add('$key | неожиданный ключ сцены');
        continue;
      }
      final dark = m[2] == 'dark';
      final parts = kBoardProviders[int.parse(m[3]!)]
          .theme
          .split(',')
          .map((e) => e.trim())
          .toList();
      final filter = parts[0];
      final seed = parts[1].toUpperCase();

      final gotDr = vars.keys.where((k) => k.startsWith('--dr-')).toSet();
      final gotRoles =
          vars.keys.where((k) => k.startsWith(_roleVarPrefix)).toSet();
      final lostDr = gotDr.difference(expectedDr);
      final missDr = expectedDr.difference(gotDr);
      final lostRoles = gotRoles.difference(expectedRoles);
      final missRoles = expectedRoles.difference(gotRoles);
      if (lostDr.isNotEmpty ||
          missDr.isNotEmpty ||
          lostRoles.isNotEmpty ||
          missRoles.isNotEmpty) {
        failures.add(
          '$key | наборы переменных не совпали: --dr-* лишние в браузере $lostDr, '
          'нет в браузере $missDr; роли лишние в браузере $lostRoles, нет в браузере $missRoles',
        );
        continue;
      }

      final s = scheme(seed, filter, dark: dark);
      for (final r in m3eRoleNames) {
        final name = '$_roleVarPrefix${_kebab(r)}';
        rolesChecked++;
        if (vars[name]!.toLowerCase() != s.hex(r)) {
          failures
              .add('$key | $name | браузер ${vars[name]}, порт ${s.hex(r)}');
        }
      }

      final h = homeVars(seed, filter, dark: dark);
      for (final k in DropwebHomeColors.keys) {
        final name = '--dr-$k';
        final exp = vars[name]!;
        final got = h.hex(k);
        drChecked++;
        final diff = _maxChannelDiff(exp, got);
        if (diff == 0) {
          drExact++;
        } else if (diff == 1) {
          drOffByOne.add('$key $name: браузер $exp, порт $got');
        } else {
          failures
              .add('$key | $name | браузер $exp, порт $got (разница $diff)');
        }
      }
    }

    // home-off и home-on в браузере должны давать одни и те же цвета: иначе часть --dr-*
    // зависит от состояния, и порт без состояния не может быть эталонным.
    for (final theme in ['light', 'dark']) {
      for (var p = 0; p < 6; p++) {
        final off = (ref['home-off-$theme-p$p'] as Map<String, dynamic>)
            .cast<String, String>();
        final on = (ref['home-on-$theme-p$p'] as Map<String, dynamic>)
            .cast<String, String>();
        for (final k in off.keys) {
          if (off[k]!.toLowerCase() != on[k]?.toLowerCase()) {
            failures.add(
                'home-off/on-$theme-p$p | $k | off ${off[k]}, on ${on[k]}');
          }
        }
      }
    }

    // ignore: avoid_print
    print(
      'Сверено с браузером: ролей $rolesChecked (hex в hex), --dr-* $drChecked '
      '(hex в hex $drExact, ±1: ${drOffByOne.length}, расхождений: ${failures.length})',
    );
    // ignore: avoid_print
    for (final l in drOffByOne) {
      // ignore: avoid_print
      print('  ±1  $l');
    }

    expect(failures, isEmpty,
        reason: '${failures.length} расхождений:\n${failures.join('\n')}');
  });
}
