// Эталоны iOS-колонки доски canon/dropweb (ворота G1 плана ios-redesign, задача T1).
//
// Что делает: поднимает статику canon на 127.0.0.1:8742, для каждой сцены × тема × режим прозрачности ×
// провайдер открывает доску в Chromium (Playwright из dropweb-flow), снимает `[data-col="ios"] .app`
// (411×914 CSS px, dpr 2 → 822×1828 px) и выгружает раскладку и разрешённые цвета.
// Это эталон для Flutter golden- и parity-тестов, поэтому повторяемость важнее скорости.
// Устроен как tool/canon/shoot_board.mjs (Android), отличия — только то, что требует iOS-колонка.
//
// Запуск из корня репо: `node tool/canon/shoot_board_ios.mjs`
// Выход: test/ios27/ref/<сцена>-<light|dark>-<norm|rt>-p<0|5>.png, layout.json, colors.json.
// Переменная IOS27_REF_DIR переопределяет папку вывода (проверка детерминизма: второй прогон в /tmp),
// IOS27_JOBS — число параллельных контекстов (по умолчанию 4).
//
// Режимы: norm — обычная прозрачность; rt — «Уменьшить прозрачность» (prefers-reduced-transparency: reduce).
// Playwright не умеет эту медиа-функцию, поэтому включаем её через CDP Emulation.setEmulatedMedia и
// на каждом кадре проверяем, что она реально сработала: matchMedia и backdrop-filter у .glass::before
// (в rt обязан стать none, в norm — нет). Итог проверки печатается в конце.
//
// Схема layout.json: { "<сцена>-<тема>-<norm|rt>-p<N>": { root:{w,h}, elements:{имя: rect|[rect]|null},
//                      mask:{statusBar:rect, homeIndicator:rect} } }
//   rect = {x,y,w,h} в CSS px относительно `.app`, округлено до 0.01. Нет совпадений → null.
//   Элементы внутри [inert], уходящие (.is-leaving), призраки перехода (.is-ghost) и нулевой площади пропускаются.
//   Главная (card, dock, power, …) отсутствует (null), если поверх неё открыта страница: страница
//   непрозрачна и закрывает главную, во Flutter её на экране нет. Селекторы страницы — только для ВЕРХНЕЙ
//   страницы: под ней лежит предыдущая (settings под appearance/about/language).
//   mask — прямоугольники имитаций системного UI доски (строка состояния, индикатор «домой»): во Flutter
//   их рисует система, golden-тест закрашивает эти области, поэтому берём их из DOM, а не угадываем.
//
// Схема colors.json (плоско): { "<сцена>-<тема>-p<N>": { "--accent": "#29FF76", ... },
//                               "<сцена>-<тема>-a<K>": { ... } }
//   сцены home-off и home-on; p0..p5 — индекс провайдера в PROVIDERS доски; a0..a7 — K-й пресет акцента
//   (PRESETS в app.js) у провайдера 0, применённый так, как доска применяет собственный цвет
//   (useOwn + own.accent). Значения — #RRGGBB или #RRGGBBAA (альфа только если не 255).
//
// Правки DOM доски (согласованы владельцем, делаются только здесь, после финального рендера и до съёмки):
//   - строка «Обновление» на странице «О приложении» — в магазинной iOS-сборке обновления нет (R10 плана).
// Больше доска не правится. Раздел «Стекло» на страницах оформления и в листе цвета остаётся как есть:
// с 30.10 владелец вернул ползунок (решение Q1 отменено), в приложении он стоит под переключателем
// «Как в системе», которого на доске нет (поэтому в тестах эталоны ниже строки сдвигаются на её высоту).
import { spawn, spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync, unlinkSync, readFileSync } from 'node:fs';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '/Users/mac/Documents/projects/dropweb-flow/node_modules/playwright/index.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = process.env.IOS27_REF_DIR ? resolve(process.env.IOS27_REF_DIR) : join(ROOT, 'test', 'ios27', 'ref');
const JOBS = Math.max(1, Number(process.env.IOS27_JOBS ?? 4) || 4);
// Отладочный срез: IOS27_ONLY=home-on,route снимает только эти сцены (полный набор — без переменной)
const ONLY = process.env.IOS27_ONLY ? process.env.IOS27_ONLY.split(',') : null;
// Порт 8742 закреплён за этой съёмкой; 8727/8740/8741/8744/8765/8799 заняты другими задачами
const PORT = 8742;
const URL = `http://127.0.0.1:${PORT}/dropweb/`;
const CANON = '/Users/mac/Documents/projects/canon';
const APP = '[data-col="ios"] .app';

// Сцены доски (SCENES в app.js), кроме switching (анимация без устойчивого кадра) и update (лист обновления
// вырезан из магазинной сборки, R10)
const BOARD_SCENES = ['home-off', 'connecting', 'home-on', 'error', 'offline', 'empty', 'disclosure', 'expiring',
  'traffic-low', 'traffic-out', 'expired', 'route', 'servers', 'sub', 'refresh-fail', 'add', 'support',
  'settings', 'appearance', 'about', 'colors'];
