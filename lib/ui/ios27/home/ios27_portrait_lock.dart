// Книжная ориентация на время, пока на экране iOS-главная (и всё, что открыто поверх неё).
//
// Info.plist разрешает iPhone альбомную ориентацию, а главная под неё не рисовалась: нижний ряд
// при высоте 375 dp ложится на карточку. Менять Info.plist нельзя (общий для магазинных сборок),
// поэтому замок ставится из Dart и снимается, когда главная уходит из дерева.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Держит `portraitUp` на iOS, пока в дереве есть хотя бы один такой виджет.
///
/// Счётчик, а не пара «поставил/снял» в каждом экземпляре: при смене главной на пустую главную
/// (и обратно) новый виджет получает `initState` раньше, чем старый — `dispose`, и без счётчика
/// старый снял бы замок, только что поставленный новым.
class Ios27PortraitLock extends StatefulWidget {
  const Ios27PortraitLock({super.key, required this.child});

  final Widget child;

  /// Сколько экземпляров сейчас держат замок. Для теста.
  @visibleForTesting
  static int get holders => _Ios27PortraitLockState._holders;

  /// Сброс счётчика между тестами: виджеты прошлого теста могли не дожить до `dispose`.
  @visibleForTesting
  static void debugReset() => _Ios27PortraitLockState._holders = 0;

  @override
  State<Ios27PortraitLock> createState() => _Ios27PortraitLockState();
}

class _Ios27PortraitLockState extends State<Ios27PortraitLock> {
  static int _holders = 0;

  /// Только iPhone-приложение: Android, рабочий стол и веб замка не получают.
  bool get _enabled => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _holders++;
    if (_holders == 1) {
      _apply(const [DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    if (_enabled) {
      _holders--;
      if (_holders <= 0) {
        _holders = 0;
        // Пустой список возвращает ориентации по умолчанию из Info.plist.
        _apply(const []);
      }
    }
    super.dispose();
  }

  // Ошибка канала не должна ронять экран: ориентация — удобство, не функция.
  void _apply(List<DeviceOrientation> orientations) {
    unawaited(
      SystemChrome.setPreferredOrientations(orientations).catchError(
        (Object e) => debugPrint('[ios27] ориентация не применена: $e'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
