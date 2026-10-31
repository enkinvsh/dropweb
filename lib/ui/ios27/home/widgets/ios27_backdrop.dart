// Фон главной iOS-редизайна: порт шейдера `canon/dropweb/bg.js` (слои изогнутых листов в цветах
// провайдера) и подложки `.home__bg` (app.css:68-79).
//
// Как на доске: ОДИН шейдер (`shaders/ios27_backdrop.frag`, FRAG из bg.js:18-106) рисует ОДИН кадр
// с плавно меняющимися uniform. Готовые кадры не смешиваются: при разнице времени между двумя
// кадрами в несколько единиц кромки двоятся и появляются «призраки» листов, поэтому листы
// едут сами: `uOn` приближается к цели, `uT` бежит быстрее, касание выгибает кромки.
//
// Закон движения (`Ios27BackdropMotion`) переписан из `frame()` и обработчиков указателя bg.js:
//   t += dt·(0.3 + e·4 + |dOn|·6 + |v|·2), on += dOn·min(1, dt·2.5), e *= exp(-1.8·dt) без пальца,
//   shift += v·dt, v *= exp(-2.5·dt), shift *= exp(-1.6·dt) без пальца (bg.js:151-167).
// Кадры идут только пока что-то движется (переход, касание, затухание): в покое тикер стоит, как
// стоит `requestAnimationFrame` доски (bg.js:12-14, 165-166). Время `t` копится между переходами
// (решение B2 «как на доске»). Первое появление (листы расступаются от кнопки, bg.js:190-191)
// играет один раз на запуск процесса, как `S.first`.
//
// Разрешение. Доска рисует холст 411×914 в 1x и растягивает его (bg.js:129-131). Здесь шейдер
// считается в ЛОГИЧЕСКИХ пикселях фактического размера виджета (`uRes` = этот размер, поэтому
// на окне Mac с другой пропорцией листы не сплющиваются) в текстуру 1x и растягивается на
// экран билинейно: на iPhone 8 это ~250 тыс. пикселей на кадр вместо миллиона.
//
// Запасной путь. Если программа не загрузилась (`FragmentProgram.fromAsset` бросил), фон
// считается CPU-портом (`renderIos27BackdropPixels`, ~80 мс в изоляте) ОДНИМ кадром для текущей
// цели и времени, без смешивания и без движения. В `flutter test` по умолчанию тоже CPU-путь:
// эталонные golden-ы главной сняты с ним (`Ios27Backdrop.debugRendering` переключает).
//
// Reduce Motion (`still()`, bg.js:135, 169): яркость переставляется сразу, `e`/`v` обнуляются,
// касания не двигают листы, время стоит. Эталоны G1 сняты именно так (`S.t` = 58, bg.js:134).

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Состояние VPN в терминах фона: `bg.mount(home, st.home)` (bg.js:171), доска выставляет цель
/// яркости листов `onT`: включено 1, подключение 0.5, всё остальное 0.
enum Ios27BackdropState {
  /// `off`, `error`, `offline`, `empty`: листы приглушены.
  off(0),

  /// `connecting`: листы светлеют до половины.
  connecting(0.5),

  /// `on`: листы светлеют полностью.
  on(1);

  const Ios27BackdropState(this.target);

  /// `S.onT` (bg.js:171).
  final double target;
}

/// Время шейдера в момент, когда доска снимает эталоны: `S.t` до первого кадра (bg.js:133).
const double kIos27BackdropT0 = 58;

/// Размер холста доски в CSS px (bg.js:121): фон считается в нём всегда и растягивается на бокс.
const int kIos27BackdropWidth = 411;
const int kIos27BackdropHeight = 914;

/// Скорость приближения яркости к цели, 1/с (bg.js:144 `dt * 2.5`).
const double _kApproachRate = 2.5;

/// Порог остановки цикла кадров доски по яркости (bg.js:149 `0.004`).
const double _kStopEps = 0.004;

/// Все входы формулы шейдера. Цвета в `0xAARRGGBB`; сравнение по значению нужно кэшу картинок.
@immutable
class Ios27BackdropSpec {
  const Ios27BackdropSpec({
    required this.base,
    required this.accent,
    required this.orb1,
    required this.orb2,
    required this.blur,
    required this.on,
    this.t = kIos27BackdropT0,
  });

