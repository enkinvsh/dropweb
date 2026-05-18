import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(Map<String, String> headers) => Profile(
      id: 'profile-cabinet-uri',
      autoUpdateDuration: Duration.zero,
      providerHeaders: headers,
    );

void main() {
  group('profileCabinetUri', () {
    test('returns parsed https URL', () {
      final uri = profileCabinetUri(
        _profile({'dropweb-cabinet': 'https://cab.dropweb.org'}),
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'cab.dropweb.org');
    });

    test('accepts http URL only on loopback hosts (dev)', () {
      for (final value in const [
        'http://localhost:8080/cab',
        'http://127.0.0.1:8080/cab',
        'http://[::1]:8080/cab',
      ]) {
        final uri = profileCabinetUri(_profile({'dropweb-cabinet': value}));
        expect(
          uri,
          isNotNull,
          reason: 'loopback http URL "$value" should be accepted',
        );
        expect(uri!.scheme, 'http');
      }
    });

    test('rejects http URL on non-loopback hosts', () {
      for (final value in const [
        'http://cab.dropweb.org',
        'http://example.com',
        'http://example.com/cab',
        'http://192.168.1.10:8080/cab',
        'http://10.0.0.1/cab',
      ]) {
        expect(
          profileCabinetUri(_profile({'dropweb-cabinet': value})),
          isNull,
          reason: 'plain http URL "$value" must not be accepted',
        );
      }
    });

    test('trims surrounding whitespace before parsing', () {
      final uri = profileCabinetUri(
        _profile({'dropweb-cabinet': '  https://cab.dropweb.org/path  '}),
      );
      expect(uri, isNotNull);
      expect(uri!.host, 'cab.dropweb.org');
      expect(uri.path, '/path');
    });

    test('maps legacy truthy marker "cabinet" to default URL', () {
      final uri = profileCabinetUri(
        _profile({'dropweb-cabinet': 'cabinet'}),
      );
      expect(uri.toString(), defaultCabinetUrl);
    });

    test('maps legacy truthy markers (true/1/yes/enabled) to default URL', () {
      for (final value in const ['true', '1', 'yes', 'enabled', 'TRUE']) {
        final uri = profileCabinetUri(_profile({'dropweb-cabinet': value}));
        expect(
          uri?.toString(),
          defaultCabinetUrl,
          reason: '"$value" should resolve to default cabinet URL',
        );
      }
    });

    test('returns null when header is missing', () {
      expect(profileCabinetUri(_profile(const {})), isNull);
      expect(profileCabinetUri(null), isNull);
    });

    test('returns null for empty / whitespace-only value', () {
      expect(profileCabinetUri(_profile({'dropweb-cabinet': ''})), isNull);
      expect(profileCabinetUri(_profile({'dropweb-cabinet': '   '})), isNull);
    });

    test('rejects unsupported / dangerous schemes', () {
      for (final value in const [
        'javascript:alert(1)',
        'tg://resolve?domain=foo',
        'intent://example',
        'file:///etc/passwd',
        'ftp://example.com',
      ]) {
        expect(
          profileCabinetUri(_profile({'dropweb-cabinet': value})),
          isNull,
          reason: '"$value" must not be accepted as a cabinet URL',
        );
      }
    });

    test('rejects relative paths and hostless URIs', () {
      for (final value in const [
        '/cabinet',
        'cab.dropweb.org',
        'https://',
        'https:///path',
      ]) {
        expect(
          profileCabinetUri(_profile({'dropweb-cabinet': value})),
          isNull,
          reason: '"$value" must not be accepted as a cabinet URL',
        );
      }
    });

    test('rejects "false"', () {
      expect(
        profileCabinetUri(_profile({'dropweb-cabinet': 'false'})),
        isNull,
      );
    });
  });
}
