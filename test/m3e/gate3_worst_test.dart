// Ворота 3, часть WORST: длинные имена и крайние числа на главной, пустом экране и
// «О программе». Без глаз проверяем три вещи: кадр не бросил исключение (RenderFlex
// overflow приходит как исключение), ни один текст не вылез за экран и числа не
// обрезаны (ни многоточия, ни клипа, ширина текста не больше отведённой).

import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart' show kM3eJoyKey;
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/surface.dart';

/// Допуск на округление раскладки в dp.
const double _eps = 0.5;

/// Все абзацы кадра.
Iterable<RenderParagraph> _paragraphs(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderParagraph>();

String _plain(RenderParagraph p) => p.text.toPlainText();

/// Ни один абзац не выходит за экран и не обрезан. Абзацы с многоточием по замыслу
/// (имя провайдера: `.dr-card__name { text-overflow: ellipsis }`) перечислены в
/// [ellipsisByDesign] ключами их контейнеров. [allowEllipsis] — режим «только в рамках
/// экрана»: для заведомо нереальных входов, где многоточие задумано (строки с
/// `maxLines`), но выхода за экран и исключений быть не должно.
void _expectNoClipped(
  WidgetTester tester,
  String tag, {
  Size screen = kM3eBoardSize,
  Set<Key> ellipsisByDesign = const {},
  bool allowEllipsis = false,
}) {
  expect(tester.takeException(), isNull, reason: '$tag: исключение кадра');
  final allowed = <RenderParagraph>{
    for (final key in ellipsisByDesign)
      for (final e in find
          .descendant(of: find.byKey(key), matching: find.byType(RichText))
          .evaluate())
        e.renderObject! as RenderParagraph,
  };
  for (final p in _paragraphs(tester)) {
    if (!p.attached || p.size.isEmpty) continue;
    final rect = p.localToGlobal(Offset.zero) & p.size;
    final text = _plain(p);
    expect(rect.left, greaterThanOrEqualTo(-_eps),
        reason: '$tag «$text» слева');
    expect(rect.right, lessThanOrEqualTo(screen.width + _eps),
        reason: '$tag «$text» справа');
    expect(rect.bottom, lessThanOrEqualTo(screen.height + _eps),
        reason: '$tag «$text» снизу');
    if (!allowEllipsis && !allowed.contains(p)) {
      expect(p.didExceedMaxLines, isFalse, reason: '$tag «$text» обрезан');
    }
  }
}

/// Число целиком влезает в отведённую ширину, не сжимаясь многоточием.
void _expectFits(WidgetTester tester, String tag, Key key) {
  final texts =
      find.descendant(of: find.byKey(key), matching: find.byType(RichText));
  if (texts.evaluate().isEmpty) {
    // Значение ещё определяется: вместо текста индикатор загрузки. Он не должен
    // выпирать за строку значения.
    final shape = find.descendant(
        of: find.byKey(key), matching: find.byType(CustomPaint));
    expect(shape, findsWidgets,
        reason: '$tag: нет ни текста, ни индикатора в $key');
    final row = tester.getRect(find.byKey(key));
    for (final e in shape.evaluate()) {
      final r = tester.getRect(find.byElementPredicate((x) => x == e));
      expect(r.top, greaterThanOrEqualTo(row.top - _eps),
          reason: '$tag $key индикатор сверху');
      expect(r.bottom, lessThanOrEqualTo(row.bottom + _eps),
          reason: '$tag $key индикатор снизу');
      expect(r.right, lessThanOrEqualTo(row.right + _eps),
          reason: '$tag $key индикатор справа');
    }
    return;
  }
  for (final e in texts.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(p.didExceedMaxLines, isFalse, reason: '$tag $key «${_plain(p)}»');
    expect(p.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + _eps),
        reason: '$tag $key «${_plain(p)}» шире отведённого места');
  }
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
}