  /// Входы формулы из цветов iOS-колонки: `--bg` темы, акцент провайдера как прислан (без подгонки
  /// контраста, `bg.theme`, bg.js:176), орбы и размытие.
  factory Ios27BackdropSpec.fromColors(
    Ios27Colors colors, {
    required double on,
    double t = kIos27BackdropT0,
  }) =>
      Ios27BackdropSpec(
        base: colors.palette.bg.toARGB32(),
        accent: 0xFF000000 |
            int.parse(colors.theme.accent.substring(1, 7), radix: 16),
        orb1: colors.orb1.toARGB32(),
        orb2: colors.orb2.toARGB32(),
        blur: colors.theme.blur,
        on: on,
        t: t,
      );

  /// `uBase`: вычисленный фон темы `--bg` (bg.js:158-161).
  final int base;

  /// `uAcc`: акцент провайдера как прислан, без подгонки контраста (bg.js:176-178).
  final int accent;

  /// `uOrb1`: верхние (задние) листы.
  final int orb1;

  /// `uOrb2`: нижние (передние) листы.
  final int orb2;

  /// Размытие провайдера 1..5; `uSoft = (blur - 1) / 4`.
  final double blur;

  /// `uOn`: 0..1, яркость листов.
  final double on;

  /// `uT`: время шейдера, двигает кромки листов.
  final double t;

  /// `uDark`: фон темнее порога (bg.js:161 `sum < 1.5`).
  bool get dark {
    final r = (base >> 16) & 255, g = (base >> 8) & 255, b = base & 255;
    return (r + g + b) / 255 < 1.5;
  }

  @override
  bool operator ==(Object other) =>
      other is Ios27BackdropSpec &&
      other.base == base &&
      other.accent == accent &&
      other.orb1 == orb1 &&
      other.orb2 == orb2 &&
      other.blur == blur &&
      other.on == on &&
      other.t == t;

  @override
  int get hashCode => Object.hash(base, accent, orb1, orb2, blur, on, t);
}

/// Приращение времени шейдера за переход яркости с [from] на [to]: симуляция цикла кадров доски
/// (bg.js:139-150) с шагом 1/60 с. Касаний нет, поэтому `S.e` и `S.v` равны нулю и время идёт со
/// скоростью `0.3 + |dOn| * 6`. Возвращает новое время и длительность перехода.
@visibleForTesting
({double t, double seconds}) ios27BackdropAdvance({
  required double t,
  required double from,
  required double to,
}) {
  const dt = 1 / 60;
  var on = from;
  var time = t;
  var steps = 0;
  while ((to - on).abs() > _kStopEps && steps < 600) {
    final d = to - on;
    on += d * math.min(1.0, dt * _kApproachRate);
    time += dt * (0.3 + d.abs() * 6);
    steps++;
  }
  return (t: time, seconds: steps * dt);
}

