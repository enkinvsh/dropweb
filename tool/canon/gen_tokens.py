#!/usr/bin/env python3
"""Генератор lib/ui/m3e/theme/tokens.g.dart из canon/material-3-expressive tokens.json.

Запуск из корня репозитория: python3 tool/canon/gen_tokens.py [путь/к/tokens.json]

Используемые пути в tokens.json:
  typescale.roles.<роль>.{scale,size,emphasized,font_token,weight,size_sp,line_height_sp,tracking_sp}
  shape.corner_scale.<имя>.{kind,dp}            shape.asymmetric.<имя>.corners_dp.{tl,tr,br,bl}
  elevation.levels.<levelN>.dp                  state.layer_opacity.<имя>.opacity, state.disabled_alpha_default
  motion.springs.{expressive,standard}.<имя>.{damping,stiffness}
  motion.legacy.durations_ms.<имя>.ms           motion.legacy.easing.<имя>.cubic_bezier

Вывод детерминирован: ключи берутся в порядке, заданном в этом файле, а не порядком JSON.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_SRC = "/Users/mac/Documents/projects/canon/material-3-expressive/sources/code/tokens.json"
OUT = Path(__file__).resolve().parents[2] / "lib/ui/m3e/theme/tokens.g.dart"

SCALES = ["display", "headline", "title", "body", "label"]
SIZES = ["large", "medium", "small"]
SPRING_SPEEDS = ["fast", "default", "slow"]
SPRING_KINDS = ["spatial", "effects"]


def camel(s: str) -> str:
    """Имя в kebab-case или snake_case превращает в lowerCamelCase."""
    parts = re.split(r"[-_]", s)
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def num(v: float) -> str:
    """Число как Dart double-литерал: repr даёт кратчайшую точную запись и всегда с точкой."""
    return repr(float(v))


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC)
    d = json.loads(src.read_text(encoding="utf-8"))
    L: list[str] = []
    w = L.append

    w("// СГЕНЕРИРОВАНО tool/canon/gen_tokens.py. Не править руками.")
    w(f"// Источник: {src}")
    w("// Пути в JSON: typescale.roles, shape.corner_scale, shape.asymmetric, elevation.levels,")
    w("// state.layer_opacity, motion.springs, motion.legacy.durations_ms, motion.legacy.easing.")
    w("")
    w("import 'package:flutter/animation.dart';")
    w("import 'package:flutter/painting.dart';")
    w("")

    # ---- Типошкала ----
    w("/// Роль типошкалы M3 (в sp/dp Flutter это логические пиксели).")
    w("class M3eTypeStyle {")
    w("  const M3eTypeStyle({")
    w("    required this.size,")
    w("    required this.lineHeight,")
    w("    required this.tracking,")
    w("    required this.weight,")
    w("    required this.brand,")
    w("  });")
    w("")
    w("  final double size;")
    w("  final double lineHeight;")
    w("")
    w("  /// Разрядка в логических пикселях (tracking_sp), в Flutter это `letterSpacing`.")
    w("  final double tracking;")
    w("  final int weight;")
    w("")
    w("  /// Роль принадлежит brand-гарнитуре (display, headline, title-large), остальные — plain.")
    w("  final bool brand;")
    w("")
    w("  /// Множитель `TextStyle.height`: у Flutter высота строки задаётся долей кегля.")
    w("  double get height => lineHeight / size;")
    w("")
    w("  FontWeight get fontWeight => FontWeight.values[weight ~/ 100 - 1];")
    w("}")
    w("")
    w("abstract final class M3eType {")
    roles = d["typescale"]["roles"]
    for emph in (False, True):
        for sc in SCALES:
            for sz in SIZES:
                name = f"{sc}{sz.capitalize()}{'Emphasized' if emph else ''}"
                r = roles[name]
                assert r["scale"] == sc and r["size"] == sz and r["emphasized"] == emph, name
                brand = r["font_token"] == "Brand"
                w(
                    f"  static const {name} = M3eTypeStyle(size: {num(r['size_sp'])}, "
                    f"lineHeight: {num(r['line_height_sp'])}, tracking: {num(r['tracking_sp'])}, "
                    f"weight: {r['weight']}, brand: {'true' if brand else 'false'});"
                )
    assert len(roles) == 30
    w("}")
    w("")

    # ---- Формы ----
    cs = d["shape"]["corner_scale"]
    w("/// Радиусы скругления в dp. `full` — CircleShape: радиус больше любой стороны,")
    w("/// RRect во Flutter сам ужимает его до половины меньшей стороны.")
    w("abstract final class M3eShape {")
    for key in ["none", "extra-small", "small", "medium", "large", "large-increased",
                "extra-large", "extra-large-increased", "extra-extra-large"]:
        # у none в JSON dp = null, значение лежит в corners_dp
        dp = cs[key]["dp"] if cs[key]["dp"] is not None else cs[key]["corners_dp"]["tl"]
        w(f"  static const {camel(key)} = {num(dp)};")
    assert cs["full"]["kind"] == "full"
    w("  static const full = 9999.0;")
    w("}")
    w("")
    w("/// Несимметричные углы (tl, tr, br, bl) в dp.")
    w("class M3eCorners {")
    w("  const M3eCorners(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);")
    w("")
    w("  final double topLeft;")
    w("  final double topRight;")
    w("  final double bottomRight;")
    w("  final double bottomLeft;")
    w("")
    w("  BorderRadius get borderRadius => BorderRadius.only(")
    w("        topLeft: Radius.circular(topLeft),")
    w("        topRight: Radius.circular(topRight),")
    w("        bottomRight: Radius.circular(bottomRight),")
    w("        bottomLeft: Radius.circular(bottomLeft),")
    w("      );")
    w("}")
    w("")
    w("abstract final class M3eShapeAsymmetric {")
    asym = d["shape"]["asymmetric"]
    for key in ["extra-large-top", "extra-small-top", "large-end", "large-start", "large-top"]:
        c = asym[key]["corners_dp"]
        w(
            f"  static const {camel(key)} = M3eCorners({num(c['tl'])}, {num(c['tr'])}, "
            f"{num(c['br'])}, {num(c['bl'])});"
        )
    w("}")
    w("")

    # ---- Высота ----
    w("/// Уровни высоты в dp. Тень рисует платформа, токены задают только Z.")
    w("abstract final class M3eElevation {")
    for i in range(6):
        w(f"  static const level{i} = {num(d['elevation']['levels'][f'level{i}']['dp'])};")
    w("}")
    w("")

    # ---- Состояния ----
    lo = d["state"]["layer_opacity"]
    w("/// Прозрачности state layer и доля цвета для отключённого содержимого.")
    w("abstract final class M3eState {")
    for key in ["hover", "focus", "pressed", "dragged"]:
        w(f"  static const {key} = {num(lo[key]['opacity'])};")
    w(f"  static const disabledContent = {num(d['state']['disabled_alpha_default'])};")
    w("}")
    w("")

    # ---- Пружины ----
    w("/// Пружина M3: относительное демпфирование (ratio) и жёсткость.")
    w("class M3eSpringSpec {")
    w("  const M3eSpringSpec({required this.damping, required this.stiffness});")
    w("")
    w("  final double damping;")
    w("  final double stiffness;")
    w("")
    w("  /// Масса 1; критическое демпфирование = 2*sqrt(k), абсолютное = ratio * оно.")
    w("  SpringDescription get description =>")
    w("      SpringDescription.withDampingRatio(mass: 1, stiffness: stiffness, ratio: damping);")
    w("}")
    w("")
    for group, cls in (("expressive", "M3eSpring"), ("standard", "M3eSpringStandard")):
        sp = d["motion"]["springs"][group]
        w(f"/// Пружины схемы {group} (motion.springs.{group}).")
        w(f"abstract final class {cls} {{")
        for kind in SPRING_KINDS:
            for speed in SPRING_SPEEDS:
                t = sp[f"{speed}_{kind}"]
                w(
                    f"  static const {speed}{kind.capitalize()} = "
                    f"M3eSpringSpec(damping: {num(t['damping'])}, stiffness: {num(t['stiffness'])});"
                )
        w("}")
        w("")

    # ---- Кривые ----
    eas = d["motion"]["legacy"]["easing"]
    w("abstract final class M3eEasing {")
    for key in ["emphasized", "emphasized-accelerate", "emphasized-decelerate", "standard",
                "standard-accelerate", "standard-decelerate", "legacy", "legacy-accelerate",
                "legacy-decelerate", "linear"]:
        a, b, c, e = eas[key]["cubic_bezier"]
        w(f"  static const {camel(key)} = Cubic({num(a)}, {num(b)}, {num(c)}, {num(e)});")
    w("}")
    w("")

    # ---- Длительности ----
    du = d["motion"]["legacy"]["durations_ms"]
    w("abstract final class M3eDuration {")
    for key in ["short1", "short2", "short3", "short4", "medium1", "medium2", "medium3",
                "medium4", "long1", "long2", "long3", "long4", "extra-long1", "extra-long2",
                "extra-long3", "extra-long4"]:
        w(f"  static const {camel(key)} = Duration(milliseconds: {int(du[key]['ms'])});")
    w("}")
    w("")

    text = "\n".join(L)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    # Формат Dart приводим тут же, чтобы повторный dart format не менял файл
    subprocess.run(["fvm", "dart", "format", str(OUT)], check=True, capture_output=True)
    print(f"записано {OUT}")


if __name__ == "__main__":
    main()
