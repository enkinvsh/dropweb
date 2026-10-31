// Обвязка тестов «Оформления»: тема из настоящего провайдера с заданным стартом, открытие страницы и листа.
//
// Страница и лист кладутся маршрутом в корневой навигатор и ставят свой `Ios27ThemeScope` из
// `themeSettingProvider`, поэтому тему провайдера (p0..p5 доски) задаёт не окно, а начальное
// состояние ThemeSetting.

import 'dart:async';
import 'dart:io';

import 'package:dropweb/models/config.dart' show ThemeProps;
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart' show Ios27GlassColors;
import 'package:dropweb/ui/ios27/screens/appearance/ios27_appearance_page.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_theme_presets.dart'
    show kIos27ThemesKey;
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// ThemeSetting с заданным стартом и без записи в `globalState` (его в тесте нет).
class FakeThemeSetting extends ThemeSetting {
  FakeThemeSetting(this.initial);

  final ThemeProps initial;

  @override
  ThemeProps build() => initial;

  // Смена состояния иначе пишет срез в globalState.configRepository.
  @override
  void onUpdate(ThemeProps value) {}
}

/// То, что `ProfileService._applyDropwebTheme` кладёт в `ThemeProps` из заголовка провайдера
/// [index] доски: цвета целыми ARGB, размытие 1..5.
ThemeProps providerProps(int index, {ThemeProps? base}) {
  final t = Ios27ProviderTheme.fromHeader(kBoardProviders[index].theme);
  return (base ?? const ThemeProps()).copyWith(
    primaryColor: ios27ArgbOfHex(t.accent),
    orbColorPrimary: ios27ArgbOfHex(t.orb1),
    orbColorSecondary: ios27ArgbOfHex(t.orb2),
    orbBlur: t.blur,
  );
}

/// Переопределение провайдера темы со стартом [props].
List<Override> themeOverrides(ThemeProps props) => [
      themeSettingProvider.overrideWith(() => FakeThemeSetting(props)),
    ];

/// Что видит главная за страницей: последний акцент `Ios27Colors` и число перестроений.
class AccentLog {
  Color? accent;
  Color? orb1;
  Color? orb2;

  /// Уровень стекла, который видит главная за страницей (`null` — как в системе).
  int? glassLevel;
  int builds = 0;
}

/// Тема провайдера [index] доски для окна-хозяина.
Ios27ProviderTheme boardTheme(int index) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[index].theme);

/// Окно доски с «главной» под страницей. Главная читает тему из провайдера (как настоящая), поэтому
/// выбор цвета на странице перекрашивает её вживую; [log] фиксирует то, что она видит.
Widget appearanceApp({
  required Brightness brightness,
  int provider = 0,
  ThemeProps? props,
  AccentLog? log,
  double textScale = 1.0,
  bool disableAnimations = false,
  bool reduceTransparency = true,
  Ios27Device device = kIos27BoardDevice,
}) =>
    ios27BoardApp(
      brightness: brightness,
      theme: boardTheme(provider),
      textScale: textScale,
      disableAnimations: disableAnimations,
      reduceTransparency: reduceTransparency,
      device: device,
      overrides: themeOverrides(props ?? providerProps(provider)),
      child: Ios27ThemeScope(
        child: Builder(
          builder: (context) {
            final colors = Ios27Colors.of(context);
            log
              ?..builds += 1
              ..accent = colors.accentColor
              ..orb1 = colors.orb1
              ..orb2 = colors.orb2
              ..glassLevel = Ios27GlassColors.maybeOf(context)?.level;
            return ColoredBox(color: colors.palette.bg);
          },
        ),
      ),
    );

