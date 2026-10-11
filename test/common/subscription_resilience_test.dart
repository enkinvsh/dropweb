// Контракт заголовков устойчивости подписки (`dropweb-sub-mirrors`,
// `dropweb-sub-id`) и порядок кандидатов, которые перебирает Profile.update.
import 'package:dropweb/common/subscription_resilience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSubscriptionMirrors', () {
    test('null / пусто → пустой список', () {
      expect(parseSubscriptionMirrors(null), isEmpty);
      expect(parseSubscriptionMirrors('  '), isEmpty);
    });

    test('разделители , ; и пробелы', () {
      expect(
        parseSubscriptionMirrors(
          'https://mirror.example/a, https://mirror.example/b;'
          'https://mirror.example/c https://mirror.example/d',
        ),
        [
          'https://mirror.example/a',
          'https://mirror.example/b',
          'https://mirror.example/c',
          'https://mirror.example/d',
        ],
      );
    });

    test('только https; http — лишь loopback; мусор отбрасывается', () {
      expect(
        parseSubscriptionMirrors(
          'http://mirror.example/a ftp://mirror.example/b not-a-url '
          'https:///nohost http://127.0.0.1:8080/s http://localhost/s '
          'http://[::1]/s https://mirror.example/ok',
        ),
        [
          'http://127.0.0.1:8080/s',
          'http://localhost/s',
          'http://[::1]/s',
          'https://mirror.example/ok',
        ],
      );
    });

    test('дубликаты убираются по нормализованному URL', () {
      expect(
        parseSubscriptionMirrors(
          'https://mirror.example/a https://mirror.example/a '
          'HTTPS://MIRROR.EXAMPLE/a',
        ),
        ['https://mirror.example/a'],
      );
    });

    test('не больше 8 зеркал', () {
      final raw =
          List.generate(12, (i) => 'https://m$i.mirror.example/s').join(',');
      final parsed = parseSubscriptionMirrors(raw);
      expect(parsed, hasLength(8));
      expect(parsed.first, 'https://m0.mirror.example/s');
      expect(parsed.last, 'https://m7.mirror.example/s');
    });
  });

  group('parseSubscriptionSubId', () {
    test('обрезает пробелы', () {
      expect(parseSubscriptionSubId('  abc123  '), 'abc123');
    });

    test('пусто / null / длиннее 128 → null', () {
      expect(parseSubscriptionSubId(null), isNull);
      expect(parseSubscriptionSubId('   '), isNull);
      expect(parseSubscriptionSubId('x' * 129), isNull);
      expect(parseSubscriptionSubId('x' * 128), 'x' * 128);
      expect(parseSubscriptionSubId('x'), 'x');
    });
  });

  group('subscriptionCandidates', () {
    const primary = 'https://primary.example/s';
    const m1 = 'https://mirror.example/1';
    const m2 = 'https://mirror.example/2';
    const fb = 'https://fallback.example/s';

    test('порядок: preferred, primary, зеркала, fallback', () {
      expect(
        subscriptionCandidates(
          preferred: m2,
          primary: primary,
          mirrors: const [m1, m2],
          fallback: fb,
        ),
        [m2, primary, m1, fb],
      );
    });

    test('устаревший preferred (не из списка) игнорируется', () {
      expect(
        subscriptionCandidates(
          preferred: 'https://stale.example/s',
          primary: primary,
          mirrors: const [m1],
          fallback: fb,
        ),
        [primary, m1, fb],
      );
    });

    test('дедупликация по нормализованному URL', () {
      expect(
        subscriptionCandidates(
          primary: primary,
          mirrors: const [' $primary ', m1, m1],
          fallback: m1,
        ),
        [primary, m1],
      );
    });

    test('не больше 6 попыток', () {
      final mirrors = List.generate(8, (i) => 'https://m$i.mirror.example/s');
      final c = subscriptionCandidates(
        primary: primary,
        mirrors: mirrors,
        fallback: fb,
      );
      expect(c, hasLength(6));
      expect(c.first, primary);
      expect(c, isNot(contains(fb)));
    });
  });

  test('секретные заголовки', () {
    expect(subscriptionSecretHeaders, {
      'dropweb-sub-mirrors',
      'dropweb-sub-id',
      'fallback-url',
    });
  });
}
