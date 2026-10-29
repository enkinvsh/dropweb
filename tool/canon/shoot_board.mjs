// Эталоны Android-колонки доски canon/dropweb (ворота 1 плана android-m3e-redesign).
//
// Что делает: поднимает статику canon на 127.0.0.1:8740, для каждой сцены × тема × провайдер
// открывает доску в Chromium (Playwright из dropweb-flow), снимает `[data-col="android"] .droid`
// (411×914 CSS px, dpr 2 → 822×1828 px) и выгружает раскладку и разрешённые цвета.
// Это эталон для Flutter golden- и parity-тестов, поэтому важнее повторяемость, чем скорость.
//
// Запуск из корня репо: `node tool/canon/shoot_board.mjs`
// Выход: test/m3e/ref/<сцена>-<light|dark>-p<0|5>.png, test/m3e/ref/layout.json и
// test/m3e/ref/colors.json (плоско: { "<сцена>-<тема>-p<N>": { "--dr-bg": "#F6F7F1", ... } }) —
// цвета всех 6 провайдеров × light/dark × home-off/home-on для сверки Dart homeVars()/scheme().
// Переменная M3E_REF_DIR переопределяет папку вывода (нужна только для проверки детерминизма).
//
// Схема layout.json: { "<сцена>-<тема>-p<N>": { root:{w,h}, elements:{имя: rect|[rect]|null}, colors:{"--имя":"#RRGGBB"} } }
//   rect = {x,y,w,h} в CSS px относительно `.droid`, округлено до 0.01.
//   Несколько совпадений → массив в порядке DOM; нет совпадений → null.
//   navBtn, card.stat, card.statValue, list.item, empty.btn — всегда массив (или null).
//   Элементы внутри [inert] слоя (главная под открытой страницей/листом) считаются отсутствующими:
//   они в DOM, но закрыты страницей, во Flutter их на экране нет.
//   Элементы с нулевой площадью (скрытые) пропускаются.
//
// Соответствие логических имён селекторам (проверено по android.js/android.css):
//   card=.dr-card  card.head/plan/line/stats/sub/site=.dr-card__head/__plan/__line/__stats/__sub/__site
//   card.refresh=.dr-card__fix (кнопка «Обновить», есть только при expired/traffic-out)
//   hero=.dr-hero  navBtn=.dr-nav-btn  subsBtn=[aria-label="Открыть подписки"]
//   routeBtn=[aria-label="Выбрать маршрут"]  toast=.dr-toast
//   empty.shape=.dr-empty__shape  empty.title=.dr-empty h2 (.dr-headline-s)  about.logo=.dr-about__logo
//   Дополнительно: card.name/state/dot/timer/why/meter, card.stat/statValue, hero.shape, joy, status, navbar,
//   empty, empty.actions, empty.btn, about, about.title, about.version, bar, bar.back, page.title,
//   list, list.item, toast.text.

