// Масштаб текста iOS-редизайна: системный Dynamic Type в пределах 0.8–2.0 (владелец, решение Q2).
//
// Настройка «Размер текста» самого приложения на iOS-интерфейс не действует. `ThemeManager`
// подменяет `MediaQuery.textScaler` у корня приложения своим значением (зажим 0.8–1.4, у владельца
// сохранено 1.4), и всё, что читает `MediaQuery` ниже, видело бы 1.4 при любом размере шрифта в
// системе. Поэтому внутри iOS-поддерева масштаб берётся у платформы напрямую, мимо предка.
// Диапазон 0.8–2.0 — решение D8: ниже 0.8 текст нечитаем, выше 2.0 раскладка ломается даже на
// доске; Apple на самых крупных размерах доступности даёт больше, но этот предел владелец принял.

import 'dart:ui' show FlutterView;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Границы и подмена масштаба текста для iOS-интерфейса.
abstract final class Ios27SystemTextScale {
  /// Нижняя граница коэффициента.
  static const double min = 0.8;

  /// Верхняя граница коэффициента.
  static const double max = 2.0;

  /// Зажимает [scaler] в [min]..[max]. Нелинейные системные масштабировщики (iOS, Android 14)
  /// остаются нелинейными, зажимается только итог.
  static TextScaler clamp(TextScaler scaler) =>
      scaler.clamp(minScaleFactor: min, maxScaleFactor: max);

  static final ValueNotifier<double?> _override = ValueNotifier<double?>(null);

  /// Подмена системного коэффициента для тестов: `null` снимает подмену. Не для продакшен-кода.
  /// Через неё harness golden-тестов задаёт масштаб (`ios27BoardApp(textScale: …)`), потому что
  /// системное значение у теста общее с окружением, а кадр обязан от него не зависеть.
  @visibleForTesting
  static double? get debugOverride => _override.value;

  @visibleForTesting
  static set debugOverride(double? value) => _override.value = value;

  /// Возвращает исходное состояние: без подмены.
  @visibleForTesting
  static void debugReset() => _override.value = null;
}

/// Кладёт над [child] `MediaQuery` с системным масштабом текста, зажатым в 0.8–2.0.
///
/// Системное значение читается из `MediaQueryData.fromView` (платформа), а не из предка: предок
/// мог быть переписан `ThemeManager`. Остальные поля `MediaQuery` берутся у предка как есть.
/// Подписка на системные изменения собственная (`didChangeTextScaleFactor`): пользователь меняет
/// размер шрифта в настройках iOS при запущенном приложении, перезапуск не нужен.
///
/// Обёртка стоит всегда и не снимается при масштабе 1.0: иначе смена масштаба переставляла бы
/// элементы поддерева и сбрасывала их состояние.
///
/// Сама обёртка перестраивается при ЛЮБОМ изменении `MediaQuery` предка (клавиатура, поворот,
/// отступы): внутренний `MediaQuery` обязан повторять данные предка, меняя только масштаб, а
/// переопубликовать их можно лишь прочитав целиком. Дёшево это потому, что перестройка — один
/// `MediaQuery` с тем же `child` (тот же экземпляр виджета, поддерево не пересобирается), а
/// потомки зависят от `MediaQuery` по аспектам: читающие только `textScaler` не просыпаются от
/// клавиатуры и поворота (`MediaQuery.updateShouldNotifyDependent` сверяет аспекты по отдельности).
/// Собственное состояние обёртки (`setState`) меняется только при реальной смене масштаба.
class Ios27TextScaleScope extends StatefulWidget {
  const Ios27TextScaleScope({required this.child, super.key});

  final Widget child;

  @override
  State<Ios27TextScaleScope> createState() => _Ios27TextScaleScopeState();
}

class _Ios27TextScaleScopeState extends State<Ios27TextScaleScope>
    with WidgetsBindingObserver {
  // Задаётся в didChangeDependencies, который идёт сразу за initState и раньше любого build.
  late FlutterView _view;
  TextScaler _scaler = TextScaler.noScaling;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Ios27SystemTextScale._override.addListener(_onOverride);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    _scaler = _resolve();
  }

  @override
  void didChangeTextScaleFactor() => _refresh();

  @override
  void dispose() {
    Ios27SystemTextScale._override.removeListener(_onOverride);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  TextScaler _resolve() {
    final override = Ios27SystemTextScale.debugOverride;
    final raw = override != null
        ? TextScaler.linear(override)
        : MediaQueryData.fromView(_view).textScaler;
    return Ios27SystemTextScale.clamp(raw);
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    final next = _resolve();
    if (next != _scaler) {
      setState(() => _scaler = next);
    }
  }

  void _onOverride() {
    // Подмена может прийти посреди кадра (из сборки теста): setState тогда нельзя.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _refresh());
    } else {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.maybeOf(context) ?? MediaQueryData.fromView(_view);
    return MediaQuery(
      data: base.copyWith(textScaler: _scaler),
      child: widget.child,
    );
  }
}