/// Считает кадр фона (RGBA, 411×914). Чистая функция: годится для изолята.
///
/// Порт `FRAG` из bg.js:27-110 для случая «касания нет» (`uTouch.z = 0`, `uShift = 0`): кромки листов
/// не выгибаются под пальцем и не сдвигаются параллаксом. Порядок операций сохранён.
Uint8List renderIos27BackdropPixels(Ios27BackdropSpec s) {
  const w = kIos27BackdropWidth, h = kIos27BackdropHeight;
  final out = Uint8List(w * h * 4);

  double ch(int argb, int shift) => ((argb >> shift) & 255) / 255;
  final base = [ch(s.base, 16), ch(s.base, 8), ch(s.base, 0)];
  final acc = [ch(s.accent, 16), ch(s.accent, 8), ch(s.accent, 0)];
  final o1 = [ch(s.orb1, 16), ch(s.orb1, 8), ch(s.orb1, 0)];
  final o2 = [ch(s.orb2, 16), ch(s.orb2, 8), ch(s.orb2, 0)];
  final soft = (s.blur - 1) / 4;
  final dark = s.dark;
  final on = s.on;
  final tt = s.t;

  // mute(): цвета провайдера приглушены, как обои Apple (bg.js:92).
  List<double> mute(List<double> c) {
    final g = c[0] * .3 + c[1] * .59 + c[2] * .11;
    return [
      g * .2 + c[0] * .8,
      g * .2 + c[1] * .8,
      g * .2 + c[2] * .8,
    ];
  }

  final c1 = mute(o1), ca = mute(acc), c2 = mute(o2);

  double clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
  double smooth(double e0, double e1, double x) {
    final t = clamp01((x - e0) / (e1 - e0));
    return t * t * (3 - 2 * t);
  }

  double edge(double u, double k) =>
      -1.35 +
      k * .58 +
      .34 * math.sin(u * 1.25 + k * .7 + tt * .3) +
      .05 * math.sin(u * 3.7 - k * 1.3 - tt * .45);

  // Палитра по t: 0 — orb1, .5 — акцент, 1 — orb2 (bg.js:93-95).
  final tintOut = [0.0, 0.0, 0.0];
  void tint(double t) {
    if (t < .5) {
      final k = smooth(0, .5, t);
      for (var i = 0; i < 3; i++) {
        tintOut[i] = c1[i] * (1 - k) + ca[i] * k;
      }
    } else {
      final k = smooth(.5, 1, t);
      for (var i = 0; i < 3; i++) {
        tintOut[i] = ca[i] * (1 - k) + c2[i] * k;
      }
    }
  }

  final col = [0.0, 0.0, 0.0];
  // sheet(): цвет листа (bg.js:53-90). a — цвет tintOut на момент вызова.
  void sheet(double d, double gap, double depth, double sweep) {
    final lit = math.exp(-d * (2.6 + (1.3 - 2.6) * soft));
    final curl = math.exp(-d * 14) * .35;
    final rim = math.exp(-d * (120 + (70 - 120) * soft));
    final shade = math.exp(-gap * 12) * .6;
    if (dark) {
      final tone = .2 + lit * .6 + curl + sweep * .12 + depth * .06;
      final gain = tone * (.55 + (.85 - .55) * on);
      final rimGain = rim * (.35 + (.6 - .35) * on);
      for (var i = 0; i < 3; i++) {
        final a = tintOut[i];
        final body = a * .75 * (1 - .08) + .8 * .08;
        var c = base[i] + body * gain;
        c *= 1 - shade;
        c += (a * .5 + .5) * rimGain;
        col[i] = c;
      }
    } else {
      final pa = (.16 + (.24 - .16) * on) + depth * .06;
      final da = .45 + (.6 - .45) * on;
      final k = clamp01((1 - lit) * .4 - curl * .6 + shade - sweep * .1);
      final r = rim * .9;
      for (var i = 0; i < 3; i++) {
        final a = tintOut[i];
        final paper = base[i] * (1 - pa) + a * pa;
        final deep = base[i] * .6 * (1 - da) + a * .8 * da;
        var c = paper * (1 - k) + deep * k;
        c = c * (1 - r) + r;
        col[i] = c;
      }
    }
  }

  // du = normalize(.9, 1.): листы идут по диагонали (bg.js:112-114).
  final dl = math.sqrt(.9 * .9 + 1.0);
  final duX = .9 / dl, duY = 1.0 / dl;
  final dvX = duY, dvY = -duX;
  const asp = w / h;
  const aa = 3 / h;
  final edges = List<double>.filled(6, 0);

  var o = 0;
  for (var py = 0; py < h; py++) {
    // gl_FragCoord.y растёт снизу вверх, центр пикселя на +0.5.
    final uvy = (h - 1 - py + .5) / h;
    final yt = 1 - uvy;
    final pY = (uvy - .5) * 2;
    for (var px = 0; px < w; px++) {
      final uvx = (px + .5) / w;
      final pX = (uvx - .5) * asp * 2;
      final u = pX * duX + pY * duY;
      final v = pX * dvX + pY * dvY;
      final sweep = smooth(-1.6, 1.8, u);
      for (var k = 0; k < 6; k++) {
        edges[k] = edge(u, k.toDouble());
      }
      var e = edges[0];
      tint(yt * .8);
      sheet(2, e - v, 0, sweep);
      var r = col[0], g = col[1], b = col[2];
      for (var j = 0; j < 5; j++) {
        final k = j.toDouble();
        final en = j < 4 ? edges[j + 1] : 9.0;
        final cov = smooth(-aa, aa, v - e);
        final depth = (k + 1) / 5;
        final pt = clamp01(yt * .8 + depth * .25 - .05);
        if (cov > 0) {
          tint(pt);
          sheet(math.max(v - e, 0), en - v, depth, sweep);
          r = r * (1 - cov) + col[0] * cov;
          g = g * (1 - cov) + col[1] * cov;
          b = b * (1 - cov) + col[2] * cov;
        }
        e = en;
      }
      out[o++] = (clamp01(r) * 255 + .5).floor();
      out[o++] = (clamp01(g) * 255 + .5).floor();
      out[o++] = (clamp01(b) * 255 + .5).floor();
      out[o++] = 255;
    }
  }
  return out;
}

