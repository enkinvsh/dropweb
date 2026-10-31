import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Снимок настроек доступности для виджетов iOS-редизайна.
///
/// Reduce Motion, Increase Contrast и Bold Text Flutter отдаёт сам через
/// `MediaQuery`; Reduce Transparency его нет, он приходит каналом
/// `dropweb/accessibility` (см. `ios/Runner/Glass/DropwebAccessibility.swift`).
@immutable
class Ios27A11yData {
  const Ios27A11yData({
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.highContrast = false,
    this.boldText = false,
  });

  /// Reduce Transparency: стекло заменяется непрозрачной Dart-заглушкой.
  final bool reduceTransparency;

  /// Reduce Motion (`MediaQuery.disableAnimations`): движение заменяется
  /// короткой сменой прозрачности.
  final bool reduceMotion;

  /// Increase Contrast (`MediaQuery.highContrast`).
  final bool highContrast;

  /// Bold Text (`MediaQuery.boldText`).
  final bool boldText;

  @override
  bool operator ==(Object other) =>
      other is Ios27A11yData &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceMotion == reduceMotion &&
      other.highContrast == highContrast &&
      other.boldText == boldText;

  @override
  int get hashCode =>
      Object.hash(reduceTransparency, reduceMotion, highContrast, boldText);

  @override
  String toString() => 'Ios27A11yData(reduceTransparency: $reduceTransparency, '
      'reduceMotion: $reduceMotion, highContrast: $highContrast, '
      'boldText: $boldText)';
}

/// Настройки доступности iOS для новых экранов.
///
/// Reduce Transparency живёт в одном глобальном источнике, а не в скоупе:
/// диалоги и тосты строятся из корневого контекста выше любой темы, и скоуп
/// туда не дотянулся бы. Слушать значение — [reduceTransparencyListenable]
/// или [Ios27A11yBuilder]. Остальные настройки читаются из `MediaQuery`
/// (`disableAnimationsOf`, `highContrastOf`, `boldTextOf`), они сами подписывают
/// виджет на нужный аспект.
///
/// На не-iOS и в тестах канала нет: значение остаётся `false`, ничего не
/// бросается. Тесты подменяют значение через [debugOverride].
abstract final class Ios27A11y {
  /// Канал с нативной стороной (`DropwebAccessibilityPlugin`).
  static const String channelName = 'dropweb/accessibility';

  static const MethodChannel _channel = MethodChannel(channelName);

  // Значение с платформы и итоговое (с подменой для тестов) разделены, чтобы
  // сброс подмены возвращал настоящее значение без повторного чтения канала.
  static final ValueNotifier<bool> _platform = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _effective = ValueNotifier<bool>(false);
  static bool? _override;
  static bool _started = false;

  // Повтор чтения после неудачи. Первый запрос уходит на старте, когда канал нативной стороны
  // может быть ещё не готов (MissingPluginException/PlatformException). Без повтора режим навсегда
  // остался бы «выключен», а нативная сторона присылает только изменения и значение, не
  // изменившееся с запуска, не пришлёт никогда. Попыток немного и опроса по таймеру нет: по одной
  // после ближайшего кадра и на каждом возврате из фона, всего не больше [_maxRetries].
  static const int _maxRetries = 3;
  static int _retriesLeft = _maxRetries;
  static bool _loaded = false;
  static bool _reading = false;
  static bool _frameRetryScheduled = false;
  static _ResumeObserver? _observer;

  // Поколение сбрасывается в debugReset: отложенный повтор и ответ канала от прошлого теста
  // не должны менять состояние следующего.
  static int _epoch = 0;

  /// Итоговое значение Reduce Transparency; запускает чтение канала на iOS.
  static bool get reduceTransparency {
    start();
    return _effective.value;
  }

  /// То же значение как источник для подписки.
  static ValueListenable<bool> get reduceTransparencyListenable {
    start();
    return _effective;
  }

  /// Подмена для тестов: `true`/`false` перекрывают платформу, `null` снимает
  /// подмену. Не для продакшен-кода.
  @visibleForTesting
  static bool? get debugOverride => _override;

  @visibleForTesting
  static set debugOverride(bool? value) {
    _override = value;
    _sync();
  }

