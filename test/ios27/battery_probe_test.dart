// ПРОБА БАТАРЕИ (аудит 2026-10-30): сколько кадров в секунду главная iOS требует у движка в покое.
//
// Что измеряет. После оседания (5 с) считает кадры, которые фреймворк ЗАПРОСИЛ за 10 с модельного
// времени при шаге 16 мс (`addPersistentFrameCallback`; `pump` строит кадр только при
// `hasScheduledFrame`, поэтому счётчик равен числу vsync, которые движок реально отдаст), число
// перестроенных элементов (`debugOnRebuildDirtyWidget`) и число живых Ticker-ов
// (`transientCallbackCount`). Каждый кадр на устройстве — это ещё и перекомпозиция всех нативных
// стёкол `UiKitView` (см. audit.md), поэтому «кадров/с» здесь — главная валюта энергии.
//
// Ограничения. FakeAsync: стоимость кадра (растр, GPU, блюр `UIVisualEffectView`) не измеряется,
// только частота. Фон идёт CPU-путём (в тесте шейдер выключен), поэтому его движение измеряется
// отдельно по `Ios27BackdropMotion.step`, а не по кадрам виджета.
//
// Как гейт. Закреплено:
//  - сцены без живой анимации дают 0 кадров/с и 0 Ticker;
//  - карточка №4 (владелец 30.10) сама не двигается: ни кольца, ни переката цифр, ни пульса, а
//    значит `home-on` после оседания ≤ 1 кадра/с (смена секунды в таймере) БЕЗ какого-либо окна
//    живости: открытие, возврат из фона, уход листа и переход off→on не открывают «живых» секунд;
//  - главная под листом: те же ≤ 1 кадра/с, часы не замерзают;
//  - спиннер шагает 8 кадров/с, connecting целиком не больше 40.
// Остальное печатает строки `BATTERY |` без утверждений.

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_elapsed_builder.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';

/// Счётчик кадров: persistent-колбэк нельзя снять, поэтому он один на файл и включается флагом.
class _Meter {
  bool on = false;
  int frames = 0;
  int rebuilds = 0;
}

final _Meter _meter = _Meter();
bool _hooked = false;

void _hook(WidgetTester tester) {
  if (_hooked) {
    return;
  }
  _hooked = true;
  tester.binding.addPersistentFrameCallback((_) {
    if (_meter.on) {
      _meter.frames++;
    }
  });
}

class _Sample {
  const _Sample(this.fps, this.rebuildsPerSecond, this.tickers);
  final double fps;
  final double rebuildsPerSecond;
  final int tickers;

  @override
  String toString() =>
      'кадров/с=${fps.toStringAsFixed(1)}  перестроек/с=${rebuildsPerSecond.toStringAsFixed(1)}  '
      'живых Ticker=$tickers';
}

const Duration _step = Duration(milliseconds: 16);

/// Оседание: пружины, переходы и roll доезжают, дальше кадры должны замолчать (или нет).
Future<void> _settle(WidgetTester tester, {int seconds = 5}) async {
  for (var i = 0; i < seconds * 1000 ~/ 16; i++) {
    await tester.pump(_step);
  }
}

Future<_Sample> _measure(WidgetTester tester, {int seconds = 10}) async {
  _hook(tester);
  _meter
    ..frames = 0
    ..rebuilds = 0
    ..on = true;
  debugOnRebuildDirtyWidget = (_, __) => _meter.rebuilds++;
  final steps = seconds * 1000 ~/ 16;
  for (var i = 0; i < steps; i++) {
    await tester.pump(_step);
  }
  _meter.on = false;
  debugOnRebuildDirtyWidget = null;
  final elapsed = steps * 0.016;
  return _Sample(
    _meter.frames / elapsed,
    _meter.rebuilds / elapsed,
    tester.binding.transientCallbackCount,
  );
}

/// Строка таблицы для отчёта: печатается, чтобы числа попали в audit.md без ручной выписки.
void _report(String name, _Sample s, {int? glasses, int? nested}) {
  final g = glasses == null ? '' : '  Ios27Glass=$glasses (nested=$nested)';
  // ignore: avoid_print
  print('BATTERY | $name | $s$g');
}