/// Кэш и очередь отрисовки фона. Дорогой расчёт идёт в изоляте; результат хранится как `ui.Image`
/// по входам формулы, поэтому поворот экрана, пересборка виджета и возврат на главную не считают заново.
class Ios27BackdropRenderer {
  Ios27BackdropRenderer._();

  static const int _capacity = 8;
  static final Map<Ios27BackdropSpec, Future<ui.Image>> _cache = {};

  /// Картинка кадра; считается один раз на набор входов. Владелец кэша — этот класс: вызывающий
  /// берёт `clone()` и освобождает свой дескриптор сам.
  static Future<ui.Image> image(Ios27BackdropSpec spec) {
    final hit = _cache.remove(spec);
    if (hit != null) {
      _cache[spec] = hit;
      return hit;
    }
    final fresh = _render(spec);
    _cache[spec] = fresh;
    while (_cache.length > _capacity) {
      final oldest = _cache.keys.first;
      final dropped = _cache.remove(oldest)!;
      // Уже выданные клоны остаются живы: dispose() оригинала их не трогает.
      unawaited(dropped.then((i) => i.dispose(), onError: (_) {}));
    }
    return fresh;
  }

  static Future<ui.Image> _render(Ios27BackdropSpec spec) async {
    final pixels = await Isolate.run(() => renderIos27BackdropPixels(spec));
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      kIos27BackdropWidth,
      kIos27BackdropHeight,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  /// Заранее кладёт кадр в кэш. Только для тестов: вызывать внутри `tester.runAsync` ДО `pumpWidget`.
  /// Изолят, запущенный из зоны `FakeAsync`, не доставляет результат, а готовая картинка из кэша
  /// доходит до виджета обычным микротиком.
  @visibleForTesting
  static Future<void> debugPrewarm(Ios27BackdropSpec spec) => image(spec);

  /// Сбрасывает кэш между тестами.
  @visibleForTesting
  static void debugClear() {
    for (final f in _cache.values) {
      unawaited(f.then((i) => i.dispose(), onError: (_) {}));
    }
    _cache.clear();
  }
}

/// Скорость затухания касания без пальца, 1/с (bg.js:154 `dt * 1.8`).
const double _kTouchDecay = 1.8;

/// Скорость затухания скорости свайпа, 1/с (bg.js:158 `dt * 2.5`).
const double _kSwipeDecay = 2.5;

/// Скорость возврата листов на место без пальца, 1/с (bg.js:160 `dt * 1.6`).
const double _kShiftReturn = 1.6;

/// Шаг сглаживания точки касания к пальцу, 1/с (bg.js:152-153 `dt * 10`).
const double _kTouchFollow = 10;

/// Потолок шага времени кадра (bg.js:150 `Math.min(0.05, …)`): после паузы кадр не «прыгает».
const double _kMaxDt = 0.05;

/// Физика фона: переписанные `frame()` и обработчики указателя bg.js (`S`, bg.js:132-170, 203-223).
///
/// Класс чистый (без Flutter), чтобы закон движения проверялся числами доски. Координаты касания
/// нормированы как у доски: `x` слева направо, `y` СНИЗУ вверх (`1 - clientY / height`, bg.js:176-178).
class Ios27BackdropMotion {
  Ios27BackdropMotion({this.on = 0, this.t = kIos27BackdropT0}) : onT = on;

  /// `S.t`: время шейдера; копится между переходами (решение B2).
  double t;

  /// `S.e`: сила касания, от неё листы выгибаются, а время идёт быстрее.
  double e = 0;

  /// `S.x`, `S.y`: сглаженная точка касания.
  double x = .5, y = .3;

  /// `S.tx`, `S.ty`: куда палец показывает сейчас.
  double tx = .5, ty = .3;

  /// `S.shift`: параллакс листов от горизонтального свайпа.
  double shift = 0;

  /// `S.v`: скорость свайпа.
  double v = 0;

  /// `S.on`: текущая яркость листов.
  double on;

  /// `S.onT`: цель яркости (`Ios27BackdropState.target`).
  double onT;

  /// `S.ptr`: палец на экране.
  bool pressed = false;

  double _gx = 0;
  double _gt = 0;

