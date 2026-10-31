// Страница iOS-редизайна (Ios27Page): сверка раскладки с доской (настройки, язык, о программе), переход,
// жест «Назад», сворачивание заголовка, масштаб шрифта, голдены prim_page_*.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/screens/about/ios27_about_page.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_appearance_page.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fixtures/board_providers.dart';
import 'screen_settings_support.dart' show settingsOverrides;
import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Тело «Настройки» доски (app.js:600-604).
Widget settingsBody() => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.globe),
            title: 'Язык',
            detail: 'Как в системе',
            accessory: Ios27RowAccessory.chevron,
          ),
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.droplet),
            title: 'Оформление',
            detail: 'Провайдер',
            accessory: Ios27RowAccessory.chevron,
          ),
        ]),
        Ios27Gap(),
        Ios27List(children: [
          Ios27ListRow(
            leading: Ios27Avatar.icon(Ios27IconName.info),
            title: 'О программе',
            detail: '0.10.3',
            accessory: Ios27RowAccessory.chevron,
          ),
        ]),
      ],
    );

/// Тело «Язык» (app.js:605-607).
Widget languageBody() => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios27List(children: [
          Ios27ListRow(
            title: 'Как в системе',
            subtitle: 'Русский',
            accessory: Ios27RowAccessory.check,
          ),
          Ios27ListRow(title: 'Русский'),
          Ios27ListRow(title: 'English'),
          Ios27ListRow(title: '日本語'),
          Ios27ListRow(title: '简体中文'),
        ]),
      ],
    );

final GlobalKey _aboutName = GlobalKey();

