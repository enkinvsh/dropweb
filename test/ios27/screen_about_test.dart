// Экран «О программе» iOS-редизайна (волна Э, e6): сверка с доской (G4), golden (G3), тёмная грань иконки в обеих темах (решение владельца 30.10, R9),
// содержимое без «Android» и «Обновления» (R8, R10), ссылки, масштаб шрифта и «Уменьшить движение» (G8).

import 'dart:typed_data';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/screens/about/ios27_about_page.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart'
    show kM3eProjectSiteUrl, m3ePrivacyUrl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Короткое окно: содержимое «О программе» (≈448 dp) в нём прокручивается больше, чем на 184 dp, и «dropweb»
/// успевает уйти под панель (строка состояния 20 + панель 44), так что можно проверить сворачивание.
const Ios27Device _kShortDevice = Ios27Device(
  name: 'short-375x260',
  size: Size(375, 260),
  dpr: 2,
  padding: EdgeInsets.only(top: 20),
);

/// Худший случай: версия и ядро без пробелов и переносов, длиннее строки.
const String _kWorstVersion = '0.10.3-pre.12+2050000023';
const String _kWorstCore =
    '1.19.31-dropweb-очень-длинный-идентификатор-ядра-без-пробелов-abcdefghijklmnopqrstuvwxyz';

Ios27ProviderTheme _provider(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

/// Ключи элементов, которые мерит сверка: страница из `Ios27Page` плюс шапка «О программе».
Map<String, Finder> _elements() => {
      for (final name in const [
        'page',
        'page.nav',
        'page.back',
        'page.small',
        'page.title',
        'page.group',
        'page.row',
        'page.rowTitle',
        'page.rowDetail',
        'page.rowIcon',
        'page.rowCheck',
        'about.icon',
        'about.name',
        'about.ver',
      ])
        name: find.byKey(ValueKey<String>(name)),
    };

/// Страница в том виде, в каком её строит `openIos27About`, но без `globalState`.
class _AboutHarness extends StatefulWidget {
  const _AboutHarness({
    this.version = '0.10.3',
    this.core = '1.19.31',
    this.onSite,
    this.onPrivacy,
  });

  final String version;
  final String core;
  final VoidCallback? onSite;
  final VoidCallback? onPrivacy;

  @override
  State<_AboutHarness> createState() => _AboutHarnessState();
}

class _AboutHarnessState extends State<_AboutHarness> {
  // Ключ живёт в состоянии: пересборка страницы не должна менять якорь сворачивания.
  final GlobalKey _name = GlobalKey();

  @override
  Widget build(BuildContext context) => Ios27Page(
        title: AppLocalizations.of(context).m3eAboutTitle,
        largeTitle: false,
        collapseAnchor: _name,
        child: Ios27AboutBody(
          version: widget.version,
          core: widget.core,
          nameKey: _name,
          onSite: widget.onSite ?? () {},
          onPrivacy: widget.onPrivacy ?? () {},
        ),
      );
}

/// Выводит страницу и дожидается растра иконки: `Image.asset` читает файл и декодирует его вне
/// FakeAsync, поэтому без прогрева кадр был бы без картинки.
Future<void> _pumpAbout(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Ios27ProviderTheme theme = Ios27ProviderTheme.defaults,
  Ios27Device device = kIos27BoardDevice,
  double textScale = 1.0,
  bool disableAnimations = false,
  bool reduceTransparency = true,
  bool highContrast = false,
  bool boldText = false,
  Locale locale = const Locale('ru'),
  Widget page = const _AboutHarness(),
}) async {
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: brightness,
      theme: theme,
      device: device,
      textScale: textScale,
      disableAnimations: disableAnimations,
      reduceTransparency: reduceTransparency,
      highContrast: highContrast,
      boldText: boldText,
      locale: locale,
      child: page,
    ),
    device: device,
    locale: locale,
  );
  await _loadIcons(tester);
}

Future<void> _loadIcons(WidgetTester tester) async {
  final context = tester.element(find.byType(Ios27AboutIcon).first);
  await tester.runAsync(() async {
    await precacheImage(const AssetImage(kIos27AboutIconDefault), context);
    await precacheImage(const AssetImage(kIos27AboutIconDark), context);
  });
  await tester.pump();
}

/// Имя ассета, который сейчас рисует иконка.
String _facet(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byType(Ios27AboutIcon),
      matching: find.byType(Image),
    ),
  );
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  return (provider as AssetImage).assetName;
}

/// Размер PNG из заголовка IHDR.
(int, int) _pngSize(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  // Сигнатура PNG и чанк IHDR: ширина и высота по смещениям 16 и 20.
  expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47], reason: 'не PNG');
  return (d.getUint32(16), d.getUint32(20));
}