  /// Идёт ли что-нибудь, что надо рисовать (условие `moving` в конце `frame()`, bg.js:165),
  /// посчитанное по текущему состоянию. Для решения «будить ли тикер».
  bool get moving =>
      pressed ||
      e > _kStopEps ||
      v.abs() > _kStopEps ||
      shift.abs() > _kStopEps ||
      (onT - on).abs() > _kStopEps;

  /// Один кадр (`frame()`, bg.js:151-167). [dtSeconds] режется до 0.05. Возвращает, нужен ли
  /// следующий кадр: `dOn` берётся ДО сдвига `on`, как на доске.
  bool step(double dtSeconds) {
    final dt = math.min(_kMaxDt, math.max(0.0, dtSeconds));
    x += (tx - x) * math.min(1.0, dt * _kTouchFollow);
    y += (ty - y) * math.min(1.0, dt * _kTouchFollow);
    if (!pressed) {
      e *= math.exp(-dt * _kTouchDecay);
    }
    shift += v * dt;
    v *= math.exp(-dt * _kSwipeDecay);
    // Без пальца листы пружиной возвращаются на место, как обои после наклона телефона.
    if (!pressed) {
      shift *= math.exp(-dt * _kShiftReturn);
    }
    final dOn = onT - on;
    on += dOn * math.min(1.0, dt * _approachRate);
    t += dt * (0.3 + e * 4 + dOn.abs() * 6 + v.abs() * 2);
    return pressed ||
        e > _kStopEps ||
        v.abs() > _kStopEps ||
        shift.abs() > _kStopEps ||
        dOn.abs() > _kStopEps;
  }

  /// `still()` (bg.js:169): Reduce Motion переставляет яркость сразу и гасит касание.
  /// Параллакс тоже обнуляется: спокойный режим не должен оставлять листы со сдвигом.
  void snapStill() {
    on = onT;
    e = 0;
    v = 0;
    shift = 0;
    pressed = false;
  }

  /// Первое появление (bg.js:190-191): листы расступаются от кнопки и встают на место.
  void intro() {
    x = tx = .5;
    y = ty = .2;
    e = .7;
  }

  /// `pointerdown` (bg.js:203-210).
  void pointerDown(double nx, double ny, double timeMs) {
    pressed = true;
    _gx = nx;
    _gt = timeMs;
    tx = nx;
    ty = ny;
    e = math.max(e, 0.55);
  }

  /// `pointermove` (bg.js:211-223): листы едут за пальцем с параллаксом. [aspect] — ширина/высота
  /// холста (`canvas.width / canvas.height`).
  void pointerMove(double nx, double ny, double timeMs, double aspect) {
    if (!pressed) {
      return;
    }
    final dt = math.max(1.0, timeMs - _gt) / 1000;
    final dx = (nx - _gx) * aspect * 2.4;
    shift -= dx * 0.8;
    v = -dx * 0.8 / dt * 0.25;
    _gx = nx;
    _gt = timeMs;
    tx = nx;
    ty = ny;
    e = math.min(1.0, e + dx.abs() * 2);
  }

  /// `pointerup` / `pointercancel` (bg.js:224-228).
  void pointerUp() {
    pressed = false;
  }

  static const double _approachRate = _kApproachRate;
}

/// Число float-uniform шейдера (bg.js:19-29): 2 + 1 + 3 + 1 + 1 + 3 + 3 + 3 + 3 + 1 + 1 = 22.
const int kIos27BackdropUniformCount = 22;

/// Значения uniform в порядке объявления в `shaders/ios27_backdrop.frag`, он же порядок `setFloat`.
/// [width], [height] — размер текстуры кадра в пикселях (`uRes`).
@visibleForTesting
List<double> ios27BackdropUniforms({
  required Ios27BackdropSpec spec,
  required Ios27BackdropMotion motion,
  required double width,
  required double height,
}) {
  double ch(int argb, int shift) => ((argb >> shift) & 255) / 255;
  return <double>[
    width, height, //                                 uRes
    spec.t, //                                        uT
    motion.x, motion.y, motion.e, //                  uTouch
    motion.shift, //                                  uShift
    spec.on, //                                       uOn
    ch(spec.base, 16), ch(spec.base, 8), ch(spec.base, 0), // uBase
    ch(spec.accent, 16), ch(spec.accent, 8), ch(spec.accent, 0), // uAcc
    ch(spec.orb1, 16), ch(spec.orb1, 8), ch(spec.orb1, 0), // uOrb1
    ch(spec.orb2, 16), ch(spec.orb2, 8), ch(spec.orb2, 0), // uOrb2
    (spec.blur - 1) / 4, //                           uSoft (bg.js:199)
    spec.dark ? 1 : 0, //                             uDark (bg.js:174)
  ];
}

/// Загрузка шейдерной программы. Одна на процесс: `FragmentProgram` дорогой, а `fragmentShader()`
/// дешёвый.
abstract final class Ios27BackdropShader {
  /// Путь к ассету из `pubspec.yaml` (`flutter: shaders:`).
  static const String asset = 'shaders/ios27_backdrop.frag';

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Готовая программа или `null`, пока грузится или если загрузка не удалась.
  static ui.FragmentProgram? get program => _program;

