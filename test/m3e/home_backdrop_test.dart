import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_home_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Центр кнопки на доске: hero 161.5,778 88x88 (ref/layout.json).
const Offset _heroAt = Offset(161.5, 778);
const Offset _waveOrigin = Offset(205.5, 822);

/// Сколько прокрутить вращение перед снимком `on`: 8 с = 120° — кратно периоду
/// Cookie9 (40°), поэтому форма стоит так же, как на эталоне (там вращение не идёт).
const Duration _spinPump = Duration(seconds: 8);

/// Сцена доски: (golden, состояние кнопки, подписка закончилась).
const List<(String, M3eHeroState, bool)> _scenes = [
  ('home-off', M3eHeroState.off, false),
  ('connecting', M3eHeroState.connecting, false),
  ('home-on', M3eHeroState.on, false),
  ('error', M3eHeroState.error, false),
  ('expired', M3eHeroState.off, true),
];

Widget _scene({
  required M3eHeroState state,
  bool blocked = false,
  bool reduced = false,
  bool tickers = true,
}) =>
    Builder(
      builder: (context) {
        final home = M3eColors.of(context).home;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: TickerMode(
            enabled: tickers,
            child: ColoredBox(
              color: home.bg,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: M3eHomeBackdrop(
                        state: state,
                        blocked: blocked,
                        waveOrigin: _waveOrigin,
                      ),
                    ),
                    Positioned(
                      left: _heroAt.dx,
                      top: _heroAt.dy,
                      width: kM3eHeroSize,
                      height: kM3eHeroSize,
                      child: M3eHeroButton(
                        state: state,
                        disabled: blocked,
                        onPressed: () {},
                        semanticLabel: 'Подключить VPN',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

Widget _app(
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
}) {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: h.accent,
    filter: h.filter,
    brightness: brightness,
    child: child,
  );
}

Future<List<int>> _bytes(WidgetTester tester) async {
  final box = tester.element(find.byKey(kM3eBoardRootKey)).renderObject!
      as RenderRepaintBoundary;
  final image = (await tester.runAsync(box.toImage))!;
  final data = await tester.runAsync(image.toByteData);
  return data!.buffer.asUint8List();
}

void main() {
  group('golden: фон главной вместе с кнопкой', () {
    for (final provider in [0, 5]) {
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        for (final (scene, state, blocked) in _scenes) {
          testWidgets('backdrop_${scene}_${theme}_p$provider', (tester) async {
            await pumpM3eBoard(
              tester,
              _app(
                // connecting снят доской с «меньше движения»: статичный SoftBurst.
                _scene(
                  state: state,
                  blocked: blocked,
                  reduced: state == M3eHeroState.connecting,
                ),
                provider: provider,
                brightness: brightness,
              ),
            );
            await tester.pump(
              state == M3eHeroState.on ? _spinPump : const Duration(seconds: 1),
            );
            await expectM3eGolden(
              tester,
              'backdrop_${scene}_${theme}_p$provider',
            );
          });
        }
      }
    }
  });

  group('поведение', () {
    testWidgets('под disableAnimations фон и кнопка без тикеров', (
      tester,
    ) async {
      for (final state in M3eHeroState.values) {
        await pumpM3eBoard(
          tester,
          _app(_scene(state: state, reduced: true)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: '$state при reduced motion',
        );
      }
    });

    testWidgets('при reduced motion смена состояния мгновенна', (tester) async {
      await pumpM3eBoard(
        tester,
        _app(_scene(state: M3eHeroState.off, reduced: true)),
      );
      final off = await _bytes(tester);
      await tester.pumpWidget(
        _app(_scene(state: M3eHeroState.on, reduced: true)),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(await _bytes(tester), isNot(off));
    });

    testWidgets('волна идёт после включения и садится без тикеров фона', (
      tester,
    ) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.on)));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = await _bytes(tester);
      await tester.pump(const Duration(seconds: 2));
      final settled = await _bytes(tester);
      expect(mid, isNot(settled), reason: 'волна ещё росла на 100 мс');
    });

    testWidgets('выключение возвращает фон к спокойному без вечных анимаций', (
      tester,
    ) async {
      final calm = await (() async {
        await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
        await tester.pump(const Duration(seconds: 1));
        return _bytes(tester);
      })();
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.on)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.off)));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(await _bytes(tester), calm);
    });

    testWidgets('прерывание на полпути не прыгает и не падает', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.connecting)));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.on)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.error)));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.off)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('blocked держит фон спокойным даже при state on', (
      tester,
    ) async {
      Widget backdrop(M3eHeroState state, {bool blocked = false}) => _app(
            Builder(
              builder: (context) => SizedBox.expand(
                child: M3eHomeBackdrop(
                  state: state,
                  blocked: blocked,
                  waveOrigin: _waveOrigin,
                ),
              ),
            ),
          );
      await pumpM3eBoard(tester, backdrop(M3eHeroState.off));
      await tester.pump(const Duration(seconds: 1));
      final calm = await _bytes(tester);
      await tester.pumpWidget(backdrop(M3eHeroState.on, blocked: true));
      await tester.pumpAndSettle();
      expect(await _bytes(tester), calm);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('при TickerMode(enabled: false) анимации не тикают', (
      tester,
    ) async {
      await pumpM3eBoard(
        tester,
        _app(_scene(state: M3eHeroState.on, tickers: false)),
      );
      await tester.pumpWidget(
        _app(_scene(state: M3eHeroState.off, tickers: false)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('ключ фона на месте', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      expect(find.byKey(kM3eBackdropKey), findsOneWidget);
      expect(tester.getSize(find.byKey(kM3eBackdropKey)), const Size(411, 914));
    });
  });
}
