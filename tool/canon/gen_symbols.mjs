#!/usr/bin/env node
// Генератор lib/ui/m3e/symbols.g.dart из canon/dropweb/vendor/symbols/symbols.js.
// Запуск из корня репозитория: node tool/canon/gen_symbols.mjs [путь/к/symbols.js]
//
// Формат источника: SYMBOLS[имя] = { o: контур, f: заливка }, сетка 960, viewBox "0 -960 960 960"
// (Material Symbols Rounded, opsz 24, wght 400, GRAD 0). Порядок записей берём из файла
// как есть: он стабилен, поэтому вывод детерминирован.
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const DEFAULT_SRC = '/Users/mac/Documents/projects/canon/dropweb/vendor/symbols/symbols.js';
const src = resolve(process.argv[2] ?? DEFAULT_SRC);
const out = resolve(dirname(fileURLToPath(import.meta.url)), '../../lib/ui/m3e/symbols.g.dart');

const { SYMBOLS } = await import(pathToFileURL(src).href);
const names = Object.keys(SYMBOLS);

const camel = (s) => s.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
// Путь SVG содержит только буквы, цифры, пробелы, минус и точку; $ и кавычки экранируем на случай обновления шрифта
const lit = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;

const L = [];
L.push('// СГЕНЕРИРОВАНО tool/canon/gen_symbols.mjs. Не править руками.');
L.push(`// Источник: ${src}`);
L.push('// Material Symbols Rounded (Apache-2.0, текст лицензии в symbols.LICENSE рядом).');
L.push('// Сетка 960, viewBox "0 -960 960 960"; o — контур (FILL 0), f — заливка (FILL 1).');
L.push('');
L.push('/// Значки, вынутые из Material Symbols Rounded.');
L.push('enum M3eSymbol {');
names.forEach((n, i) => {
  L.push(`  ${camel(n)}(${lit(n)})${i === names.length - 1 ? ';' : ','}`);
});
L.push('');
L.push('  const M3eSymbol(this.id);');
L.push('');
L.push('  /// Имя значка в Material Symbols (snake_case).');
L.push('  final String id;');
L.push('}');
L.push('');
L.push('/// Данные пути SVG: контурный и залитый вариант.');
L.push('class M3eSymbolPaths {');
L.push('  const M3eSymbolPaths({required this.o, required this.f});');
L.push('');
L.push('  final String o;');
L.push('  final String f;');
L.push('}');
L.push('');
L.push('const Map<M3eSymbol, M3eSymbolPaths> kM3eSymbolPaths = {');
for (const n of names) {
  const g = SYMBOLS[n];
  if (!g.o || !g.f) throw new Error(`у значка ${n} нет o или f`);
  L.push(`  M3eSymbol.${camel(n)}: M3eSymbolPaths(o: ${lit(g.o)}, f: ${lit(g.f)}),`);
}
L.push('};');
L.push('');

writeFileSync(out, L.join('\n'), 'utf8');
// Формат Dart приводим сразу, чтобы повторный dart format не менял файл
execFileSync('fvm', ['dart', 'format', out], { stdio: 'ignore' });
console.log(`записано ${out}: ${names.length} значков`);
