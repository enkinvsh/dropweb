// Генератор ресурсов виджета рабочего стола из той же геометрии, что у кнопки подключения.
// Запуск из корня репозитория (нужен dart:ui, поэтому через flutter test):
//   fvm flutter test tool/canon/gen_widget_assets.dart
//
// Пишет:
//   android/app/src/main/res/drawable/widget_shape_{circle,cookie9,softburst}.xml
//   android/app/src/main/res/drawable/widget_ic_power.xml, widget_ic_connecting.xml
//   android/app/src/main/res/values{,-night}/widget_colors.xml  (цвета превью)
//   android/app/src/main/kotlin/app/dropweb/widgets/WidgetStyleDefaults.kt
//   .omo/m3e-android/widget/gen.json  (кубики и цвета для листа сравнения)
//
// Детерминирован: тот же вход даёт те же байты. Руками сгенерированное не правим.
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widget/m3e_widget_payload.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_shape.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

const _res = 'android/app/src/main/res';
const _kt = 'android/app/src/main/kotlin/app/dropweb/widgets';
const _hdr = 'СГЕНЕРИРОВАНО tool/canon/gen_widget_assets.dart, руками не править.';

/// Доля кнопки, занятая индикатором connecting и знаком: `kM3eHeroIndicator` и
/// `_iconSize / 88` из `m3e_hero_button.dart`.
const _indicator = 0.56;
const _glyph = 36 / 88;

String _n(double v) {
  final s = (v * 100).toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Путь `M x,y C … Z` в координатах viewport 100.
String _path(M3eCubics cubics) {
  final b = StringBuffer('M${_n(cubics.first[0])},${_n(cubics.first[1])}');
  for (final c in cubics) {
    b.write(' C${_n(c[2])},${_n(c[3])} ${_n(c[4])},${_n(c[5])} '
        '${_n(c[6])},${_n(c[7])}');
  }
  b.write(' Z');
  return b.toString();
}

String _vector({
  required String dp,
  required String body,
  String viewport = '100',
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<!-- $_hdr -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${dp}dp"
    android:height="${dp}dp"
    android:viewportWidth="$viewport"
    android:viewportHeight="$viewport">
$body</vector>
''';

String _fill(String path, {String indent = '    '}) =>
    '$indent<path\n$indent    android:fillColor="#FFFFFFFF"\n'
    '$indent    android:pathData="$path" />\n';

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

String _kotlinColor(String hex) => '0xFF${hex.substring(1).toUpperCase()}';

String _kotlinColors(String name, Map<String, String> c) {
  final fields = [
    for (final k in ['bg', 'title', 'sub', 'offBg', 'offFg', 'onBg', 'onFg'])
      '        $k = ${_kotlinColor(c[k]!)}.toInt(),',
  ].join('\n');
  return '    val $name = WidgetColors(\n$fields\n    )\n';
}

String _xmlColors(Map<String, String> c) => [
      for (final k in ['bg', 'title', 'sub', 'offBg', 'offFg', 'onBg', 'onFg'])
        '    <color name="widget_preview_$k">${c[k]!.toUpperCase()}</color>',
    ].join('\n');

void main() {
  test('генерирует ресурсы виджета', () {
    final circle = m3ePlacedShape(MaterialShapes.circle);
    final cookie = m3ePlacedShape(MaterialShapes.cookie9Sided);
    final burst = m3ePlacedShape(MaterialShapes.softBurst);
    final burstSmall = m3ePlace(m3eRawCubics(MaterialShapes.softBurst),
        scale: _indicator);

    // Формы с внутренним размером 48 dp: ImageView с adjustViewBounds берёт из него
    // пропорцию 1:1, а размер задаёт верстка.
    for (final (name, cubics) in [
      ('circle', circle),
      ('cookie9', cookie),
      ('softburst', burst),
    ]) {
      _write('$_res/drawable/widget_shape_$name.xml',
          _vector(dp: '48', body: _fill(_path(cubics))));
    }

    // Знаки лежат поверх формы и растягиваются по ней (fitXY), поэтому внутренний
    // размер 1 dp: он не раздувает кнопку с wrap_content. Знак `power_settings_new`
    // одинаков в контурном и залитом виде (в символах obtained o == f).
    final power = kM3eSymbolPaths[M3eSymbol.powerSettingsNew]!;
    expect(power.o, power.f, reason: 'теперь знак различается: нужен второй drawable');
    const k = _glyph / 960 * 100;
    const tx = 50 - 480 * k, ty = 50 + 480 * k;
    _write(
      '$_res/drawable/widget_ic_power.xml',
      _vector(
        dp: '1',
        body: '    <group\n'
            '        android:scaleX="${k.toStringAsFixed(6)}"\n'
            '        android:scaleY="${k.toStringAsFixed(6)}"\n'
            '        android:translateX="${tx.toStringAsFixed(4)}"\n'
            '        android:translateY="${ty.toStringAsFixed(4)}">\n'
            '${_fill(power.o, indent: '        ')}'
            '    </group>\n',
      ),
    );
    _write('$_res/drawable/widget_ic_connecting.xml',
        _vector(dp: '1', body: _fill(_path(burstSmall))));

    const source =
        M3eThemeSource(seed: m3eDefaultSeed, filter: m3eOwnColorFilter);
    final light = m3eWidgetColors(source, dark: false);
    final dark = m3eWidgetColors(source, dark: true);

    for (final (dir, c) in [('values', light), ('values-night', dark)]) {
      _write('$_res/$dir/widget_colors.xml', '''<?xml version="1.0" encoding="utf-8"?>
<!-- $_hdr Цвета превью виджета: «Голубой», схема fidelity. -->
<resources>
${_xmlColors(c)}
</resources>
''');
    }

    _write('$_kt/WidgetStyleDefaults.kt', '''package app.dropweb.widgets

// $_hdr
/**
 * Цвета до первого пуша из приложения: схема «Голубой» (seed $m3eDefaultSeed, фильтр
 * $m3eOwnColorFilter) из Dart-порта `scheme()`/`homeVars()`. Берутся те же роли, что у
 * кнопки подключения на главной (`m3eWidgetColors`).
 */
object WidgetStyleDefaults {
${_kotlinColors('light', light)}
${_kotlinColors('dark', dark)}}
''');

    const alt = M3eThemeSource(seed: '#A78BFA', filter: 'fidelity');
    _write(
      '.omo/m3e-android/widget/gen.json',
      '${const JsonEncoder.withIndent(' ').convert({
        'shapes': {
          'circle': circle,
          'cookie9': cookie,
          'softburst': burst,
          'indicator': burstSmall,
        },
        'glyph': {'path': power.o, 'size': _glyph},
        'providers': {
          'default': {
            'light': light,
            'dark': dark,
          },
          'violet': {
            'light': m3eWidgetColors(alt, dark: false),
            'dark': m3eWidgetColors(alt, dark: true),
          },
        },
      })}\n',
    );
  });
}