  /// Грузит программу один раз. `null` — не вышло (тогда фон считает CPU-порт).
  static Future<ui.FragmentProgram?> load() => _loading ??= _load();

  /// Подмена загрузки в тестах (например, имитация сбоя).
  @visibleForTesting
  static Future<ui.FragmentProgram?> Function()? debugLoader;

  static Future<ui.FragmentProgram?> _load() async {
    try {
      final loader = debugLoader;
      if (loader != null) {
        return _program = await loader();
      }
      return _program = await ui.FragmentProgram.fromAsset(asset);
    } on Object catch (error) {
      debugPrint(
          'Ios27Backdrop: шейдер не загрузился, фон считает CPU: $error');
      return null;
    }
  }

  /// Забыть загруженное (тесты).
  @visibleForTesting
  static void debugReset() {
    _program = null;
    _loading = null;
  }
}

/// Прогревает фон при старте экрана: загружает программу и один раз рисует ею крошечную
/// текстуру, чтобы первый настоящий кадр не платил за сборку конвейера (Impeller собирает его
/// при первой отрисовке) и не был плоским `--bg`. Безопасно вызывать много раз и без ожидания.
Future<void> warmUpIos27Backdrop() async {
  final program = await Ios27BackdropShader.load();
  if (program == null) {
    return;
  }
  final shader = program.fragmentShader();
  for (var i = 0; i < kIos27BackdropUniformCount; i++) {
    shader.setFloat(i, i == 0 || i == 1 ? 8 : 0);
  }
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..shader = shader,
  );
  final picture = recorder.endRecording();
  // На Impeller `toImageSync` не рисует сразу, а ставит снимок в очередь растрового потока и
  // держит картинку слабой ссылкой: dispose сразу после него отменяет снимок вместе со сборкой
  // конвейера. `await toImage` ждёт, пока растровый поток реально нарисует кадр 8×8.
  final ui.Image image;
  try {
    image = await picture.toImage(8, 8);
  } finally {
    picture.dispose();
    shader.dispose();
  }
  image.dispose();
}

/// Чем рисовать фон (для тестов).
@visibleForTesting
enum Ios27BackdropRendering {
  /// Шейдер в приложении, CPU-порт в `flutter test` (эталоны главной сняты с ним).
  auto,

  /// Всегда шейдер.
  shader,

  /// Всегда CPU-порт одним кадром.
  cpu,
}

/// Фон главной. Заполняет родителя; поверх рисует [child].
///
/// Цвета берутся из [Ios27Colors]: `--bg`, акцент провайдера, два орба и размытие (`palette()` доски,
/// app.js:410-413). Позиционирования внутри нет: виджет ложится в `Stack` экрана на всю площадь.
/// Касания слушаются `Listener(translucent)` вокруг всего содержимого, поэтому кнопки поверх
/// получают тапы без перехвата, а фон узнаёт о каждом пальце (bg.js:203).
class Ios27Backdrop extends StatefulWidget {
  const Ios27Backdrop({
    super.key,
    this.state = Ios27BackdropState.off,
    this.child,
    @visibleForTesting this.debugMotion,
  });

  /// Состояние VPN: от него зависит яркость листов.
  final Ios27BackdropState state;

  final Widget? child;

  /// Физика снаружи, чтобы тест видел `t`, `on`, `e`, `shift`.
  final Ios27BackdropMotion? debugMotion;

  /// Чем рисовать; по умолчанию шейдер, в `flutter test` CPU.
  @visibleForTesting
  static Ios27BackdropRendering debugRendering = Ios27BackdropRendering.auto;

  /// Первое появление уже сыграно (`S.first`, bg.js:134): один раз на процесс.
  static bool _introPlayed = false;

  /// Сбрасывает «первое появление» (тесты).
  @visibleForTesting
  static void debugResetIntro() => _introPlayed = false;

