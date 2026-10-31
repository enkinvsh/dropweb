#!/usr/bin/env node
// Генератор assets/images/ios27/about_icon_{default,dark}.png: грани иконки для страницы «О программе» iOS.
// Читает canon/dropweb/icon/icon.js (iosPaint, iosForeground, iosMask), канон только читается.
// Запуск из корня репозитория: node tool/canon/gen_ios_about_icon.mjs [каталог/доски] [каталог/вывода]
// Нужны сеть для `npx -y @resvg/resvg-js-cli` и Mac владельца (путь к канону ниже).
//
// Почему не плоский dropweb-1024*.png: доска рисует appIcon() (app.js:15-27) с маской iosMask(96, 12),
// чёрной кромкой 22, белым градиентным ободком 9 и бликами на буквах, а у плоского PNG этого нет.
// Маска запекается в альфу, поэтому во Flutter иконка рисуется обычным Image.asset без клипа.
// build.mjs канона НЕ запускать: он стирает icon/ios. Размер 288 px = 96 pt @3x; результат
// детерминирован (при повторном запуске те же байты).
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const CANON = '/Users/mac/Documents/projects/canon';
const BOARD = resolve(process.argv[2] ?? `${CANON}/dropweb`);
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const OUT = resolve(process.argv[3] ?? join(ROOT, 'assets/images/ios27'));
const SIZE = 288;

const { iosPaint, iosForeground, iosMask } = await import(pathToFileURL(`${BOARD}/icon/icon.js`).href);

// Одна грань: слои и порядок как у `face` в appIcon(); координаты в холсте 1024, маска внешняя —
// с теми же 12 шагами дуги, что у clip-path доски (там она считалась в пикселях 96, здесь в 1024:
// форма та же, масштаб линейный).
function face(mode) {
  const p = iosPaint(mode);
  const dark = mode === 'dark';
  const d = iosMask(1024);
  const outer = iosMask(1024, 12);
  const [g0, g1] = p.bg;
  // Вложенный svg переднего плана: viewBox 1024 ложится 1:1, uid разводит id фильтров и градиентов.
  const fg = iosForeground(p, { uid: `ai-${mode}` }).replace('<svg ', '<svg x="0" y="0" width="1024" height="1024" ');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 1024 1024"><defs>`
    + `<clipPath id="o"><path d="${outer}"/></clipPath>`
    + `<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${g0}"/><stop offset="1" stop-color="${g1}"/></linearGradient>`
    + `<clipPath id="c"><path d="${d}"/></clipPath>`
    + `<linearGradient id="r" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="${dark ? 0.32 : 0.55}"/>`
    + `<stop offset=".45" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="${dark ? 0.14 : 0.25}"/></linearGradient></defs>`
    + `<g clip-path="url(#o)"><rect width="1024" height="1024" fill="url(#bg)"/>`
    + `<g clip-path="url(#c)" fill="none"><path d="${d}" stroke="#000" stroke-opacity="${dark ? 0.5 : 0.1}" stroke-width="22"/>`
    + `<path d="${d}" stroke="url(#r)" stroke-width="9"/></g>${fg}</g></svg>\n`;
}

mkdirSync(OUT, { recursive: true });
const TMP = mkdtempSync(join(tmpdir(), 'dropweb-about-icon-'));
try {
  for (const [mode, name] of [['default', 'about_icon_default'], ['dark', 'about_icon_dark']]) {
    const svg = join(TMP, `${name}.svg`);
    writeFileSync(svg, face(mode));
    execFileSync('npx', ['-y', '@resvg/resvg-js-cli', '--fit-width', String(SIZE), svg, join(OUT, `${name}.png`)], { stdio: 'inherit' });
  }
} finally {
  rmSync(TMP, { recursive: true, force: true });
}
console.log('ok: грани иконки записаны в', OUT);
