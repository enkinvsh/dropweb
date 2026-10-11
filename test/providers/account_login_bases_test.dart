// Контракт `dropweb-account`: какой бэкенд аккаунта видит приложение и
// когда вход по почте вообще доступен.
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(String id, [Map<String, String> headers = const {}]) =>
    Profile(
      id: id,
      autoUpdateDuration: const Duration(hours: 12),
      providerHeaders: headers,
    );

const _default = 'https://default.example/api';

void main() {
  group('parseAccountApiBases / profileAccountApiBases', () {
    test('одна https-база, хвостовой слэш срезается', () {
      expect(parseAccountApiBases('https://cab.example.com/api/'),
          ['https://cab.example.com/api']);
    });

    test('зеркала через запятую и пробелы, дубли убираются', () {
      expect(
        parseAccountApiBases(
          ' https://a.example/api, https://b.example/api  https://a.example/api ',
        ),
        ['https://a.example/api', 'https://b.example/api'],
      );
      // Так зеркала приходят из --dart-define через setup.dart.
      expect(parseAccountApiBases('https://a.example/api;https://b.example/api'),
          ['https://a.example/api', 'https://b.example/api']);
    });

    test('мусор и http на публичном хосте отбрасываются', () {
      expect(
        parseAccountApiBases(
          'http://public.example/api, /api, tg://x, javascript:alert(1), '
          'cabinet, https:///nohost, https://ok.example/api',
        ),
        ['https://ok.example/api'],
      );
    });

    test('http разрешён только для loopback', () {
      expect(
        parseAccountApiBases(
          'http://localhost:8080/api, http://127.0.0.1/api, http://[::1]/api',
        ),
        [
          'http://localhost:8080/api',
          'http://127.0.0.1/api',
          'http://[::1]/api',
        ],
      );
    });

    test('нет заголовка / пусто / ничего валидного → пустой список', () {
      expect(parseAccountApiBases(null), isEmpty);
      expect(parseAccountApiBases('  '), isEmpty);
      expect(parseAccountApiBases('http://evil.example/api'), isEmpty);
      expect(profileAccountApiBases(null), isEmpty);
      expect(profileAccountApiBases(_profile('p')), isEmpty);
    });

    test('профиль: читается dropweb-account', () {
      expect(
        profileAccountApiBases(_profile('p', {
          'dropweb-account': 'https://cab.example.com/api',
        })),
        ['https://cab.example.com/api'],
      );
    });
  });

  group('resolveAccountLoginBases', () {
    final withHeader = _profile('a', {
      'dropweb-account': 'https://a.example/api, https://a2.example/api',
    });
    final withoutHeader = _profile('b', {
      'dropweb-cabinet': 'https://cab.b.example',
    });

    test('профиль с заголовком → его базы', () {
      expect(
        resolveAccountLoginBases(
          profiles: [withHeader, withoutHeader],
          current: withHeader,
          defaults: const [_default],
        ),
        ['https://a.example/api', 'https://a2.example/api'],
      );
    });

    test('профиль без заголовка + дефолт сборки → вход недоступен', () {
      expect(
        resolveAccountLoginBases(
          profiles: [withHeader, withoutHeader],
          current: withoutHeader,
          defaults: const [_default],
        ),
        isEmpty,
      );
    });

    test('профилей нет + дефолт → дефолт', () {
      expect(
        resolveAccountLoginBases(
          profiles: const [],
          current: null,
          defaults: const [_default],
        ),
        [_default],
      );
    });

    test('профилей нет + пустой дефолт → вход недоступен', () {
      expect(
        resolveAccountLoginBases(
          profiles: const [],
          current: null,
          defaults: const [],
        ),
        isEmpty,
      );
    });
  });

  group('accountLoginBasesProvider', () {
    ProviderContainer container(
      List<Profile> profiles,
      String? currentId, {
      bool storeBuild = false,
    }) {
      globalState.config = Config(
        themeProps: defaultThemeProps,
        profiles: profiles,
        currentProfileId: currentId,
      );
      final c = ProviderContainer(overrides: [
        accountDefaultApiBasesProvider.overrideWith((ref) => const [_default]),
        accountFeatureEnabledProvider.overrideWith((ref) => !storeBuild),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('пересчитывается при смене текущего профиля', () {
      final c = container([
        _profile('a', {'dropweb-account': 'https://a.example/api'}),
        _profile('b'),
      ], 'a');
      final sub = c.listen(accountLoginAvailableProvider, (_, __) {});
      addTearDown(sub.close);

      expect(c.read(accountLoginBasesProvider), ['https://a.example/api']);
      expect(c.read(accountLoginAvailableProvider), isTrue);

      c.read(currentProfileIdProvider.notifier).value = 'b';
      expect(c.read(accountLoginBasesProvider), isEmpty);
      expect(c.read(accountLoginAvailableProvider), isFalse);
    });

    test('без профилей — дефолт сборки', () {
      final c = container(const [], null);
      expect(c.read(accountLoginBasesProvider), [_default]);
      expect(c.read(accountLoginAvailableProvider), isTrue);
    });

    // Магазинная сборка — чистый клиент без аккаунта: ни заголовок
    // провайдера, ни дефолт сборки вход не включают.
    test('магазинная сборка: вход недоступен даже с заголовком и дефолтом', () {
      final withHeader = container([
        _profile('a', {'dropweb-account': 'https://a.example/api'}),
      ], 'a', storeBuild: true);
      expect(withHeader.read(accountLoginAvailableProvider), isFalse);

      final empty = container(const [], null, storeBuild: true);
      expect(empty.read(accountLoginAvailableProvider), isFalse);
    });

    test('магазинная сборка: restore не поднимает сессию', () async {
      final c = container(const [], null, storeBuild: true);
      await c.read(accountProvider.notifier).restore();
      expect(c.read(accountProvider).status, AccountStatus.unknown);
    });
  });
}
