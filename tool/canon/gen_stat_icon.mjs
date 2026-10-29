#!/usr/bin/env node
// Генератор android/app/src/main/res/drawable/ic_stat_dropweb.xml — значок плитки быстрых
// настроек и маленькой иконки уведомления VPN.
// Запуск из корня репозитория: node tool/canon/gen_stat_icon.mjs [каталог/доски]
//
// Почему не ic_launcher_monochrome: это слой адаптивной иконки 108 dp, знак в нём занимает
// ~50 dp внутри безопасной зоны. В слоте 24 dp (плитка, строка состояния) он сжимается до
// ~11 dp и выглядит карликовым. Здесь тот же знак «db», но вьюпорт 24 × 24 растянут по
// рамке букв: знак занимает 20 dp из 24 (живая зона системных значков Material, 2 dp поля).
// Только буквы, одним белым цветом: тень ANSI на таком размере превращается в грязь, а
// градиенты и альфа системе в строке состояния не нужны — она берёт только форму.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const BOARD = resolve(process.argv[2] ?? '/Users/mac/Documents/projects/canon/dropweb');
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const OUT = join(ROOT, 'android/app/src/main/res/drawable/ic_stat_dropweb.xml');

const { mark, BOX } = await import(pathToFileURL(`${BOARD}/icon/icon.js`).href);

const SIZE = 24, LIVE = 20;
// Масштаб по большей стороне рамки букв (она шире, чем выше), знак по центру вьюпорта.
// Преобразование запекаем в координаты пути (mark(s, tx, ty)), чтобы без <group>/transform
const s = LIVE / Math.max(BOX.w, BOX.h);
const tx = (SIZE - BOX.w * s) / 2 - BOX.x * s;
const ty = (SIZE - BOX.h * s) / 2 - BOX.y * s;
const m = mark(s, tx, ty);

const xml = `<?xml version="1.0" encoding="utf-8"?>
<!-- Значок для плитки быстрых настроек и уведомления VPN. Отдельно от ic_launcher_monochrome:
     тот — слой адаптивной иконки 108 dp и в слоте 24 dp сжимается до ~11 dp.
     Здесь знак «db» (только буквы, белый) занимает ~20 dp из 24 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${SIZE}dp"
    android:height="${SIZE}dp"
    android:viewportWidth="${SIZE}"
    android:viewportHeight="${SIZE}">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="${m.letters}" />
</vector>
`;
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, xml);
console.log('ok:', OUT);