int _glassCount(WidgetTester tester) =>
    find.byType(Ios27Glass).evaluate().length;

int _nestedCount(WidgetTester tester) => find
    .byType(Ios27Glass)
    .evaluate()
    .where((e) => (e.widget as Ios27Glass).nested)
    .length;

Future<void> _pumpScene(
  WidgetTester tester,
  String scene, {
  bool worst = false,
  Widget? overlay,
}) =>
    pumpHomeScene(
      tester,
      scene,
      // Движение включено: это то, что видит владелец с выключенным «Уменьшением движения».
      disableAnimations: false,
      // Для счёта стёкол: на устройстве без Reduce Transparency каждое стекло — UiKitView.
      worst: worst,
      overlay: overlay,
    );

/// `m:ss` таймера на карточке.
String _timerText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .firstWhere((t) => RegExp(r'^\d+:\d\d$').hasMatch(t), orElse: () => '');

int _parseSeconds(String mmss) {
  final parts = mmss.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Главная `home-on`, у которой `glassAway` берётся из маршрута так же, как в `Ios27Home`:
/// `ModalRoute.isCurrentOf(context) == false`. Без этого лист поверх главной ничего не меняет.
Future<void> _pumpCoveredHome(WidgetTester tester) async {
  await prewarmHomeBackdrop(
    tester,
    homeColors(0, Brightness.light),
    Ios27BackdropState.on,
  );
  final since = tester.binding.clock.now().subtract(kHomeRunTime);
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: Brightness.light,
      theme: homeProviderTheme(0),
      disableAnimations: false,
      child: Builder(
        builder: (context) => ios27HomeFrame(
          input: homeInputFor('home-on'),
          since: since,
          now: tester.binding.clock.now,
          glassAway: ModalRoute.isCurrentOf(context) == false,
        ),
      ),
    ),
  );
  await settleHomeBackdrop(tester);
}

class _ProbePopup extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Widget buildPage(BuildContext c, Animation<double> a, Animation<double> s) =>
      const Align(
          alignment: Alignment.bottomCenter, child: SizedBox(height: 120));
}

class _ProbePage extends PageRouteBuilder<void> {
  _ProbePage()
      : super(
          pageBuilder: (c, a, s) => const ColoredBox(color: Colors.black),
          transitionDuration: const Duration(milliseconds: 300),
        );
}

