// СГЕНЕРИРОВАНО tool/canon/gen_ios_icons.mjs из canon/dropweb/app.js df156ea1. Не править руками.
// Значки Feather (MIT), карта `P` в app.js:30-58. SF Symbols не берём: лицензия Apple только для макетов.
// Сетка 24, контур без заливки, закруглённые окончания; толщина линии задаётся в единицах сетки,
// как `stroke-width` в CSS доски (`.ico`, app.css:30), поэтому при размере 22 линия рисуется 2·22/24 px.

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Имена значков доски (ключи карты `P`).
enum Ios27IconName {
  power,
  settings,
  right,
  left,
  more,
  check,
  x,
  plus,
  refresh,
  chat,
  trash,
  clipboard,
  link,
  qr,
  globe,
  layers,
  info,
  out,
  clock,
  alert,
  zap,
  stack,
  wifiOff,
  camera,
  shield,
  droplet;
}

/// Фрагменты SVG (то, что лежит внутри `<svg viewBox="0 0 24 24">`).
const Map<Ios27IconName, String> kIos27IconBody = {
  Ios27IconName.power:
      '<path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/>',
  Ios27IconName.settings:
      '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
  Ios27IconName.right: '<polyline points="9 18 15 12 9 6"/>',
  Ios27IconName.left: '<polyline points="15 18 9 12 15 6"/>',
  Ios27IconName.more:
      '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
  Ios27IconName.check: '<polyline points="20 6 9 17 4 12"/>',
  Ios27IconName.x:
      '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
  Ios27IconName.plus:
      '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
  Ios27IconName.refresh:
      '<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>',
  Ios27IconName.chat:
      '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>',
  Ios27IconName.trash:
      '<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  Ios27IconName.clipboard:
      '<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1"/>',
  Ios27IconName.link:
      '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  Ios27IconName.qr:
      '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM21 14v.01M14 21v.01M17 21h4v-3"/>',
  Ios27IconName.globe:
      '<circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
  Ios27IconName.layers:
      '<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>',
  Ios27IconName.info:
      '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>',
  Ios27IconName.out:
      '<line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/>',
  Ios27IconName.clock:
      '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  Ios27IconName.alert:
      '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
  Ios27IconName.zap:
      '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>',
  Ios27IconName.stack:
      '<rect x="2" y="10" width="20" height="12" rx="2.5"/><path d="M4.5 6h15M7.5 2h9"/>',
  Ios27IconName.wifiOff:
      '<line x1="1" y1="1" x2="23" y2="23"/><path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/><path d="M10.71 5.05A16 16 0 0 1 22.58 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/>',
  Ios27IconName.camera:
      '<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>',
  Ios27IconName.shield:
      '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
  Ios27IconName.droplet: '<path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/>',
};

/// Размер и толщина линии значка в одном из мест доски (ссылки на app.css).
class Ios27IconSpec {
  const Ios27IconSpec(this.size, [this.strokeWidth = 2]);

  /// Сторона квадрата значка в логических пикселях.
  final double size;

  /// Толщина линии в единицах сетки 24.
  final double strokeWidth;
}

/// Размеры значков по контекстам доски (app.css), чтобы экраны не угадывали числа.
abstract final class Ios27IconSpecs {
  /// `.ico` и `.dock-btn .ico` (app.css:30, 567).
  static const standard = Ios27IconSpec(22);

  /// Кнопка питания: `.power .ico` (app.css:91).
  static const power = Ios27IconSpec(32, 2.1);

  /// Значок в тексте кнопки и в тосте: `.btn .ico`, `.toast .ico` (app.css:121, 418).
  static const button = Ios27IconSpec(20);

  /// Кнопка листа: `.sheet__btn .ico` (app.css:356).
  static const sheetButton = Ios27IconSpec(18, 2.4);

  /// Значок в плитке строки и хвостовой шеврон: `.row__icon .ico`, `.row > .ico` (app.css:216, 240).
  static const row = Ios27IconSpec(18);

  /// Галочка выбранной строки: `.row > .ico.check` (app.css:241).
  static const check = Ios27IconSpec(20, 2.5);

  /// Значок пустого экрана: `.empty__icon.ico` (app.css:127).
  static const empty = Ios27IconSpec(56, 1.75);

  /// Значок ошибки поля: `.field-error .ico` (app.css:379).
  static const fieldError = Ios27IconSpec(16);
}

/// Готовая SVG-строка значка [name] с толщиной линии [strokeWidth]; цвет линии задаёт [Ios27Icon].
String ios27IconSvg(Ios27IconName name, {double strokeWidth = 2}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" '
    'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">'
    '${kIos27IconBody[name]}</svg>';

/// Значок доски. Цвет, как `currentColor` в CSS: не задан — берётся из [IconTheme], затем из текста.
class Ios27Icon extends StatelessWidget {
  const Ios27Icon(
    this.name, {
    super.key,
    this.size = 22,
    this.strokeWidth = 2,
    this.color,
  });

  /// Значок по спецификации контекста из [Ios27IconSpecs].
  Ios27Icon.spec(this.name, Ios27IconSpec spec, {super.key, this.color})
      : size = spec.size,
        strokeWidth = spec.strokeWidth;

  final Ios27IconName name;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    // srcIn вместо цвета в самой разметке: полупрозрачный цвет красит значок один раз,
    // а не дважды в местах, где линии пересекаются
    return SvgPicture.string(
      ios27IconSvg(name, strokeWidth: strokeWidth),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
