// Список iOS-редизайна (Ios27List, Ios27ListRow, Ios27Avatar): сверка с листами «Маршрут» и «Подписка» доски,
// нажатие, отключённая строка, масштаб шрифта, голдены prim_list_*.

import 'dart:ui' show Tristate;

import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Тело листа «Маршрут» доски (app.js:672-706): авто, страны, переключатель, группы.
Widget routeBody({bool toggle = true}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.zap),
            title: 'Авто',
            subtitle: 'Нидерланды',
            detail: '41 мс',
            accessory: Ios27RowAccessory.check,
          ),
          Ios27ListRow(
            leading: Ios27Avatar.flag('🇳🇱'),
            title: 'Нидерланды',
            detail: '41 мс',
          ),
          Ios27ListRow(
            leading: Ios27Avatar.flag('🇫🇮'),
            title: 'Финляндия',
            detail: '64 мс',
          ),
          Ios27ListRow(
            leading: Ios27Avatar.flag('🇩🇪'),
            title: 'Германия',
            detail: '88 мс',
          ),
          Ios27ListRow(
            leading: Ios27Avatar.flag('🇺🇸'),
            title: 'США',
            detail: '156 мс',
          ),
        ]),
        const Ios27Gap(),
        Ios27List(children: [
          Ios27ListRow(
            title: 'Весь трафик через VPN',
            trailing: Ios27Toggle(
              key: const ValueKey('sheet.switch'),
              value: toggle,
              onChanged: (_) {},
            ),
          ),
        ]),
        const Ios27Gap(),
        const Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.layers),
            title: 'Серверы и группы',
            detail: '6',
            accessory: Ios27RowAccessory.chevron,
          ),
        ]),
      ],
    );

/// Тело листа «Подписка» доски (app.js:570-578).
Widget subBody() => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.refresh),
            title: 'Обновить',
            detail: '4 минуты назад',
          ),
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.chat),
            title: 'Справочная',
            detail: 'cfgpull.com',
            detailShrinks: true,
            accessory: Ios27RowAccessory.external,
          ),
        ]),
        Ios27Gap(),
        Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.logo(initials: 'db'),
            title: 'DROPWEB',
            accessory: Ios27RowAccessory.check,
          ),
          Ios27ListRow(
            leading: Ios27Avatar.logo(initials: 'Д'),
            title: 'Дом',
          ),
          Ios27ListRow(
            title: 'Добавить подписку',
            tone: Ios27RowTone.link,
          ),
        ]),
        Ios27Gap(),
        Ios27List(children: [
          Ios27ListRow(
            title: 'Удалить подписку',
            tone: Ios27RowTone.danger,
          ),
        ]),
      ],
    );