Widget _screen(
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: h.accent,
    filter: h.filter,
    brightness: brightness,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  tearDown(() => debugDisableShadows = true);

  group('ворота 3: WORST, главная (все 10 сцен)', () {
    for (final scene in kHomeSceneIds) {
      for (final (brightness, p) in [
        (Brightness.light, 0),
        (Brightness.dark, 5),
      ]) {
        testWidgets('$scene ${brightness.name} p$p', (tester) async {
          await _pump(
            tester,
            gateHomeApp(scene,
                provider: p, brightness: brightness, worst: true),
          );
          final tag = 'worst $scene ${brightness.name} p$p';
          _expectNoClipped(
            tester,
            tag,
            ellipsisByDesign: {M3eCardKeys.name},
          );
          // Показатель карточки (страна) и таймер.
          _expectFits(tester, tag, M3eCardKeys.country);
          if (find.byKey(M3eCardKeys.timer).evaluate().isNotEmpty) {
            _expectFits(tester, tag, M3eCardKeys.timer);
          }
          // Карточка не доезжает до нижнего ряда кнопок.
          expect(
            tester.getRect(find.byKey(M3eCardKeys.card)).bottom,
            lessThan(tester.getRect(find.byKey(kM3eJoyKey)).top),
            reason: '$tag: карточка наехала на кнопки',
          );
        });
      }
    }
  });

  group('ворота 3: NORMAL, карточка с подвалом выше ряда кнопок', () {
    // Размеры телефонов: компактный, доска и крупный; масштаб текста системы 0,8–2,0.
    const sizes = [
      (name: '360x640', size: Size(360, 640), top: 24.0, bottom: 24.0),
      (name: '411x914', size: kM3eBoardSize, top: 44.0, bottom: 24.0),
      (name: '440x956', size: Size(440, 956), top: 48.0, bottom: 24.0),
    ];
    for (final d in sizes) {
      for (final scale in const [0.8, 1.0, 1.4, 2.0]) {
        for (final scene in const ['home-on', 'error', 'expired']) {
          testWidgets('${d.name} x$scale $scene', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue);
            await pumpM3eBoard(
              tester,
              gateHomeApp(scene, brightness: Brightness.dark),
            );
            final padding = FakeViewPadding(
              top: d.top * kM3eBoardDpr,
              bottom: d.bottom * kM3eBoardDpr,
            );
            tester.view
              ..physicalSize = d.size * kM3eBoardDpr
              ..padding = padding
              ..viewPadding = padding;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            final footer = find.byKey(M3eCardKeys.footer).evaluate().isNotEmpty
                ? tester.getRect(find.byKey(M3eCardKeys.footer)).bottom
                : tester.getRect(find.byKey(M3eCardKeys.card)).bottom;
            final joy = tester.getRect(find.byKey(kM3eJoyKey));
            expect(footer, lessThanOrEqualTo(joy.top),
                reason: 'карточка с подвалом наезжает на ряд кнопок');
          });
        }
      }
    }
  });

  group('ворота 3: WORST, пустой экран', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('textScale $scale', (tester) async {
        await _pump(
          tester,
          _screen(
            M3eEmptyView(onSettings: () {}, onPaste: () {}, onScan: () {}),
            textScale: scale,
          ),
        );
        // Кнопка M3 однострочная и фиксированной высоты: при системном шрифте 2,0
        // подпись «Сканировать QR-код» усекается многоточием по замыслу, остальное
        // (границы, исключения) проверяется всегда.
        _expectNoClipped(tester, 'empty x$scale', allowEllipsis: scale > 1.5);
      });
    }

    testWidgets('узкое окно 320 dp при крупном шрифте', (tester) async {
      await _pump(
        tester,
        _screen(
          M3eEmptyView(onSettings: () {}, onPaste: () {}, onScan: () {}),
          textScale: 1.3,
        ),
      );
      tester.view.physicalSize = const Size(320 * 2, 914 * 2);
      await tester.pump();
      _expectNoClipped(tester, 'empty 320', screen: const Size(320, 914));
    });
  });

  group('ворота 3: WORST, «О программе»', () {
    // Самые длинные из реальных: версия сборки с суффиксом, версия обновления
    // с сервера (X.Y.Z[-pre.N]). Строка «Доступна версия …» однострочная (как
    // `.dr-item__sup` доски): при шрифте 2,0 она усекается многоточием по замыслу,
    // при 1,3 и меньше обязана влезать.
    const longVersion = '10.123.456-beta.7+2050000023';
    const longCore = 'v1.19.31-alpha-20261029';
    const longUpdate = '0.10.12-pre.12';
    // Заведомо нереальные: 50+ знаков, подпись «Обновление» усекается (maxLines 1).
    const absurdVersion = '10.123.456-beta.7+2050000023-very-long-build-suffix';
    const absurdCore = 'v1.19.31-alpha-20261029-commit-abcdef0123456789abcdef';
    const absurdUpdate = '10.123.457-beta.8+2050000024-very-long-build-suffix';

    testWidgets('нереально длинные строки: в границах экрана, без исключений',
        (tester) async {
      await _pump(
        tester,
        _screen(
          M3eAboutView(
            version: absurdVersion,
            core: absurdCore,
            updateVersion: absurdUpdate,
            onBack: () {},
            onUpdate: () {},
            onSite: () {},
            onPrivacy: () {},
          ),
        ),
      );
      _expectNoClipped(tester, 'about absurd', allowEllipsis: true);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('длинные версии, textScale $scale', (tester) async {
        await _pump(
          tester,
          _screen(
            M3eAboutView(
              version: longVersion,
              core: longCore,
              updateVersion: longUpdate,
              onBack: () {},
              onUpdate: () {},
              onSite: () {},
              onPrivacy: () {},
            ),
            textScale: scale,
          ),
        );
        _expectNoClipped(tester, 'about x$scale', allowEllipsis: scale > 1.5);
      });
    }
  });
}
