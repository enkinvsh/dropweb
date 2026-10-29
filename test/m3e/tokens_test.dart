import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';

// Сверка сгенерированных токенов с тем же tokens.json, из которого их строил
// gen_tokens.py. Если файла нет (CI без canon), тест пропускается.
const _tokensPath =
    '/Users/mac/Documents/projects/canon/material-3-expressive/sources/code/tokens.json';

void main() {
  final file = File(_tokensPath);
  final skip = file.existsSync() ? null : 'нет $_tokensPath';
  late Map<String, dynamic> json;
  if (skip == null) {
    json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('tokens.g.dart против tokens.json', () {
    test('типошкала: bodyMedium, displayLarge, labelLargeEmphasized', () {
      final roles = json['typescale']['roles'] as Map<String, dynamic>;
      void check(String name, M3eTypeStyle s) {
        final r = roles[name] as Map<String, dynamic>;
        expect(s.size, (r['size_sp'] as num).toDouble(), reason: name);
        expect(s.lineHeight, (r['line_height_sp'] as num).toDouble(),
            reason: name);
        expect(s.tracking, (r['tracking_sp'] as num).toDouble(), reason: name);
        expect(s.weight, r['weight'], reason: name);
        expect(s.brand, r['font_token'] == 'Brand', reason: name);
      }

      check('bodyMedium', M3eType.bodyMedium);
      check('displayLarge', M3eType.displayLarge);
      check('labelLargeEmphasized', M3eType.labelLargeEmphasized);
      expect(M3eType.bodyMedium.size, 14);
      expect(M3eType.bodyMedium.lineHeight, 20);
      expect(M3eType.bodyMedium.tracking, 0.2);
      expect(M3eType.labelLargeEmphasized.weight, 700);
      expect(M3eType.bodyMedium.height, closeTo(20 / 14, 1e-9));
    });

    test('все 30 ролей типошкалы есть в JSON', () {
      final roles = json['typescale']['roles'] as Map<String, dynamic>;
      expect(roles.length, 30);
      expect(M3eType.titleLargeEmphasized.size, 22);
    });

    test('углы', () {
      final cs = json['shape']['corner_scale'] as Map<String, dynamic>;
      expect(M3eShape.extraSmall, cs['extra-small']['dp']);
      expect(M3eShape.large, cs['large']['dp']);
      expect(M3eShape.extraLarge, cs['extra-large']['dp']);
      expect(M3eShape.extraExtraLarge, cs['extra-extra-large']['dp']);
      expect(M3eShape.none, 0);
      expect(M3eShape.full, greaterThan(1000));
      final top = json['shape']['asymmetric']['large-end']['corners_dp'];
      expect(M3eShapeAsymmetric.largeEnd.topRight, top['tr']);
      expect(M3eShapeAsymmetric.largeEnd.topLeft, top['tl']);
    });

    test('высота и состояния', () {
      final lv = json['elevation']['levels'] as Map<String, dynamic>;
      expect(M3eElevation.level3, lv['level3']['dp']);
      expect(M3eElevation.level5, lv['level5']['dp']);
      final st = json['state']['layer_opacity'] as Map<String, dynamic>;
      expect(M3eState.hover, st['hover']['opacity']);
      expect(M3eState.pressed, st['pressed']['opacity']);
      expect(M3eState.dragged, st['dragged']['opacity']);
      expect(M3eState.disabledContent, json['state']['disabled_alpha_default']);
    });

    test('пружины expressive и standard', () {
      final ex = json['motion']['springs']['expressive'];
      expect(M3eSpring.fastSpatial.damping, ex['fast_spatial']['damping']);
      expect(M3eSpring.fastSpatial.stiffness, ex['fast_spatial']['stiffness']);
      expect(M3eSpring.defaultSpatial.damping, 0.8);
      expect(M3eSpring.defaultSpatial.stiffness, 380);
      expect(M3eSpring.slowEffects.stiffness, ex['slow_effects']['stiffness']);
      final sd = json['motion']['springs']['standard'];
      expect(M3eSpringStandard.slowSpatial.stiffness,
          sd['slow_spatial']['stiffness']);
    });

    test('SpringDescription: масса 1, демпфирование = ratio * 2 * sqrt(k)', () {
      final d = M3eSpring.fastSpatial.description;
      expect(d.mass, 1);
      expect(d.stiffness, 800);
      expect(d.damping, closeTo(0.6 * 2 * math.sqrt(800), 1e-9));
    });

    test('кривые и длительности', () {
      final eas = json['motion']['legacy']['easing'] as Map<String, dynamic>;
      final e = (eas['emphasized-decelerate']['cubic_bezier'] as List)
          .map((x) => (x as num).toDouble())
          .toList();
      expect([
        M3eEasing.emphasizedDecelerate.a,
        M3eEasing.emphasizedDecelerate.b,
        M3eEasing.emphasizedDecelerate.c,
        M3eEasing.emphasizedDecelerate.d,
      ], e);
      expect(M3eEasing.emphasizedAccelerate.a, 0.3);
      final du = json['motion']['legacy']['durations_ms'];
      expect(M3eDuration.short4.inMilliseconds, du['short4']['ms']);
      expect(M3eDuration.medium4.inMilliseconds, 400);
      expect(M3eDuration.extraLong4.inMilliseconds, 1000);
    });
  }, skip: skip);
}