// Состояния, до которых на доске доходят только кликом (inventory.md, раздел «а»). Клики идут через
// el.click() без pointer-событий: рябь и :hover не должны попасть в кадр
const CLICK_SCENES = [
  { key: 'language', board: 'settings', clicks: ['[data-act="open-page"][data-arg="language"]'] },
  { key: 'delete-alert', board: 'sub', clicks: ['[data-act="ask-delete"]'] },
  { key: 'add-empty', board: 'empty', clicks: ['[data-act="paste"]'] },
  // Лист цвета для слота «акцент»; выглядит как сцена colors — совпадение байт проверяется отдельно
  { key: 'color-sheet', board: 'appearance', clicks: ['[data-act="colors"][data-arg="own"]', '[data-act="well"][data-arg="accent"]'] },
];
const SCENES = [...BOARD_SCENES.map((id) => ({ key: id, board: id, clicks: [] })), ...CLICK_SCENES];
// Какая правка DOM доски нужна сцене (см. шапку)
const EDIT_OF = { about: 'update' };

const THEMES = ['light', 'dark'];
const MODES = ['norm', 'rt'];
// p0 — DROPWEB (по умолчанию), p5 — «Серый»: самая «холодная» тройка цветов в PROVIDERS доски.
// Логотип в доске привязан к профилю, а не к провайдеру, поэтому кадры p0 и p5 несут одну и ту же метку
const PROVIDERS = [0, 5];
const COLOR_PROVIDERS = [0, 1, 2, 3, 4, 5];
const COLOR_ACCENTS = [0, 1, 2, 3, 4, 5, 6, 7];
const COLOR_SCENES = ['home-off', 'home-on'];

// Фиксированные «сейчас» и зерно. Часовой пояс задан явно, чтобы дата не зависела от машины
const NOW = new Date('2026-10-29T09:00:00+05:00');
const TZ = 'Asia/Yekaterinburg';
const SEED = 0x5eed1234;
// Часы ставим на паузу сразу после install: иначе время течёт само, и таймер сессии в home-on
// (since = now − 12:48) зависел бы от скорости загрузки страницы
const PAUSE_AT = new Date(NOW.getTime() + 10_000);
// Прокручиваем фейковые часы на ~1,2 с: один тик таймера home-on и отложенные setTimeout приложения
const SETTLE_MS = 1200;

