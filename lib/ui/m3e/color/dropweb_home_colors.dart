// Цвета главной поверх ролей схемы: перенос `homeVars()` и предупреждений из `schemeVars()`
// android.js доски (строки 92-148). Логика и числа те же, комментарии доски -- про выбор владельца.

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'hex.dart';
import 'm3e_scheme.dart';
import 'mcu/tonal_palette.dart';
import 'oklab_mix.dart';

/// Все `--dr-*` главной и тройка предупреждений.
class DropwebHomeColors {
  const DropwebHomeColors._(this._argb);

  final Map<String, int> _argb;

  /// Имена полей как в CSS-переменных доски без префикса `--dr-`.
  static const List<String> keys = [
    'bg',
    'card',
    'ink',
    'ink2',
    'line',
    'ok',
    'dot-off',
    'sh-a',
    'sh-b',
    'sh-c',
    'flood',
    'on-flood',
    'lv-a',
    'lv-b',
    'lv-c',
    'hero-on',
    'on-hero-on',
    'warn',
    'warn-container',
    'on-warn-container',
  ];

  Color operator [](String key) => Color(_argb[key]!);

  /// Hex в нижнем регистре для сверки с эталоном.
  String hex(String key) => hexFromArgb(_argb[key]!);

  /// Фон главной: почти нейтральный, оттенок провайдера.
  Color get bg => this['bg'];

  /// Карточка и боковые кнопки (secondary-container).
  Color get card => this['card'];
  Color get ink => this['ink'];

  /// Второстепенный текст карточки.
  Color get ink2 => this['ink2'];

  /// Черта на карточке.
  Color get line => this['line'];

  /// Точка «подключено» -- зелёная при любом провайдере.
  Color get ok => this['ok'];

  /// Точка «не подключено» -- серая без оттенка провайдера.
  Color get dotOff => this['dot-off'];

  /// Кольца вокруг кнопки без подключения, от дальнего к ближнему.
  Color get shA => this['sh-a'];
  Color get shB => this['sh-b'];
  Color get shC => this['sh-c'];

  /// Заливка экрана при подключении.
  Color get flood => this['flood'];

  /// Кольца при подключении.
  Color get lvA => this['lv-a'];
  Color get lvB => this['lv-b'];
  Color get lvC => this['lv-c'];

  /// Кнопка подключения во включённом состоянии и знак на ней.
  Color get heroOn => this['hero-on'];
  Color get onHeroOn => this['on-hero-on'];

  Color get warn => this['warn'];
}

// Своя тональная палитра янтарного: в M3 нет роли warning, тоны как у error.
final McuTonalPalette _warn =
    McuTonalPalette.fromInt(argbFromHexOrNull('#F59E0B')!);
// Зелёная точка «подключено» не зависит от провайдера: у красного seed «зелёный = включено» не должен краснеть.
final McuTonalPalette _ok =
    McuTonalPalette.fromInt(argbFromHexOrNull('#22C55E')!);

final Map<String, DropwebHomeColors> _cache = {};

/// Цвета главной для [seedHex] и [filter]. Запоминается по `seed|filter|dark`.
DropwebHomeColors homeVars(String seedHex, String filter,
        {required bool dark}) =>
    _cache.putIfAbsent('$seedHex|$filter|$dark', () {
      final s = scheme(seedHex, filter, dark: dark);
      final hct = m3eSeedHct(seedHex);
      final n = McuTonalPalette.fromHueAndChroma(hct.hue, 4);
      // Тёмная заливка: тон 14 палитры провайдера, насыщенность не ниже 24 --
      // у серого seed иначе выходил чёрный экран без цвета.
      final p =
          McuTonalPalette.fromHueAndChroma(hct.hue, math.max(24, hct.chroma));
      final g = McuTonalPalette.fromHueAndChroma(hct.hue, 0);
      final c = McuTonalPalette.fromHueAndChroma(
        hct.hue,
        math.min(24, math.max(8, hct.chroma / 2)),
      );
      int argb(String role) => s.role(role).toARGB32();
      int mix(int a, int b, int k) => oklabMixArgb(a, b, k);

      final sc = argb('secondaryContainer');
      final onSc = argb('onSecondaryContainer');
      final pc = argb('primaryContainer');
      final onPc = argb('onPrimaryContainer');
      final p14 = p.tone(14);

      final out = <String, int>{
        'bg': n.tone(dark ? 6 : 97),
        'card': sc,
        'ink': onSc,
        // Второстепенный текст разбавлен всего на 12 %: при 16 % подписи 13 px
        // падали ниже контраста 4.5:1.
        'ink2': mix(onSc, sc, 12),
        'line': mix(sc, onSc, 16),
        'ok': _ok.tone(dark ? 76 : 48),
        'dot-off': g.tone(dark ? 56 : 62),
        'sh-a': c.tone(dark ? 10 : 94),
        'sh-b': c.tone(dark ? 14 : 88),
        'sh-c': c.tone(dark ? 19 : 82),
        if (dark) ...{
          'flood': p14,
          'on-flood': p.tone(90),
          'lv-a': mix(pc, p14, 80),
          'lv-b': mix(pc, p14, 66),
          'lv-c': mix(pc, p14, 52),
          'hero-on': pc,
          'on-hero-on': onPc,
        } else ...{
          'flood': pc,
          'on-flood': onPc,
          'lv-a': mix(pc, 0xFFFFFFFF, 22),
          'lv-b': mix(pc, onPc, 9),
          'lv-c': mix(pc, onPc, 20),
          'hero-on': onPc,
          'on-hero-on': pc,
        },
        'warn': _warn.tone(dark ? 80 : 40),
        'warn-container': _warn.tone(dark ? 30 : 90),
        'on-warn-container': _warn.tone(dark ? 90 : 10),
      };
      return DropwebHomeColors._(out);
    });
