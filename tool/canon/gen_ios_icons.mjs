#!/usr/bin/env node
// Генератор lib/ui/ios27/icons.g.dart из карты значков `P` в canon/dropweb/app.js (строки 30-58).
// Запуск из корня репозитория: node tool/canon/gen_ios_icons.mjs [путь/к/app.js]
//
// Почему текстовый разбор, а не import: app.js тянет lens.js, bg.js, motion.js, которым нужен DOM.
// Карта P устроена строго: одна строка `имя: '<svg-фрагмент>',`, поэтому вынимаем её регуляркой
// и сверяем число значков с планом (26), чтобы тихо не потерять строку при правке доски.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const CANON = '/Users/mac/Documents/projects/canon';
const src = resolve(process.argv[2] ?? `${CANON}/dropweb/app.js`);
const out = resolve(dirname(fileURLToPath(import.meta.url)), '../../lib/ui/ios27/icons.g.dart');

const text = readFileSync(src, 'utf8');
const start = text.indexOf('const P = {\n');
if (start < 0) throw new Error('в app.js нет `const P = {`');
const end = text.indexOf('\n};', start);
if (end < 0) throw new Error('не найден конец карты P');
const block = text.slice(start + 'const P = {\n'.length, end);

// Комментарии внутри карты (`// Как rectangle.stack ...`) пропускаем, значки читаем построчно
const icons = [];
for (const line of block.split('\n')) {
  const t = line.trim();
  if (!t || t.startsWith('//')) continue;
  const m = t.match(/^([A-Za-z0-9]+): '(.*)',$/);
  if (!m) throw new Error(`строка карты P не разобрана: ${t.slice(0, 80)}`);
  icons.push([m[1], m[2]]);
}
const EXPECTED = 26;
if (icons.length !== EXPECTED) throw new Error(`в P ${icons.length} значков, ожидалось ${EXPECTED}`);
if (new Set(icons.map(([n]) => n)).size !== icons.length) throw new Error('повтор имён в P');
for (const [n, body] of icons) {
  // Тело — только фрагмент SVG без одинарных кавычек и `$`: иначе Dart-литерал придётся экранировать
  if (/['\\$]/.test(body)) throw new Error(`в значке ${n} символ, требующий экранирования`);
  if (!/^(<(path|circle|line|polyline|polygon|rect)\b[^>]*\/>)+$/.test(body)) throw new Error(`в значке ${n} неожиданная разметка: ${body.slice(0, 60)}`);
}

// Коммит доски в шапку: по нему видно, с какой версии канона сняты контуры
const git = (...a) => execFileSync('git', ['-C', CANON, ...a], { encoding: 'utf8' }).trim();
const commit = git('rev-parse', '--short=8', 'HEAD');
const dirty = git('status', '--short', '--', 'dropweb/app.js') !== '';
const stamp = dirty ? `${commit}+изменён` : commit;

const L = [];
L.push(`// СГЕНЕРИРОВАНО tool/canon/gen_ios_icons.mjs из canon/dropweb/app.js ${stamp}. Не править руками.`);
L.push('// Значки Feather (MIT), карта `P` в app.js:30-58. SF Symbols не берём: лицензия Apple только для макетов.');
L.push('// Сетка 24, контур без заливки, закруглённые окончания; толщина линии задаётся в единицах сетки,');
L.push('// как `stroke-width` в CSS доски (`.ico`, app.css:30), поэтому при размере 22 линия рисуется 2·22/24 px.');
L.push('');
L.push("import 'package:flutter/widgets.dart';");
L.push("import 'package:flutter_svg/flutter_svg.dart';");
L.push('');
L.push('/// Имена значков доски (ключи карты `P`).');
L.push('enum Ios27IconName {');
icons.forEach(([n], i) => L.push(`  ${n}${i === icons.length - 1 ? ';' : ','}`));
L.push('}');
L.push('');
L.push('/// Фрагменты SVG (то, что лежит внутри `<svg viewBox="0 0 24 24">`).');
L.push('const Map<Ios27IconName, String> kIos27IconBody = {');
for (const [n, body] of icons) L.push(`  Ios27IconName.${n}: '${body}',`);
L.push('};');
L.push('');
L.push('/// Размер и толщина линии значка в одном из мест доски (ссылки на app.css).');
L.push('class Ios27IconSpec {');
L.push('  const Ios27IconSpec(this.size, [this.strokeWidth = 2]);');
L.push('');
L.push('  /// Сторона квадрата значка в логических пикселях.');
L.push('  final double size;');
L.push('');
L.push('  /// Толщина линии в единицах сетки 24.');
L.push('  final double strokeWidth;');
L.push('}');
L.push('');
L.push('/// Размеры значков по контекстам доски (app.css), чтобы экраны не угадывали числа.');
L.push('abstract final class Ios27IconSpecs {');
L.push('  /// `.ico` и `.dock-btn .ico` (app.css:30, 567).');
L.push('  static const standard = Ios27IconSpec(22);');
L.push('');
L.push('  /// Кнопка питания: `.power .ico` (app.css:91).');
L.push('  static const power = Ios27IconSpec(32, 2.1);');
L.push('');
L.push('  /// Значок в тексте кнопки и в тосте: `.btn .ico`, `.toast .ico` (app.css:121, 418).');
L.push('  static const button = Ios27IconSpec(20);');
L.push('');
L.push('  /// Кнопка листа: `.sheet__btn .ico` (app.css:356).');
L.push('  static const sheetButton = Ios27IconSpec(18, 2.4);');
L.push('');
L.push('  /// Значок в плитке строки и хвостовой шеврон: `.row__icon .ico`, `.row > .ico` (app.css:216, 240).');
L.push('  static const row = Ios27IconSpec(18);');
L.push('');
L.push('  /// Галочка выбранной строки: `.row > .ico.check` (app.css:241).');
L.push('  static const check = Ios27IconSpec(20, 2.5);');
L.push('');
L.push('  /// Значок пустого экрана: `.empty__icon.ico` (app.css:127).');
L.push('  static const empty = Ios27IconSpec(56, 1.75);');
L.push('');
L.push('  /// Значок ошибки поля: `.field-error .ico` (app.css:379).');
L.push('  static const fieldError = Ios27IconSpec(16);');
L.push('}');
L.push('');
L.push('/// Готовая SVG-строка значка [name] с толщиной линии [strokeWidth]; цвет линии задаёт [Ios27Icon].');
L.push('String ios27IconSvg(Ios27IconName name, {double strokeWidth = 2}) =>');
L.push("    '<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#000000\" '");
L.push("    'stroke-width=\"$strokeWidth\" stroke-linecap=\"round\" stroke-linejoin=\"round\">'");
L.push("    '${kIos27IconBody[name]}</svg>';");
L.push('');
L.push('/// Значок доски. Цвет, как `currentColor` в CSS: не задан — берётся из [IconTheme], затем из текста.');
L.push('class Ios27Icon extends StatelessWidget {');
L.push('  const Ios27Icon(');
L.push('    this.name, {');
L.push('    super.key,');
L.push('    this.size = 22,');
L.push('    this.strokeWidth = 2,');
L.push('    this.color,');
L.push('  });');
L.push('');
L.push('  /// Значок по спецификации контекста из [Ios27IconSpecs].');
L.push('  Ios27Icon.spec(this.name, Ios27IconSpec spec, {super.key, this.color})');
L.push('      : size = spec.size,');
L.push('        strokeWidth = spec.strokeWidth;');
L.push('');
L.push('  final Ios27IconName name;');
L.push('  final double size;');
L.push('  final double strokeWidth;');
L.push('  final Color? color;');
L.push('');
L.push('  @override');
L.push('  Widget build(BuildContext context) {');
L.push('    final c = color ??');
L.push('        IconTheme.of(context).color ??');
L.push('        DefaultTextStyle.of(context).style.color ??');
L.push('        const Color(0xFF000000);');
L.push('    // srcIn вместо цвета в самой разметке: полупрозрачный цвет красит значок один раз,');
L.push('    // а не дважды в местах, где линии пересекаются');
L.push('    return SvgPicture.string(');
L.push('      ios27IconSvg(name, strokeWidth: strokeWidth),');
L.push('      width: size,');
L.push('      height: size,');
L.push('      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),');
L.push('      excludeFromSemantics: true,');
L.push('    );');
L.push('  }');
L.push('}');
L.push('');

writeFileSync(out, L.join('\n'), 'utf8');
// Формат Dart приводим сразу, чтобы повторный dart format не менял файл
execFileSync('fvm', ['dart', 'format', out], { stdio: 'ignore' });
console.log(`записано ${out}: ${icons.length} значков, источник ${stamp}`);
