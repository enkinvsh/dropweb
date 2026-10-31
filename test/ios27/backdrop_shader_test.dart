// Фон главной: один шейдер вместо смешения двух кадров. Проверяется (1) что шейдер даёт тот же
// кадр, что CPU-порт доски; (2) закон движения числами bg.js; (3) жизнь тикера: покой без
// кадров, касание, Reduce Motion, TickerMode, уход в фон, dispose, запасной путь.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';

Ios27ProviderTheme _board(int provider) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[provider].theme);

/// Свои цвета владельца (замер G6, `.omo/ios/g6/diag-bg-power.md`, B1).
const Ios27ProviderTheme _own = Ios27ProviderTheme(
  accent: '#BE38F3',
  orb1: '#0042A9',
  orb2: '#2BFF7A',
  blur: 4,
);

Ios27Colors _colors(Ios27ProviderTheme theme, Brightness b) => Ios27Colors.from(
      theme: theme,
      brightness: b,
      child: const SizedBox.shrink(),
    );

/// Снимок фона в логических пикселях (`pixelRatio: 1`): 411×914 RGBA.
Future<Uint8List> _capture(
  WidgetTester tester, {
  required Ios27BackdropRendering rendering,
  required Ios27ProviderTheme theme,
  required Brightness brightness,
  required Ios27BackdropState state,
  Size size = const Size(411, 914),
  double pixelRatio = 1,
}) async {
  Ios27Backdrop.debugRendering = rendering;
  final key = GlobalKey();
  if (rendering == Ios27BackdropRendering.cpu) {
    await tester.runAsync(
      () => Ios27BackdropRenderer.debugPrewarm(
        Ios27BackdropSpec.fromColors(
          _colors(theme, brightness),
          on: state.target,
        ),
      ),
    );
  } else {
    await tester.runAsync(Ios27BackdropShader.load);
  }
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ios27BoardApp(
      brightness: brightness,
      theme: theme,
      disableAnimations: true,
      child: RepaintBoundary(
        key: key,
        child: Ios27Backdrop(state: state),
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData();
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  return data!;
}

/// Среднеквадратичная разница по каналам RGB в долях 0..255.
double _rms(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      final d = a[i + c] - b[i + c];
      sum += d * d;
      n++;
    }
  }
  return math.sqrt(sum / n);
}

