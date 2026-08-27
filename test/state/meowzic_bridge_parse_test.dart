import 'package:dropweb/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// `dropweb-music` carries the credential AND the switch, so a parsing slip
/// here is either a dead feature or a request that spends itself on a 403.
void main() {
  group('parseMeowzicBridge', () {
    test('token alone falls back to the built-in bridge address', () {
      final bridge = parseMeowzicBridge('abc123');

      expect(bridge, isNotNull);
      expect(bridge!.token, 'abc123');
      expect(bridge.baseUrl.toString(), 'http://meow.dropweb.org:8090');
    });

    test('second field overrides the address', () {
      final bridge = parseMeowzicBridge('abc123,https://music.example.com');

      expect(bridge!.baseUrl.toString(), 'https://music.example.com');
    });

    test('surrounding whitespace is tolerated', () {
      final bridge = parseMeowzicBridge('  abc123 , https://music.example.com ');

      expect(bridge!.token, 'abc123');
      expect(bridge.baseUrl.host, 'music.example.com');
    });

    test('a trailing slash does not become a double slash in the path', () {
      final bridge = parseMeowzicBridge('abc123,https://music.example.com/');

      expect(bridge!.searchUri('nirvana').path, '/s');
      expect(bridge.audioUri('xyz').path, '/a/xyz');
    });

    test('a sub-path base keeps its prefix', () {
      final bridge = parseMeowzicBridge('abc123,https://example.com/bridge');

      expect(bridge!.audioUri('xyz').path, '/bridge/a/xyz');
    });

    // The old contract was a switch. Sending it on now would mean handing
    // the word "on" to the bridge as a credential.
    for (final legacy in ['on', 'true', '1', 'yes', 'enabled', 'ON', 'True']) {
      test('legacy switch value "$legacy" leaves music off', () {
        expect(parseMeowzicBridge(legacy), isNull);
      });
    }

    for (final off in ['off', 'false', '0', 'no', 'disabled']) {
      test('explicit off value "$off" leaves music off', () {
        expect(parseMeowzicBridge(off), isNull);
      });
    }

    test('absent or empty header leaves music off', () {
      expect(parseMeowzicBridge(null), isNull);
      expect(parseMeowzicBridge(''), isNull);
      expect(parseMeowzicBridge('   '), isNull);
      expect(parseMeowzicBridge(',https://music.example.com'), isNull);
    });

    test('a non-ASCII token is refused rather than thrown on later', () {
      // dart:io rejects non-ASCII header values, so this would otherwise
      // surface as an exception on the first search instead of "music off".
      expect(parseMeowzicBridge('токен'), isNull);
      expect(parseMeowzicBridge('two words'), isNull);
    });

    test('a bare host is refused — the contract needs a scheme', () {
      // Uri.parse('meow.dropweb.org:8090') yields a schemeless oddity with no
      // authority. Failing closed here is what forces the panel to send a
      // full URL, which is also what lets a third-party bridge serve https.
      expect(parseMeowzicBridge('abc123,meow.dropweb.org:8090'), isNull);
    });

    test('a non-http scheme is refused', () {
      expect(parseMeowzicBridge('abc123,ftp://example.com'), isNull);
      expect(parseMeowzicBridge('abc123,ws://example.com'), isNull);
    });

    test('the token travels as a header, never in the query', () {
      final bridge = parseMeowzicBridge('abc123')!;

      expect(bridge.headers, {'X-Bridge-Token': 'abc123'});
      expect(bridge.searchUri('nirvana').query, 'q=nirvana&n=20');
      expect(bridge.audioUri('xyz').query, isEmpty);
      expect(bridge.searchUri('nirvana').toString(), isNot(contains('abc123')));
      expect(bridge.audioUri('xyz').toString(), isNot(contains('abc123')));
    });

    test('equal headers compare equal, so watchers do not churn', () {
      expect(parseMeowzicBridge('abc123'), parseMeowzicBridge('abc123'));
      expect(parseMeowzicBridge('abc123'), isNot(parseMeowzicBridge('zzz999')));
    });
  });
}