/// Тело «О программе» (app.js:630-636).
Widget aboutBody(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              const SizedBox.square(
                key: ValueKey<String>('about.icon'),
                dimension: 96,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'dropweb',
                  key: _aboutName,
                  textAlign: TextAlign.center,
                  style: ios27Text(context, Ios27Text.title1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Версия 0.10.3, ядро 1.19.31',
                    key: const ValueKey<String>('about.ver'),
                    textAlign: TextAlign.center,
                    style: ios27Text(context, Ios27Text.subhead),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Ios27Gap(),
        const Ios27List(children: [
          Ios27ListRow(
            title: 'Сайт проекта',
            detail: 'dropweb.org',
            accessory: Ios27RowAccessory.external,
          ),
          Ios27ListRow(
            title: 'Политика конфиденциальности',
            accessory: Ios27RowAccessory.external,
          ),
        ]),
      ],
    );

Widget settingsPage() => Ios27Page(
      title: 'Настройки',
      child: settingsBody(),
    );

Ios27ProviderTheme providerTheme(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

Map<String, Finder> pageElements() => {
      'page': find.byKey(const ValueKey('page')),
      'page.nav': find.byKey(const ValueKey('page.nav')),
      'page.back': find.byKey(const ValueKey('page.back')),
      'page.small': find.byKey(const ValueKey('page.small')),
      'page.title': find.byKey(const ValueKey('page.title')),
      'page.group': find.byKey(const ValueKey('page.group')),
      'page.row': find.byKey(const ValueKey('page.row')),
      'page.rowTitle': find.byKey(const ValueKey('page.rowTitle')),
      'page.rowDetail': find.byKey(const ValueKey('page.rowDetail')),
      'page.rowIcon': find.byKey(const ValueKey('page.rowIcon')),
      'page.rowCheck': find.byKey(const ValueKey('page.rowCheck')),
    };

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    group('сверка с доской, $mode', () {
      testWidgets('настройки: рамки ±4 dp и golden', (tester) async {
        await pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: brightness,
            theme: providerTheme(0),
            child: settingsPage(),
          ),
        );
        expectIos27Parity(
          ios27Parity(tester, 'settings-$mode-rt-p0', pageElements()),
        );
        await expectIos27Golden(tester, 'prim_page_settings_${mode}_p0');
      });

      testWidgets('язык: рамки ±4 dp и golden', (tester) async {
        await pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: brightness,
            theme: providerTheme(0),
            child: Ios27Page(title: 'Язык', child: languageBody()),
          ),
        );
        // Строки 4-5 («日本語», «简体中文»): шрифт теста не содержит иероглифов, ширина
        // заглушки другая; координаты и высота у них те же, их проверяет `page.row`.
        expectIos27Parity(
          ios27Parity(tester, 'language-$mode-rt-p0', pageElements())
              .where((r) =>
                  r.name != 'page.rowTitle[3]' && r.name != 'page.rowTitle[4]')
              .toList(),
        );
        await expectIos27Golden(tester, 'prim_page_language_${mode}_p0');
      });

      testWidgets('о программе: рамки ±4 dp и golden', (tester) async {
        await pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: brightness,
            theme: providerTheme(0),
            child: Builder(
              builder: (context) => Ios27Page(
                title: 'О программе',
                largeTitle: false,
                collapseAnchor: _aboutName,
                child: aboutBody(context),
              ),
            ),
          ),
        );
        final elements = pageElements()
          ..['about.icon'] = find.byKey(const ValueKey('about.icon'))
          ..['about.ver'] = find.byKey(const ValueKey('about.ver'));
        expectIos27Parity(
          ios27Parity(tester, 'about-$mode-rt-p0', elements),
        );
        await expectIos27Golden(tester, 'prim_page_about_${mode}_p0');
      });
    });
  }

  // «Язык», а не «Настройки»: галочка выбранной строки — единственное, что красит провайдер.
  testWidgets('провайдер p5 (серый): язык golden', (tester) async {
    await pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        theme: providerTheme(5),
        child: Ios27Page(title: 'Язык', child: languageBody()),
      ),
    );
    await expectIos27Golden(tester, 'prim_page_language_light_p5');
  });

  group('переход и жесты', () {
    Widget host(
      WidgetBuilder body, {
      VoidCallback? onTitleTap,
      String? titleId,
      String title = 'Настройки',
      List<NavigatorObserver> observers = const [],
    }) =>
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => pushIos27Page<void>(
                context,
                title: title,
                builder: body,
                onTitleTap: onTitleTap,
                titleSemanticsIdentifier: titleId,
              ),
              child: const Text('Открыть'),
            ),
          ),
        );

    testWidgets('кнопка «Назад» закрывает страницу', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
      expect(find.text('Настройки'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('page.back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('свайп от левого края закрывает страницу', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      final gesture = await tester.startGesture(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('короткий свайп возвращает страницу на место', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      final gesture = await tester.startGesture(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      // Остановка перед отпусканием гасит скорость: ниже порога броска.
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
      final left = tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;
      expect(left, closeTo(0, 0.5));
    });

    testWidgets('маршрут убран посреди свайпа: жест навигатора не залипает',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      final gesture = await tester.startGesture(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(navigator.userGestureInProgress, isTrue);

      // Страницу убирают из кода, пока палец ещё на экране (`pop` навигатор откладывает до
      // конца жеста, а `removeRoute`, `pushReplacement`, `popUntil` снимают маршрут сразу).
      navigator.removeRoute(
        ModalRoute.of(tester.element(find.byKey(const ValueKey('page'))))!,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(navigator.userGestureInProgress, isFalse);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(navigator.userGestureInProgress, isFalse);
    });

    testWidgets('нажатие на заголовок и идентификатор', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host(
            (_) => settingsBody(),
            onTitleTap: () => taps++,
            titleId: 'dw_settings_title',
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('page.title')));
      expect(taps, 1);
      expect(
        find.bySemanticsIdentifier('dw_settings_title'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('«Уменьшить движение»: только угасание, нет тикеров',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          disableAnimations: true,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Посреди угасания страница уже на месте, не едет справа.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
        closeTo(0, 0.5),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('обычный режим: страница въезжает справа пружиной',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.light,
          child: host((_) => settingsBody()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final early = tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;
      expect(early, greaterThan(100));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
        closeTo(0, 0.5),
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('страница несёт свою тему при контексте над скоупом',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          overrides: layerOverrides(),
          brightness: Brightness.dark,
          theme: providerTheme(5),
          child: const SizedBox.shrink(),
        ),
      );
      final root = tester.element(find.byType(Navigator).first);
      // ignore: unawaited_futures
      pushIos27Page<void>(root, title: 'Язык', builder: (_) => languageBody());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('page.title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('заголовок и край', () {
    testWidgets('маленький заголовок проявляется при прокрутке',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27Page(
            title: 'Настройки',
            child: Column(
              children: [
                for (var i = 0; i < 30; i++) Ios27ListRow(title: 'Строка $i'),
              ],
            ),
          ),
        ),
      );
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byKey(const ValueKey('page.small')),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      double edge() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('page.edge')),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(opacity(), 0);
      expect(edge(), 0);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 1);
      expect(edge(), 1);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 0);
    });

    // Дымовой тест: на старом коде он тоже зелёный, регрессию держит тест
    // «ScrollEndNotification изнутри раскладки…» ниже.
    testWidgets(
        'содержимое сжалось во время инерции: страница не падает',
        (tester) async {
      var rows = 60;
      late StateSetter rebuild;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27Page(
            title: 'Настройки',
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  children: [
                    for (var i = 0; i < rows; i++)
                      Ios27ListRow(title: 'Строка $i'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.fling(
          find.byType(SingleChildScrollView), const Offset(0, -600), 3000);
      await tester.pump(const Duration(milliseconds: 100));
      // Высота падает посреди инерции: viewport поправляет положение прямо в раскладке и
      // сразу завершает прокрутку, уведомление приходит изнутри performLayout.
      rebuild(() => rows = 2);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      // Страница вернулась к началу: край и маленький заголовок снова скрыты.
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: find.byKey(const ValueKey('page.edge')),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );
    });

    testWidgets(
        'ScrollEndNotification изнутри раскладки откладывается до конца кадра',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27Page(
            title: 'Настройки',
            child: Column(
              children: [
                const _LayoutPing(),
                for (var i = 0; i < 30; i++) Ios27ListRow(title: 'Строка $i'),
              ],
            ),
          ),
        ),
      );
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      final notifyContext = scrollable.context;
      // Так viewport завершает прокрутку, когда поправляет положение в `performLayout`:
      // уведомление уходит с контекста Scrollable прямо посреди раскладки.
      final ping = tester.renderObject<_RenderLayoutPing>(
        find.byType(_LayoutPing),
      )
        ..onLayout = () {
          ScrollEndNotification(
            metrics: scrollable.position.copyWith(),
            context: notifyContext,
          ).dispatch(notifyContext);
        }
        ..markNeedsLayout();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Отложенный расчёт отрабатывает в post-frame следующего кадра.
      ping.onLayout = null;
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('без крупного заголовка маленький остаётся скрытым',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27Page(
            title: 'О программе',
            largeTitle: false,
            child: Column(
              children: [
                for (var i = 0; i < 30; i++) Ios27ListRow(title: 'Строка $i'),
              ],
            ),
          ),
        ),
      );
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));
      final o = tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byKey(const ValueKey('page.small')),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(o, 0);
    });

    testWidgets('кнопка справа в панели', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27Page(
            title: 'Настройки',
            trailing: const SizedBox.square(
              key: ValueKey('trailing'),
              dimension: 44,
            ),
            child: settingsBody(),
          ),
        ),
      );
      final r = tester.getRect(find.byKey(const ValueKey('trailing')));
      expect(r.right, closeTo(411 - 16, 0.5));
      expect(r.top, closeTo(48, 0.5));
    });

    testWidgets('контроллеры освобождаются', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(brightness: Brightness.light, child: settingsPage()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('масштаб шрифта', () {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        testWidgets('${device.name} ×$scale: нет переполнения', (tester) async {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.light,
              textScale: scale,
              device: device,
              child: Ios27Page(
                title: 'Очень длинное название страницы настроек приложения',
                child: Column(
                  children: [
                    settingsBody(),
                    languageBody(),
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

    testWidgets('Повышенная контрастность и жирный текст', (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.dark,
          highContrast: true,
          boldText: true,
          child: settingsPage(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('page.back')), findsOneWidget);
    });
  });

  group('titleBuilder: заголовок следует за языком', () {
    setUp(() {
      globalState.packageInfo = PackageInfo(
        appName: 'dropweb',
        packageName: 'app.dropweb',
        version: '0.10.3',
        buildNumber: '2050000023',
      );
      globalState.coreVersion = '1.19.31';
    });

    Widget app(Locale locale, Widget child) => ios27BoardApp(
          overrides: [...layerOverrides(), ...settingsOverrides()],
          brightness: Brightness.light,
          locale: locale,
          child: child,
        );

    // Смена языка = тот же MaterialApp с другой `locale`: стопка навигатора остаётся.
    Future<void> switchLocale(
      WidgetTester tester,
      Locale locale,
      Widget child,
    ) async {
      await tester.runAsync(() => AppLocalizations.load(locale));
      await tester.pumpWidget(app(locale, child));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('title и titleBuilder вместе или оба пропущены — assert',
        (tester) async {
      await pumpIos27Board(
        tester,
        app(const Locale('ru'), const SizedBox()),
      );
      final ctx = tester.element(find.byType(Navigator).first);
      expect(
        () => pushIos27Page<void>(ctx, builder: (_) => const SizedBox()),
        throwsAssertionError,
      );
      expect(
        () => pushIos27Page<void>(
          ctx,
          title: 'A',
          titleBuilder: (_) => 'B',
          builder: (_) => const SizedBox(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
        'страница в стопке переименовывается, новые страницы открываются сразу на English',
        (tester) async {
      final host = Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              key: const ValueKey('open.generic'),
              onPressed: () => pushIos27Page<void>(
                context,
                titleBuilder: (c) => AppLocalizations.of(c).settings,
                builder: (_) => settingsBody(),
              ),
              child: const Text('1'),
            ),
            TextButton(
              key: const ValueKey('open.appearance'),
              onPressed: () => openIos27Appearance(context),
              child: const Text('2'),
            ),
            TextButton(
              key: const ValueKey('open.about'),
              onPressed: () => openIos27About(context),
              child: const Text('3'),
            ),
          ],
        ),
      );
      await pumpIos27Board(tester, app(const Locale('ru'), host));
      // Геттеры читают текущую локаль, а не хранят её: строки снимаются сразу после загрузки.
      Future<({String settings, String appearance, String about})> strings(
        Locale locale,
      ) async {
        final l = (await tester.runAsync(() => AppLocalizations.load(locale)))!;
        return (
          settings: l.settings,
          appearance: l.m3eAppearanceTitle,
          about: l.m3eAboutTitle,
        );
      }

      final en = await strings(const Locale('en'));
      final ru = await strings(const Locale('ru'));
      expect(ru.settings, isNot(en.settings));
      expect(ru.appearance, isNot(en.appearance));
      expect(ru.about, isNot(en.about));

      Finder title() => find.byKey(const ValueKey('page.title'));
      String titleText() => tester
          .widget<Text>(
            find.descendant(of: title().last, matching: find.byType(Text)),
          )
          .data!;

      await tester.tap(find.byKey(const ValueKey('open.generic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(titleText(), ru.settings);

      await switchLocale(tester, const Locale('en'), host);
      expect(titleText(), en.settings,
          reason: 'страница в стопке перечиталась');

      // Страницы, открытые после смены языка.
      await tester.tap(find.byKey(const ValueKey('page.back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('open.appearance')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(titleText(), en.appearance);

      await tester.tap(find.byKey(const ValueKey('page.back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('open.about')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(en.about), findsWidgets);
      expect(find.text(ru.about), findsNothing);
    });
  });
}

/// Нулевой по размеру виджет, в `performLayout` которого тест вызывает произвольный код:
/// так воспроизводится уведомление о прокрутке, пришедшее изнутри раскладки.
class _LayoutPing extends LeafRenderObjectWidget {
  const _LayoutPing();

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayoutPing();
}

class _RenderLayoutPing extends RenderBox {
  VoidCallback? onLayout;

  @override
  void performLayout() {
    size = constraints.constrain(Size.zero);
    onLayout?.call();
  }
}
