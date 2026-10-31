#!/usr/bin/env node
// Генератор lib/ui/ios27/theme/tokens.g.dart: токены iOS-колонки доски canon/dropweb, снятые из браузера.
// Запуск из корня репозитория: node tool/canon/gen_ios_tokens.mjs
//
// Что делает: поднимает статику canon на 127.0.0.1:8744 (порт закреплён за этим генератором; 8727, 8740,
// 8741, 8742, 8765, 8799 заняты другими задачами), открывает доску с iOS-колонкой в Chromium
// (Playwright из dropweb-flow) и читает ВЫЧИСЛЕННЫЕ значения всех пользовательских свойств корня
// `[data-col="ios"] .app` — не текст CSS:
//   цвета      светлая / тёмная / «Увеличение контраста» × обе темы (4 набора);
//   длины      радиусы, отступы, размеры (px);
//   шрифт      размер, интерлиньяж, насыщенность, трекинг стилей `.t-*` (tokens.css:104-113);
//   стекло     радиус, размытие, насыщенность и слои заливки каждого варианта `.glass*`,
//              плотная замена при «Уменьшении прозрачности» (glass.css);
//   движение   пружины `--spring-*` (подбор параметров SwiftUI по таблице linear()), кривая
//              `--ease-out`, длительности и безразмерные константы motion.js.
//
// Почему цвет читается строкой computed style, а не пикселем canvas, как в shoot_board.mjs: canvas хранит
// цвет с предумноженной альфой в 8 бит, и у полупрозрачных цветов каналы плывут (#3C3C432E читается как
// #3D3D432E, #78788033 как #78788233). Строка `rgba(r, g, b, a)` точна. Пиксель canvas остаётся
// перекрёстной проверкой: у непрозрачных цветов он обязан совпасть, у полупрозрачных — совпасть
// с предумноженным округлением точного цвета.
//
// Что НЕ токен и не читается: свойства, выставленные на корне инлайном (--accent, --on-accent, --accent-soft,
// --orb1, --orb2, --lg, --knob-lens, --thumb-lens) — это состояние прототипа; акцент считает accent.dart.
// Свойства чужих таблиц (Android-колонка кладёт на :root около 400 своих --md-*) отсекаются по имени файла.
import { execFileSync, spawn } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '/Users/mac/Documents/projects/dropweb-flow/node_modules/playwright/index.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = process.env.IOS27_TOKENS_OUT ? resolve(process.env.IOS27_TOKENS_OUT) : resolve(ROOT, 'lib/ui/ios27/theme/tokens.g.dart');
const CANON = '/Users/mac/Documents/projects/canon';
const PORT = 8744;
const URL = `http://127.0.0.1:${PORT}/dropweb/`;
const COL = '[data-col="ios"] .app';
const SHEETS = /\/dropweb\/(tokens|app|glass)\.css$/;