  static bool get _useShader => switch (debugRendering) {
        Ios27BackdropRendering.shader => true,
        Ios27BackdropRendering.cpu => false,
        // В `flutter test` без явной просьбы остаётся CPU-порт: golden-ы главной байт-в-байт.
        Ios27BackdropRendering.auto =>
          !Platform.environment.containsKey('FLUTTER_TEST'),
      };

  @override
  State<Ios27Backdrop> createState() => _Ios27BackdropState();
}

class _Ios27BackdropState extends State<Ios27Backdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ios27BackdropMotion _motion =
      widget.debugMotion ?? Ios27BackdropMotion();
  final _Repaint _repaint = _Repaint();
  late final _BackdropView _view = _BackdropView(_motion);
  late final Ticker _ticker;

  Duration? _lastElapsed;
  int? _pointer;
  bool _suspended = false;
  bool _reduce = false;
  late final bool _wantShader = Ios27Backdrop._useShader;
  bool _shaderFailed = false;

  // CPU-путь: какой кадр заказан, чтобы не заказывать его повторно.
  Ios27BackdropSpec? _cpuSpec;
  int _cpuSerial = 0;

  bool get _shaderActive => _wantShader && !_shaderFailed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    if (_wantShader) {
      unawaited(_loadShader());
    }
  }

  Future<void> _loadShader() async {
    final program = await Ios27BackdropShader.load();
    if (!mounted) {
      return;
    }
    if (program == null) {
      // Запасной путь: никаких кадров, один CPU-снимок текущей цели.
      _shaderFailed = true;
      _stopTicker();
      _motion.snapStill();
      _syncCpu();
      _repaint.poke();
      return;
    }
    _view.program = program;
    _repaint.poke();
    unawaited(warmUpIos27Backdrop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final first = _view.colors == null;
    _view.colors = Ios27Colors.of(context);
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (first) {
      _motion.onT = widget.state.target;
      if (_shaderActive && !_reduce && !Ios27Backdrop._introPlayed) {
        // Первое появление: яркость растёт с нуля, листы расступаются от кнопки.
        Ios27Backdrop._introPlayed = true;
        _motion
          ..on = 0
          ..intro();
      } else {
        _motion.on = _motion.onT;
        if (_shaderActive) {
          Ios27Backdrop._introPlayed = true;
        }
      }
    }
    _applyMotion();
    if (!_shaderActive) {
      _syncCpu();
    }
    _repaint.poke();
  }

  @override
  void didUpdateWidget(Ios27Backdrop old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      final from = _motion.on;
      _motion.onT = widget.state.target;
      if (_shaderActive) {
        _applyMotion();
      } else {
        // Запасной путь: без движения, но время сдвигается как за переход доски (B2).
        if (!_reduce && from != _motion.onT) {
          _motion.t = ios27BackdropAdvance(
            t: _motion.t,
            from: from,
            to: _motion.onT,
          ).t;
        }
        _motion.on = _motion.onT;
        _syncCpu();
      }
      _repaint.poke();
    }
  }

  /// Согласует тикер с состоянием: в Reduce Motion кадров нет, иначе будим, если есть что двигать.
  void _applyMotion() {
    if (!_shaderActive) {
      return;
    }
    if (_reduce) {
      _motion.snapStill();
      _stopTicker();
      return;
    }
    // Тикер будим только если есть что двигать: смена зависимостей (тема, MediaQuery) в покое
    // не должна заводить кадры.
    if (_motion.moving) {
      _kick();
    }
  }

  /// `kick()` (bg.js:168-171): кадры идут, пока что-то движется.
  void _kick() {
    if (_suspended || _ticker.isActive || !mounted) {
      return;
    }
    _lastElapsed = null;
    _ticker.start();
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastElapsed = null;
  }

  void _onTick(Duration elapsed) {
    // Первый кадр после пробуждения идёт на один такт, как у доски (S.last = now).
    final dt = _lastElapsed == null
        ? 1 / 60
        : (elapsed - _lastElapsed!).inMicroseconds /
            Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    final more = _motion.step(dt);
    _repaint.poke();
    if (!more) {
      _stopTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `!document.hidden` (bg.js:166): в фоне кадров нет, после возврата дорисовываем остаток.
    final away = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (away == _suspended) {
      return;
    }
    _suspended = away;
    if (away) {
      _stopTicker();
    } else if (_shaderActive && !_reduce && _motion.moving) {
      _kick();
    }
  }

  // --- CPU-путь ---------------------------------------------------------------------------

  void _syncCpu() {
    final colors = _view.colors;
    if (colors == null || !mounted) {
      return;
    }
    final next = Ios27BackdropSpec.fromColors(
      colors,
      on: _motion.on,
      t: _motion.t,
    );
    if (next == _cpuSpec) {
      return;
    }
    _cpuSpec = next;
    final serial = ++_cpuSerial;
    unawaited(
      Ios27BackdropRenderer.image(next).then((image) {
        if (!mounted || serial != _cpuSerial) {
          return;
        }
        _view.setCpuImage(image.clone());
        _repaint.poke();
      }),
    );
  }

  // --- Касания ----------------------------------------------------------------------------

  bool get _touchEnabled => _shaderActive && !_reduce;

  /// Нормированная точка касания: Y снизу вверх, как `point()` доски (bg.js:176-178).
  (double, double, double)? _normalized(PointerEvent event) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    final size = box.size;
    return (
      event.localPosition.dx / size.width,
      1 - event.localPosition.dy / size.height,
      size.width / size.height,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_touchEnabled || _pointer != null) {
      return;
    }
    final n = _normalized(event);
    if (n == null) {
      return;
    }
    _pointer = event.pointer;
    _motion.pointerDown(n.$1, n.$2, event.timeStamp.inMicroseconds / 1000);
    _kick();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final n = _normalized(event);
    if (n == null) {
      return;
    }
    _motion.pointerMove(
      n.$1,
      n.$2,
      event.timeStamp.inMicroseconds / 1000,
      n.$3,
    );
    _kick();
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _motion.pointerUp();
    // Затухание догоняют кадры: тикер уже идёт или просыпается здесь.
    _kick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cpuSerial++;
    _ticker.dispose();
    _view.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _BackdropPainter(_view, _repaint),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        ),
      );
}

