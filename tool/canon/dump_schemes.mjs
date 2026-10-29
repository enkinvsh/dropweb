// Дамп эталонных цветов доски в test/m3e/fixtures/schemes.json.
// Запуск из корня репозитория: node tool/canon/dump_schemes.mjs
//
// Эталон считает собственный код доски: vendor/mcu/mcu.js (MCU bd811e4 без правок) и копия
// scheme()/homeVars()/schemeVars() из canon/dropweb/android.js. Строки `color-mix(in oklab,…)`
// превращаются в hex тем, что реально рисует Chromium (через Playwright), а не нашей формулой:
// иначе тест сверял бы Dart сам с собой.

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const BOARD = '/Users/mac/Documents/projects/canon/dropweb';
const PLAYWRIGHT = '/Users/mac/Documents/projects/dropweb-flow/node_modules/playwright/index.mjs';
const OUT = new URL('../../test/m3e/fixtures/schemes.json', import.meta.url);

const {
  Hct, argbFromHex, hexFromArgb, TonalPalette, MaterialDynamicColors,
  SchemeVibrant, SchemeTonalSpot, SchemeExpressive, SchemeNeutral, SchemeCmf,
} = await import(`${BOARD}/vendor/mcu/mcu.js`);
const { chromium } = await import(PLAYWRIGHT);

// ---- Копия из canon/dropweb/app.js, строки 66-82 (PROVIDERS, parseTheme). Не править ----
const PROVIDERS = [
  { name: 'DROPWEB', theme: 'fidelity,#29FF76,#000000,#2BFF7A,4' },
  { name: 'Голубой', theme: 'fidelity,#38BDF8,#6366F1,#22D3EE,3' },
  { name: 'Сиреневый', theme: 'fidelity,#A78BFA,#EC4899,#6366F1,4' },
  { name: 'Красный', theme: 'fidelity,#EF4444,#F59E0B,#BE185D,3' },
  { name: 'Янтарный', theme: 'fidelity,#F59E0B,#EF4444,#FACC15,4' },
  { name: 'Серый', theme: 'fidelity,#64748B,#0EA5E9,#94A3B8,2' },
];
const HEX = /^#?([0-9a-f]{6})([0-9a-f]{2})?$/i;
function parseTheme(header) {
  const [, a, o1, o2, b] = header.split(',').map((x) => x.trim());
  const hx = (v, fb) => (HEX.test(v || '') ? `#${v.replace('#', '').slice(0, 6).toUpperCase()}` : fb);
  const accent = hx(a, '#29FF76');
  return { accent, orb1: hx(o1, accent), orb2: hx(o2, accent), blur: Math.min(5, Math.max(1, Number(b) || 3)) };
}

// ---- Копия из canon/dropweb/android.js, строки 47-148. Не «улучшать» ----
const MDC = new MaterialDynamicColors();
const ROLES = [
  'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer', 'inversePrimary',
  'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
  'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
  'error', 'onError', 'errorContainer', 'onErrorContainer',
  'background', 'onBackground', 'surface', 'onSurface', 'surfaceVariant', 'onSurfaceVariant',
  'surfaceDim', 'surfaceBright', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
  'surfaceContainerHigh', 'surfaceContainerHighest', 'inverseSurface', 'inverseOnSurface',
  'outline', 'outlineVariant', 'scrim', 'shadow', 'surfaceTint',
];
const VARIANTS = {
  tonal_spot: [SchemeTonalSpot, '2025'], vibrant: [SchemeVibrant, '2025'],
  expressive: [SchemeExpressive, '2025'], neutral: [SchemeNeutral, '2025'],
};
const WARN = TonalPalette.fromInt(argbFromHex('#F59E0B'));
const schemes = new Map();

function scheme(seed, filter, dark) {
  const key = `${seed}|${filter}|${dark}`;
  if (!schemes.has(key)) {
    const [Make, spec] = VARIANTS[filter] || [SchemeCmf, '2026'];
    let hct;
    try { hct = Hct.fromInt(argbFromHex(seed)); } catch { hct = Hct.fromInt(argbFromHex('#29FF76')); }
    const s = new Make(hct, dark, 0, spec);
    const out = {};
    for (const r of ROLES) out[r] = hexFromArgb(MDC[r]().getArgb(s));
    const tame = (pal, max) => TonalPalette.fromHueAndChroma(pal.hue, Math.min(pal.chroma, max));
    const a1 = tame(s.primaryPalette, 36), a2 = tame(s.secondaryPalette, 16);
    out.icon = dark
      ? { fg: hexFromArgb(a1.tone(80)), bg: hexFromArgb(a2.tone(20)) }
      : { fg: hexFromArgb(a1.tone(30)), bg: hexFromArgb(a1.tone(90)) };
    schemes.set(key, out);
  }
  return schemes.get(key);
}

const OK = TonalPalette.fromInt(argbFromHex('#22C55E'));