// ---------- Сервер ----------
let server = null;
function stopServer() {
  if (server && server.exitCode === null) { try { server.kill('SIGKILL'); } catch { /* уже мёртв */ } }
  server = null;
}
process.on('exit', stopServer);
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => { stopServer(); process.exit(130); });
process.on('uncaughtException', (e) => { console.error(e); stopServer(); process.exit(1); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function startServer() {
  // Если на порту кто-то слушает — это чужой процесс, его не трогаем и не подменяем
  const busy = await fetch(`http://127.0.0.1:${PORT}/`).then(() => true, () => false);
  if (busy) throw new Error(`порт ${PORT} уже занят — остановитесь, это чужой процесс`);
  server = spawn('python3', ['-c',
    `import http.server as h; h.ThreadingHTTPServer.request_queue_size=128; h.test(h.SimpleHTTPRequestHandler, h.ThreadingHTTPServer, port=${PORT}, bind='127.0.0.1')`],
  { cwd: CANON, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) {
    if (await fetch(URL).then((r) => r.ok, () => false)) return;
    await sleep(100);
  }
  throw new Error('статический сервер не поднялся');
}

// ---------- Код внутри страницы ----------
// Самодостаточная функция: выполняется в браузере. dark — тема, по ней раскрывается light-dark() в тексте.
function collectInPage({ sheetsSrc, dark }) {
  const sheetRe = new RegExp(sheetsSrc);
  const root = document.querySelector('[data-col="ios"] .app');
  const cs = getComputedStyle(root);
  const out = { theme: document.documentElement.dataset.theme, names: [], inline: [], colors: {}, colorsCanvas: {}, lengths: {}, times: {}, easings: {}, fonts: {}, other: {}, text: {}, glass: {}, glassTint: null, controls: {}, supports: {} };

  // --- имена свойств в порядке объявления, только из таблиц iOS-колонки ---
  const seen = new Set();
  const walk = (rules) => {
    for (const r of rules) {
      if (r.selectorText && r.style) {
        let hit = false;
        try { hit = !!root.closest(r.selectorText); } catch { /* псевдоэлемент: корню не подходит */ }
        if (hit) for (const p of r.style) if (p.startsWith('--') && !seen.has(p)) { seen.add(p); out.names.push(p); }
      } else if (r.cssRules) walk(r.cssRules);
    }
  };
  for (const sh of document.styleSheets) if (sheetRe.test(sh.href || '')) walk(sh.cssRules);
  for (const p of root.style) if (p.startsWith('--')) out.inline.push(p);

  // --- пробы ---
  const probe = document.createElement('div');
  probe.style.cssText = 'position:absolute;width:1px;height:1px;transition:none;pointer-events:none;visibility:hidden';
  root.append(probe);
  const cv = document.createElement('canvas');
  cv.width = cv.height = 1;
  const g = cv.getContext('2d', { willReadFrequently: true });

  const parseColor = (s) => {
    let m = s.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/);
    let k = 1;
    if (!m) { m = s.match(/^color\(srgb\s+([\d.e+-]+)\s+([\d.e+-]+)\s+([\d.e+-]+)(?:\s*\/\s*([\d.e+-]+%?))?\s*\)$/); k = 255; }
    if (!m) return null;
    const al = m[4] == null ? 1 : m[4].endsWith('%') ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
    return [Math.round(parseFloat(m[1]) * k), Math.round(parseFloat(m[2]) * k), Math.round(parseFloat(m[3]) * k), Math.round(al * 255)];
  };
  const hex8 = (c) => `#${c.map((v) => v.toString(16).padStart(2, '0').toUpperCase()).join('')}`;
  const canvasPx = (css) => { g.clearRect(0, 0, 1, 1); g.fillStyle = '#000'; g.fillStyle = css; g.fillRect(0, 0, 1, 1); return [...g.getImageData(0, 0, 1, 1).data]; };
  // Цвет любого CSS-значения (в том числе `var(--x)` и `light-dark(...)`): [r,g,b,a], 0..255. Строка computed style точна;
  // canvas — только перекрёстная проверка
  const colorOf = (css) => {
    probe.style.color = '';
    probe.style.color = css;
    const str = getComputedStyle(probe).color;
    const c = parseColor(str);
    if (!c) throw new Error(`цвет «${css}» вычислен в неразбираемую форму «${str}»`);
    return { c, canvas: canvasPx(str) };
  };
  const px = (css) => { probe.style.width = ''; probe.style.width = css; return parseFloat(getComputedStyle(probe).width); };

  // --- раскрытие light-dark() в тексте (для слоёв стекла): балансируем скобки ---
  const splitTop = (s) => {
    const parts = []; let depth = 0, cur = '';
    for (const ch of s) {
      if (ch === '(') depth++;
      if (ch === ')') depth--;
      if (ch === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; } else cur += ch;
    }
    parts.push(cur.trim());
    return parts;
  };
  const pickLD = (s) => {
    for (;;) {
      const i = s.indexOf('light-dark(');
      if (i < 0) return s;
      let j = i + 'light-dark('.length, depth = 1;
      while (depth && j < s.length) { if (s[j] === '(') depth++; if (s[j] === ')') depth--; j++; }
      const [l, d] = splitTop(s.slice(i + 'light-dark('.length, j - 1));
      s = s.slice(0, i) + (dark ? d : l) + s.slice(j);
    }
  };

  // --- классификация и чтение свойств корня ---
  for (const n of out.names) {
    if (out.inline.includes(n)) continue;
    const v = cs.getPropertyValue(n).trim();
    if (CSS.supports('color', v)) {
      const r = colorOf(`var(${n})`);
      out.colors[n] = hex8(r.c);
      out.colorsCanvas[n] = hex8(r.canvas);
    } else if (/^-?\d*\.?\d+px$/.test(v)) out.lengths[n] = px(`var(${n})`);
    else if (/^\d*\.?\d+ms$/.test(v)) out.times[n] = parseFloat(v);
    else if (/^\d*\.?\d+s$/.test(v)) out.times[n] = parseFloat(v) * 1000;
    else if (/^(linear|cubic-bezier)\(/.test(v)) out.easings[n] = v;
    else if (/^"/.test(v)) out.fonts[n] = v;
    else out.other[n] = v;
  }

  // --- стили текста: классы .t-* из tokens.css ---
  const roles = [];
  const walkT = (rules) => {
    for (const r of rules) {
      if (r.selectorText) { const m = r.selectorText.match(/^\.(t-[a-z0-9]+)$/); if (m && !roles.includes(m[1])) roles.push(m[1]); } else if (r.cssRules) walkT(r.cssRules);
    }
  };
  for (const sh of document.styleSheets) if (sheetRe.test(sh.href || '')) walkT(sh.cssRules);
  for (const cls of roles) {
    const el = document.createElement('span');
    el.className = cls;
    root.append(el);
    const s = getComputedStyle(el);
    const ls = s.letterSpacing === 'normal' ? 0 : parseFloat(s.letterSpacing);
    out.text[cls] = { size: parseFloat(s.fontSize), lineHeight: parseFloat(s.lineHeight), weight: Number(s.fontWeight), tracking: ls, family: s.fontFamily };
    el.remove();
  }

  // --- варианты стекла ---
  const VARIANTS = [['base', 'glass'], ['md', 'glass glass--md'], ['widget', 'glass glass--widget'], ['lg', 'glass glass--lg'], ['tint', 'glass glass--tint'], ['inactive', 'glass glass--inactive']];
  for (const [id, cls] of VARIANTS) {
    const el = document.createElement('div');
    el.className = cls;
    el.style.cssText = 'position:absolute;width:10px;height:10px;visibility:hidden';
    root.append(el);
    const s = getComputedStyle(el);
    const bg = pickLD(s.getPropertyValue('--g-bg').trim());
    const layers = [];
    let tint = false;
    for (const part of splitTop(bg)) {
      if (/color-mix\(|var\(/.test(part)) { tint = true; continue; }
      const m = part.match(/^linear-gradient\(([^,]+),/);
      layers.push(hex8(colorOf(m ? m[1].trim() : part).c));
    }
    out.glass[id] = { radius: parseFloat(s.borderTopLeftRadius), blur: parseFloat(s.getPropertyValue('--g-blur')), sat: parseFloat(s.getPropertyValue('--g-sat')), layers, tint };
    el.remove();
  }
  // Доля цвета у тонированного стекла лежит в тексте правила (color-mix с var(--accent) считать нечем): [светлая, тёмная]
  const walkG = (rules) => {
    for (const r of rules) {
      // В @media (prefers-reduced-transparency) то же правило задаёт `var(--accent)`: берём только то, где есть --g-tint
      if (r.selectorText === '.glass--tint' && /--g-tint/.test(r.style.getPropertyValue('--g-bg'))) {
        out.glassTint = [...r.style.getPropertyValue('--g-bg').matchAll(/calc\(var\(--g-tint\) \* (\d+)%\)/g)].map((m) => Number(m[1]) / 100);
      } else if (r.cssRules) walkG(r.cssRules);
    }
  };
  for (const sh of document.styleSheets) if (sheetRe.test(sh.href || '')) walkG(sh.cssRules);

  // --- контроли пробы ---
  const k1 = colorOf('#FF3B30');
  out.controls.opaque = { got: hex8(k1.c), canvas: hex8(k1.canvas), want: '#FF3B30FF' };
  const k2 = colorOf('#78788033');
  out.controls.translucent = { got: hex8(k2.c), canvas: hex8(k2.canvas), want: '#78788033' };
  out.controls.rtMedia = matchMedia('(prefers-reduced-transparency: reduce)').matches;
  out.controls.contrastMedia = matchMedia('(prefers-contrast: more)').matches;
  out.controls.motionMedia = matchMedia('(prefers-reduced-motion: reduce)').matches;
  out.supports = { colorLightDark: CSS.supports('color', 'light-dark(#000, #fff)') };
  probe.remove();
  return out;
}

// mode: normal | contrast (prefers-contrast: more) | reduceTransparency (CDP)
async function readState(browser, theme, mode) {
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 1200 },
    deviceScaleFactor: 2,
    colorScheme: theme,
    // Не 'reduce': под ним tokens.css обнуляет --spring-*-dur в 1ms
    reducedMotion: 'no-preference',
    contrast: mode === 'contrast' ? 'more' : 'no-preference',
    locale: 'ru-RU',
  });
  try {
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript((t) => {
      localStorage.setItem('dw-board:v1', JSON.stringify({ screen: 'home-off', theme: t, provider: 0, worst: false, view: 'ios' }));
    }, theme);
    if (mode === 'reduceTransparency') {
      const cdp = await ctx.newCDPSession(page);
      await cdp.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-transparency', value: 'reduce' }] });
    }
    await page.goto(URL);
    await page.waitForSelector(COL, { state: 'attached' });
    await page.evaluate(() => document.fonts.ready.then(() => 0));
    const data = await page.evaluate(collectInPage, { sheetsSrc: SHEETS.source, dark: theme === 'dark' });
    if (data.theme !== theme) throw new Error(`${theme}/${mode}: data-theme=${data.theme}`);
    if (errors.length) console.warn(`  ! ${theme}/${mode}: ошибки страницы: ${errors.join(' | ')}`);
    // Эмуляции действительно включились (иначе «контрастные» значения были бы обычными)
    if (mode === 'contrast' && !data.controls.contrastMedia) throw new Error('prefers-contrast: more не включился');
    if (mode === 'reduceTransparency' && !data.controls.rtMedia) throw new Error('prefers-reduced-transparency: reduce не включился');
    if (mode === 'normal' && (data.controls.contrastMedia || data.controls.rtMedia || data.controls.motionMedia)) throw new Error('в обычном режиме включена эмуляция');
    if (!data.supports.colorLightDark) throw new Error('Chromium без light-dark(): значения не разрешить');
    return data;
  } finally {
    await ctx.close();
  }
}

// ---------- Проверки пробы ----------
const hexParts = (h) => [1, 3, 5, 7].map((i) => (h.length > i ? parseInt(h.slice(i, i + 2), 16) : 255));
// То, что даёт canvas: предумноженная 8-битная запись и обратно
const premulRoundTrip = (hex) => {
  const [r, g, b, a] = hexParts(hex);
  if (a === 255) return hex;
  if (a === 0) return '#00000000';
  const f = (v) => Math.round(Math.round((v * a) / 255) * 255 / a);
  return `#${[f(r), f(g), f(b), a].map((v) => Math.min(255, v).toString(16).padStart(2, '0').toUpperCase()).join('')}`;
};

function verifyProbe(state, label) {
  const k = state.controls;
  // Положительный контроль: известные цвета читаются без потерь
  if (k.opaque.got !== k.opaque.want || k.opaque.canvas !== k.opaque.want) throw new Error(`${label}: контроль #FF3B30 прочитан как ${k.opaque.got} / canvas ${k.opaque.canvas}`);
  if (k.translucent.got !== k.translucent.want) throw new Error(`${label}: контроль #78788033 прочитан как ${k.translucent.got}`);
  if (k.translucent.canvas !== premulRoundTrip(k.translucent.want)) throw new Error(`${label}: canvas-контроль ${k.translucent.canvas} не равен предумноженному округлению ${premulRoundTrip(k.translucent.want)}`);
  // Перекрёстная проверка всех цветов
  let lossy = 0;
  for (const [n, c] of Object.entries(state.colors)) {
    const cv = state.colorsCanvas[n];
    if (cv === c) continue;
    if (cv !== premulRoundTrip(c)) throw new Error(`${label}: ${n}: строка ${c}, canvas ${cv}, предумноженное округление ${premulRoundTrip(c)}`);
    lossy++;
  }
  return lossy;
}

// ---------- Пружины ----------
// Таблица linear() — 41 отсчёт пружины SwiftUI .spring(duration:bounce:) за время затухания до 0.1 %.
// Подбираем (duration, bounce) перебором и требуем малой невязки: иначе параметры не «выражаются».
function springSamples(str) {
  const m = str.match(/^linear\((.*)\)$/);
  if (!m) throw new Error(`не linear(): ${str.slice(0, 40)}`);
  return m[1].split(',').map((x) => parseFloat(x));
}
// Шаг пружины с единичной массой, начальным смещением 1 → положение 1 - x(t)
function springValue(t, duration, bounce) {
  const w = (2 * Math.PI) / duration, z = 1 - bounce;
  if (Math.abs(z - 1) < 1e-9) return 1 - Math.exp(-w * t) * (1 + w * t);
  const wd = w * Math.sqrt(1 - z * z);
  return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + ((z * w) / wd) * Math.sin(wd * t));
}
function fitSpring(samples, settleMs) {
  let best = { err: Infinity };
  for (let d = 0.05; d <= 1.5001; d += 0.0025) {
    for (let b = 0; b <= 0.9001; b += 0.0025) {
      let err = 0;
      for (let i = 0; i < samples.length; i++) {
        const t = (i / (samples.length - 1)) * (settleMs / 1000);
        err = Math.max(err, Math.abs(springValue(t, d, b) - samples[i]));
      }
      if (err < best.err) best = { err, duration: d, bounce: b };
    }
  }
  return { duration: Number(best.duration.toFixed(4)), bounce: Number(best.bounce.toFixed(4)), err: best.err };
}

// ---------- Константы motion.js ----------
// Безразмерные числа, которых нет в CSS: каждое сверяется с исходником по регулярному выражению, поэтому
// правка доски без правки генератора роняет генерацию, а не молча расходится.
const MOTION_CONSTS = [
  ['fadeMs', 180, /duration: 180, easing: 'ease-out', fill: show \? 'none'/, 'fade(): короткое угасание вместо движения (Reduce Motion), мс'],
  ['vanishMs', 300, /duration: 300, easing: 'ease-out', fill: 'forwards'/, 'vanish(): снимок уходит в размытие, мс'],
  ['vanishScale', 0.96, /scale: 0\.96/, 'vanish(): масштаб в конце'],
  ['vanishBlur', 6, /opacity: 0, filter: 'blur\(6px\)', scale: 0\.96/, 'vanish(): размытие в конце, px'],
  ['zoomOutDurationFactor', 0.75, /const d = duration \* 0\.75/, 'zoomOut(): доля длительности пружины smooth'],
  ['zoomIconScale', 1.6, /scale: 1\.6/, 'zoomIn/zoomOut: масштаб значка кнопки внутри растущего стекла'],
  ['zoomIconBlur', 6, /filter: 'blur\(6px\)', scale: 1\.6/, 'zoomIn/zoomOut: размытие значка кнопки, px'],
  ['morphScale', 0.8, /scale: 0\.8/, 'morph(): масштаб уходящего и приходящего содержимого'],
  ['morphBlur', 6, /const blur = \(on\) => \(on \? 'blur\(6px\)'/, 'morph(): размытие при замене, px'],
  ['emergeFrom', 0.94, /'--g-in': 0\.94/, 'emerge(): начальный масштаб нового стекла'],
  ['rollOutDurationFactor', 0.6, /duration: duration \* 0\.6/, 'roll(): доля длительности у уходящей цифры'],
  ['rollOffsetEm', 0.6, /sign \* 0\.6\}em/, 'roll(): сдвиг цифры, em'],
  ['rollBlur', 3, /filter: 'blur\(3px\)'/, 'roll(): размытие цифры, px'],
  ['replaceIconScale', 0.5, /scale: icon \? 0\.5 : 0\.92/, 'appear(icon): начальный масштаб значка (symbolEffect .replace)'],
  ['replaceWordScale', 0.92, /scale: icon \? 0\.5 : 0\.92/, 'appear(word): начальный масштаб слова (blurReplace)'],
  ['replaceIconBlur', 4, /blur\(\$\{icon \? 4 : 6\}px\)/, 'appear(icon): размытие, px'],
  ['replaceWordBlur', 6, /blur\(\$\{icon \? 4 : 6\}px\)/, 'appear(word): размытие, px'],
  ['slideUnderFraction', 0.3, /const third = `\$\{-w \* 0\.3\}px 0`/, 'slide(): на какую долю ширины уходит нижний экран'],
  ['slideUnderOpacity', 0.6, /opacity: 0\.6, clipPath/, 'slide(): прозрачность нижнего экрана в конце'],
  ['rowFadeOffset', 0.35, /opacity: 1 \}, \{ opacity: 0, offset: 0\.35/, 'drop(): когда строка успевает погаснуть (доля пружины)'],
];

// ---------- Dart ----------
const camel = (s) => s.replace(/^--/, '').replace(/^t-/, '').replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
const dnum = (n) => { const v = Number(Number(n).toFixed(4)); return Number.isInteger(v) ? v.toFixed(1) : String(v); };
const argb = (h) => {
  const [r, g, b, a] = hexParts(h);
  return `Color(0x${[a, r, g, b].map((v) => v.toString(16).padStart(2, '0').toUpperCase()).join('')})`;
};
const ARGB_INT = (h) => { const [r, g, b, a] = hexParts(h); return ((a << 24) | (r << 16) | (g << 8) | b) >>> 0; };

async function main() {
  await startServer();
  const browser = await chromium.launch();
  let st;
  try {
    st = {
      light: await readState(browser, 'light', 'normal'),
      dark: await readState(browser, 'dark', 'normal'),
      lightHc: await readState(browser, 'light', 'contrast'),
      darkHc: await readState(browser, 'dark', 'contrast'),
      lightRt: await readState(browser, 'light', 'reduceTransparency'),
      darkRt: await readState(browser, 'dark', 'reduceTransparency'),
    };
  } finally {
    await browser.close().catch(() => {});
    stopServer();
  }

  // --- проверки ---
  const lossy = Object.fromEntries(Object.entries(st).map(([k, v]) => [k, verifyProbe(v, k)]));
  const colorNames = st.light.names.filter((n) => n in st.light.colors);
  for (const k of Object.keys(st)) {
    const names = st[k].names.filter((n) => n in st[k].colors);
    if (names.join() !== colorNames.join()) throw new Error(`${k}: набор цветовых свойств отличается от светлой темы`);
  }
  // Контроль «Увеличение контраста» действительно меняет значения (иначе набор ничего не добавил бы)
  if (st.light.colors['--red'] === st.lightHc.colors['--red']) throw new Error('в режиме повышенного контраста --red не изменился: эмуляция не подействовала');
  // Контроль «Уменьшение прозрачности»: у обычного стекла размытие обнуляется
  if (st.lightRt.glass.base.blur !== 0) throw new Error('при Reduce Transparency --g-blur не обнулился');
  if (st.light.glass.base.blur === 0) throw new Error('в обычном режиме --g-blur уже 0');

  const lengthNames = Object.keys(st.light.lengths);
  for (const n of lengthNames) if (st.light.lengths[n] !== st.dark.lengths[n]) throw new Error(`длина ${n} зависит от темы`);
  const fonts = st.light.fonts;
  if (!fonts['--font'] || !/^"Onest"/.test(fonts['--font'])) throw new Error(`--font не начинается с Onest: ${fonts['--font']}`);
  if (Object.keys(st.light.other).length) console.warn(`  ! свойства без разбора (в Dart не попадают): ${JSON.stringify(st.light.other)}`);

  // --- пружины ---
  const springs = [];
  for (const n of Object.keys(st.light.easings).filter((x) => x.startsWith('--spring-'))) {
    const id = n.replace('--spring-', '');
    const dur = st.light.times[`${n}-dur`];
    if (!dur) throw new Error(`у ${n} нет ${n}-dur`);
    const f = fitSpring(springSamples(st.light.easings[n]), dur);
    if (f.err > 0.005) throw new Error(`пружина ${id} не выражается параметрами SwiftUI: невязка ${f.err}`);
    springs.push({ id, dur, ...f });
  }
  const ease = st.light.easings['--ease-out'].match(/^cubic-bezier\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$/);
  if (!ease) throw new Error(`--ease-out не cubic-bezier: ${st.light.easings['--ease-out']}`);

  // --- константы motion.js ---
  const motionSrc = readFileSync(`${CANON}/dropweb/motion.js`, 'utf8');
  for (const [name, , re] of MOTION_CONSTS) if (!re.test(motionSrc)) throw new Error(`motion.js больше не содержит константу ${name} (${re})`);

  // --- текст ---
  const roles = Object.entries(st.light.text);
  for (const [cls, r] of roles) if (!/^"?Onest"?,/.test(r.family)) throw new Error(`${cls}: шрифт ${r.family}`);

  // --- стекло ---
  const variants = Object.keys(st.light.glass);
  const tintAlpha = st.light.glassTint;
  if (!tintAlpha || tintAlpha.length !== 2) throw new Error(`доля цвета у стекла tint не найдена: ${JSON.stringify(tintAlpha)}`);

  // --- коммит канона ---
  const git = (...a) => execFileSync('git', ['-C', CANON, ...a], { encoding: 'utf8' }).trim();
  const commit = git('rev-parse', '--short=8', 'HEAD');
  const dirty = git('status', '--short', '--', 'dropweb/tokens.css', 'dropweb/app.css', 'dropweb/glass.css', 'dropweb/motion.js') !== '';
  const stamp = dirty ? `${commit}+изменён` : commit;

  // --- вывод ---
  const L = [];
  const push = (...a) => L.push(...a);
  push(`// СГЕНЕРИРОВАНО tool/canon/gen_ios_tokens.mjs из canon/dropweb (tokens.css, app.css, glass.css, motion.js) ${stamp}. Не править руками.`);
  push('// Значения сняты из Chromium: вычисленные свойства корня iOS-колонки, не текст CSS. Цвет — #RRGGBB или');
  push('// #RRGGBBAA доски, здесь ARGB. Акцент провайдера (--accent, --on-accent, --accent-soft, --orb1, --orb2) сюда не входит:');
  push('// на доске он выставлен инлайном и считается в accent.dart.');
  push('');
  push("import 'dart:math' as math;");
  push('');
  push("import 'package:flutter/animation.dart';");
  push("import 'package:flutter/painting.dart';");
  push('');
  push("import '../../../enum/enum.dart';");
  push('');

  // Палитра
  push('/// Цветовые токены iOS-колонки одной темы. Поля названы по свойствам доски (`--label-2` -> `label2`).');
  push('class Ios27Palette {');
  push('  const Ios27Palette({');
  for (const n of colorNames) push(`    required this.${camel(n)},`);
  push('  });');
  push('');
  for (const n of colorNames) push(`  /// \`${n}\`.`, `  final Color ${camel(n)};`, '');
  push('  /// Значения по именам свойств доски (`--label` -> ARGB): сверка с colors.json эталона.');
  push('  Map<String, int> toVars() => {');
  for (const n of colorNames) push(`        '${n}': ${camel(n)}.toARGB32(),`);
  push('      };');
  push('}');
  push('');

  const palette = (name, s) => {
    push(`  static const Ios27Palette ${name} = Ios27Palette(`);
    for (const n of colorNames) push(`    ${camel(n)}: ${argb(s.colors[n])},`);
    push('  );');
    push('');
  };

  // Стекло
  push('/// Вариант стекла (`.glass`, `.glass--md`, ...) в одной теме. Слои заливки идут сверху вниз, как в CSS.');
  push('class Ios27GlassMaterial {');
  push('  const Ios27GlassMaterial({');
  push('    required this.radius,');
  push('    required this.blur,');
  push('    required this.saturation,');
  push('    required this.layers,');
  push('    this.opaque,');
  push('    this.tintAlpha,');
  push('  });');
  push('');
  push('  /// `border-radius`, px (капсула — 9999).');
  push('  final double radius;');
  push('');
  push('  /// `--g-blur`, px.');
  push('  final double blur;');
  push('');
  push('  /// `--g-sat`.');
  push('  final double saturation;');
  push('');
  push('  /// Слои `--g-bg` без цвета провайдера, сверху вниз.');
  push('  final List<Color> layers;');
  push('');
  push('  /// Плотная заливка при «Уменьшении прозрачности»; у tint её нет — там цвет акцента.');
  push('  final Color? opaque;');
  push('');
  push('  /// Доля акцента в заливке tint (`--g-tint` = 1); у остальных null.');
  push('  final double? tintAlpha;');
  push('}');
  push('');
  push('/// Все варианты стекла одной темы.');
  push('class Ios27GlassSet {');
  push('  const Ios27GlassSet({');
  for (const v of variants) push(`    required this.${v},`);
  push('  });');
  push('');
  const glassDoc = { base: '`.glass`: кнопки и капсулы', md: '`.glass--md`: листы и меню', widget: '`.glass--widget`: карточка главной', lg: '`.glass--lg`: алерты', tint: '`.glass--tint`: акцентная кнопка', inactive: '`.glass--inactive`: недоступное' };
  for (const v of variants) push(`  /// ${glassDoc[v] ?? v}.`, `  final Ios27GlassMaterial ${v};`, '');
  push('}');
  push('');

  const glassSet = (name, s, rt, tintIdx) => {
    push(`  static const Ios27GlassSet ${name} = Ios27GlassSet(`);
    for (const v of variants) {
      const g = s.glass[v];
      const flat = rt.glass[v];
      const opaque = !g.tint && flat.layers.length === 1 ? `, opaque: ${argb(flat.layers[0])}` : '';
      const ta = g.tint ? `, tintAlpha: ${dnum(tintAlpha[tintIdx])}` : '';
      push(`    ${v}: Ios27GlassMaterial(radius: ${dnum(g.radius)}, blur: ${dnum(g.blur)}, saturation: ${dnum(g.sat)}, layers: [${g.layers.map(argb).join(', ')}]${opaque}${ta}),`);
    }
    push('  );');
    push('');
  };

  push('/// Цвета, меры и стекло iOS-колонки.');
  push('abstract final class Ios27Tokens {');
  palette('light', st.light);
  palette('dark', st.dark);
  palette('lightIncreasedContrast', st.lightHc);
  palette('darkIncreasedContrast', st.darkHc);
  push('  /// Набор цветов темы; [increasedContrast] — «Увеличение контраста» (`MediaQuery.highContrast`).');
  push('  static Ios27Palette palette({required bool dark, bool increasedContrast = false}) => dark');
  push('      ? (increasedContrast ? darkIncreasedContrast : Ios27Tokens.dark)');
  push('      : (increasedContrast ? lightIncreasedContrast : light);');
  push('');
  glassSet('glassLight', st.light, st.lightRt, 0);
  glassSet('glassDark', st.dark, st.darkRt, 1);
  push('  /// Стекло темы.');
  push('  static Ios27GlassSet glass({required bool dark}) => dark ? glassDark : glassLight;');
  push('');
  for (const n of lengthNames) push(`  /// \`${n}\`, логических пикселей.`, `  static const double ${camel(n)} = ${dnum(st.light.lengths[n])};`, '');
  push('  /// `--font`: Onest, затем Twemoji для флагов и эмодзи.');
  push('  static String get fontFamily => FontFamily.onest.value;');
  push('');
  push('  /// Запасные гарнитуры: флаги и эмодзи рисует Twemoji, а не системный набор.');
  push('  static List<String> get fontFallback => [FontFamily.twEmoji.value];');
  push('}');
  push('');

  // Текст
  push('/// Стиль текста iOS (`.t-*` в tokens.css): кегль, интерлиньяж, насыщенность, трекинг.');
  push('class Ios27TextRole {');
  push('  const Ios27TextRole({');
  push('    required this.size,');
  push('    required this.lineHeight,');
  push('    required this.weight,');
  push('    required this.tracking,');
  push('  });');
  push('');
  push('  final double size;');
  push('');
  push('  /// Интерлиньяж, px.');
  push('  final double lineHeight;');
  push('  final int weight;');
  push('');
  push('  /// Разрядка, px (`letter-spacing` из em уже пересчитан браузером).');
  push('  final double tracking;');
  push('');
  push('  /// Множитель `TextStyle.height`: во Flutter высота строки — доля кегля.');
  push('  double get height => lineHeight / size;');
  push('');
  push('  FontWeight get fontWeight => FontWeight.values[weight ~/ 100 - 1];');
  push('}');
  push('');
  push('abstract final class Ios27Text {');
  for (const [cls, r] of roles) {
    push(`  /// \`.${cls}\`.`);
    push(`  static const ${camel(cls)} = Ios27TextRole(size: ${dnum(r.size)}, lineHeight: ${dnum(r.lineHeight)}, weight: ${r.weight}, tracking: ${dnum(r.tracking)});`);
  }
  push('');
  push('  /// Роль как [TextStyle] в Onest с Twemoji в запасных.');
  push('  static TextStyle style(Ios27TextRole role, {Color? color}) => TextStyle(');
  push('        fontFamily: FontFamily.onest.value,');
  push('        fontFamilyFallback: [FontFamily.twEmoji.value],');
  push('        fontSize: role.size,');
  push('        height: role.height,');
  push('        letterSpacing: role.tracking,');
  push('        fontWeight: role.fontWeight,');
  push('        color: color,');
  push('        // Строка по CSS делит свободное место поровну сверху и снизу.');
  push('        leadingDistribution: TextLeadingDistribution.even,');
  push('      );');
  push('}');
  push('');

  // Движение
  push('/// Пружина SwiftUI `.spring(duration:bounce:)`, подобранная по таблице linear() доски.');
  push('class Ios27SpringSpec {');
  push('  const Ios27SpringSpec({required this.duration, required this.bounce, required this.settle});');
  push('');
  push('  /// Параметр `duration` SwiftUI, секунды.');
  push('  final double duration;');
  push('');
  push('  /// Параметр `bounce` SwiftUI: 0 — без отскока.');
  push('  final double bounce;');
  push('');
  push('  /// Время затухания до 0.1 % (`--spring-*-dur` доски).');
  push('  final Duration settle;');
  push('');
  push('  /// Единичная масса; жёсткость (2π/duration)², демпфирование 4π(1 - bounce)/duration.');
  push('  SpringDescription get description => SpringDescription(');
  push('        mass: 1,');
  push('        stiffness: math.pow(2 * math.pi / duration, 2).toDouble(),');
  push('        damping: 4 * math.pi * (1 - bounce) / duration,');
  push('      );');
  push('}');
  push('');
  push('/// Движение iOS 27: пружины, кривая угасания и безразмерные константы motion.js.');
  push('abstract final class Ios27Motion {');
  for (const s of springs) {
    push(`  /// \`--spring-${s.id}\`: затухает за ${dnum(s.dur)} мс (невязка подбора ${s.err.toFixed(5)}).`);
    push(`  static const spring${s.id[0].toUpperCase()}${s.id.slice(1)} = Ios27SpringSpec(duration: ${dnum(s.duration)}, bounce: ${dnum(s.bounce)}, settle: Duration(milliseconds: ${Math.round(s.dur)}));`);
    push('');
  }
  push('  /// `--ease-out`: угасание прозрачности, где пружина не нужна.');
  push(`  static const easeOut = Cubic(${dnum(ease[1])}, ${dnum(ease[2])}, ${dnum(ease[3])}, ${dnum(ease[4])});`);
  push('');
  for (const [name, value, , doc] of MOTION_CONSTS) {
    if (name.endsWith('Ms')) push(`  /// ${doc}.`, `  static const ${name.replace(/Ms$/, '')} = Duration(milliseconds: ${value});`, '');
    else push(`  /// ${doc}.`, `  static const double ${name} = ${dnum(value)};`, '');
  }
  push('}');
  push('');

  writeFileSync(OUT, L.join('\n'), 'utf8');
  execFileSync('fvm', ['dart', 'format', OUT], { stdio: 'ignore' });

  const nCol = colorNames.length;
  console.log(`записано ${OUT}`);
  console.log(`цветов: ${nCol} (наборов 4: light, dark, light+HC, dark+HC), длин: ${lengthNames.length}, ролей текста: ${roles.length}, `
    + `вариантов стекла: ${variants.length}, пружин: ${springs.length}, констант motion.js: ${MOTION_CONSTS.length}`);
  console.log(`цвета без потерь canvas: полупрозрачных, у которых canvas отличается: ${JSON.stringify(lossy)}`);
  console.log(`пружины: ${springs.map((s) => `${s.id}=${s.duration}/${s.bounce} err ${s.err.toFixed(5)}`).join('; ')}`);
  console.log(`контроль пробы: #FF3B30 -> ${st.light.controls.opaque.got}, #78788033 -> ${st.light.controls.translucent.got} (canvas ${st.light.controls.translucent.canvas})`);
  console.log(`имена: ${colorNames.join(' ')}`);
  console.log(`длины: ${lengthNames.join(' ')}`);
  console.log(`коммит канона: ${stamp}`);
}

main().catch((e) => { console.error(e); stopServer(); process.exit(1); });
