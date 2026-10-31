// Фон главной iOS: порт FRAG из canon/dropweb/bg.js:18-106 под Flutter (FragmentProgram).
// Формулы цвета, смешивание орбов и рябь кромок взяты 1:1; изменено только то, чего требует
// Flutter: точка входа `out vec4 fragColor`, координаты через FlutterFragCoord() и
// ось Y сверху вниз (у gl_FragCoord Y растёт вверх, поэтому uv.y переворачивается).
//
// Порядок uniform важен: Dart задаёт их через setFloat подряд в порядке объявления
// (uRes 2, uT, uTouch 3, uShift, uOn, uBase 3, uAcc 3, uOrb1 3, uOrb2 3, uSoft, uDark = 22 float).
#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uRes;
uniform float uT;
uniform vec3 uTouch;
uniform float uShift;
uniform float uOn;
uniform vec3 uBase;
uniform vec3 uAcc;
uniform vec3 uOrb1;
uniform vec3 uOrb2;
uniform float uSoft;
uniform float uDark;

out vec4 fragColor;

// Край листа k (0 — задний, 4 — передний) поперёк диагонали: одна большая S-волна
// вдоль листа и мелкая рябь. Передние листы сдвигаются сильнее задних — параллакс глубины
float edge(float u, float k) {
  return -1.35 + k * .58
    + .34 * sin(u * 1.25 + k * .7 + uT * .3)
    + .05 * sin(u * 3.7 - k * 1.3 - uT * .45)
    + (k + 1.) * .035 * uShift;
}

// Цвет листа: d — расстояние от его края внутрь, gap — до края листа перед ним
vec3 sheet(float d, float gap, float depth, float sweep, vec3 acc) {
  // blur из dropweb-theme (1 — чёткие орбы, 5 — диффузные) делает свет мягче и шире
  float lit = exp(-d * mix(2.6, 1.3, uSoft)); // свет на изгибе у края
  float curl = exp(-d * 14.) * .35;        // блик там, где лист загибается
  float rim = exp(-d * mix(120., 70., uSoft)); // тонкая кромка
  float shade = exp(-gap * 12.) * .6;      // тень переднего листа
  vec3 col;
  if (uDark > .5) {
    // Тело листа само несёт цвет (.2): при одном свете у кромки экран оставался чёрным
    float tone = .2 + lit * .6 + curl + sweep * .12 + depth * .06;
    col = uBase + mix(acc * .75, vec3(.8), .08) * tone * mix(.55, .85, uOn);
    col *= 1. - shade;
    col += mix(acc, vec3(1.), .5) * rim * mix(.35, .6, uOn);
  } else {
    // Светлая: пастельная бумага в цвете листа, тень складки темнее в том же цвете
    vec3 paper = mix(uBase, acc, mix(.16, .24, uOn) + depth * .06);
    vec3 deep = mix(uBase * .6, acc * .8, mix(.45, .6, uOn));
    float k = clamp((1. - lit) * .4 - curl * .6 + shade - sweep * .1, 0., 1.);
    col = mix(paper, deep, k);
    col = mix(col, vec3(1.), rim * .9);
  }
  return col;
}

vec3 mute(vec3 c) { return mix(vec3(dot(c, vec3(.3, .59, .11))), c, .8); }
// Палитра по t: 0 — orb1, .5 — акцент, 1 — orb2
vec3 tint(float t, vec3 c1, vec3 ca, vec3 c2) {
  return t < .5 ? mix(c1, ca, smoothstep(0., .5, t)) : mix(ca, c2, smoothstep(.5, 1., t));
}

void main() {
  vec2 fc = FlutterFragCoord().xy;
  // gl_FragCoord у bg.js растёт снизу вверх, у Flutter — сверху вниз
  vec2 uv = vec2(fc.x / uRes.x, 1. - fc.y / uRes.y);
  float asp = uRes.x / uRes.y;
  vec2 p = vec2((uv.x - .5) * asp, uv.y - .5) * 2.;
  vec2 t = vec2((uTouch.x - .5) * asp, uTouch.y - .5) * 2.;
  // Листы идут по диагонали снизу слева вверх направо, как на обоях
  vec2 du = normalize(vec2(.9, 1.));
  vec2 dv = vec2(du.y, -du.x);
  float u = dot(p, du), v = dot(p, dv);
  vec2 w = vec2(u - dot(t, du), v - dot(t, dv));
  // Под пальцем края выгибаются: листы расступаются, как жидкость
  float bump = uTouch.z * .22 * exp(-dot(w, w) * 5.);
  float sweep = smoothstep(-1.6, 1.8, u);
  // Цвета провайдера приглушены: обои Apple мягкие, неон спорил бы со стеклом и текстом
  vec3 c1 = mute(uOrb1), ca = mute(uAcc), c2 = mute(uOrb2);
  // Сглаживание края в полтора пикселя: без него на 2x-экране видны ступеньки
  float aa = 3. / uRes.y;

  // Сзади наперёд: каждый лист накрывает предыдущие по своей кромке
  float e = edge(u, 0.) + bump;
  // Цвет идёт по экрану сверху вниз (верх orb1, середина акцент, низ у кнопки orb2)
  // и чуть по глубине листа: только по глубине соседние листы почти одного цвета
  float yt = 1. - uv.y;
  vec3 col = sheet(2., e - v, 0., sweep, tint(yt * .8, c1, ca, c2));
  for (int j = 0; j < 5; j++) {
    float k = float(j);
    float en = j < 4 ? edge(u, k + 1.) + bump : 9.;
    float cov = smoothstep(-aa, aa, v - e);
    float depth = (k + 1.) / 5.;
    float pt = clamp(yt * .8 + depth * .25 - .05, 0., 1.);
    col = mix(col, sheet(max(v - e, 0.), en - v, depth, sweep, tint(pt, c1, ca, c2)), cov);
    e = en;
  }
  fragColor = vec4(col, 1.);
}
