#!/usr/bin/env node
// Генератор тёмной иконки лаунчера Android: android/app/src/main/res/{drawable,mipmap-*}/ic_launcher*.
// Запуск из корня репозитория: node tool/canon/gen_launcher_dark.mjs [каталог/доски]
//
// Повторяет android-часть canon/dropweb/icon/build.mjs, но с PALETTE.dark вместо PALETTE.light
// и пишет прямо в res/ этого репозитория. Сам build.mjs не запускаем: он стирает и пересоздаёт
// canon/dropweb/icon/{ios,android}, а канон здесь только для чтения.
import { mkdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const BOARD = resolve(process.argv[2] ?? '/Users/mac/Documents/projects/canon/dropweb');
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const RES = join(ROOT, 'android/app/src/main/res');

const { PALETTE, androidMark, androidIcon } = await import(pathToFileURL(`${BOARD}/icon/icon.js`).href);

// androidIcon() не принимает палитру (второй аргумент — тема монохрома) и жёстко читает
// PALETTE.light. Чтобы не копировать рисунок знака и не править канон на диске, подменяем
// значения светлой палитры тёмными в памяти этого процесса: PALETTE — обычный объект.
// Тёмный фон — SYSTEM_DARK (#252525→#131313): это тот же градиент, что iosFlat('dark')
// кладёт в dropweb-1024-dark.svg, поэтому android и iOS-dark получаются одного цвета.
const p = PALETTE.dark;
if (!Array.isArray(p.bg) || p.bg.length !== 2) throw new Error('PALETTE.dark.bg должен быть парой цветов');
Object.assign(PALETTE.light, p);

const put = (path, text) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
};

const n2 = (v) => +v.toFixed(2);
const argb = (hex) => `#FF${hex.slice(1).toUpperCase()}`;
// Заливка пути VectorDrawable: строка — сплошной цвет, пара цветов — вертикальный градиент
// через aapt:attr (API 24+, адаптивной иконке нужен 26, так что поддержан везде)
const vpath = ({ d, fill, alpha = 1, y0, y1 }) => {
  const a = alpha < 1 ? `\n        android:fillAlpha="${alpha}"` : '';
  if (typeof fill === 'string') return `    <path\n        android:fillColor="${fill}"${a}\n        android:pathData="${d}" />`;
  return `    <path${a}\n        android:pathData="${d}">\n        <aapt:attr name="android:fillColor">\n`
    + `            <gradient android:type="linear" android:startX="0" android:startY="${n2(y0)}" android:endX="0" android:endY="${n2(y1)}">\n`
    + `                <item android:offset="0" android:color="${argb(fill[0])}" />\n`
    + `                <item android:offset="1" android:color="${argb(fill[1])}" />\n`
    + `            </gradient>\n        </aapt:attr>\n    </path>`;
};
const vector = (paths, comment) => `<?xml version="1.0" encoding="utf-8"?>
<!-- ${comment} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
${paths.map(vpath).join('\n')}
</vector>
`;

const ADAPTIVE = `<?xml version="1.0" encoding="utf-8"?>
<!-- Адаптивная иконка dropweb: слои 108 dp, маску выбирает лаунчер.
     monochrome — для тематических иконок Android 13+ -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
`;

const m = androidMark();
put(join(RES, 'mipmap-anydpi-v26/ic_launcher.xml'), ADAPTIVE);
put(join(RES, 'mipmap-anydpi-v26/ic_launcher_round.xml'), ADAPTIVE);
put(join(RES, 'drawable/ic_launcher_background.xml'), vector(
  [{ d: 'M0 0H108V108H0Z', fill: p.bg, y0: 18, y1: 90 }],
  'Фон: тёмный градиент System Dark на все 108 dp, без маски и теней. Градиент по видимым 72 dp, как на iOS'));
put(join(RES, 'drawable/ic_launcher_foreground.xml'), vector([
  { d: m.shadow, fill: p.shadow, alpha: p.shadowOpacity, y0: m.shadowBox.y, y1: m.shadowBox.y + m.shadowBox.h },
  { d: m.letters, fill: p.letters, y0: m.box.y, y1: m.box.y + m.box.h },
], 'Знак «db» с тенью ANSI, неоновые буквы на тёмном фоне: 50 × 40 dp по центру, целиком в безопасном круге 66 dp'));
// Монохром не зависит от фона: система красит его в тон обоев (значок Android 13+, плитка
// быстрых настроек, малая иконка VPN-уведомления), поэтому остаётся белым, как в светлом каноне
put(join(RES, 'drawable/ic_launcher_monochrome.xml'), vector([
  { d: m.shadow, fill: '#FFFFFFFF', alpha: PALETTE.mono.shadowOpacity },
  { d: m.letters, fill: '#FFFFFFFF' },
], 'Монохром для тематической иконки: система перекрашивает его в тон обоев, альфа тени сохраняется'));

// Растр. minSdk = 24, а адаптивные иконки есть только с API 26: на Android 7.x лаунчер берёт
// mipmap-*/ic_launcher.png, поэтому PNG рисуем в том же тёмном варианте под квадратной и
// круглой маской Launcher3. Растеризует resvg через npx (в системе нет rsvg/magick/inkscape)
const standalone = (svg, size) => svg.replace('<svg ', `<svg width="${size}" height="${size}" `).replace(' aria-hidden="true"', '') + '\n';
const TMP = mkdtempSync(join(tmpdir(), 'dropweb-launcher-'));
try {
  const DENSITIES = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
  for (const [name, shape] of [['ic_launcher', 'square'], ['ic_launcher_round', 'circle']]) {
    const svg = join(TMP, `${name}.svg`);
    writeFileSync(svg, standalone(androidIcon(shape, null, 'l'), 192));
    for (const [dpi, size] of Object.entries(DENSITIES)) {
      const png = join(RES, `mipmap-${dpi}/${name}.png`);
      mkdirSync(dirname(png), { recursive: true });
      execFileSync('npx', ['-y', '@resvg/resvg-js-cli', '--fit-width', String(size), svg, png], { stdio: 'inherit' });
    }
  }
} finally {
  rmSync(TMP, { recursive: true, force: true });
}
console.log('ok: тёмная иконка лаунчера записана в', RES);