/// Контекст корневого навигатора: выше любой области темы.
BuildContext rootContext(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

/// Дать маршруту отыграть переход.
Future<void> settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Открывает страницу «Оформление» из корневого контекста и ждёт конца перехода.
Future<void> openAppearance(WidgetTester tester) async {
  unawaited(openIos27Appearance(rootContext(tester)));
  await settle(tester);
}

/// Контейнер Riverpod дерева.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// Высота строки «Как в системе», которой на доске нет (добавка приложения по решению владельца
/// 30.10, `Ios27ListRow` минимальной высоты `kIos27RowMinHeight`).
const double kGlassSystemRowHeight = 52;

Rect _boxRect(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Ссылочные рамки доски со сдвигом на строку «Как в системе».
///
/// Её на доске нет, поэтому всё страничное (`page.*`), что стоит на уровне низа превью стекла и
/// ниже, в приложении сдвинуто вниз на [kGlassSystemRowHeight], а группа «Стекло», которую эта
/// строка раздвигает, выше на столько же. Оверлеи листа цвета (`sheet`, `cp.*`, `dim`) лежат поверх
/// страницы и не двигаются.
Map<String, List<Rect>> shiftedForSystemRow(Ios27RefLayout layout) {
  final preview = layout.element('page.glassPreview');
  if (preview == null) {
    return layout.rects;
  }
  final insertY = preview.bottom;
  Rect shift(Rect r) {
    if (r.top >= insertY - 0.01) {
      return r.shift(const Offset(0, kGlassSystemRowHeight));
    }
    // Рамка охватывает точку вставки (сама группа «Стекло»): растёт на высоту строки.
    if (r.top < insertY && r.bottom > insertY + 0.01) {
      return Rect.fromLTWH(
          r.left, r.top, r.width, r.height + kGlassSystemRowHeight);
    }
    return r;
  }

  return {
    for (final entry in layout.rects.entries)
      entry.key: entry.key.startsWith('page.')
          ? entry.value.map(shift).toList()
          : entry.value,
  };
}

/// Сверка с доской для страницы «Оформление» (как `ios27Parity`, но с поправкой на строку «Как в
/// системе», см. [shiftedForSystemRow]).
List<Ios27ParityRow> appearanceParity(
  String refKey,
  Map<String, Finder> elements, {
  double tol = 4,
}) {
  final refs = shiftedForSystemRow(Ios27RefLayout.load(refKey));
  final rows = <Ios27ParityRow>[];
  for (final entry in elements.entries) {
    final want = refs[entry.key] ?? const <Rect>[];
    final have = entry.value.evaluate().map(_boxRect).toList();
    final count = want.length > have.length ? want.length : have.length;
    if (count == 0) {
      rows.add(Ios27ParityRow(name: entry.key, ref: null, app: null, tol: tol));
      continue;
    }
    for (var i = 0; i < count; i++) {
      rows.add(
        Ios27ParityRow(
          name: count == 1 ? entry.key : '${entry.key}[$i]',
          ref: i < want.length ? want[i] : null,
          app: i < have.length ? have[i] : null,
          tol: tol,
        ),
      );
    }
  }
  final path = Platform.environment['IOS27_PARITY_TABLE'];
  if (path != null && path.isNotEmpty) {
    ios27AppendParityTable(path, refKey, rows);
  }
  return rows;
}

/// Совпадения родителя без первых [count]: в порядке документа первой строкой страницы теперь
/// идёт «Как в системе», а строки-образцы цветов доски (`page.row`, `page.rowTitle`) следуют за ней.
class SkipFinder extends ChainedFinder {
  SkipFinder(super.parent, this.count);

  final int count;

  @override
  // ignore: deprecated_member_use
  String get description => 'совпадения без первых $count';

  @override
  String describeMatch(Plurality plurality) =>
      '${parent.describeMatch(plurality)} (без первых $count)';

  @override
  Iterable<Element> filter(Iterable<Element> parentCandidates) =>
      parentCandidates.skip(count);
}

/// Совпадения родителя вне группы «Темы» (`kIos27ThemesKey`).
///
/// Группы «Темы» нет на доске (добавка приложения по просьбе владельца 30.10, «нет пресетов
/// тем»), а её заголовок, карточка и строки носят те же ключи `page.*`, что и остальные. Сверка с
/// рамками доски и подсчёты в старых тестах смотрят только на то, что есть на доске, поэтому группа
/// из них исключается целиком; сама группа проверяется в `screen_appearance_themes_test.dart`.
class OutsideThemesFinder extends ChainedFinder {
  OutsideThemesFinder(super.parent);

  @override
  // ignore: deprecated_member_use
  String get description => 'вне группы «Темы»';

  @override
  String describeMatch(Plurality plurality) =>
      '${parent.describeMatch(plurality)} (вне группы «Темы»)';

  @override
  Iterable<Element> filter(Iterable<Element> parentCandidates) =>
      parentCandidates.where((element) {
        var inside = false;
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget.key == kIos27ThemesKey) {
            inside = true;
            return false;
          }
          return true;
        });
        return !inside;
      });
}

/// Элемент страницы по ключу, без группы «Темы».
Finder pageKey(String key) =>
    OutsideThemesFinder(find.byKey(ValueKey<String>(key)));

/// Строки «Провайдер» / «Свои» и колодцы: все `page.row`, кроме строки «Как в системе».
Finder colorRows() => SkipFinder(pageKey('page.row'), 1);

/// Заголовки тех же строк.
Finder colorRowTitles() => SkipFinder(pageKey('page.rowTitle'), 1);

/// Подводит [target] в экран, только если он за краем.
///
/// `WidgetTester.ensureVisible` центрирует цель, даже когда она уже видна, если у прокрутки есть
/// запас. С группой «Темы» запас у страницы есть всегда, и каждое нажатие по тексту уводило бы
/// страницу вниз: снимки и рамки сверки снимались бы не с верха страницы, а с произвольного места.
Future<void> revealIfHidden(WidgetTester tester, Finder target) async {
  final rect = tester.getRect(target);
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (rect.top >= 0 && rect.bottom <= view.height) {
    return;
  }
  await tester.ensureVisible(target);
  await tester.pump();
}
