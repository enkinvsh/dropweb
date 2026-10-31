// Секция «Стекло» страницы «Оформление»: хранение уровня (null = как в системе), названия значений,
// ползунок (касание, перетаскивание, захват ручки, семантика), строка «Как в системе», передача
// уровня в стекло через область темы, движение (G8) и Reduce Transparency.
//
// Рамки по доске и golden этой секции проверяет `screen_appearance_page_test.dart`.

import 'dart:convert';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/config.dart' show ThemeProps;
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_level.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_slider.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_appearance_harness.dart';
import 'support/golden.dart';

Finder _k(String key) => find.byKey(ValueKey<String>(key));

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Центр ручки при значении [value]: `left + 18.5 + (W − 37) · value / 100` (app.js:427).
Offset _thumbCentre(WidgetTester tester, int value) {
  final slider = _rect(tester, _k('page.slider'));
  final span = slider.width - kIos27SliderThumbWidth;
  return Offset(
    slider.left + kIos27SliderThumbWidth / 2 + span * value / 100,
    slider.center.dy,
  );
}

/// Дать пружине ручки доиграть. Первый кадр только запускает отсчёт (у `Ticker` время идёт от
/// первого тика), поэтому один длинный `pump` не доводит анимацию до конца.
Future<void> _settleSpring(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapAtValue(WidgetTester tester, int value) async {
  await tester.tapAt(_thumbCentre(tester, value));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

int? _level(WidgetTester tester) =>
    containerOf(tester).read(themeSettingProvider).ios27GlassLevel;

bool _toggleOn(WidgetTester tester) =>
    tester.widget<Ios27Toggle>(_k('page.glassSystemSwitch')).value;

Future<void> _open(
  WidgetTester tester, {
  ThemeProps? props,
  AccentLog? log,
  bool reduceTransparency = true,
  bool disableAnimations = false,
}) async {
  await pumpIos27Board(
    tester,
    appearanceApp(
      brightness: Brightness.light,
      props: props,
      log: log,
      reduceTransparency: reduceTransparency,
      disableAnimations: disableAnimations,
    ),
  );
  await openAppearance(tester);
}

SemanticsDataOf _sliderData(WidgetTester tester) => SemanticsDataOf(
      tester
          .getSemantics(
              find.bySemanticsIdentifier('dw_appearance_glass_slider'))
          .getSemanticsData(),
    );

/// Узел семантики ползунка «Стекло».
FinderBase<SemanticsNode> _sliderNode() => find.semantics.byPredicate(
      (node) => node.identifier == 'dw_appearance_glass_slider',
    );

/// Тонкая обёртка над `SemanticsData`, чтобы читать только нужные поля.
class SemanticsDataOf {
  SemanticsDataOf(this.data);

  final dynamic data;

  bool get isSlider => data.flagsCollection.isSlider as bool;
  String get label => data.label as String;
  String get value => data.value as String;
  String get increased => data.increasedValue as String;
  String get decreased => data.decreasedValue as String;
  bool hasAction(SemanticsAction action) => data.hasAction(action) as bool;
}

/// Ползунок без страницы: значение хранит хозяин, вызовы `onChanged` копятся в `calls`.
Widget _standalone(
  List<int> calls, {
  int value = 50,
  bool reduceTransparency = true,
  bool disableAnimations = false,
}) {
  var current = value;
  return ios27BoardApp(
    brightness: Brightness.light,
    reduceTransparency: reduceTransparency,
    disableAnimations: disableAnimations,
    child: Center(
      child: SizedBox(
        width: 347,
        child: StatefulBuilder(
          builder: (context, setState) => Ios27GlassSlider(
            value: current,
            onChanged: (next) {
              calls.add(next);
              setState(() => current = next);
            },
            label: 'Стекло',
            valueText: (v) => '$v',
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('названия значений (app.js:425)', () {
    late AppLocalizations ru;

    setUpAll(() async {
      ru = await AppLocalizations.load(const Locale('ru'));
    });

    const expected = {
      0: 'Прозрачнее',
      16: 'Прозрачнее',
      17: 'Стандартное',
      25: 'Стандартное',
      33: 'Стандартное',
      34: 'Плотнее',
      60: 'Плотнее',
      85: 'Плотнее',
      86: 'Тонированное',
      100: 'Тонированное',
    };
    for (final entry in expected.entries) {
      test('значение ${entry.key} → «${entry.value}»', () {
        expect(ios27GlassName(ru, entry.key), entry.value);
      });
    }
  });

  group('хранение уровня', () {
    test('в старом JSON настроек поля нет: читается как «как в системе»', () {
      // `toJson` у freezed неглубокий: настоящий путь хранения идёт через jsonEncode.
      final old = jsonDecode(jsonEncode(const ThemeProps()))
          as Map<String, dynamic>
        ..remove('ios27GlassLevel');
      expect(ThemeProps.fromJson(old).ios27GlassLevel, isNull);
    });

    test('значение переживает JSON', () {
      final back = ThemeProps.fromJson(
        jsonDecode(jsonEncode(const ThemeProps(ios27GlassLevel: 40)))
            as Map<String, dynamic>,
      );
      expect(back.ios27GlassLevel, 40);
    });

    test('по умолчанию null: «Как в системе» включено, ручка на 25', () {
      final c =
          ProviderContainer(overrides: themeOverrides(const ThemeProps()));
      addTearDown(c.dispose);
      expect(c.read(ios27GlassLevelProvider), isNull);
      expect(c.read(ios27GlassSystemProvider), isTrue);
      expect(c.read(ios27GlassSliderValueProvider), kIos27GlassStandard);
    });

    test('setLevel держит 0..100, useSystem возвращает null, useOwn — 25', () {
      final c =
          ProviderContainer(overrides: themeOverrides(const ThemeProps()));
      addTearDown(c.dispose);
      final actions = c.read(ios27GlassLevelActionsProvider)..setLevel(140);
      expect(c.read(ios27GlassLevelProvider), 100);
      actions.setLevel(-5);
      expect(c.read(ios27GlassLevelProvider), 0);
      expect(c.read(ios27GlassSystemProvider), isFalse);
      actions.setLevel(63);
      expect(c.read(ios27GlassSliderValueProvider), 63);
      actions.useSystem();
      expect(c.read(ios27GlassLevelProvider), isNull);
      expect(c.read(ios27GlassSliderValueProvider), kIos27GlassStandard);
      actions.useOwn();
      expect(c.read(ios27GlassLevelProvider), kIos27GlassStandard);
    });
  });

  group('передача в стекло', () {
    test('Ios27GlassParams.toMap шлёт level: −1 «как в системе» или значение',
        () {
      const shape = Ios27GlassShape.capsule();
      expect(
        const Ios27GlassParams(shape: shape, dark: false).toMap()['level'],
        Ios27GlassParams.levelSystem,
      );
      expect(Ios27GlassParams.levelSystem, -1);
      expect(
        const Ios27GlassParams(shape: shape, dark: false, level: 40)
            .toMap()['level'],
        40,
      );
      expect(
        const Ios27GlassParams(shape: shape, dark: false),
        isNot(const Ios27GlassParams(shape: shape, dark: false, level: 40)),
      );
    });

    testWidgets('область темы по провайдеру отдаёт level в Ios27GlassColors',
        (tester) async {
      final log = AccentLog();
      await _open(tester, log: log);
      // Главная за страницей стоит в такой же области: видит то же, что стекло под страницей.
      expect(log.glassLevel, isNull);
      containerOf(tester).read(ios27GlassLevelActionsProvider).setLevel(60);
      await tester.pump();
      expect(log.glassLevel, 60);
      containerOf(tester).read(ios27GlassLevelActionsProvider).useSystem();
      await tester.pump();
      expect(log.glassLevel, isNull);
    });

    testWidgets('Ios27ThemeScope.explicit: glassLevel доходит до стекла',
        (tester) async {
      int? seen = -2;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.defaults,
            glassLevel: 70,
            child: Builder(
              builder: (context) {
                seen = Ios27GlassColors.maybeOf(context)?.level;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen, 70);
    });

    test('Ios27GlassColors оповещает зависимых только при смене уровня', () {
      const child = SizedBox.shrink();
      const system = Ios27GlassColors(child: child);
      expect(
        const Ios27GlassColors(level: 30, child: child)
            .updateShouldNotify(system),
        isTrue,
      );
      expect(
        const Ios27GlassColors(level: 30, child: child).updateShouldNotify(
          const Ios27GlassColors(level: 30, child: child),
        ),
        isFalse,
      );
      expect(system.updateShouldNotify(system), isFalse);
    });
  });

  group('секция на странице', () {
    testWidgets('по умолчанию: «Как в системе» включено, ручка на стандарте',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      expect(_toggleOn(tester), isTrue);
      expect(_level(tester), isNull);
      final data = _sliderData(tester);
      expect(data.value, 'Стандартное');
      final thumb = _rect(tester, _k('slider.thumb'));
      final want = _thumbCentre(tester, kIos27GlassStandard);
      expect(thumb.center.dx, closeTo(want.dx, 0.01));
      for (final text in [
        'Стекло',
        'Как в системе',
        'Прозрачное',
        'Тонированное'
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      handle.dispose();
    });

    testWidgets(
        'движение ползунка включает своё значение и выключает «как в системе»',
        (tester) async {
      final log = AccentLog();
      await _open(tester, log: log);
      await _tapAtValue(tester, 50);
      expect(_level(tester), 50);
      expect(_toggleOn(tester), isFalse);
      expect(log.glassLevel, 50,
          reason: 'главная за страницей видит новый уровень');
    });

    testWidgets('тумблер: выключен → стандартные 25, включён → снова null',
        (tester) async {
      await _open(tester);
      await tester.tap(_k('page.glassSystemSwitch'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), kIos27GlassStandard);
      expect(_toggleOn(tester), isFalse);
      await tester.tap(_k('page.glassSystemSwitch'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), isNull);
      expect(_toggleOn(tester), isTrue);
    });

    testWidgets('нажатие на подпись строки переключает так же, как тумблер',
        (tester) async {
      await _open(tester);
      await tester.tap(find.text('Как в системе'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), kIos27GlassStandard);
      await tester.tap(find.text('Как в системе'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), isNull);
    });

    testWidgets('включение «как в системе» возвращает ручку на стандарт',
        (tester) async {
      await _open(tester);
      await _tapAtValue(tester, 80);
      expect(_level(tester), 80);
      // Тумблер был выключен ползунком: нажатие включает «как в системе» (null).
      await tester.tap(_k('page.glassSystemSwitch'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), isNull);
      expect(_toggleOn(tester), isTrue);
      expect(
        _rect(tester, _k('slider.thumb')).center.dx,
        closeTo(_thumbCentre(tester, kIos27GlassStandard).dx, 0.01),
        reason: 'пока стекло системное, ручка стоит на стандарте доски',
      );
      // Выключение возвращает стандартные 25 как своё значение.
      await tester.tap(_k('page.glassSystemSwitch'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), kIos27GlassStandard);
    });

    testWidgets(
        'выбранное значение переживает закрытие и повторное открытие страницы',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, props: const ThemeProps(ios27GlassLevel: 60));
      expect(_toggleOn(tester), isFalse);
      expect(_sliderData(tester).value, 'Плотнее');
      await tester.tap(_k('page.back'));
      await settle(tester);
      expect(_k('page'), findsNothing);
      await openAppearance(tester);
      expect(_level(tester), 60);
      expect(
        _rect(tester, _k('slider.thumb')).center.dx,
        closeTo(_thumbCentre(tester, 60).dx, 0.01),
      );
      handle.dispose();
    });

    testWidgets(
        'превью неактивно: нажатия не проходят, VoiceOver его не читает',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      final preview = _k('page.glassPreview');
      expect(
        find.descendant(of: preview, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(find.bySemanticsIdentifier('dw_exit'), findsNothing);
      // Нажатие по кнопке питания в превью ничего не включает и не падает.
      await tester.tap(_k('page.glassBtn').at(1), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  group('ползунок', () {
    testWidgets('семантика: регулируемый элемент, значение словами, шаг 5',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, props: const ThemeProps(ios27GlassLevel: 30));
      final data = _sliderData(tester);
      expect(data.isSlider, isTrue);
      expect(data.label, 'Стекло');
      expect(data.value, 'Стандартное');
      expect(data.increased, 'Плотнее', reason: '35');
      expect(data.decreased, 'Стандартное', reason: '25');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);

      tester.semantics.performAction(_sliderNode(), SemanticsAction.increase);
      await tester.pump();
      expect(_level(tester), 35);
      expect(_sliderData(tester).value, 'Плотнее');

      tester.semantics.performAction(_sliderNode(), SemanticsAction.decrease);
      await tester.pump();
      expect(_level(tester), 30);
      handle.dispose();
    });

    testWidgets('на краях шкалы недоступно лишнее действие', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, props: const ThemeProps(ios27GlassLevel: 100));
      final data = _sliderData(tester);
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      expect(data.value, 'Тонированное');
      handle.dispose();
    });

    testWidgets('касание по дорожке ставит ручку под палец, края зажаты 0..100',
        (tester) async {
      await _open(tester);
      await _tapAtValue(tester, 75);
      expect(_level(tester), 75);
      final slider = _rect(tester, _k('page.slider'));
      await tester.tapAt(Offset(slider.left + 1, slider.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), 0);
      await tester.tapAt(Offset(slider.right - 1, slider.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), 100);
    });

    testWidgets('перетаскивание ручки двигает значение вместе с пальцем',
        (tester) async {
      await _open(tester, props: const ThemeProps(ios27GlassLevel: 25));
      final slider = _rect(tester, _k('page.slider'));
      final span = slider.width - kIos27SliderThumbWidth;
      // 20 единиц шкалы в пикселях.
      await tester.dragFrom(_thumbCentre(tester, 25), Offset(span * 0.2, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), 45);
      await tester.dragFrom(_thumbCentre(tester, 45), Offset(-span * 0.45, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), 0);
    });

    testWidgets('схваченная за край ручка не прыгает под палец',
        (tester) async {
      final calls = <int>[];
      await pumpIos27Board(tester, _standalone(calls, value: 50));
      final centre = _thumbCentre(tester, 50);
      // Нажатие на правую часть ручки: значение остаётся прежним.
      final gesture = await tester.startGesture(centre + const Offset(12, 0));
      await tester.pump();
      expect(calls, isEmpty);
      // Тянем на 31 px вправо (10 единиц при диапазоне 310 px): значение +10, а не +10 ± захват.
      await gesture.moveBy(const Offset(31, 0));
      await tester.pump();
      expect(calls, isNotEmpty);
      expect(calls.last, 60);
      await gesture.up();
      await _settleSpring(tester);
    });

    testWidgets(
        'вертикальная прокрутка страницы со стартом на дорожке не пишет уровень',
        (tester) async {
      await _open(tester);
      expect(_level(tester), isNull);
      expect(_toggleOn(tester), isTrue);
      final slider = _rect(tester, _k('page.slider'));
      final span = slider.width - kIos27SliderThumbWidth;
      final start = Offset(
        slider.left + kIos27SliderThumbWidth / 2 + span * 0.8,
        slider.center.dy,
      );
      await tester.dragFrom(start, const Offset(0, -150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_level(tester), isNull,
          reason: 'вертикальный жест выигрывает арену, ползунок не пишет');
      expect(_toggleOn(tester), isTrue, reason: '«Как в системе» остаётся');
      // Ручка отпущена: арена проиграна, увеличение снято.
      await _settleSpring(tester);
      expect(
        _rect(tester, _k('slider.thumb')).width,
        closeTo(kIos27SliderThumbWidth, 0.5),
      );
    });

    testWidgets('касание ручки со сдвигом 3 px не выключает «Как в системе»',
        (tester) async {
      await _open(tester);
      expect(_level(tester), isNull);
      expect(_toggleOn(tester), isTrue);
      // Ручка на стандарте (25); живой палец при касании смещается на пару пунктов.
      final gesture = await tester.startGesture(_thumbCentre(tester, 25));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(3, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_level(tester), isNull,
          reason: 'подъём на ручке без перетаскивания значение не пишет');
      expect(_toggleOn(tester), isTrue);
    });

    testWidgets('горизонтальный жест со стартом на дорожке пишет значение',
        (tester) async {
      await _open(tester);
      final slider = _rect(tester, _k('page.slider'));
      final span = slider.width - kIos27SliderThumbWidth;
      final start = Offset(
        slider.left + kIos27SliderThumbWidth / 2 + span * 0.5,
        slider.center.dy,
      );
      await tester.dragFrom(start, Offset(span * 0.2, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_level(tester), 70);
      expect(_toggleOn(tester), isFalse);
    });

    testWidgets('onChanged вызывается только при смене значения',
        (tester) async {
      final calls = <int>[];
      await pumpIos27Board(tester, _standalone(calls, value: 50));
      await tester.tapAt(_thumbCentre(tester, 50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, isEmpty,
          reason: 'нажатие на ту же точку значения не меняет');
      await tester.tapAt(_thumbCentre(tester, 20));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, [20]);
      await tester.tapAt(_thumbCentre(tester, 20));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, [20]);
    });

    testWidgets('под пальцем ручка растёт, потом возвращается', (tester) async {
      final calls = <int>[];
      await pumpIos27Board(tester, _standalone(calls));
      final rest = _rect(tester, _k('slider.thumb'));
      expect(rest.width, closeTo(kIos27SliderThumbWidth, 0.01));
      final gesture = await tester.startGesture(_thumbCentre(tester, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final pressed = _rect(tester, _k('slider.thumb'));
      expect(pressed.width, greaterThan(kIos27SliderThumbWidth * 1.4));
      expect(pressed.height, greaterThan(kIos27SliderThumbHeight * 1.4));
      await gesture.up();
      await _settleSpring(tester);
      expect(
        _rect(tester, _k('slider.thumb')).width,
        closeTo(kIos27SliderThumbWidth, 0.5),
      );
      // G8: после возврата пружины кадров-хвостов нет.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: ручка не растёт', (tester) async {
      final calls = <int>[];
      await pumpIos27Board(
        tester,
        _standalone(calls, disableAnimations: true),
      );
      final gesture = await tester.startGesture(_thumbCentre(tester, 50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _rect(tester, _k('slider.thumb')).width,
        closeTo(kIos27SliderThumbWidth, 0.01),
      );
      await gesture.up();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    Color thumbFill(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(_k('slider.thumb'));
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('Reduce Transparency: ручка под пальцем остаётся белой',
        (tester) async {
      await pumpIos27Board(tester, _standalone(<int>[]));
      final gesture = await tester.startGesture(_thumbCentre(tester, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(thumbFill(tester), const Color(0xFFFFFFFF));
      await gesture.up();
      await _settleSpring(tester);
    });

    testWidgets('без Reduce Transparency ручка под пальцем становится линзой',
        (tester) async {
      await pumpIos27Board(
        tester,
        _standalone(<int>[], reduceTransparency: false),
      );
      expect(thumbFill(tester), const Color(0xFFFFFFFF));
      final gesture = await tester.startGesture(_thumbCentre(tester, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Светлая тема: `#FFFFFF33`.
      expect(thumbFill(tester).a, lessThan(0.5));
      await gesture.up();
      await _settleSpring(tester);
      expect(thumbFill(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('на странице ползунок и подписи не вылезают за ширину карточки',
        (tester) async {
      await _open(tester);
      final group = _rect(tester, _k('page.group').first);
      for (final key in ['page.slider', 'page.sliderCaps', 'page.sliderRow']) {
        final r = _rect(tester, _k(key));
        expect(r.left, greaterThanOrEqualTo(group.left - 0.01), reason: key);
        expect(r.right, lessThanOrEqualTo(group.right + 0.01), reason: key);
      }
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('G8 на странице', () {
    testWidgets('после перетаскивания и отпускания кадров-хвостов нет',
        (tester) async {
      await _open(tester);
      final slider = _rect(tester, _k('page.slider'));
      await tester.dragFrom(
        _thumbCentre(tester, 25),
        Offset(slider.width * 0.3, 0),
      );
      await _settleSpring(tester);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