// Раскладка: [имя, область, селектор, 'optional'?]. 'optional': нет совпадений — ключа в layout.json нет вовсе. Область: root — весь корень; home — главная (null под страницей);
// page — только верхняя страница ('' = сама страница)
const SPEC = [
  ['card', 'home', '.hc'],
  ['card.head', 'home', '.hc__head'],
  ['card.state', 'home', '.hc__state'],
  ['card.dot', 'home', '.hc__dot'],
  ['card.name', 'home', '.hc__name'],
  ['card.why', 'home', '.hc__why'],
  ['card.timer', 'home', '.hc__timer'],
  ['card.plan', 'home', '.hc__plan'],
  ['card.line', 'home', '.hc__line'],
  ['card.meter', 'home', '.hc .meter'],
  ['card.stats', 'home', '.hc__stats'],
  ['card.stat', 'home', '.hc__stat'],
  ['card.statKey', 'home', '.hc__k'],
  ['card.statValue', 'home', '.hc__v'],
  ['card.ip', 'home', '.js-ip'],
  ['card.flag', 'home', '.hc__flag'],
  ['card.spinner', 'home', '.hc__v .spin'],
  ['card.sub', 'home', '.hc__sub'],
  ['card.announce', 'home', '.hc__announce'],
  ['card.refresh', 'home', '.hc__sub .btn'],
  ['settings', 'home', '.home__nav .circle-btn'],
  ['dock', 'home', '.joy'],
  ['dock-sub', 'home', '.dock-btn[data-arg="sub"]'],
  ['power', 'home', '.power'],
  ['dock-route', 'home', '.dock-btn[data-arg="route"]'],
  ['empty', 'home', '.empty'],
  ['empty.icon', 'home', '.empty__icon'],
  ['empty.title', 'home', '.empty__title'],
  ['empty.actions', 'home', '.empty__actions'],
  ['empty.btn', 'home', '.empty__actions .btn'],
  ['toast', 'root', '.toast'],
  ['toast.text', 'root', '.toast > span'],
  ['toast.icon', 'root', '.toast .ico'],
  ['dim', 'root', '.dim'],
  ['dim.alert', 'root', '.dim--alert'],
  ['sheet', 'root', '.sheet'],
  ['sheet.bar', 'root', '.sheet__bar'],
  ['sheet.title', 'root', '.sheet__title'],
  ['sheet.back', 'root', '.sheet__bar [data-act="pop"]'],
  ['sheet.close', 'root', '.sheet__bar [data-act="close-sheet"]'],
  ['sheet.body', 'root', '.sheet__body'],
  ['sheet.foot', 'root', '.sheet__foot'],
  ['sheet.submit', 'root', '.sheet__submit'],
  ['sheet.group', 'root', '.sheet .group'],
  ['sheet.groupHead', 'root', '.sheet .group-head'],
  ['sheet.row', 'root', '.sheet .row'],
  ['sheet.rowTitle', 'root', '.sheet .row__title'],
  ['sheet.rowDetail', 'root', '.sheet .row__detail'],
  ['sheet.rowIcon', 'root', '.sheet .row__icon'],
  ['sheet.rowFlag', 'root', '.sheet .row .flag'],
  ['sheet.rowLogo', 'root', '.sheet .row__logo'],
  ['sheet.rowCheck', 'root', '.sheet .row > .check'],
  ['sheet.field', 'root', '.sheet .field'],
  ['sheet.fieldInput', 'root', '.sheet .field input'],
  ['sheet.fieldPaste', 'root', '.sheet .field .btn'],
  ['sheet.fieldError', 'root', '.sheet .field-error'],
  ['sheet.addBtn', 'root', '.sheet [data-act="add-submit"]'],
  ['sheet.switch', 'root', '.sheet .switch'],
  ['cp.grid', 'root', '.cp__grid'],
  ['cp.current', 'root', '.cp__current'],
  ['cp.dots', 'root', '.cp__dots'],
  ['cp.dot', 'root', '.cp__dot'],
  ['alert', 'root', '.alert'],
  ['alert.title', 'root', '.alert__title'],
  ['alert.text', 'root', '.alert__text'],
  ['alert.link', 'root', '.alert__link'],
  ['alert.actions', 'root', '.alert__actions'],
  ['alert.btn', 'root', '.alert__actions .btn'],
  ['page', 'page', ''],
  ['page.nav', 'page', '.page__nav'],
  ['page.back', 'page', '.page__nav .circle-btn'],
  ['page.small', 'page', '.page__small'],
  ['page.title', 'page', '.page__title'],
  ['page.groupHead', 'page', '.group-head'],
  ['page.group', 'page', '.group'],
  ['page.row', 'page', '.row'],
  ['page.rowTitle', 'page', '.row__title'],
  ['page.rowDetail', 'page', '.row__detail'],
  ['page.rowIcon', 'page', '.row__icon'],
  ['page.rowCheck', 'page', '.row > .check'],
  ['page.rowSwatch', 'page', '.row__swatch'],
  ['page.well', 'page', '.well'],
  // Раздел «Стекло» страницы «Оформление» (app.js:611-629). Только там и есть: на остальных страницах
  // ключей нет вовсе, чтобы layout.json других сцен не менялся ни на байт
  ['page.glassPreview', 'page', '.glass-preview', 'optional'],
  ['page.glassBtn', 'page', '.glass-preview .glass', 'optional'],
  ['page.sliderRow', 'page', '.slider-row', 'optional'],
  ['page.slider', 'page', '.slider', 'optional'],
  ['page.sliderCaps', 'page', '.slider-caps', 'optional'],
  ['about.icon', 'page', '.app-icon'],
  ['about.name', 'page', '.about__name'],
  ['about.ver', 'page', '.about__ver'],
];
// Повторяющиеся элементы всегда массив (или null): тип значения не должен зависеть от числа совпадений
const ALWAYS_ARRAY = ['card.stat', 'card.statKey', 'card.statValue', 'empty.btn', 'dim', 'sheet.group', 'sheet.groupHead',
  'sheet.row', 'sheet.rowTitle', 'sheet.rowDetail', 'sheet.rowIcon', 'sheet.rowFlag', 'sheet.rowLogo', 'sheet.rowCheck',
  'sheet.field', 'sheet.fieldInput', 'sheet.switch', 'cp.dot', 'alert.btn', 'page.groupHead', 'page.group', 'page.row',
  'page.rowTitle', 'page.rowDetail', 'page.rowIcon', 'page.rowCheck', 'page.rowSwatch', 'page.well', 'page.glassBtn'];

// ---------- Сервер ----------
let server = null;
function stopServer() {
  if (server && server.exitCode === null) { try { server.kill('SIGKILL'); } catch { /* уже мёртв */ } }
  // Страховка: если сервер остался сиротой, гасим только свой — порт 8742 никому больше не отдан,
  // а занятый порт startServer отвергает до запуска
  if (server) spawnSync('pkill', ['-f', `port=${PORT}`]);
  server = null;
}
// Сервер обязан умереть при любом выходе, иначе порт 8742 останется занятым для следующих запусков
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
// Всё, что асинхронно дозаполняется само: шрифты, картинки, метки логотипа, линзы стекла, WAAPI-переходы.
// Фейковые часы стоят, а эти вещи идут по реальному времени, поэтому ждём на стороне node.
// Возвращает список причин «ещё не готово»; пустой — можно снимать
function notReadyInPage(appSel) {
  const root = document.querySelector(appSel);
  const why = [];
  if (document.fonts.status !== 'loaded') why.push('шрифты');
  if (![...root.querySelectorAll('img')].every((i) => i.complete)) why.push('картинки');
  // Метка логотипа вырезается из картинки асинхронно (img.decode) и пишется в --mark
  if ([...root.querySelectorAll('[data-mark]')].some((el) => !el.style.getPropertyValue('--mark'))) why.push('метка логотипа');
  // Линза стекла считается ResizeObserver-ом по реальным кадрам и пишется в --g-lens; data-URL feImage
  // декодируется ещё позже, это добирает цикл стабильности кадра в node
  const glass = [...root.querySelectorAll('.glass:not(.glass--inactive):not(.is-zooming)')]
    .filter((g) => g.offsetWidth > 0 && !g.closest('[inert]'));
  if (glass.some((g) => !g.style.getPropertyValue('--g-lens'))) why.push('линза стекла');
  // Конечные анимации: переходы листов/страниц и fade() на WAAPI идут по реальному времени
  if (document.getAnimations().some((a) => a.playState === 'running' && a.effect?.getComputedTiming().iterations !== Infinity)) why.push('анимации');
  return why;
}