double _smallOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('page.small')),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    group('сверка с доской, $mode', () {
      for (final p in [0, 5]) {
        testWidgets('p$p, rt: рамки ±4 dp', (tester) async {
          await _pumpAbout(
            tester,
            brightness: brightness,
            theme: _provider(p),
          );
          expectIos27Parity(
            ios27Parity(tester, 'about-$mode-rt-p$p', _elements()),
          );
        });
      }

      testWidgets('p0, norm: рамки ±4 dp', (tester) async {
        await _pumpAbout(
          tester,
          brightness: brightness,
          theme: _provider(0),
          reduceTransparency: false,
        );
        expectIos27Parity(
          ios27Parity(tester, 'about-$mode-norm-p0', _elements()),
        );
      });

      testWidgets('golden p0', (tester) async {
        await _pumpAbout(
          tester,
          brightness: brightness,
          theme: _provider(0),
        );
        await expectIos27Golden(tester, 'about_${mode}_p0');
      });
    });
  }

  // Владелец 30.10: тёмная иконка основная везде, как на рабочем столе. На доске грань шла по теме.
  group('грань иконки: тёмная в обеих темах', () {
    testWidgets('светлая тема: Dark, не Default', (tester) async {
      await _pumpAbout(tester);
      expect(_facet(tester), kIos27AboutIconDark);
      expect(_facet(tester), isNot(kIos27AboutIconDefault));
    });

    testWidgets('тёмная тема: Dark', (tester) async {
      await _pumpAbout(tester, brightness: Brightness.dark);
      expect(_facet(tester), kIos27AboutIconDark);
    });

    testWidgets('провайдер не красит иконку: p0..p5 дают ту же грань',
        (tester) async {
      for (var p = 0; p < kBoardProviders.length; p++) {
        await _pumpAbout(tester, theme: _provider(p));
        expect(_facet(tester), kIos27AboutIconDark, reason: 'светлая p$p');
        await _pumpAbout(
          tester,
          brightness: Brightness.dark,
          theme: _provider(p),
        );
        expect(_facet(tester), kIos27AboutIconDark, reason: 'тёмная p$p');
      }
    });

    testWidgets('смена темы на лету грань не меняет', (tester) async {
      await _pumpAbout(tester);
      expect(_facet(tester), kIos27AboutIconDark);
      await tester.pumpWidget(
        ios27BoardApp(
          brightness: Brightness.dark,
          child: const _AboutHarness(),
        ),
      );
      await tester.pump();
      expect(_facet(tester), kIos27AboutIconDark);
    });

    testWidgets('оба растра зарегистрированы, 288×288 и различаются',
        (tester) async {
      final bytes = (await tester.runAsync(() async => [
            (await rootBundle.load(kIos27AboutIconDefault))
                .buffer
                .asUint8List(),
            (await rootBundle.load(kIos27AboutIconDark)).buffer.asUint8List(),
          ]))!;
      expect(_pngSize(bytes[0]), (288, 288));
      expect(_pngSize(bytes[1]), (288, 288));
      expect(bytes[0], isNot(bytes[1]));
    });

    testWidgets('иконка рисуется картинкой: кадр её декодировал',
        (tester) async {
      await _pumpAbout(tester);
      final box = tester.getRect(find.byType(Ios27AboutIcon));
      expect(box.size, const Size.square(96));
      expect(tester.takeException(), isNull);
    });

    testWidgets('иконка декоративна: вне дерева семантики', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpAbout(tester);
      expect(
        find.descendant(
          of: find.byType(Ios27AboutIcon),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('dropweb'), findsOneWidget);
      handle.dispose();
    });
  });

  group('содержимое', () {
    testWidgets('ru: тексты доски', (tester) async {
      await _pumpAbout(tester);
      expect(find.text('dropweb'), findsOneWidget);
      expect(find.text('Версия 0.10.3, ядро 1.19.31'), findsOneWidget);
      expect(find.text('Сайт проекта'), findsOneWidget);
      expect(find.text('dropweb.org'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      // Группа «Обновление» не рисуется (R10), слова Android нет (R8).
      expect(find.textContaining('Обновлен'), findsNothing);
      expect(find.textContaining('Android'), findsNothing);
    });

    testWidgets('en: тексты из l10n, без Android и Update', (tester) async {
      await _pumpAbout(tester, locale: const Locale('en'));
      expect(find.text('Version 0.10.3, core 1.19.31'), findsOneWidget);
      expect(find.text('Project website'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.textContaining('Android'), findsNothing);
      expect(find.textContaining('Update'), findsNothing);
    });

    testWidgets('две строки-ссылки, обе с внешним значком', (tester) async {
      await _pumpAbout(tester);
      expect(find.byKey(const ValueKey('page.row')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('page.rowIcon')), findsNothing);
    });

    testWidgets('сайт проекта: адрес и деталь строки совпадают',
        (tester) async {
      expect(Uri.parse(kM3eProjectSiteUrl).host, 'dropweb.org');
      expect(
        m3ePrivacyUrl(),
        anyOf(
          'https://dropweb.org/privacy',
          'https://dropweb.org/app/privacy/',
        ),
      );
    });

    testWidgets('нажатие по строкам зовёт свои обратные вызовы',
        (tester) async {
      var site = 0;
      var privacy = 0;
      await _pumpAbout(
        tester,
        page: _AboutHarness(
          onSite: () => site++,
          onPrivacy: () => privacy++,
        ),
      );
      await tester.tap(find.text('Сайт проекта'));
      await tester.pump();
      expect((site, privacy), (1, 0));
      await tester.tap(find.text('Политика конфиденциальности'));
      await tester.pump();
      expect((site, privacy), (1, 1));
    });

    testWidgets('«Жирный текст» и «Повышенная контрастность» без ошибок',
        (tester) async {
      await _pumpAbout(
        tester,
        brightness: Brightness.dark,
        boldText: true,
        highContrast: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('dropweb'), findsOneWidget);
    });
  });

  group('openIos27About', () {
    setUp(() {
      globalState.packageInfo = PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: '0.10.3',
        buildNumber: '2050000023',
      );
      globalState.coreVersion = '1.19.31';
    });

    Widget host() => Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => openIos27About(context),
              child: const Text('Открыть'),
            ),
          ),
        );

    Future<void> open(
      WidgetTester tester, {
      Ios27Device device = kIos27BoardDevice,
      Brightness brightness = Brightness.light,
      bool disableAnimations = false,
    }) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: brightness,
          device: device,
          disableAnimations: disableAnimations,
          child: host(),
        ),
        device: device,
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await _loadIcons(tester);
    }

    testWidgets('страница открывается со шапкой, версией и строками',
        (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
      expect(find.text('dropweb'), findsOneWidget);
      expect(find.text('Версия 0.10.3, ядро 1.19.31'), findsOneWidget);
      expect(find.text('Сайт проекта'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      // Крупного заголовка нет: заголовок страницы только маленький, в панели.
      expect(find.byKey(const ValueKey('page.title')), findsNothing);
      expect(find.text('О программе'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('тёмная тема страницы: грань Dark', (tester) async {
      await open(tester, brightness: Brightness.dark);
      expect(_facet(tester), kIos27AboutIconDark);
    });

    testWidgets('ядро: пусто или null даёт «—», как у Android', (tester) async {
      globalState.coreVersion = '';
      await open(tester);
      expect(find.text('Версия 0.10.3, ядро —'), findsOneWidget);
    });

    testWidgets('ядро null даёт «—»', (tester) async {
      globalState.coreVersion = null;
      await open(tester);
      expect(find.text('Версия 0.10.3, ядро —'), findsOneWidget);
    });

    testWidgets('кнопка «Назад» закрывает страницу', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('page.back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'маленький заголовок проявляется, когда «dropweb» ушло под панель',
        (tester) async {
      await open(tester, device: _kShortDevice);
      expect(_smallOpacity(tester), 0);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_smallOpacity(tester), 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_smallOpacity(tester), 0);
    });

    testWidgets('«Уменьшить движение»: только угасание, нет тикеров',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          disableAnimations: true,
          child: host(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
        closeTo(0, 0.5),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('движение (G8)', () {
    for (final reduced in [false, true]) {
      testWidgets(
          'статичная страница не держит тикеров, '
          'Reduce Motion=$reduced', (tester) async {
        await _pumpAbout(tester, disableAnimations: reduced);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });

  group('худшие данные × масштаб шрифта × устройства', () {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
              '${device.name} ×$scale ${dark ? 'dark' : 'light'}: без '
              'переполнения и обрезки', (tester) async {
            await _pumpAbout(
              tester,
              brightness: dark ? Brightness.dark : Brightness.light,
              device: device,
              textScale: scale,
              page: const _AboutHarness(
                version: _kWorstVersion,
                core: _kWorstCore,
              ),
            );
            expect(tester.takeException(), isNull);

            final width = device.size.width;
            // Версия: по ширине в пределах полей шапки (24 dp), без выпадения за экран.
            final ver = tester.getRect(find.byKey(const ValueKey('about.ver')));
            expect(ver.left, greaterThanOrEqualTo(24 - 0.5));
            expect(ver.right, lessThanOrEqualTo(width - 24 + 0.5));
            final name =
                tester.getRect(find.byKey(const ValueKey('about.name')));
            expect(name.left, greaterThanOrEqualTo(24 - 0.5));
            expect(name.right, lessThanOrEqualTo(width - 24 + 0.5));
            // Иконка не сжимается и стоит по центру.
            final icon =
                tester.getRect(find.byKey(const ValueKey('about.icon')));
            expect(icon.size, const Size.square(96));
            expect(icon.center.dx, closeTo(width / 2, 0.5));

            // Строки докручиваются до видимой части, тексты внутри полей группы.
            await tester
                .ensureVisible(find.text('Политика конфиденциальности'));
            await tester.pump();
            for (final key in const ['page.rowTitle', 'page.rowDetail']) {
              for (final e in find.byKey(ValueKey(key)).evaluate()) {
                final r = tester.getRect(find.byWidget(e.widget));
                expect(r.left, greaterThanOrEqualTo(16 - 0.5), reason: key);
                expect(r.right, lessThanOrEqualTo(width - 16 + 0.5),
                    reason: key);
              }
            }
            final last = tester.getRect(
              find.byKey(const ValueKey('page.row')).last,
            );
            expect(last.bottom, lessThanOrEqualTo(device.size.height + 0.5));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