// Единственное отличие от android.js: возвращает объект {ключ: значение}, а не строку
// `--dr-k:v;…` (последняя строка функции) -- так проще раскладывать в JSON
function homeVars(seed, s, dark) {
  let hct;
  try { hct = Hct.fromInt(argbFromHex(seed)); } catch { hct = Hct.fromInt(argbFromHex('#29FF76')); }
  const N = TonalPalette.fromHueAndChroma(hct.hue, 4);
  const P = TonalPalette.fromHueAndChroma(hct.hue, Math.max(24, hct.chroma));
  const t = (p, x) => hexFromArgb(p.tone(x));
  const mix = (a, b, k) => `color-mix(in oklab,${a},${b} ${k}%)`;
  const G = TonalPalette.fromHueAndChroma(hct.hue, 0);
  const sc = s.secondaryContainer, onSc = s.onSecondaryContainer;
  const base = {
    bg: t(N, dark ? 6 : 97), card: sc, ink: onSc, ink2: mix(onSc, sc, 12), line: mix(sc, onSc, 16),
    ok: hexFromArgb(OK.tone(dark ? 76 : 48)), 'dot-off': t(G, dark ? 56 : 62),
  };
  const pc = s.primaryContainer, onPc = s.onPrimaryContainer;
  const C = TonalPalette.fromHueAndChroma(hct.hue, Math.min(24, Math.max(8, hct.chroma / 2)));
  const calm = { 'sh-a': t(C, dark ? 10 : 94), 'sh-b': t(C, dark ? 14 : 88), 'sh-c': t(C, dark ? 19 : 82) };
  const live = dark
    ? { flood: t(P, 14), 'on-flood': t(P, 90), 'lv-a': mix(pc, t(P, 14), 80), 'lv-b': mix(pc, t(P, 14), 66), 'lv-c': mix(pc, t(P, 14), 52), 'hero-on': pc, 'on-hero-on': onPc }
    : { flood: pc, 'on-flood': onPc, 'lv-a': mix(pc, '#fff', 22), 'lv-b': mix(pc, onPc, 9), 'lv-c': mix(pc, onPc, 20), 'hero-on': onPc, 'on-hero-on': pc };
  return { ...base, ...calm, ...live };
}

// Предупреждения из schemeVars() (android.js 142-148): только три переменные --dr-warn*
function warnVars(dark) {
  const w = (t) => hexFromArgb(WARN.tone(t));
  return { warn: w(dark ? 80 : 40), 'warn-container': w(dark ? 30 : 90), 'on-warn-container': w(dark ? 90 : 10) };
}
// ---- конец копии ----

// ---- Разрешение color-mix тем, что рисует Chromium ----
const browser = await chromium.launch({ headless: true });
let resolveMix;
try {
  const page = await browser.newPage();
  await page.setContent('<div id="probe"></div><canvas id="c" width="1" height="1"></canvas>');
  resolveMix = async (exprs) => page.evaluate((list) => {
    const probe = document.getElementById('probe');
    const ctx = document.getElementById('c').getContext('2d', { willReadFrequently: true });
    return list.map((expr) => {
      probe.style.background = '';
      probe.style.background = expr;
      const computed = getComputedStyle(probe).backgroundColor;
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = '#000';
      ctx.fillStyle = computed;
      ctx.fillRect(0, 0, 1, 1);
      const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data;
      const h = (v) => v.toString(16).padStart(2, '0');
      return { computed, hex: `#${h(r)}${h(g)}${h(b)}`, alpha: a };
    });
  }, exprs);

  const cases = [];
  const pending = new Set();
  const addCase = (c) => { cases.push(c); };

  const accents = PROVIDERS.map((p) => ({ name: p.name, ...parseTheme(p.theme), filter: p.theme.split(',')[0].trim() }));

  for (const p of accents) {
    for (const dark of [false, true]) {
      const s = scheme(p.accent, p.filter, dark);
      const { icon, ...roles } = s;
      const home = { ...homeVars(p.accent, s, dark), ...warnVars(dark) };
      for (const v of Object.values(home)) if (v.startsWith('color-mix(')) pending.add(v);
      addCase({ id: `${p.name}|${p.accent}|${p.filter}|${dark ? 'dark' : 'light'}`, kind: 'provider', seed: p.accent, filter: p.filter, dark, roles, icon, home });
    }
  }
  for (const filter of ['tonal_spot', 'vibrant', 'expressive', 'neutral']) {
    for (const p of accents) {
      for (const dark of [false, true]) {
        const { icon, ...roles } = scheme(p.accent, filter, dark);
        addCase({ id: `${filter}|${p.accent}|${dark ? 'dark' : 'light'}`, kind: 'filter', seed: p.accent, filter, dark, roles, icon });
      }
    }
  }

  const list = [...pending];
  const resolved = await resolveMix(list);
  const byExpr = new Map(list.map((e, i) => [e, resolved[i]]));
  for (const r of resolved) if (r.alpha !== 255) throw new Error(`альфа не 255: ${JSON.stringify(r)}`);

  // home: {ключ: {hex, expr?}} -- для mix хранится и выражение, и hex из Chromium
  for (const c of cases) {
    if (!c.home) continue;
    c.home = Object.fromEntries(Object.entries(c.home).map(([k, v]) => [
      k,
      v.startsWith('color-mix(') ? { hex: byExpr.get(v).hex, expr: v, computed: byExpr.get(v).computed } : { hex: v },
    ]));
  }

  mkdirSync(dirname(fileURLToPath(OUT)), { recursive: true });
  writeFileSync(OUT, JSON.stringify({
    source: 'tool/canon/dump_schemes.mjs; canon/dropweb/vendor/mcu/mcu.js + android.js; Chromium для color-mix',
    chromium: browser.version(),
    cases,
  }, null, 1) + '\n');
  console.log(`кейсов: ${cases.length}, уникальных color-mix: ${list.length}, Chromium ${browser.version()}`);
} finally {
  await browser.close();
}