// Правки DOM доски, согласованные владельцем (см. шапку). Форма проверяется жёстко: если доска
// изменится, лучше упасть, чем молча снять не то
function applyEditInPage({ appSel, edit }) {
  const root = document.querySelector(appSel);
  const must = (cond, what) => { if (!cond) throw new Error(`правка доски (${edit}): ${what}`); };
  if (edit === 'update') {
    // Группа со строкой «Обновление» + следующий зазор (app.js:633-634)
    const rows = [...root.querySelectorAll('.page .row')].filter((r) => r.querySelector('.row__title')?.textContent.trim() === 'Обновление');
    must(rows.length === 1, `строк «Обновление» ${rows.length}, ожидалась 1`);
    const group = rows[0].closest('.group'), gap = group?.nextElementSibling;
    must(group && group.querySelectorAll('.row').length === 1, 'строка не одна в своей группе');
    must(gap?.classList.contains('gap'), 'после группы нет .gap');
    group.remove(); gap.remove();
  }
}

// Раскладка, маски, масштаб и проверки режима. Выполняется в браузере, поэтому самодостаточна
function collectInPage({ appSel, spec, always }) {
  const root = document.querySelector(appSel);
  const rr = root.getBoundingClientRect();
  const r2 = (v) => Math.round(v * 100) / 100;
  const rect = (el) => {
    const r = el.getBoundingClientRect();
    return { x: r2(r.left - rr.left), y: r2(r.top - rr.top), w: r2(r.width), h: r2(r.height) };
  };
  const pages = [...root.children].filter((el) => el.classList.contains('page'));
  const top = pages[pages.length - 1] ?? null;
  const skip = (el) => el.closest('[inert]') || el.closest('.is-leaving') || el.closest('.is-ghost');
  const elements = {};
  for (const [name, scope, sel, optional] of spec) {
    let list = [];
    if (scope === 'root') list = [...root.querySelectorAll(sel)];
    else if (scope === 'home') list = top ? [] : [...root.querySelectorAll(sel)];
    else if (top) list = sel ? [...top.querySelectorAll(sel)] : [top];
    list = list.filter((el) => !skip(el)).map(rect).filter((r) => r.w * r.h > 0);
    if (optional && list.length === 0) continue;
    elements[name] = list.length === 0 ? null : (list.length === 1 && !always.includes(name)) ? list[0] : list;
  }
  const mask = {};
  for (const [name, sel] of [['statusBar', '.sys-bar'], ['homeIndicator', '.sys-gesture']]) {
    const el = root.querySelector(sel);
    mask[name] = el ? rect(el) : null;
  }
  // Проверка режима прозрачности: matchMedia и реальный backdrop-filter первого «живого» стекла
  const glass = [...root.querySelectorAll('.glass:not(.glass--tint):not(.glass--inactive)')].find((g) => g.offsetWidth > 0 && !g.closest('[inert]'));
  const backdrop = glass ? getComputedStyle(glass, '::before').backdropFilter : null;
  return {
    root: { w: r2(rr.width), h: r2(rr.height) },
    zoom: getComputedStyle(root.closest('.device')).zoom,
    theme: document.documentElement.dataset.theme,
    rtMedia: matchMedia('(prefers-reduced-transparency: reduce)').matches,
    motionMedia: matchMedia('(prefers-reduced-motion: reduce)').matches,
    backdrop,
    elements,
    mask,
  };
}