//
// Фаза B (листы, диалог, страницы): сцены disclosure, route, servers, sub, refresh-fail, add, settings,
// appearance, colors, update + language. Набор селекторов отдельный (SELECTORS_B): добавление имён в общий
// набор дописало бы null-ключи в записи фазы A, а они должны оставаться побайтово прежними.
//   scrim=.dr-scrim  sheet=.dr-sheet  sheet.head/handle/title/view=.dr-sheet__head/__handle/__title/__view
//   sheet.back=.dr-sheet__head .md-icon-button  sheet.item=.dr-sheet .dr-item  sheet.btn=.dr-sheet .md-button
//   sheet.actions=.dr-sheet__actions  dialog=.dr-dialog  dialog.icon/title/text=.dr-dialog__icon/__title/__text
//   dialog.action=.dr-dialog__actions .md-button (список)  field=.dr-field  field.input=.dr-field__input
//   field.label=.dr-field__label  field.paste=.dr-field .md-icon-button  field.sup=.dr-field__sup
//   progress=.dr-sheet .dr-progress (в сцене update фаза «available» — полосы нет, null)
//   update.size/notes/phase=.dr-update__size/.dr-notes/.dr-update__phase
//   swatches=.dr-swatches (список)  swatch=.dr-swatch (список)  swatch.checked=.dr-swatch[aria-checked="true"]
//   list=.dr-list (список)  list.item=.dr-li (список)  list.head=.dr-list-head (список)  item=.dr-item (список)
//   bar, bar.back, page.title, page — ТОЛЬКО верхней страницы (.dr-page:last-child в слое страниц): под ней лежит
//   предыдущая страница (settings под appearance/about/language), она не [inert], но закрыта.
//   Страница «Язык»: сцены нет, скрипт открывает доску на settings и кликает пункт open-page/language
//   через el.click() (без pointer-событий: рябь и :hover не попадают в кадр).
//
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync, unlinkSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '/Users/mac/Documents/projects/dropweb-flow/node_modules/playwright/index.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = process.env.M3E_REF_DIR ? resolve(process.env.M3E_REF_DIR) : join(ROOT, 'test', 'm3e', 'ref');
// Порт 8740 закреплён за съёмкой доски; 8727/8741/8765/8799 заняты другими задачами
const PORT = 8740;
const URL = `http://127.0.0.1:${PORT}/dropweb/`;
const CANON = '/Users/mac/Documents/projects/canon';

const SCENES = ['home-off', 'connecting', 'switching', 'home-on', 'error', 'offline', 'expiring',
  'traffic-low', 'traffic-out', 'expired', 'empty', 'support', 'about'];
const THEMES = ['light', 'dark'];
const PROVIDERS = [0, 5];
// Цвета нужны по всем провайдерам из PROVIDERS в app.js, а снимки и раскладка — только по двум
const COLOR_PROVIDERS = [0, 1, 2, 3, 4, 5];
const COLOR_SCENES = ['home-off', 'home-on'];

// Фиксированные «сейчас» и зерно. Часовой пояс задан явно, чтобы дата не зависела от машины
const NOW = new Date('2026-10-29T09:00:00+05:00');
const TZ = 'Asia/Yekaterinburg';
const SEED = 0x5eed1234;
// Часы ставим на паузу сразу после install: иначе время течёт само, и таймер «12:48», число тиков
// jitter()/sessionGB в home-on зависели бы от скорости загрузки страницы
const PAUSE_AT = new Date(NOW.getTime() + 10_000);
// Прокручиваем фейковые часы на ~1,2 с, как в плане: волны, морф героя и один тик home-on
const SETTLE_MS = 1200;

const SELECTORS = {
  card: '.dr-card',
  'card.head': '.dr-card__head',
  'card.plan': '.dr-card__plan',
  'card.line': '.dr-card__line',
  'card.stats': '.dr-card__stats',
  'card.sub': '.dr-card__sub',
  'card.site': '.dr-card__site',
  'card.refresh': '.dr-card__fix',
  'card.name': '.dr-card__name',
  'card.state': '.dr-card__state',
  'card.dot': '.dr-card__dot',
  'card.timer': '.dr-card__timer',
  'card.why': '.dr-card__why',
  'card.meter': '.dr-meter',
  'card.stat': '.dr-stat',
  'card.statValue': '.dr-stat__v',
  hero: '.dr-hero',
  'hero.shape': '.dr-hero__shape',
  joy: '.dr-joy',
  navBtn: '.dr-nav-btn',
  subsBtn: '[aria-label="Открыть подписки"]',
  routeBtn: '[aria-label="Выбрать маршрут"]',
  toast: '.dr-toast',
  'toast.text': '.dr-toast__text',
  empty: '.dr-empty',
  'empty.shape': '.dr-empty__shape',
  'empty.title': '.dr-empty h2',
  'empty.actions': '.dr-actions',
  'empty.btn': '.dr-actions .md-button',
  about: '.dr-about',
  'about.logo': '.dr-about__logo',
  'about.title': '.dr-about .dr-headline-s',
  'about.version': '.dr-about .dr-muted',
  bar: '.dr-bar',
  'bar.back': '.dr-bar .md-icon-button',
  'page.title': '.dr-page__title',
  list: '.dr-list',
  'list.item': '.dr-li',
  status: '.dr-status',
  navbar: '.dr-nav',
};
const ALWAYS_ARRAY = ['navBtn', 'card.stat', 'card.statValue', 'list.item', 'empty.btn'];

