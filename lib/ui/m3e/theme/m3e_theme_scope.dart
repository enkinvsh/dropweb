import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../color/color.dart';
import 'm3e_theme.dart';
import 'm3e_theme_source.dart';

/// Схема и цвета главной для потомков; [M3eThemeScope] кладёт их рядом с `Theme`.
class M3eColors extends InheritedWidget {
  const M3eColors({
    super.key,
    required this.scheme,
    required this.home,
    required this.brightness,
    required super.child,
  });

  final M3eScheme scheme;

  /// Цвета `--dr-*` главной (фон, карточка, чернила, кольца, заливка).
  final DropwebHomeColors home;
  final Brightness brightness;

  static M3eColors of(BuildContext context) {
    final colors = context.dependOnInheritedWidgetOfExactType<M3eColors>();
    assert(colors != null, 'Нет M3eThemeScope выше по дереву');
    return colors!;
  }

  @override
  bool updateShouldNotify(M3eColors old) =>
      !identical(scheme, old.scheme) ||
      !identical(home, old.home) ||
      brightness != old.brightness;
}

/// Тема новых экранов: светлая или тёмная по системе, цвет от провайдера подписки.
///
/// Яркость берётся из `MediaQuery.platformBrightnessOf`, а не из платформы, чтобы
/// golden-тесты на macOS управлялись тем же путём, что и устройство.
class M3eThemeScope extends StatelessWidget {
  /// Рабочий вариант: seed и filter из [m3eThemeSourceProvider].
  const M3eThemeScope({super.key, required this.child})
      : _seed = null,
        _filter = null,
        _brightness = null;

  /// Явные значения без чтения провайдеров (тесты, предпросмотр).
  const M3eThemeScope.explicit({
    super.key,
    required String seed,
    required String filter,
    Brightness? brightness,
    required this.child,
  })  : _seed = seed,
        _filter = filter,
        _brightness = brightness;

  final Widget child;
  final String? _seed;
  final String? _filter;
  final Brightness? _brightness;

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? MediaQuery.platformBrightnessOf(context);
    if (_seed != null) {
      return _Scope(
        source: M3eThemeSource(seed: _seed, filter: _filter!),
        brightness: brightness,
        child: child,
      );
    }
    return Consumer(
      builder: (context, ref, _) => _Scope(
        source: ref.watch(m3eThemeSourceProvider),
        brightness: brightness,
        child: child,
      ),
    );
  }
}

class _Scope extends StatelessWidget {
  const _Scope({
    required this.source,
    required this.brightness,
    required this.child,
  });

  final M3eThemeSource source;
  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final s = scheme(source.seed, source.filter, dark: dark);
    final home = homeVars(source.seed, source.filter, dark: dark);
    return M3eColors(
      scheme: s,
      home: home,
      brightness: brightness,
      child: Theme(
        data: m3eThemeData(s, brightness: brightness),
        child: child,
      ),
    );
  }
}