// Цвета корня `.app`: все custom properties, которые на нём определены и разрешаются в цвет.
// Значение берём не из текста свойства, а через пробу: `color: var(--x)` → getComputedStyle (браузер
// раскрывает light-dark(), color-mix и т. п.). Точное значение — из разобранной строки rgb()/color(srgb),
// canvas служит перекрёстной проверкой (его getImageData на полупрозрачном цвете теряет точность из-за
// премультипликации, поэтому для альфы<255 сверяем с допуском и сообщаем отклонение)
function resolveColorsInPage({ appSel, theme }) {
  const root = document.querySelector(appSel);
  const names = new Set();
  const walk = (rules) => {
    for (const r of rules) {
      if (r.style) for (const p of r.style) if (p.startsWith('--')) names.add(p);
      if (r.cssRules) walk(r.cssRules);
    }
  };
  // Только таблицы iOS-колонки: доска грузит и Android-стили (--md-ref-*, --md-sys-*) и свои (--board),
  // а custom properties наследуются, так что на iOS-корне они «определены», хотя принадлежат не ему
  for (const sh of document.styleSheets) {
    if (!/\/dropweb\/(tokens|glass|app)\.css$/.test(sh.href ?? '')) continue;
    walk(sh.cssRules);
  }
  for (const p of root.style) if (p.startsWith('--')) names.add(p);
  // Из объявленного оставляем то, что реально определено на корне (вложенные области вроде .glass — нет)
  const cs = getComputedStyle(root);
  const defined = [...names].filter((n) => cs.getPropertyValue(n).trim() !== '').sort();

  // Обёртка с «сентинелом»: если var() не разрешился в цвет, проба наследует цвет обёртки.
  // Два разных сентинела исключают случайное совпадение настоящего цвета с сентинелом
  const wrap = document.createElement('div');
  wrap.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden;pointer-events:none;transition:none;color:rgb(1, 2, 3)';
  const probe = document.createElement('div');
  probe.style.cssText = 'transition:none';
  wrap.append(probe);
  root.append(wrap);
  const cv = document.createElement('canvas');
  cv.width = cv.height = 1;
  const g = cv.getContext('2d', { willReadFrequently: true });
  const hex2 = (n) => n.toString(16).padStart(2, '0').toUpperCase();
  const toHex = ([r, gg, b, a]) => `#${hex2(r)}${hex2(gg)}${hex2(b)}${a === 255 ? '' : hex2(a)}`;
  const parse = (s) => {
    let m = s.match(/^rgba?\(([^)]+)\)$/);
    if (m) {
      const p = m[1].split(/[\s,/]+/).filter(Boolean).map(Number);
      return [p[0], p[1], p[2], Math.round((p.length > 3 ? p[3] : 1) * 255)];
    }
    m = s.match(/^color\(srgb ([^)]+)\)$/);
    if (m) {
      const p = m[1].split(/[\s/]+/).filter(Boolean).map(Number);
      return [Math.round(p[0] * 255), Math.round(p[1] * 255), Math.round(p[2] * 255), Math.round((p.length > 3 ? p[3] : 1) * 255)];
    }
    throw new Error(`неизвестный формат цвета: ${s}`);
  };
  const SENT_A = 'rgb(1, 2, 3)', SENT_B = 'rgb(4, 5, 6)';
  const stats = { translucent: 0, maxRgbDev: 0, maxAlphaDev: 0 };
  const mismatches = [];
  // null — не цвет; иначе { rgba, hex }
  const resolve = (value, label) => {
    probe.style.color = value;
    wrap.style.color = SENT_A;
    const a = getComputedStyle(probe).color;
    wrap.style.color = SENT_B;
    const b = getComputedStyle(probe).color;
    wrap.style.color = SENT_A;
    if (a === SENT_A && b === SENT_B) return null;
    const rgba = parse(a);
    g.clearRect(0, 0, 1, 1);
    g.fillStyle = '#000';
    g.fillStyle = a;
    g.fillRect(0, 0, 1, 1);
    const px = [...g.getImageData(0, 0, 1, 1).data];
    if (rgba[3] === 255) {
      if (px.some((v, i) => v !== rgba[i])) mismatches.push(`${label}: разбор ${toHex(rgba)} ≠ canvas ${toHex(px)}`);
    } else {
      stats.translucent++;
      stats.maxRgbDev = Math.max(stats.maxRgbDev, ...[0, 1, 2].map((i) => Math.abs(px[i] - rgba[i])));
      stats.maxAlphaDev = Math.max(stats.maxAlphaDev, Math.abs(px[3] - rgba[3]));
    }
    return { rgba, hex: toHex(rgba) };
  };

  const vars = {};
  const nonColor = [];
  for (const n of defined) {
    const r = resolve(`var(${n})`, n);
    if (r) vars[n] = r.hex; else nonColor.push(n);
  }

  // Положительный контроль: известные значения обязаны читаться обратно побайтово
  wrap.style.setProperty('--dw-ctl', '#FF3B30');
  const controls = [
    ['#FF3B30', '#FF3B30'],
    ['#FF3B3080', '#FF3B3080'],
    ['light-dark(#FF3B30, #00FF00)', theme === 'light' ? '#FF3B30' : '#00FF00'],
    ['var(--dw-ctl)', '#FF3B30'],
  ].map(([css, want]) => {
    const r = resolve(css, `контроль ${css}`);
    return { css, want, got: r ? r.hex : null, ok: !!r && r.hex === want };
  });
  wrap.remove();
  return { vars, nonColor, controls, mismatches, stats };
}

