import 'dart:convert';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widget/m3e_widget_payload.dart';
import 'package:dropweb/ui/m3e/widget/m3e_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';

M3eThemeSource _source(int provider) {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  return M3eThemeSource(seed: h.accent, filter: h.filter);
}

void main() {
  late AppLocalizations ru;

  setUpAll(() async {
    ru = await AppLocalizations.load(const Locale('ru'));
  });

  group('payload', () {
    for (final p in [0, 5]) {
      for (final dark in [false, true]) {
        test('цвета совпадают со схемой: провайдер $p, ${dark ? 'dark' : 'light'}',
            () {
          final src = _source(p);
          final payload = m3eWidgetPayload(
            source: src,
            serviceName: 'Zeny',
            l10n: ru,
          );
          final c = payload[dark ? 'dark' : 'light']! as Map<String, String>;
          final s = scheme(src.seed, src.filter, dark: dark);
          final h = homeVars(src.seed, src.filter, dark: dark);
          expect(c['bg'], s.hex('surfaceContainer'));
          expect(c['title'], s.hex('onSurface'));
          expect(c['sub'], s.hex('onSurfaceVariant'));
          // Кнопка: те же роли, что у M3eHeroButton (off — контейнер, on — hero-on).
          expect(c['offBg'], s.hex('primaryContainer'));
          expect(c['offFg'], s.hex('onPrimaryContainer'));
          expect(c['onBg'], h.hex('hero-on'));
          expect(c['onFg'], h.hex('on-hero-on'));
          for (final v in c.values) {
            expect(v, matches(RegExp(r'^#[0-9a-f]{6}$')));
          }
        });
      }
    }

    test('провайдеры дают разные цвета, светлая и тёмная схемы различаются', () {
      final a = m3eWidgetColors(_source(0), dark: false);
      final b = m3eWidgetColors(_source(5), dark: false);
      final d = m3eWidgetColors(_source(0), dark: true);
      expect(a['offBg'], isNot(b['offBg']));
      expect(a['bg'], isNot(d['bg']));
    });

    test('подписи берутся из локализации приложения', () async {
      // Геттеры Intl читают глобальную локаль в момент вызова, поэтому каждую
      // локаль загружаем и проверяем сразу, а не держим два экземпляра.
      final on = <String>[];
      for (final locale in const [Locale('ru'), Locale('en')]) {
        final l = await AppLocalizations.load(locale);
        final t = m3eWidgetPayload(
          source: _source(0),
          serviceName: 'x',
          l10n: l,
        )['texts']! as Map<String, String>;
        expect(t['on'], l.m3eStatusConnected);
        expect(t['off'], l.m3eStatusDisconnected);
        expect(t['pending'], l.m3eStatusConnecting);
        expect(t['cdOn'], l.m3eA11yDisconnect);
        expect(t['cdOff'], l.m3eA11yConnect);
        expect(t['cdPending'], l.m3eA11yCancel);
        on.add(t['on']!);
      }
      expect(on[0], 'Подключено');
      expect(on[1], 'Connected');
    });

    test('имя: обрезается, пустое заменяется на dropweb', () {
      String name(String n) => m3eWidgetPayload(
            source: _source(0),
            serviceName: n,
            l10n: ru,
          )['name']! as String;
      expect(name('  Zeny VPN '), 'Zeny VPN');
      expect(name(''), 'dropweb');
      expect(name('   '), kM3eWidgetFallbackName);
    });

    test('JSON детерминирован и несёт версию формата', () {
      String json() => m3eWidgetPayloadJson(
            source: _source(5),
            serviceName: 'Zeny',
            l10n: ru,
          );
      expect(json(), json());
      expect(
        (jsonDecode(json()) as Map<String, Object?>)['v'],
        kM3eWidgetPayloadVersion,
      );
    });
  });

  group('синхронизатор', () {
    final source = StateProvider<M3eThemeSource>((_) => _source(0));
    final profile = StateProvider<Profile?>((_) => null);
    final locale = ValueNotifier<Locale>(const Locale('ru'));

    Future<(ProviderContainer, List<String>)> pumpSync(
      WidgetTester tester,
    ) async {
      locale.value = const Locale('ru');
      final sent = <String>[];
      final container = ProviderContainer(
        overrides: [
          m3eWidgetSinkProvider.overrideWithValue((json) async => sent.add(json)),
          m3eThemeSourceProvider.overrideWith((ref) => ref.watch(source)),
          currentProfileProvider.overrideWith((ref) => ref.watch(profile)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (_, l, __) => MaterialApp(
              locale: l,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: const M3eWidgetStyleSync(child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, sent);
    }

    Map<String, Object?> last(List<String> sent) =>
        jsonDecode(sent.last) as Map<String, Object?>;

    testWidgets('шлёт стиль при старте, повторные перестроения не шлют', (
      tester,
    ) async {
      final (_, sent) = await pumpSync(tester);
      expect(sent, hasLength(1));
      expect(last(sent)['name'], kM3eWidgetFallbackName);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sent, hasLength(1));
    });

    testWidgets('смена источника темы, имени сервиса и языка шлёт новый стиль', (
      tester,
    ) async {
      final (container, sent) = await pumpSync(tester);

      container.read(source.notifier).state = _source(5);
      await tester.pump();
      expect(sent, hasLength(2));
      final light = (last(sent)['light']! as Map)['offBg'];
      expect(light, scheme(_source(5).seed, _source(5).filter, dark: false)
          .hex('primaryContainer'));

      container.read(profile.notifier).state =
          Profile.normal(label: 'Zeny VPN');
      await tester.pump();
      expect(sent, hasLength(3));
      expect(last(sent)['name'], 'Zeny VPN');

      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(sent, hasLength(4));
      expect((last(sent)['texts']! as Map)['on'], 'Connected');
    });

    testWidgets('ошибка канала не ломает экран', (tester) async {
      final container = ProviderContainer(
        overrides: [
          m3eThemeSourceProvider.overrideWithValue(_source(0)),
          currentProfileProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      // Настоящий приёмник: без нативного плагина `app` — null, пуш молча пропускается.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: const M3eWidgetStyleSync(child: Text('ok')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