const SELECTORS_B = {
  ...SELECTORS,
  scrim: '.dr-scrim',
  sheet: '.dr-sheet',
  'sheet.handle': '.dr-sheet__handle',
  'sheet.head': '.dr-sheet__head',
  'sheet.title': '.dr-sheet__title',
  'sheet.back': '.dr-sheet__head .md-icon-button',
  'sheet.view': '.dr-sheet__view',
  'sheet.item': '.dr-sheet .dr-item',
  'sheet.btn': '.dr-sheet .md-button',
  'sheet.actions': '.dr-sheet__actions',
  dialog: '.dr-dialog',
  'dialog.icon': '.dr-dialog__icon',
  'dialog.title': '.dr-dialog__title',
  'dialog.text': '.dr-dialog__text',
  'dialog.action': '.dr-dialog__actions .md-button',
  field: '.dr-field',
  'field.input': '.dr-field__input',
  'field.label': '.dr-field__label',
  'field.paste': '.dr-field .md-icon-button',
  'field.sup': '.dr-field__sup',
  progress: '.dr-sheet .dr-progress',
  'update.size': '.dr-update__size',
  'update.notes': '.dr-notes',
  'update.phase': '.dr-update__phase',
  swatches: '.dr-swatches',
  swatch: '.dr-swatch',
  'swatch.checked': '.dr-swatch[aria-checked="true"]',
  item: '.dr-item',
  'list.head': '.dr-list-head',
  page: '.dr-l:nth-child(2) > .dr-page:last-child',
  bar: '.dr-l:nth-child(2) > .dr-page:last-child .dr-bar',
  'bar.back': '.dr-l:nth-child(2) > .dr-page:last-child .dr-bar .md-icon-button',
  'page.title': '.dr-l:nth-child(2) > .dr-page:last-child .dr-page__title',
};
const ALWAYS_ARRAY_B = [...ALWAYS_ARRAY, 'scrim', 'dialog.action', 'sheet.item', 'sheet.btn', 'swatches', 'swatch',
  'swatch.checked', 'list', 'item', 'list.head'];

// Сцены фазы B. board — id сцены доски, key — имя в файлах; action — действие после загрузки
const SCENES_B = [
  ...['disclosure', 'route', 'servers', 'sub', 'refresh-fail', 'add', 'settings', 'appearance', 'colors', 'update']
    .map((id) => ({ key: id, board: id })),
  { key: 'language', board: 'settings', click: '[data-act="open-page"][data-arg="language"]' },
];

// Seed-ные кроссчеки цвета «вторым способом» (пиксель скриншота элемента) — по нескольким ролям
const CROSS = ['--dr-bg', '--dr-card', '--dr-ink2', '--dr-line', '--dr-lv-a', '--dr-sh-b', '--dr-flood', '--md-sys-color-primary'];