// ---------- Съёмка ----------
function pngSize(buf) {
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

// Новый контекст на кадр: localStorage/sessionStorage и часы не протекают между кадрами
async function openPage(browser, { screen, theme, provider, mode }) {
  const ctx = await browser.newContext({
    // 1440×1200: при меньшей высоте fit() доски уменьшает .device через zoom, и снимок выходит
    // уменьшенным. Размер зафиксирован планом; zoom≠1 → скрипт падает ниже
    viewport: { width: 1440, height: 1200 },
    deviceScaleFactor: 2, reducedMotion: 'reduce', colorScheme: theme, locale: 'ru-RU', timezoneId: TZ,
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  if (mode === 'rt') {
    // До goto: первая отрисовка должна идти уже в режиме «Уменьшить прозрачность». Цветовую схему и
    // reduced-motion повторяем в том же вызове: setEmulatedMedia заменяет набор features целиком
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('Emulation.setEmulatedMedia', {
      features: [
        { name: 'prefers-color-scheme', value: theme },
        { name: 'prefers-reduced-motion', value: 'reduce' },
        { name: 'prefers-reduced-transparency', value: 'reduce' },
      ],
    });
  }
  await page.addInitScript(({ state, seed }) => {
    localStorage.setItem('dw-board:v1', JSON.stringify(state));
    // mulberry32: iOS-приложение Math.random не использует, но зерно нужно на случай изменений доски
    let a = seed >>> 0;
    Math.random = () => {
      a = (a + 0x6D2B79F5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }, { state: { screen, theme, provider, worst: false, view: 'ios' }, seed: SEED });
  await page.clock.install({ time: NOW });
  await page.clock.pauseAt(PAUSE_AT);
  await page.goto(URL);
  await page.waitForSelector(APP, { state: 'attached' });
  return { ctx, page, errors };
}

// Ждёт готовности по реальному времени. На таймауте падает с причинами — тихий неполный кадр хуже падения
async function waitReady(page, key) {
  let why = [];
  for (let i = 0; i < 200; i++) {
    why = await page.evaluate(notReadyInPage, APP);
    if (why.length === 0) return;
    await sleep(100);
  }
  throw new Error(`${key}: за 20 с не готово: ${why.join(', ')}`);
}

// Шрифты и картинки грузятся по реальной сети, а часы стоят; после каждой перемотки часов
// приложение может запустить новые переходы, поэтому ждём готовности до и после
async function settle(page, key, ms = SETTLE_MS) {
  await waitReady(page, key);
  await page.evaluate(() => document.fonts.ready.then(() => 0));
  await page.clock.runFor(ms);
  await waitReady(page, key);
  await page.clock.runFor(100);
  await waitReady(page, key);
}

async function shootFrame(browser, sc, theme, mode, provider, outDir) {
  const key = `${sc.key}-${theme}-${mode}-p${provider}`;
  const { ctx, page, errors } = await openPage(browser, { screen: sc.board, theme, provider, mode });
  try {
    await settle(page, key);
    for (const q of sc.clicks) {
      const ok = await page.evaluate(([app, sel]) => {
        const el = document.querySelector(`${app} ${sel}`);
        if (!el) return false;
        el.click();
        return true;
      }, [APP, q]);
      if (!ok) throw new Error(`${key}: не найден элемент клика ${q}`);
      await settle(page, key);
    }
    const edit = EDIT_OF[sc.key];
    if (edit) {
      await page.evaluate(applyEditInPage, { appSel: APP, edit });
      await settle(page, key, 100);
    }

    // Цикл стабильности: линза стекла (feImage data-URL) и WebGL-фон дорисовываются на реальных кадрах уже
    // после того, как DOM «готов»; призрак прежнего IP (ipSwap) гаснет и удаляется по WAAPI-промису через
    // 100 мс реального времени и на картинке невидим (opacity 0), но в раскладку попадает вторым элементом.
    // Поэтому стабильным считаем кадр, у которого два подряд снимка совпали побайтово И раскладка совпала.
    // Раскладку меряем после скриншота: animations:'disabled' сбрасывает бесконечные анимации (.spin крутится
    // и даёт разные bounding box в зависимости от угла), то есть измеряется та же поза, что на картинке
    const grab = async () => {
      const buf = await page.locator(APP).screenshot({ animations: 'disabled' });
      const data = await page.evaluate(collectInPage, { appSel: APP, spec: SPEC, always: ALWAYS_ARRAY });
      return { buf, data, sig: JSON.stringify(data) };
    };
    let prev = await grab(), cur = null;
    for (let i = 0; i < 10 && !cur; i++) {
      await sleep(150);
      const next = await grab();
      if (next.buf.equals(prev.buf) && next.sig === prev.sig) cur = next; else prev = next;
    }
    if (!cur) throw new Error(`${key}: кадр или раскладка не стабилизировались за 10 повторных снимков`);
    const { buf, data } = cur;

    if (data.zoom !== '1' || Math.abs(data.root.w - 411) > 0.01 || Math.abs(data.root.h - 914) > 0.01) {
      const dev = await page.evaluate(() => { const r = document.querySelector('[data-col="ios"] .device').getBoundingClientRect(); return `${r.width}×${r.height}`; });
      throw new Error(`${key}: окно 1440×1200, zoom .device = ${data.zoom}, .device ${dev}, корень ${data.root.w}×${data.root.h} — ожидалось 411×914, zoom 1`);
    }
    if (data.theme !== theme) throw new Error(`${key}: data-theme=${data.theme}, ожидалась ${theme}`);
    if (!data.motionMedia) throw new Error(`${key}: prefers-reduced-motion не включён`);
    if (data.rtMedia !== (mode === 'rt')) throw new Error(`${key}: prefers-reduced-transparency=${data.rtMedia}, режим ${mode}`);
    if (!data.mask.statusBar || !data.mask.homeIndicator) throw new Error(`${key}: не найдены имитации системного UI (.sys-bar/.sys-gesture)`);
    // Реальный эффект режима: в rt backdrop-filter у стекла выключен, в norm — нет
    const blurOff = data.backdrop === 'none';
    if (data.backdrop !== null && blurOff !== (mode === 'rt')) throw new Error(`${key}: backdrop-filter у .glass::before = «${data.backdrop}», режим ${mode}`);
    const dim = pngSize(buf);
    if (dim.w !== 822 || dim.h !== 1828) throw new Error(`${key}: PNG ${dim.w}×${dim.h}, ожидалось 822×1828`);
    writeFileSync(join(outDir, `${key}.png`), buf);
    if (errors.length) console.warn(`  ! ${key}: ошибки страницы: ${errors.join(' | ')}`);
    return {
      key, mode, blurOff, hasGlass: data.backdrop !== null,
      layout: { root: data.root, elements: data.elements, mask: data.mask },
    };
  } finally {
    await ctx.close();
  }
}

// Цвета: p<N> — провайдер, a<K> — K-й пресет акцента у провайдера 0. Чтение home-off и home-on идёт
// переключением сцены кнопкой в рейке доски (как это делает пользователь доски), состояние own/useOwn
// при этом сохраняется между сценами
async function shootColors(browser, theme, tag, provider, accent) {
  const first = accent === null ? 'home-off' : 'appearance';
  const { ctx, page, errors } = await openPage(browser, { screen: first, theme, provider, mode: 'norm' });
  const out = {};
  const label = `colors-${theme}-${tag}`;
  try {
    await settle(page, label);
    if (accent !== null) {
      const click = (sel) => page.evaluate(([app, q]) => {
        const el = document.querySelector(`${app} ${q}`);
        if (!el) return false;
        el.click();
        return true;
      }, [APP, sel]);
      if (!(await click('[data-act="colors"][data-arg="own"]'))) throw new Error(`${label}: нет строки «Свои»`);
      await settle(page, label);
      if (!(await click('[data-act="well"][data-arg="accent"]'))) throw new Error(`${label}: нет колодца акцента`);
      await settle(page, label);
      const dots = await page.evaluate((app) => document.querySelectorAll(`${app} .cp__dot`).length, APP);
      if (dots !== COLOR_ACCENTS.length) throw new Error(`${label}: в палитре ${dots} точек, ожидалось ${COLOR_ACCENTS.length}`);
      const ok = await page.evaluate(([app, k]) => { const d = document.querySelectorAll(`${app} .cp__dot`)[k]; if (!d) return false; d.click(); return true; }, [APP, accent]);
      if (!ok) throw new Error(`${label}: нет точки пресета ${accent}`);
      await settle(page, label);
    }
    let info = null;
    for (const scene of COLOR_SCENES) {
      // Рейка доски лежит вне .app; клик по ней вызывает scene() у обоих приложений
      if (!(accent === null && scene === 'home-off')) {
        const ok = await page.evaluate((id) => {
          const b = document.querySelector(`button[data-screen="${id}"]`);
          if (!b) return false;
          b.click();
          return true;
        }, scene);
        if (!ok) throw new Error(`${label}: нет кнопки сцены ${scene} в рейке доски`);
        await settle(page, label);
      }
      const r = await page.evaluate(resolveColorsInPage, { appSel: APP, theme });
      const bad = r.controls.filter((c) => !c.ok);
      if (bad.length) throw new Error(`${label}/${scene}: положительный контроль не прошёл: ${JSON.stringify(bad)}`);
      if (r.mismatches.length) throw new Error(`${label}/${scene}: расхождение разбора и canvas: ${r.mismatches.join('; ')}`);
      out[`${scene}-${theme}-${tag}`] = r.vars;
      info = { controls: r.controls, stats: r.stats, nonColor: r.nonColor };
    }
    if (errors.length) console.warn(`  ! ${label}: ошибки страницы: ${errors.join(' | ')}`);
    return { vars: out, info };
  } finally {
    await ctx.close();
  }
}

// Простой пул: JOBS контекстов одновременно; порядок результатов не важен — всё сортируется при записи
async function pool(items, n, fn) {
  let next = 0;
  const worker = async () => { for (;;) { const i = next++; if (i >= items.length) return; await fn(items[i], i); } };
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, worker));
}

async function main() {
  // Эталоны Android лежат отдельно и не должны пострадать от опечатки в IOS27_REF_DIR
  if ((OUT + sep).startsWith(join(ROOT, 'test', 'm3e') + sep)) throw new Error(`${OUT}: это папка эталонов Android`);
  mkdirSync(OUT, { recursive: true });
  // Идемпотентность: старые кадры не должны переживать смену набора сцен
  for (const f of readdirSync(OUT)) if (/^[a-z0-9-]+-(light|dark)-(norm|rt)-p\d\.png$/.test(f)) unlinkSync(join(OUT, f));

  await startServer();
  const browser = await chromium.launch();
  const layout = {}, colorsAll = {};
  const rt = { norm: { frames: 0, blurOn: 0, blurOff: 0, noGlass: 0 }, rt: { frames: 0, blurOn: 0, blurOff: 0, noGlass: 0 } };
  let colorInfo = null, varSets = new Map();
  const t0 = Date.now();
  try {
    const frameJobs = [];
    for (const sc of SCENES) {
      if (ONLY && !ONLY.includes(sc.key)) continue;
      for (const theme of THEMES) for (const mode of MODES) for (const provider of PROVIDERS) frameJobs.push({ sc, theme, mode, provider });
    }
    let colorJobs = [];
    for (const theme of THEMES) {
      for (const p of COLOR_PROVIDERS) colorJobs.push({ theme, tag: `p${p}`, provider: p, accent: null });
      for (const k of COLOR_ACCENTS) colorJobs.push({ theme, tag: `a${k}`, provider: 0, accent: k });
    }
    // Отладочный срез (IOS27_ONLY): по цветам — только два заходных кадра, чтобы быстро проверить обе ветки
    if (ONLY) colorJobs = colorJobs.filter((j) => (j.theme === 'light' && j.tag === 'p0') || (j.theme === 'dark' && j.tag === 'a3'));
    let done = 0;
    await pool(frameJobs, JOBS, async ({ sc, theme, mode, provider }) => {
      const r = await shootFrame(browser, sc, theme, mode, provider, OUT);
      layout[r.key] = r.layout;
      const s = rt[mode];
      s.frames++;
      if (!r.hasGlass) s.noGlass++; else if (r.blurOff) s.blurOff++; else s.blurOn++;
      done++;
      if (done % 20 === 0 || done === frameJobs.length) console.log(`кадры ${done}/${frameJobs.length}  (${Math.round((Date.now() - t0) / 1000)} с)`);
    });
    await pool(colorJobs, JOBS, async ({ theme, tag, provider, accent }) => {
      const r = await shootColors(browser, theme, tag, provider, accent);
      Object.assign(colorsAll, r.vars);
      colorInfo = r.info;
      for (const [k, v] of Object.entries(r.vars)) varSets.set(k, Object.keys(v).join(','));
      console.log(`цвета ${theme}-${tag}`);
    });
  } finally {
    await browser.close().catch(() => {});
    stopServer();
  }

  // Набор переменных обязан быть одинаковым во всех записях: Dart-тест идёт по ключам записи
  const distinct = [...new Set(varSets.values())];
  if (distinct.length !== 1) throw new Error(`наборы переменных отличаются между записями colors.json: ${distinct.map((d) => d.split(',').length).join(', ')}`);

  const sortObj = (o) => Object.fromEntries(Object.keys(o).sort().map((k) => [k, o[k]]));
  // Ключи сортируем: порядок записи не должен зависеть от очерёдности съёмки
  writeFileSync(join(OUT, 'layout.json'), `${JSON.stringify(sortObj(layout), null, 1)}\n`);
  const colorsSorted = sortObj(Object.fromEntries(Object.entries(colorsAll).map(([k, v]) => [k, sortObj(v)])));
  writeFileSync(join(OUT, 'colors.json'), `${JSON.stringify(colorsSorted, null, 1)}\n`);

  // Имена, ни разу не нашедшиеся ни в одном кадре, — подозрение на опечатку в селекторе
  const seen = new Set();
  for (const e of Object.values(layout)) for (const [n, v] of Object.entries(e.elements)) if (v !== null) seen.add(n);
  const never = SPEC.map((s) => s[0]).filter((n) => !seen.has(n));

  const varNames = Object.keys(Object.values(colorsSorted)[0]);
  console.log(`\nГотово: ${Object.keys(layout).length} кадров (${SCENES.length} сцен × ${THEMES.length} темы × ${MODES.length} режима × ${PROVIDERS.length} провайдера), `
    + `822×1828 px, layout.json, colors.json (${Object.keys(colorsSorted).length} ключей × ${varNames.length} переменных) → ${OUT}`);
  console.log(`Переменные colors.json: ${varNames.join(' ')}`);
  console.log(`Не цвета (отброшены): ${colorInfo.nonColor.join(' ')}`);
  console.log(`Полупрозрачные: канал canvas отклоняется от точного разбора до ${colorInfo.stats.maxRgbDev} по RGB и ${colorInfo.stats.maxAlphaDev} по альфе (в json идёт точный разбор)`);
  console.log(`Положительный контроль цвета: ${colorInfo.controls.map((c) => `${c.css}→${c.got}`).join('; ')}`);
  for (const m of MODES) {
    const s = rt[m];
    console.log(`Режим ${m}: кадров ${s.frames}, backdrop-filter у .glass::before = none в ${s.blurOff}, не none в ${s.blurOn}, без стекла ${s.noGlass}`);
  }
  console.log(`Имена раскладки без единого совпадения: ${never.length ? never.join(' ') : '—'}`);
  console.log(`Время: ${Math.round((Date.now() - t0) / 1000)} с, JOBS=${JOBS}`);
}

main().catch((e) => { console.error(e); stopServer(); process.exit(1); });
