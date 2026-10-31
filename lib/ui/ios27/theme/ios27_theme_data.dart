// Material-тема под iOS-редизайн: всё, что виджеты Flutter берут из `Theme.of`, идёт из палитры доски.

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/cupertino.dart' show NoDefaultCupertinoThemeData;
import 'package:flutter/material.dart';

/// [ThemeData] для поддерева [Ios27ThemeScope]; цвета берутся из [c].
///
/// Экраны iOS рисуются своими виджетами и токенами, а эта тема нужна, чтобы чужие виджеты Material
/// (поле ввода, диалог системного пикера, `Scaffold`) не выбивались из палитры доски.
ThemeData ios27ThemeData(Ios27Colors c) {
  final p = c.palette;
  final accent = c.accentColor;
  final onAccent = c.onAccent;
  // Тот же стиль, что кладёт в поддерево `DefaultTextStyle` скоупа: Material строит тексты от
  // `textTheme`, и без этого `Text` внутри Material-виджетов получил бы шрифт и кегль Material.
  final body = ios27RoleStyle(Ios27Text.body, color: p.label);

  final base = ThemeData(
    // Material 3 включён, чтобы не тянуть устаревшие значения по умолчанию; видимых отличий нет,
    // потому что цвета и формы заданы ниже.
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: ColorScheme(
      brightness: c.brightness,
      primary: accent,
      onPrimary: onAccent,
      // У iOS одного акцента: вторичный цвет Material равен основному.
      secondary: accent,
      onSecondary: onAccent,
      error: p.red,
      // Текст на красной заливке у доски белый (`.row--danger` без заливки, `.glass--tint` с белым
      // текстом); в палитре отдельного токена нет, а Material требует цвет поверх `error`.
      onError: Colors.white,
      surface: p.bg,
      onSurface: p.label,
      onSurfaceVariant: p.label2,
      outline: p.separator,
      outlineVariant: p.separator,
      // Затемнение под листом: `.dim` доски (app.css:273) берёт именно `--dim`.
      scrim: p.dim,
      // Material 3 подмешивает surfaceTint к приподнятым поверхностям; на iOS приподнятость
      // выражает материал стекла, а не тон, поэтому подмес отключён.
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    fontFamily: FontFamily.onest.value,
    // Эмодзи и флаги рисует Twemoji: системного эмодзи-шрифта в golden нет, и флаги стали бы буквами.
    fontFamilyFallback: [FontFamily.twEmoji.value],
    // iOS: упругая прокрутка и переходы Cupertino, в том числе в тестах на macOS.
    platform: TargetPlatform.iOS,
    // iOS не рисует рябь Material: нажатие показывает сам элемент (прозрачность, масштаб, стекло).
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionHandleColor: accent,
      // Подсветка выделения — мягкий тон акцента доски (`--accent-soft`), своего токена у выделения нет.
      selectionColor: c.accentSoft,
    ),
    // Cupertino-виджеты внутри Material (пикеры, переключатели) берут акцент отсюда.
    cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
      brightness: c.brightness,
      primaryColor: accent,
    ),
  );

  // Тексты Material-виджетов красим в `--label`, а основной стиль делаем ролью body: типографика
  // по умолчанию красит их чёрным/белым и берёт кегль Material. Делается после сборки, потому что
  // `textTheme` по умолчанию зависит от яркости и шрифта, которые задаёт сам `ThemeData`.
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: p.label, displayColor: p.label)
        .copyWith(bodyLarge: body, bodyMedium: body),
  );
}