// ---------- Сервер ----------
let server = null;
function stopServer() {
  if (server && server.exitCode === null) { try { server.kill('SIGKILL'); } catch { /* уже мёртв */ } }
  server = null;
}
// Сервер обязан умереть при любом выходе, иначе порт 8740 останется занятым для следующих запусков
process.on('exit', stopServer);
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => { stopServer(); process.exit(130); });
process.on('uncaughtException', (e) => { console.error(e); stopServer(); process.exit(1); });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function startServer() {
  // Если на порту уже кто-то слушает — это чужой процесс, его не трогаем и не подменяем
  const busy = await fetch(`http://127.0.0.1:${PORT}/`).then(() => true, () => false);
  if (busy) throw new Error(`порт ${PORT} уже занят — остановитесь, это чужой процесс`);
  // request_queue_size=128: очередь listen по умолчанию 5, на всплеске запросов доски рвутся соединения
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
// Собирает rect-ы и цвета. Выполняется в браузере, поэтому самодостаточна
function collectInPage({ selectors, alwaysArray }) {
  const root = document.querySelector('[data-col="android"] .droid');
  const rr = root.getBoundingClientRect();
  const r2 = (v) => Math.round(v * 100) / 100;
  const rect = (el) => {
    const r = el.getBoundingClientRect();
    return { x: r2(r.left - rr.left), y: r2(r.top - rr.top), w: r2(r.width), h: r2(r.height) };
  };
  const elements = {};
  for (const [name, sel] of Object.entries(selectors)) {
    const list = [...root.querySelectorAll(sel)]
      .filter((el) => !el.closest('[inert]') && !el.closest('[data-leave]'))
      .map(rect)
      .filter((r) => r.w * r.h > 0);
    elements[name] = list.length === 0 ? null : (list.length === 1 && !alwaysArray.includes(name)) ? list[0] : list;
  }

  // Имена переменных берём из <style data-droid> доски: они выставляются именно этим стилем
  // на корне `.droid`. В getComputedStyle значения color-mix остаются строкой, поэтому
  // разрешаем цвет через фон пробы и 1×1 canvas — получаем то, что браузер реально рисует (sRGB 8 бит)
  const css = document.querySelector(`style[data-droid="${root.dataset.dr}"]`).textContent;
  const names = [...new Set(css.match(/--(?:dr|md-sys-color)-[a-z0-9-]+(?=:)/g))].sort();
  const probe = document.createElement('div');
  probe.style.cssText = 'position:absolute;width:1px;height:1px;transition:none;pointer-events:none';
  root.append(probe);
  const cv = document.createElement('canvas');
  cv.width = cv.height = 1;
  const g = cv.getContext('2d', { willReadFrequently: true });
  const hex = (n) => n.toString(16).padStart(2, '0').toUpperCase();
  const colors = {};
  for (const n of names) {
    probe.style.backgroundColor = `var(${n})`;
    const bg = getComputedStyle(probe).backgroundColor;
    g.clearRect(0, 0, 1, 1);
    g.fillStyle = '#000';
    g.fillStyle = bg;
    g.fillRect(0, 0, 1, 1);
    const [r, gg, b, a] = g.getImageData(0, 0, 1, 1).data;
    colors[n] = `#${hex(r)}${hex(gg)}${hex(b)}${a === 255 ? '' : hex(a)}`;
  }
  probe.remove();
  return { root: { w: r2(rr.width), h: r2(rr.height) }, zoom: getComputedStyle(root.closest('.device')).zoom, elements, colors };
}

// Проба лежит в (200,400), а не в углу: у `.droid` скруглённые углы с overflow:hidden, угол срезается.
// Второй способ: скриншот пробы 8×8 с цветом переменной → пиксель PNG, декодированный в canvas
async function crossCheck(page, colors) {
  const out = [];
  for (const n of CROSS) {
    await page.evaluate((name) => {
      const root = document.querySelector('[data-col="android"] .droid');
      const p = document.createElement('div');
      p.id = 'dw-probe';
      p.style.cssText = `position:absolute;left:200px;top:400px;width:8px;height:8px;z-index:99999;transition:none;background:var(${name})`;
      root.append(p);
    }, n);
    const buf = await page.locator('#dw-probe').screenshot();
    const px = await page.evaluate(async (b64) => {
      const blob = await (await fetch(`data:image/png;base64,${b64}`)).blob();
      const bmp = await createImageBitmap(blob);
      const c = document.createElement('canvas');
      c.width = bmp.width; c.height = bmp.height;
      const g = c.getContext('2d');
      g.drawImage(bmp, 0, 0);
      const d = g.getImageData(bmp.width >> 1, bmp.height >> 1, 1, 1).data;
      return [d[0], d[1], d[2]];
    }, buf.toString('base64'));
    await page.evaluate(() => document.getElementById('dw-probe')?.remove());
    const hex = `#${px.map((v) => v.toString(16).padStart(2, '0').toUpperCase()).join('')}`;
    out.push({ name: n, canvas: colors[n].slice(0, 7), shot: hex, same: colors[n].slice(0, 7) === hex });
  }
  return out;
}

// full=false: только цвета (без PNG и кросс-проверки) — для провайдеров, у которых нет эталонных снимков
// Размер из заголовка PNG (IHDR): проверка не зависит от внешних библиотек
function pngSize(file) {
  const b = readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

async function shoot(browser, scene, theme, provider, outDir, full = true, sc = null) {
  // sc — описание сцены фазы B ({key, board, click}); фаза A идёт со старым набором селекторов без изменений
  const key = `${sc ? sc.key : scene}-${theme}-p${provider}`;
  const selectors = sc ? SELECTORS_B : SELECTORS, alwaysArray = sc ? ALWAYS_ARRAY_B : ALWAYS_ARRAY;
  // Новый контекст на кадр: localStorage/sessionStorage и часы не протекают между кадрами
  const ctx = await browser.newContext({
    // 1440×1200: при меньшей высоте fit() доски уменьшает .device через zoom (высота колонки − 8 < 934),
    // и снимок с раскладкой выходит уменьшенным. Размер зафиксирован планом; zoom≠1 → скрипт падает ниже
    viewport: { width: 1440, height: 1200 },
    deviceScaleFactor: 2, reducedMotion: 'reduce', colorScheme: theme, locale: 'ru-RU', timezoneId: TZ,
  });
  try {
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript(({ state, seed }) => {
      localStorage.setItem('dw-board:v1', JSON.stringify(state));
      // mulberry32: jitter() пинга и приращение трафика в home-on берут Math.random
      let a = seed >>> 0;
      Math.random = () => {
        a = (a + 0x6D2B79F5) >>> 0;
        let t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    }, { state: { screen: sc ? sc.board : scene, theme, provider, worst: false, view: 'android' }, seed: SEED });
    await page.clock.install({ time: NOW });
    await page.clock.pauseAt(PAUSE_AT);
    await page.goto(URL);
    await page.waitForSelector('[data-col="android"] .droid', { state: 'attached' });

    // Шрифты и картинки грузятся по реальной сети, а часы стоят: ждём на стороне node,
    // потому что таймеры страницы заморожены
    const ready = () => page.evaluate(() => document.fonts.status === 'loaded'
      && [...document.querySelectorAll('[data-col="android"] img')].every((i) => i.complete));
    for (let i = 0; i < 100 && !(await ready()); i++) await sleep(100);
    await page.evaluate(() => document.fonts.ready.then(() => 0));
    await page.clock.runFor(SETTLE_MS);
    for (let i = 0; i < 100 && !(await ready()); i++) await sleep(100);
    await page.evaluate(() => document.fonts.ready.then(() => 0));
    await page.clock.runFor(100);

    if (sc?.click) {
      // Не-тихий переход: страница появляется CSS-анимацией 150 мс, а её таймеры фейковые часы не ведут —
      // ждём реальное время, пока не исчезнут data-enter/data-leave
      await page.evaluate((q) => document.querySelector(`[data-col="android"] .droid ${q}`).click(), sc.click);
      for (let i = 0; i < 50; i++) {
        await sleep(100);
        if (!(await page.evaluate(() => document.querySelector('[data-col="android"] .droid [data-enter],[data-col="android"] .droid [data-leave]')))) break;
      }
      await page.clock.runFor(SETTLE_MS);
    }

    const data = await page.evaluate(collectInPage, { selectors, alwaysArray });
    if (data.zoom !== '1' || Math.abs(data.root.w - 411) > 0.01 || Math.abs(data.root.h - 914) > 0.01) {
      const dev = await page.evaluate(() => { const r = document.querySelector('[data-col="android"] .device').getBoundingClientRect(); return `${r.width}×${r.height}`; });
      throw new Error(`${key}: окно 1440×1200, zoom .device = ${data.zoom}, .device ${dev}, корень ${data.root.w}×${data.root.h} — ожидалось 411×914, zoom 1`);
    }
    const theme_ = await page.evaluate(() => document.documentElement.dataset.theme);
    if (theme_ !== theme) throw new Error(`${key}: data-theme=${theme_}, ожидалась ${theme}`);

    if (!full) return { key, colors: data.colors };
    const file = join(outDir, `${key}.png`);
    await page.locator('[data-col="android"] .droid').screenshot({ path: file, animations: 'disabled' });
    const dim = pngSize(file);
    if (dim.w !== 822 || dim.h !== 1828) throw new Error(`${key}: PNG ${dim.w}×${dim.h}, ожидалось 822×1828`);
    const cross = await crossCheck(page, data.colors);
    if (errors.length) console.warn(`  ! ${key}: ошибки страницы: ${errors.join(' | ')}`);
    return { key, colors: data.colors, layout: { root: data.root, elements: data.elements, colors: data.colors }, cross };
  } finally {
    await ctx.close();
  }
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  // Идемпотентность: старые кадры не должны переживать смену набора сцен
  for (const f of readdirSync(OUT)) if (/^[a-z-]+-(light|dark)-p\d\.png$/.test(f)) unlinkSync(join(OUT, f));

  await startServer();
  const browser = await chromium.launch();
  const layout = {}, colorsAll = {};
  let bad = 0, checks = 0;
  try {
    for (const scene of SCENES) {
      for (const theme of THEMES) {
        for (const provider of PROVIDERS) {
          const r = await shoot(browser, scene, theme, provider, OUT);
          layout[r.key] = r.layout;
          if (COLOR_SCENES.includes(scene)) colorsAll[r.key] = r.colors;
          for (const c of r.cross) { checks++; if (!c.same) { bad++; console.warn(`  ! ${r.key} ${c.name}: canvas ${c.canvas} ≠ скриншот ${c.shot}`); } }
          console.log(`ok ${r.key}`);
        }
      }
    }
    for (const sc of SCENES_B) {
      for (const theme of THEMES) {
        for (const provider of PROVIDERS) {
          const r = await shoot(browser, sc.board, theme, provider, OUT, true, sc);
          layout[r.key] = r.layout;
          for (const c of r.cross) { checks++; if (!c.same) { bad++; console.warn(`  ! ${r.key} ${c.name}: canvas ${c.canvas} ≠ скриншот ${c.shot}`); } }
          console.log(`ok ${r.key}`);
        }
      }
    }
    // Остальные провайдеры: только цвета. Тот же путь (проба → canvas), что и для снимков
    for (const scene of COLOR_SCENES) {
      for (const theme of THEMES) {
        for (const provider of COLOR_PROVIDERS.filter((p) => !PROVIDERS.includes(p))) {
          const r = await shoot(browser, scene, theme, provider, OUT, false);
          colorsAll[r.key] = r.colors;
          console.log(`ok colors ${r.key}`);
        }
      }
    }
  } finally {
    await browser.close().catch(() => {});
    stopServer();
  }
  writeFileSync(join(OUT, 'layout.json'), `${JSON.stringify(layout, null, 1)}\n`);
  // Ключи сортируем: порядок записи не должен зависеть от очерёдности съёмки
  const sorted = Object.fromEntries(Object.keys(colorsAll).sort().map((k) => [k, colorsAll[k]]));
  writeFileSync(join(OUT, 'colors.json'), `${JSON.stringify(sorted, null, 1)}\n`);
  const n = Object.keys(layout).length;
  const nColors = Object.keys(Object.values(layout)[0].colors).length;
  console.log(`\nГотово: ${n} кадров (${SCENES.length}+${SCENES_B.length} сцен × ${THEMES.length} темы × ${PROVIDERS.length} провайдера), `
    + `822×1828 px, layout.json, colors.json (${Object.keys(sorted).length} ключей), ${nColors} цветов на кадр. Кросс-проверка цвета: ${checks - bad}/${checks} совпало. → ${OUT}`);
  if (bad) process.exitCode = 2;
}

main().catch((e) => { console.error(e); stopServer(); process.exit(1); });