Ios27ProviderTheme _theme(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

Map<String, Finder> _sheetElements() => {
      'sheet.group': find.byKey(const ValueKey('sheet.group')),
      'sheet.row': find.byKey(const ValueKey('sheet.row')),
      'sheet.rowTitle': find.byKey(const ValueKey('sheet.rowTitle')),
      'sheet.rowDetail': find.byKey(const ValueKey('sheet.rowDetail')),
      'sheet.rowIcon': find.byKey(const ValueKey('sheet.rowIcon')),
      'sheet.rowFlag': find.byKey(const ValueKey('sheet.rowFlag')),
      'sheet.rowLogo': find.byKey(const ValueKey('sheet.rowLogo')),
      'sheet.rowCheck': find.byKey(const ValueKey('sheet.rowCheck')),
      'sheet.switch': find.byKey(const ValueKey('sheet.switch')),
    };

Future<void> _openSheet(
  WidgetTester tester, {
  required String title,
  required Widget body,
}) async {
  final root = tester.element(find.byType(Navigator).first);
  // ignore: unawaited_futures
  showIos27Sheet<void>(root, title: title, builder: (_) => body);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    testWidgets('лист «Маршрут» $mode: рамки ±4 dp и golden', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: brightness,
          theme: _theme(0),
          child: const SizedBox.expand(),
        ),
      );
      await _openSheet(tester, title: 'Маршрут', body: routeBody());
      expectIos27Parity(
        ios27Parity(tester, 'route-$mode-rt-p0', _sheetElements()),
      );
      await expectIos27Golden(tester, 'prim_list_route_${mode}_p0');
    });

    testWidgets('лист «Подписка» $mode: рамки ±4 dp и golden', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: brightness,
          theme: _theme(0),
          child: const SizedBox.expand(),
        ),
      );
      await _openSheet(tester, title: 'Подписка', body: subBody());
      expectIos27Parity(
        ios27Parity(tester, 'sub-$mode-rt-p0', _sheetElements()),
      );
      await expectIos27Golden(tester, 'prim_list_sub_${mode}_p0');
    });
  }

  // Тема провайдера задаётся скоупом окна, а лист ставит свой скоуп из провайдера, поэтому
  // p5 снимается прямо в окне: красятся только галочка и включённый переключатель.
  testWidgets('провайдер p5: тело «Маршрут» golden', (tester) async {
    await pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        theme: _theme(5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 60),
          child: routeBody(),
        ),
      ),
    );
    await expectIos27Golden(tester, 'prim_list_route_light_p5');
  });

  group('поведение строки', () {
    Widget list(List<Widget> rows) => ios27BoardApp(
          brightness: Brightness.light,
          child: SingleChildScrollView(child: Ios27List(children: rows)),
        );

    testWidgets('тап вызывает onTap, нажатая строка заливается fill4',
        (tester) async {
      var taps = 0;
      await pumpIos27Board(
        tester,
        list([
          Ios27ListRow(title: 'Язык', onTap: () => taps++),
          const Ios27ListRow(title: 'Без нажатия'),
        ]),
      );
      final palette = ios27ColorsFor(
        tester.element(find.byType(Ios27List)),
      ).palette;
      Color? fill(int i) => (tester
              .widget<AnimatedContainer>(
                find.byKey(const ValueKey('page.row')).at(i),
              )
              .decoration as BoxDecoration?)
          ?.color;
      expect(fill(0), const Color(0x00000000));

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Язык')));
      await tester.pump();
      expect(fill(0), palette.fill4);
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      // Подсветка гаснет 250 мс ease-out: не мгновенно.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fill(0), const Color(0x00000000));

      // Строка без onTap не подсвечивается.
      final g2 =
          await tester.startGesture(tester.getCenter(find.text('Без нажатия')));
      await tester.pump();
      expect(fill(1), const Color(0x00000000));
      await g2.up();
    });

    testWidgets('отключённая строка: подпись label3, нет отклика',
        (tester) async {
      var taps = 0;
      await pumpIos27Board(
        tester,
        list([
          Ios27ListRow(title: 'Выкл', enabled: false, onTap: () => taps++),
        ]),
      );
      final palette = ios27ColorsFor(
        tester.element(find.byType(Ios27List)),
      ).palette;
      expect(
        tester.widget<Text>(find.text('Выкл')).style!.color,
        palette.label3,
      );
      await tester.tap(find.text('Выкл'));
      expect(taps, 0);
    });

    testWidgets('семантика: кнопка, выбрано, идентификатор', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        list([
          Ios27ListRow(
            title: 'Русский',
            accessory: Ios27RowAccessory.check,
            semanticIdentifier: 'dw_lang_ru',
            onTap: () {},
          ),
        ]),
      );
      final data = tester
          .getSemantics(find.bySemanticsIdentifier('dw_lang_ru'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.label, contains('Русский'));
      handle.dispose();
    });

    testWidgets('разделитель: у первой строки нет, дальше с отступом 62',
        (tester) async {
      await pumpIos27Board(
        tester,
        list(const [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.globe),
            title: 'А',
          ),
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.globe),
            title: 'Б',
          ),
          Ios27ListRow(title: 'В'),
        ]),
      );
      final seps = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((c) =>
              c.color ==
              ios27ColorsFor(
                tester.element(find.byType(Ios27List)),
              ).palette.separator)
          .length;
      expect(seps, 2);
    });
  });

  group('аватары', () {
    testWidgets('fromName: флаг, эмодзи и значок по умолчанию', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Column(
            children: [
              Ios27Avatar.fromName('🇩🇪 Германия'),
              Ios27Avatar.fromName('🎮 Игры'),
              Ios27Avatar.fromName('Просто группа'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final r
          in tester.widgetList<Ios27Avatar>(find.byType(Ios27Avatar))) {
        expect(
          tester.getSize(find.byWidget(r)),
          const Size(kIos27AvatarSize, kIos27AvatarSize),
        );
      }
      expect(Ios27Avatar.isFlagEmoji('🇩🇪'), isTrue);
      expect(Ios27Avatar.isFlagEmoji('🎮'), isFalse);
    });
  });

  group('масштаб шрифта', () {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        testWidgets('${device.name} ×$scale: нет переполнения', (tester) async {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.dark,
              textScale: scale,
              device: device,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    routeBody(),
                    subBody(),
                    const Ios27GroupHead('Заголовок группы, довольно длинный'),
                    const Ios27List(children: [
                      Ios27ListRow(
                        leading: Ios27Avatar.icon(Ios27IconName.globe),
                        title: 'Очень длинное название строки без пробелов'
                            'ПродолжениеНазванияСтроки',
                        subtitle: 'Подпись под названием тоже длинная',
                        detail: 'Значение справа длинное',
                        accessory: Ios27RowAccessory.chevron,
                      ),
                    ]),
                    const Ios27GroupFoot('Примечание под группой'),
                  ],
                ),
              ),
            ),
            device: device,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