/// Сигнал перерисовки фона: тик физики, смена цветов, готовность программы или CPU-кадра.
class _Repaint extends ChangeNotifier {
  void poke() => notifyListeners();
}

/// Всё, что нужно кисти: живёт в состоянии, кисть только читает.
class _BackdropView {
  _BackdropView(this.motion);

  final Ios27BackdropMotion motion;
  Ios27Colors? colors;
  ui.FragmentProgram? program;

  ui.Image? _cpu;
  ui.Image? _frame;
  List<double>? _frameKey;

  void setCpuImage(ui.Image image) {
    _cpu?.dispose();
    _cpu = image;
  }

  /// Кадр шейдера для текущей физики и цветов; кэшируется по uniform, поэтому перерисовки
  /// без движения (прокрутка поверх, смена кадра родителя) шейдер не запускают.
  ui.Image? shaderFrame(Size size) {
    final prog = program;
    final c = colors;
    if (prog == null || c == null || size.isEmpty) {
      return null;
    }
    // Размер текстуры = размер виджета в логических пикселях (вверх до целого): 1x, как холст доски.
    final w = math.max(1, size.width.ceil());
    final h = math.max(1, size.height.ceil());
    final spec = Ios27BackdropSpec.fromColors(c, on: motion.on, t: motion.t);
    final key = ios27BackdropUniforms(
      spec: spec,
      motion: motion,
      width: w.toDouble(),
      height: h.toDouble(),
    );
    if (_frame != null && listEquals(key, _frameKey)) {
      return _frame;
    }
    final shader = prog.fragmentShader();
    for (var i = 0; i < key.length; i++) {
      shader.setFloat(i, key[i]);
    }
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    shader.dispose();
    // Предыдущий кадр уже ушёл в слой: картинки считаются нативно, dispose Dart-дескриптора безопасен.
    _frame?.dispose();
    _frame = image;
    _frameKey = key;
    return image;
  }

  void dispose() {
    _cpu?.dispose();
    _frame?.dispose();
    _cpu = null;
    _frame = null;
  }

  ui.Image? get cpu => _cpu;
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.view, Listenable repaint) : super(repaint: repaint);

  final _BackdropView view;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Билинейная растяжка, как у холста доски на экране с dpr 2 (bg.js:131).
    final paint = Paint()..filterQuality = FilterQuality.low;
    final frame = view.shaderFrame(size);
    final image = frame ?? view.cpu;
    if (image == null) {
      final base = view.colors?.palette.bg;
      if (base != null) {
        canvas.drawRect(rect, Paint()..color = base);
      }
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => !identical(old.view, view);
}