void main() {
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
    _meter.on = false;
  });

  group('покой главной', () {
    for (final scene in const [
      'home-off',
      'error',
      'offline',
      'expiring',
      'traffic-low',
    ]) {
      testWidgets('$scene: после оседания кадров нет', (tester) async {
        await _pumpScene(tester, scene);
        await _settle(tester);
        final s = await _measure(tester);
        _report(scene, s,
            glasses: _glassCount(tester), nested: _nestedCount(tester));
        // Гейт: сцены без живой анимации на доске обязаны молчать.
        expect(s.fps, 0, reason: '$scene не должна заказывать кадры в покое');
        expect(s.tickers, 0);
      });
    }

    for (final scene in const ['traffic-out', 'expired']) {
      testWidgets('$scene: после оседания кадров нет (с кнопкой «Обновить»)',
          (tester) async {
        await _pumpScene(tester, scene);
        await _settle(tester);
        final s = await _measure(tester);
        _report(scene, s,
            glasses: _glassCount(tester), nested: _nestedCount(tester));
        expect(s.fps, 0);
        expect(s.tickers, 0);
      });
    }
  });

  group('живые сцены (данные для решения владельца, не гейт)', () {
    testWidgets('connecting: спиннер страны + спиннер питания', (tester) async {
      await _pumpScene(tester, 'connecting');
      await _settle(tester);
      final s = await _measure(tester);
      _report('connecting', s,
          glasses: _glassCount(tester), nested: _nestedCount(tester));
      // Спиннер страны 8 Гц + спиннер питания 8 Гц (точки с пульсом на карточке больше нет).
      expect(s.fps, greaterThan(0));
      expect(s.fps, lessThanOrEqualTo(40));
      expect(s.tickers, 0, reason: 'вместо Ticker теперь Timer');
    });

    testWidgets('home-on: только секундный таймер, окна живости нет',
        (tester) async {
      await _pumpScene(tester, 'home-on');
      // Оседание фона (переход до 2,2 с) и всё: больше «живых» секунд карточка не ждёт.
      await _settle(tester, seconds: 3);
      final s = await _measure(tester);
      _report('home-on', s,
          glasses: _glassCount(tester), nested: _nestedCount(tester));
      expect(s.fps, lessThanOrEqualTo(1.2));
      expect(s.tickers, 0);
    });

    testWidgets('home-on: кто перестраивается (гистограмма за 4 с)',
        (tester) async {
      await _pumpScene(tester, 'home-on');
      await _settle(tester);
      final hist = <String, int>{};
      debugOnRebuildDirtyWidget = (e, _) {
        final key = '${e.widget.runtimeType}';
        hist[key] = (hist[key] ?? 0) + 1;
      };
      for (var i = 0; i < 250; i++) {
        await tester.pump(_step);
      }
      debugOnRebuildDirtyWidget = null;
      final top = hist.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in top.take(10)) {
        // ignore: avoid_print
        print('BATTERY | перестройки home-on за 4 с | ${e.key}: ${e.value}');
      }
    });

    testWidgets('home-on при «Уменьшить движение»: только секундный таймер',
        (tester) async {
      await pumpHomeScene(tester, 'home-on', disableAnimations: true);
      await _settle(tester);
      final s = await _measure(tester);
      _report('home-on + reduce motion', s);
      // Timer раз в секунду заказывает один кадр.
      expect(s.fps, lessThan(2));
    });
  });

  testWidgets('home-on в фоне (paused): кадров и таймеров нет', (tester) async {
    await _pumpScene(tester, 'home-on');
    await _settle(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final s = await _measure(tester);
    _report('home-on, paused', s);
    expect(s.fps, 0);
    expect(s.tickers, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  group('отдельные источники в изоляции (без остального экрана)', () {
    testWidgets('только таймер (простой текст)', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: homeProviderTheme(0),
          disableAnimations: false,
          child: Center(
            child: Ios27ElapsedBuilder(
              since: tester.binding.clock
                  .now()
                  .subtract(const Duration(minutes: 12, seconds: 49)),
              now: tester.binding.clock.now,
              builder: (c, text) =>
                  Text(text, style: const TextStyle(fontSize: 17)),
            ),
          ),
        ),
      );
      await _settle(tester);
      final s = await _measure(tester, seconds: 20);
      _report('изолированный таймер', s);
      expect(s.fps, lessThanOrEqualTo(1.2));
      expect(s.fps, greaterThan(0.8), reason: 'секунды должны идти');
      expect(s.tickers, 0);
    });

    testWidgets('только спиннер', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: homeProviderTheme(0),
          disableAnimations: false,
          child: const Center(child: Ios27ActivityIndicator(size: 20)),
        ),
      );
      await _settle(tester);
      final s = await _measure(tester);
      _report('изолированный спиннер (8 ступеней/с)', s);
      expect(s.fps, lessThanOrEqualTo(9));
      expect(s.fps, greaterThan(7), reason: 'ступени не должны пропадать');
    });

    testWidgets('спиннер под TickerMode(false): кадров нет', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: homeProviderTheme(0),
          disableAnimations: false,
          child: const TickerMode(
            enabled: false,
            child: Center(child: Ios27ActivityIndicator(size: 20)),
          ),
        ),
      );
      await _settle(tester);
      final s = await _measure(tester);
      _report('TickerMode(false), спиннер', s);
      expect(s.fps, 0);
    });

    testWidgets('спиннер в фоне (paused) встаёт и возвращается',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: homeProviderTheme(0),
          disableAnimations: false,
          child: const Center(child: Ios27ActivityIndicator(size: 20)),
        ),
      );
      await _settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      try {
        await tester.pump();
        expect((await _measure(tester, seconds: 3)).fps, 0);
      } finally {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await tester.pump();
      expect((await _measure(tester, seconds: 3)).fps, greaterThan(7));
    });
  });

  group('над главной открыт слой', () {
    testWidgets(
        'home-on + лист (PopupRoute): остаётся только смена секунды, часы идут',
        (tester) async {
      await _pumpCoveredHome(tester);
      await _settle(tester, seconds: 3);
      final context = tester.element(find.byType(Ios27HomeScreen));
      // Настоящий `Ios27SheetRoute` — `PopupRoute` (ios27_sheet.dart:148): непрозрачности нет,
      // главная под ним остаётся на сцене. Содержимое листа тянет провайдеры приложения, которых
      // в пробе нет, поэтому берём пустой `PopupRoute` с теми же свойствами навигатора.
      // ignore: unawaited_futures
      final popped =
          Navigator.of(context, rootNavigator: true).push<void>(_ProbePopup());
      await _settle(tester);
      final timerBefore = _timerText(tester);
      final s = await _measure(tester);
      _report('home-on + лист', s,
          glasses: _glassCount(tester), nested: _nestedCount(tester));
      // Остаётся одна смена секунды в секунду; 1.2 — запас на границы окна из 10 с.
      expect(s.fps, lessThanOrEqualTo(1.2),
          reason: 'под листом карточка просит только смену секунды');
      expect(s.tickers, 0);
      // Часы под листом не замерзают: 10 с измерения — текст другой.
      expect(_timerText(tester), isNot(timerBefore));
      expect(find.byType(Ios27ElapsedBuilder), findsOneWidget);

      // Лист закрылся: ничего «живого» не открывается, секунды считаются от `since` без скачка.
      Navigator.of(context, rootNavigator: true).pop();
      await tester.pump(const Duration(milliseconds: 400));
      await popped;
      // Возврат стекла кнопок после листа — конечная анимация; дожидаемся её, а не считаем в покой.
      final comeBack = await _measure(tester, seconds: 2);
      _report('home-on, возврат кнопок после листа', comeBack);
      final after = await _measure(tester, seconds: 4);
      _report('home-on после листа', after);
      expect(after.fps, lessThanOrEqualTo(1.2),
          reason: 'после ухода листа карточка не оживает');
      expect(_parseSeconds(_timerText(tester)),
          greaterThanOrEqualTo(_parseSeconds(timerBefore) + 10));
    });

    testWidgets('home-on + страница (PageRoute): главная под страницей встала',
        (tester) async {
      await _pumpScene(tester, 'home-on');
      await _settle(tester);
      final context = tester.element(find.byType(Ios27HomeScreen));
      // `Ios27PageRoute` — `PageRoute` без переопределения `opaque` (ios27_page.dart:96), то есть
      // непрозрачный: Navigator гасит Ticker-ы всего, что под ним.
      // ignore: unawaited_futures
      Navigator.of(context).push<void>(_ProbePage());
      await _settle(tester);
      final s = await _measure(tester);
      _report('home-on + страница', s,
          glasses: _glassCount(tester), nested: _nestedCount(tester));
    });
  });

  group('карточка №4 не оживает сама: ни при открытии, ни после события', () {
    testWidgets('открытие на подключённом VPN: сразу ≤ 1 кадра/с, секунды идут',
        (tester) async {
      await _pumpScene(tester, 'home-on');
      // Без оседания: первые секунды жизни экрана (фон ещё может доезжать, но не карточка).
      await _settle(tester, seconds: 3);
      final textBefore = _timerText(tester);
      final calm = await _measure(tester, seconds: 8);
      _report('home-on, 3–11 с после старта', calm);
      expect(calm.fps, lessThanOrEqualTo(1.2));
      expect(calm.tickers, 0);
      expect(_parseSeconds(_timerText(tester)),
          greaterThanOrEqualTo(_parseSeconds(textBefore) + 8));
    });

    testWidgets('возврат приложения (resumed): окна живости нет',
        (tester) async {
      await _pumpScene(tester, 'home-on');
      await _settle(tester, seconds: 3);
      expect((await _measure(tester, seconds: 3)).fps, lessThanOrEqualTo(1.2));
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // В фоне кадров нет и таймер секунд снят.
      expect((await _measure(tester, seconds: 8)).fps, 0);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final after = await _measure(tester, seconds: 5);
      _report('home-on после resumed', after);
      expect(after.fps, lessThanOrEqualTo(1.2),
          reason: 'раньше первые 6 с после возврата шли ≈ 62 кадра/с');
    });

    testWidgets('переход off → on: после фона карточка ≤ 1 кадра/с',
        (tester) async {
      final on = ValueNotifier<bool>(false);
      addTearDown(on.dispose);
      await prewarmHomeBackdrop(
        tester,
        homeColors(0, Brightness.light),
        Ios27BackdropState.off,
      );
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: homeProviderTheme(0),
          disableAnimations: false,
          child: ValueListenableBuilder<bool>(
            valueListenable: on,
            builder: (context, isOn, _) => ios27HomeFrame(
              input: homeInputFor(isOn ? 'home-on' : 'home-off'),
              since: isOn
                  ? tester.binding.clock.now().subtract(kHomeRunTime)
                  : null,
              now: tester.binding.clock.now,
            ),
          ),
        ),
      );
      await settleHomeBackdrop(tester);
      await _settle(tester, seconds: 8);
      expect((await _measure(tester, seconds: 3)).fps, 0);
      on.value = true;
      await tester.pump();
      await _settle(tester, seconds: 3); // фон перехода off→on кончается к ~2 с
      final calm = await _measure(tester, seconds: 5);
      _report('off→on, 3–8 с после подключения', calm);
      expect(calm.fps, lessThanOrEqualTo(1.2));
    });
  });

  testWidgets('empty: пустая главная', (tester) async {
    await prewarmHomeBackdrop(
      tester,
      homeColors(0, Brightness.light),
      Ios27BackdropState.off,
    );
    await pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        theme: homeProviderTheme(0),
        disableAnimations: false,
        child: Ios27EmptyView(
          onSettings: () {},
          onPaste: () {},
          onScan: () {},
        ),
      ),
    );
    await settleHomeBackdrop(tester);
    await _settle(tester);
    final s = await _measure(tester);
    _report('empty', s,
        glasses: _glassCount(tester), nested: _nestedCount(tester));
    expect(s.fps, 0);
  });

  group('фон Ios27Backdrop: кадры тикера, пока что-то движется', () {
    int framesUntilStill(Ios27BackdropMotion m, {int cap = 600}) {
      var frames = 0;
      // Шаг 1/60 с: ровно то, что отдаёт vsync 60 Гц.
      while (frames < cap) {
        frames++;
        if (!m.step(1 / 60)) {
          break;
        }
      }
      return frames;
    }

    test('переходы off→on, on→off, off→connecting и intro', () {
      final rows = <String, int>{};
      rows['off→on'] = framesUntilStill(Ios27BackdropMotion()..onT = 1);
      rows['on→off'] = framesUntilStill(
        Ios27BackdropMotion(on: 1)..onT = 0,
      );
      final connecting = Ios27BackdropMotion()
        ..onT = Ios27BackdropState.connecting.target;
      rows['off→connecting'] = framesUntilStill(connecting);
      rows['intro (первый запуск)'] =
          framesUntilStill(Ios27BackdropMotion()..intro());
      rows.forEach((name, frames) {
        // ignore: avoid_print
        print(
          'BATTERY | фон $name | кадров до покоя=$frames '
          '(${(frames / 60).toStringAsFixed(2)} с при 60 Гц)',
        );
        // Гейт: переход не бесконечен (потолок 600 кадров = 10 с).
        expect(frames, lessThan(600), reason: name);
      });
    });
  });
}