  /// Начинает слушать канал; безопасно звать много раз. Звать из инициализации
  /// приложения: без этого первый кадр при включённом Reduce Transparency может
  /// мигнуть нативным стеклом до ответа канала.
  static void start() {
    if (_started || kIsWeb || !Platform.isIOS) {
      return;
    }
    _started = true;
    unawaited(_attach());
  }

  /// Подключает канал независимо от платформы: для теста канала с подменённым
  /// обработчиком.
  @visibleForTesting
  static Future<void> debugAttach() {
    _started = true;
    return _attach();
  }

  /// Возвращает состояние к исходному: без подписки, без подмены, `false`.
  @visibleForTesting
  static void debugReset() {
    _channel.setMethodCallHandler(null);
    _epoch++;
    _stopRetrying();
    _retriesLeft = _maxRetries;
    _loaded = false;
    _reading = false;
    _frameRetryScheduled = false;
    _started = false;
    _override = null;
    _platform.value = false;
    _sync();
  }

  /// Сколько повторов чтения ещё доступно (для тестов).
  @visibleForTesting
  static int get debugRetriesLeft => _retriesLeft;

  static Future<void> _attach() async {
    // Обработчик ставится до чтения: событие, пришедшее между ними, не теряется.
    _channel.setMethodCallHandler(_onCall);
    await _read();
  }

  static Future<void> _read() async {
    if (_reading) {
      return;
    }
    _reading = true;
    final epoch = _epoch;
    try {
      final value = await _channel.invokeMethod<bool>('reduceTransparency');
      if (epoch != _epoch) {
        return;
      }
      _platform.value = value ?? false;
      _sync();
      _markLoaded();
    } on MissingPluginException {
      // Нативной части нет (старая сборка, иная платформа) либо канал ещё не поднят.
      _scheduleRetry(epoch);
    } on PlatformException catch (e) {
      debugPrint('Ios27A11y: не удалось прочитать reduceTransparency: $e');
      _scheduleRetry(epoch);
    } finally {
      if (epoch == _epoch) {
        _reading = false;
      }
    }
  }

  /// Значение известно (ответ канала или событие): повторы больше не нужны.
  static void _markLoaded() {
    _loaded = true;
    _stopRetrying();
  }

  static void _scheduleRetry(int epoch) {
    if (epoch != _epoch || _loaded) {
      return;
    }
    if (_retriesLeft <= 0) {
      _stopRetrying();
      return;
    }
    _observer ??= _ResumeObserver()..attach();
    if (!_frameRetryScheduled) {
      _frameRetryScheduled = true;
      // После ближайшего кадра: к этому моменту движок и каналы обычно уже подняты. Обратный
      // вызов после кадра сам кадр не заказывает, а в простое (сбой пришёл позже первого кадра)
      // его пришлось бы ждать до первого касания, поэтому один кадр заказываем сами.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          if (epoch == _epoch) {
            _retry();
          }
        })
        ..ensureVisualUpdate();
    }
  }

  static void _retry() {
    if (_loaded || _reading || _retriesLeft <= 0) {
      return;
    }
    _retriesLeft--;
    unawaited(_read());
  }

  static void _stopRetrying() {
    _observer?.detach();
    _observer = null;
  }

  static Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'reduceTransparencyChanged') {
      _platform.value = call.arguments == true;
      _sync();
      // Событие несёт то же значение, что и ответ на запрос: читать повторно незачем.
      _markLoaded();
    }
    return null;
  }

  static void _sync() {
    _effective.value = _override ?? _platform.value;
  }
}

/// Возврат из фона запускает повторное чтение Reduce Transparency, если первое не удалось.
/// Живёт только пока есть неудача и остаток попыток; сам себя снимает.
class _ResumeObserver with WidgetsBindingObserver {
  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Ios27A11y._retry();
    }
  }
}

/// Строит дочерний виджет по актуальному снимку доступности.
///
/// Подписывает на Reduce Transparency (источник [Ios27A11y]) и на аспекты
/// `MediaQuery`, поэтому перестраивается при любом изменении.
class Ios27A11yBuilder extends StatelessWidget {
  const Ios27A11yBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Ios27A11yData data) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Ios27A11y.reduceTransparencyListenable,
        builder: (context, reduceTransparency, _) => builder(
          context,
          Ios27A11yData(
            reduceTransparency: reduceTransparency,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            highContrast: MediaQuery.highContrastOf(context),
            boldText: MediaQuery.boldTextOf(context),
          ),
        ),
      );
}