/// Монтирует фон с внешней физикой. [state] меняется через возвращённый нотификатор.
Future<ValueNotifier<Ios27BackdropState>> _mount(
  WidgetTester tester,
  Ios27BackdropMotion motion, {
  Ios27BackdropState state = Ios27BackdropState.off,
  bool disableAnimations = false,
  bool tickerEnabled = true,
  Widget? child,
}) async {
  Ios27Backdrop.debugRendering = Ios27BackdropRendering.shader;
  await tester.runAsync(Ios27BackdropShader.load);
  final notifier = ValueNotifier<Ios27BackdropState>(state);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
    ios27BoardApp(
      brightness: Brightness.light,
      theme: _board(0),
      disableAnimations: disableAnimations,
      child: ValueListenableBuilder<Ios27BackdropState>(
        valueListenable: notifier,
        builder: (context, value, _) => TickerMode(
          enabled: tickerEnabled,
          child: Ios27Backdrop(
            state: value,
            debugMotion: motion,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

/// Прогоняет кадры по 16 мс: один длинный `pump` дал бы один тик, а шаг режется до 0.05 с.
Future<void> _run(WidgetTester tester, int milliseconds) async {
  for (var ms = 0; ms < milliseconds; ms += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  tearDown(() {
    Ios27Backdrop.debugRendering = Ios27BackdropRendering.auto;
    Ios27Backdrop.debugResetIntro();
    Ios27BackdropShader.debugLoader = null;
    Ios27BackdropShader.debugReset();
    TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  group('шейдер ≈ CPU-порт (RMS ≤ 3/255)', () {
    final themes = <String, Ios27ProviderTheme>{
      'p0 DROPWEB': _board(0),
      'p5 Серый': _board(5),
      'свои цвета': _own,
    };
    for (final entry in themes.entries) {
      for (final brightness in Brightness.values) {
        for (final state in Ios27BackdropState.values) {
          testWidgets('${entry.key} ${brightness.name} ${state.name}',
              (tester) async {
            final cpu = await _capture(
              tester,
              rendering: Ios27BackdropRendering.cpu,
              theme: entry.value,
              brightness: brightness,
              state: state,
            );
            final shader = await _capture(
              tester,
              rendering: Ios27BackdropRendering.shader,
              theme: entry.value,
              brightness: brightness,
              state: state,
            );
            final rms = _rms(cpu, shader);
            debugPrint('RMS ${entry.key} ${brightness.name} ${state.name}: '
                '${rms.toStringAsFixed(3)}');
            expect(rms, lessThanOrEqualTo(3));
          });
        }
      }
    }

    testWidgets('другой размер и пропорция не сплющивают листы (B4)',
        (tester) async {
      final base = await _capture(
        tester,
        rendering: Ios27BackdropRendering.shader,
        theme: _board(0),
        brightness: Brightness.light,
        state: Ios27BackdropState.on,
      );
      // Тот же фон в вдвое большем боксе, снятый обратно в 411×914: пропорция та же, форма листов
      // не должна измениться (разница только в сглаживании кромок).
      final big = await _capture(
        tester,
        rendering: Ios27BackdropRendering.shader,
        theme: _board(0),
        brightness: Brightness.light,
        state: Ios27BackdropState.on,
        size: const Size(822, 1828),
        pixelRatio: .5,
      );
      expect(_rms(base, big), lessThanOrEqualTo(6));
    });
  });

  group('закон движения (bg.js:151-167)', () {
    const dt = 1 / 60;

    test('покой: время идёт со скоростью 0.3, яркость на цели', () {
      final m = Ios27BackdropMotion(on: 1);
      final more = m.step(dt);
      expect(m.t, closeTo(kIos27BackdropT0 + dt * 0.3, 1e-12));
      expect(m.on, 1);
      expect(more, isFalse);
    });

    test('переход: on += dOn·dt·2.5, t += dt·(0.3 + |dOn|·6)', () {
      final m = Ios27BackdropMotion()..onT = 1;
      final more = m.step(dt);
      expect(m.on, closeTo(dt * 2.5, 1e-12));
      expect(m.t, closeTo(kIos27BackdropT0 + dt * (0.3 + 6), 1e-12));
      expect(more, isTrue);
    });

    test('шаг режется до 0.05 с', () {
      final m = Ios27BackdropMotion()
        ..onT = 1
        ..step(2);
      expect(m.on, closeTo(0.05 * 2.5, 1e-12));
    });

    test('переход сходится и останавливается; время сдвигается как у доски',
        () {
      final m = Ios27BackdropMotion()..onT = 1;
      var steps = 0;
      while (m.step(dt) && steps < 1000) {
        steps++;
      }
      final adv = ios27BackdropAdvance(t: kIos27BackdropT0, from: 0, to: 1);
      expect(steps, inInclusiveRange(100, 160));
      expect((steps + 1) * dt, closeTo(adv.seconds, 2 * dt));
      expect(m.t, closeTo(adv.t, 0.03));
      expect((m.on - 1).abs(), lessThanOrEqualTo(0.004));
    });

    test('касание без пальца затухает как exp(-1.8·t)', () {
      final m = Ios27BackdropMotion(on: 1)..e = 1;
      for (var i = 0; i < 60; i++) {
        m.step(dt);
      }
      expect(m.e, closeTo(math.exp(-1.8), 1e-9));
    });

    test('с пальцем касание не затухает, время идёт быстрее', () {
      final m = Ios27BackdropMotion(on: 1)..pointerDown(.5, .5, 0);
      expect(m.e, 0.55);
      final before = m.t;
      for (var i = 0; i < 60; i++) {
        m.step(dt);
      }
      expect(m.e, 0.55);
      expect(m.t - before, closeTo(1 * (0.3 + 0.55 * 4), 1e-9));
    });

    test('сдвиг листов возвращается как exp(-1.6·t), скорость как exp(-2.5·t)',
        () {
      final m = Ios27BackdropMotion(on: 1)
        ..shift = 1
        ..v = 1;
      for (var i = 0; i < 60; i++) {
        m.step(dt);
      }
      expect(m.v, closeTo(math.exp(-2.5), 1e-9));
      // shift += v·dt даёт добавку, поэтому проверяем только убывание и порядок величины.
      expect(m.shift, lessThan(1));
      expect(m.shift, greaterThan(0));
    });

    test('pointermove: сдвиг, скорость и сила по формулам доски', () {
      final m = Ios27BackdropMotion(on: 1)..pointerDown(.5, .5, 1000);
      const aspect = 411 / 914;
      m.pointerMove(.6, .5, 1016, aspect);
      const dx = (.6 - .5) * aspect * 2.4;
      expect(m.shift, closeTo(-dx * .8, 1e-12));
      expect(m.v, closeTo(-dx * .8 / .016 * .25, 1e-9));
      expect(m.e, closeTo(math.min(1, .55 + dx * 2), 1e-12));
      expect(m.tx, .6);
    });

    test('pointermove без пальца ничего не делает', () {
      final m = Ios27BackdropMotion(on: 1)..pointerMove(.9, .9, 10, .5);
      expect(m.shift, 0);
      expect(m.v, 0);
    });

    test('после отпускания всё затухает и цикл кадров кончается', () {
      final m = Ios27BackdropMotion(on: 1)
        ..pointerDown(.5, .5, 0)
        ..pointerMove(.9, .5, 16, 411 / 914)
        ..pointerUp();
      var steps = 0;
      while (m.step(dt) && steps < 2000) {
        steps++;
      }
      expect(steps, lessThan(900));
      expect(m.e, lessThanOrEqualTo(0.004));
      expect(m.shift.abs(), lessThanOrEqualTo(0.004));
    });

    test('still(): яркость сразу, касание и сдвиг гасятся', () {
      final m = Ios27BackdropMotion()
        ..onT = 1
        ..e = .8
        ..v = 1
        ..shift = .5
        ..snapStill();
      expect(m.on, 1);
      expect(m.e, 0);
      expect(m.v, 0);
      expect(m.shift, 0);
      expect(m.moving, isFalse);
    });

    test('первое появление: касание у кнопки с силой 0.7', () {
      final m = Ios27BackdropMotion()..intro();
      expect(m.e, .7);
      expect(m.tx, .5);
      expect(m.ty, .2);
    });
  });

  test('uniform идут в порядке объявления шейдера', () {
    final spec = Ios27BackdropSpec.fromColors(
      _colors(_board(5), Brightness.dark),
      on: .5,
      t: 61,
    );
    final m = Ios27BackdropMotion()
      ..x = .1
      ..y = .2
      ..e = .3
      ..shift = .4;
    final u = ios27BackdropUniforms(
      spec: spec,
      motion: m,
      width: 393,
      height: 852,
    );
    expect(u, hasLength(kIos27BackdropUniformCount));
    expect(u.sublist(0, 8), [393, 852, 61, .1, .2, .3, .4, .5]);
    // uBase.r — первый канал фона тёмной темы; uSoft = (blur - 1) / 4; uDark = 1.
    expect(u[8], closeTo(((spec.base >> 16) & 255) / 255, 1e-12));
    expect(u[20], closeTo((spec.blur - 1) / 4, 1e-12));
    expect(u[21], 1);
  });

  group('жизнь тикера', () {
    testWidgets('покой: ни одного кадра (G8)', (tester) async {
      final motion = Ios27BackdropMotion(on: 0);
      Ios27Backdrop.debugResetIntro();
      await _mount(tester, motion);
      // Первое появление играет затухание касания; ждём, пока цикл кончится.
      await _run(tester, 4500);
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.e, lessThanOrEqualTo(0.004));
      final t = motion.t;
      await _run(tester, 500);
      expect(motion.t, t, reason: 'в покое время не идёт: кадров нет');
    });

    testWidgets('первое появление играет один раз за процесс', (tester) async {
      Ios27Backdrop.debugResetIntro();
      final first = Ios27BackdropMotion();
      await _mount(tester, first);
      expect(first.e, closeTo(.7, .05));
      await tester.pumpWidget(const SizedBox.shrink());
      final second = Ios27BackdropMotion();
      await _mount(tester, second);
      expect(second.e, 0);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('смена состояния: листы едут, потом кадры кончаются',
        (tester) async {
      final motion = Ios27BackdropMotion(on: 0);
      Ios27Backdrop.debugResetIntro();
      final notifier = await _mount(tester, motion);
      await _run(tester, 4500);
      expect(tester.binding.transientCallbackCount, 0);
      final t0 = motion.t;
      notifier.value = Ios27BackdropState.on;
      await tester.pump();
      await _run(tester, 300);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(motion.on, inExclusiveRange(0, 1));
      await _run(tester, 4000);
      expect(tester.binding.transientCallbackCount, 0);
      expect((motion.on - 1).abs(), lessThanOrEqualTo(0.004));
      expect(motion.t - t0, greaterThan(2), reason: 'время сдвинулось (B2)');
    });

    testWidgets('касание: кадры идут, тап по кнопке поверх проходит',
        (tester) async {
      final motion = Ios27BackdropMotion(on: 1);
      Ios27Backdrop.debugResetIntro();
      var taps = 0;
      await _mount(
        tester,
        motion,
        state: Ios27BackdropState.on,
        child: Center(
          child: GestureDetector(
            key: const ValueKey('btn'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      );
      await _run(tester, 4500);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(find.byKey(const ValueKey('btn')));
      await tester.pump();
      expect(taps, 1, reason: 'Listener(translucent) не перехватывает тапы');
      expect(motion.e, greaterThan(0.5), reason: 'фон узнал о касании');
      await _run(tester, 200);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _run(tester, 5000);
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.e, lessThanOrEqualTo(0.004));
    });

    testWidgets('свайп сдвигает листы, после отпускания они возвращаются',
        (tester) async {
      final motion = Ios27BackdropMotion(on: 1);
      Ios27Backdrop.debugResetIntro();
      await _mount(tester, motion, state: Ios27BackdropState.on);
      await _run(tester, 4500);
      final g = await tester.startGesture(const Offset(100, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(motion.pressed, isTrue);
      expect(motion.shift, isNegative, reason: 'вправо → shift -= dx·0.8');
      await g.up();
      await tester.pump();
      expect(motion.pressed, isFalse);
      await _run(tester, 12000);
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.shift.abs(), lessThanOrEqualTo(0.004));
    });

    testWidgets('Reduce Motion: яркость сразу, кадров и касаний нет',
        (tester) async {
      final motion = Ios27BackdropMotion();
      Ios27Backdrop.debugResetIntro();
      final notifier = await _mount(
        tester,
        motion,
        disableAnimations: true,
      );
      expect(motion.e, 0, reason: 'первое появление в Reduce Motion не играет');
      notifier.value = Ios27BackdropState.on;
      await tester.pump();
      expect(motion.on, 1);
      expect(motion.t, kIos27BackdropT0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
      final g = await tester.startGesture(const Offset(100, 400));
      await g.moveBy(const Offset(100, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(motion.pressed, isFalse);
      expect(motion.shift, 0);
      expect(tester.binding.transientCallbackCount, 0);
      await g.up();
    });

    testWidgets('TickerMode(false): тикер молчит, время не идёт',
        (tester) async {
      final motion = Ios27BackdropMotion();
      Ios27Backdrop.debugResetIntro();
      final notifier = await _mount(tester, motion, tickerEnabled: false);
      notifier.value = Ios27BackdropState.on;
      await tester.pump();
      await _run(tester, 500);
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.t, kIos27BackdropT0);
      expect(motion.on, 0);
    });

    testWidgets('paused останавливает кадры, resumed доигрывает',
        (tester) async {
      final motion = Ios27BackdropMotion(on: 0);
      Ios27Backdrop.debugResetIntro();
      final notifier = await _mount(tester, motion);
      await _run(tester, 4500);
      notifier.value = Ios27BackdropState.on;
      await tester.pump();
      await _run(tester, 200);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final frozen = motion.t;
      await _run(tester, 400);
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.t, frozen);

      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _run(tester, 4000);
      expect(motion.t, greaterThan(frozen));
      expect(tester.binding.transientCallbackCount, 0);
      expect((motion.on - 1).abs(), lessThanOrEqualTo(0.004));
    });

    testWidgets('dispose посреди перехода и касания не бросает',
        (tester) async {
      final motion = Ios27BackdropMotion(on: 0);
      Ios27Backdrop.debugResetIntro();
      final notifier = await _mount(tester, motion);
      notifier.value = Ios27BackdropState.on;
      await tester.pump();
      await _run(tester, 100);
      final g = await tester.startGesture(const Offset(100, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox.shrink());
      await g.up();
      await _run(tester, 500);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('запасной путь: шейдер не загрузился → CPU-кадр без тикеров',
        (tester) async {
      Ios27Backdrop.debugRendering = Ios27BackdropRendering.shader;
      Ios27BackdropShader.debugReset();
      Ios27BackdropShader.debugLoader = () async => null;
      final colors = _colors(_board(0), Brightness.light);
      await tester.runAsync(
        () => Ios27BackdropRenderer.debugPrewarm(
          Ios27BackdropSpec.fromColors(colors, on: 0),
        ),
      );
      final key = GlobalKey();
      final motion = Ios27BackdropMotion();
      await tester.pumpWidget(
        ios27BoardApp(
          brightness: Brightness.light,
          theme: _board(0),
          child: RepaintBoundary(
            key: key,
            child: Ios27Backdrop(debugMotion: motion),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      expect(motion.e, 0);
      expect(tester.takeException(), isNull);
      // Кадр не плоский --bg: CPU-порт дошёл до экрана.
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final px = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      final first = px!.sublist(0, 3);
      var distinct = false;
      for (var i = 0; i < px.length; i += 4 * 977) {
        if (px[i] != first[0] || px[i + 1] != first[1]) {
          distinct = true;
          break;
        }
      }
      expect(distinct, isTrue);
    });
  });
}
