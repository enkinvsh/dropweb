#!/usr/bin/env node
// Генератор lib/ui/m3e/icon/app_icon.g.dart и test/m3e/fixtures/app_icon.json
// из canon/dropweb/icon/icon.js (androidIcon) и android.js («О программе»).
// Запуск из корня репозитория: node tool/canon/gen_icon.mjs [каталог/доски]
//
// Шаблон получается вызовом самого androidIcon('circle', {bg, fg}, uid) с метками вместо
// цветов: рисунок знака не копируется в Dart руками, а берётся из кода доски. Эталон для
// теста — SVG, который androidIcon выдаёт для 6 провайдеров × светлая/тёмная схема.
// Цвета fg/bg берутся из test/m3e/fixtures/schemes.json (их считал код доски, а не Dart),
// так что тест проверяет и шаблон, и scheme().icon сразу.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const BOARD = resolve(process.argv[2] ?? '/Users/mac/Documents/projects/canon/dropweb');
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const OUT_DART = resolve(ROOT, 'lib/ui/m3e/icon/app_icon.g.dart');
const OUT_JSON = resolve(ROOT, 'test/m3e/fixtures/app_icon.json');
const SCHEMES = resolve(ROOT, 'test/m3e/fixtures/schemes.json');

const { androidIcon } = await import(pathToFileURL(`${BOARD}/icon/icon.js`).href);
const { PROVIDERS, parseTheme } = await import(pathToFileURL(`${BOARD}/app.js`).href);

// uid на доске нужен только чтобы id внутри нескольких svg на странице не совпадали; во
// Flutter каждый SvgPicture разбирается отдельно, поэтому берём один постоянный
const UID = 'ai';
const TOKENS = { uid: '{{uid}}', bg: '{{bg}}', fg: '{{fg}}' };

const template = androidIcon('circle', { bg: TOKENS.bg, fg: TOKENS.fg }, TOKENS.uid);
for (const t of Object.values(TOKENS)) {
  if (!template.includes(t)) throw new Error(`в шаблоне нет метки ${t}`);
}
// Одинарные кавычки, $ и обратная косая в SVG доски не встречаются; проверка на случай обновления доски
if (/['$\\]/.test(template)) throw new Error('в SVG появились символы, требующие экранирования Dart');

const dart = `// СГЕНЕРИРОВАНО tool/canon/gen_icon.mjs. Не править руками.
// Источник: ${BOARD}/icon/icon.js, androidIcon('circle', {bg, fg}, uid)
// (так доска рисует значок на экране «О программе»).

/// SVG значка в круге; метки {{uid}}, {{bg}}, {{fg}} подставляет [m3eAppIconSvg].
const String kM3eAppIconTemplate =
    '${template}';

/// SVG значка dropweb в круге: знак цветом [fg] на плашке [bg] (hex \`#rrggbb\`).
///
/// [uid] попадает в id маски; нужен, только если несколько SVG разбираются вместе.
String m3eAppIconSvg({
  required String fg,
  required String bg,
  String uid = '${UID}',
}) =>
    kM3eAppIconTemplate
        .replaceAll('{{uid}}', uid)
        .replaceAll('{{bg}}', bg)
        .replaceAll('{{fg}}', fg);
`;

mkdirSync(dirname(OUT_DART), { recursive: true });
writeFileSync(OUT_DART, dart, 'utf8');
// Формат Dart приводим сразу, чтобы повторный dart format не менял файл
execFileSync('fvm', ['dart', 'format', OUT_DART], { stdio: 'ignore' });

// ---- Эталон ----
const schemes = JSON.parse(readFileSync(SCHEMES, 'utf8'));
const cases = [];
for (const p of PROVIDERS) {
  const { accent } = parseTheme(p.theme);
  const filter = p.theme.split(',')[0].trim();
  for (const dark of [false, true]) {
    const c = schemes.cases.find((x) => x.seed === accent && x.filter === filter && x.dark === dark);
    if (!c) throw new Error(`нет схемы ${accent}|${filter}|${dark} в schemes.json`);
    // Объект темы ровно как в android.js: icons = [scheme(light).icon, scheme(dark).icon]
    const theme = { fg: c.icon.fg, bg: c.icon.bg };
    cases.push({
      id: `${p.name}|${accent}|${filter}|${dark ? 'dark' : 'light'}`,
      seed: accent,
      filter,
      dark,
      fg: theme.fg,
      bg: theme.bg,
      svg: androidIcon('circle', theme, UID),
    });
  }
}
mkdirSync(dirname(OUT_JSON), { recursive: true });
writeFileSync(
  OUT_JSON,
  JSON.stringify({ source: `${BOARD}/icon/icon.js androidIcon('circle', theme, '${UID}'); цвета из schemes.json`, uid: UID, cases }, null, 2) + '\n',
  'utf8',
);
console.log(`записано ${OUT_DART} и ${OUT_JSON}: ${cases.length} эталонов`);
