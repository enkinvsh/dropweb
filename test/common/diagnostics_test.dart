import 'dart:convert';

import 'package:dropweb/common/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sampleConfig() => <String, dynamic>{
      'mixed-port': 7890,
      'secret': 'api-secret-value',
      'authentication': ['user:pass'],
      'dns': {
        'enable': true,
        'nameserver': ['https://dns.example/dns-query'],
      },
      'proxies': [
        {
          'name': 'Germany 1',
          'type': 'vless',
          'server': 'de1.example.net',
          'port': 443,
          'uuid': '11111111-2222-3333-4444-555555555555',
          'servername': 'www.microsoft.com',
          'reality-opts': {
            'public-key': 'PUBKEYSECRET',
            'short-id': 'abcd1234',
          },
        },
        {
          'name': 'Germany 2',
          'type': 'vless',
          'server': 'de1.example.net',
          'port': 8443,
          'uuid': '99999999-2222-3333-4444-555555555555',
        },
        {
          'name': 'Finland',
          'type': 'hysteria2',
          'server': 'fi.example.net',
          'password': 'hy2-pass',
          'obfs-password': 'obfs-secret',
          'sni': 'fi.example.net',
        },
        {
          'name': 'WG',
          'type': 'wireguard',
          'server': 'wg.example.net',
          'private-key': 'WGPRIVATE',
          'peers': [
            {
              'server': 'peer.example.net',
              'public-key': 'PEERPUB',
              'pre-shared-key': 'PEERPSK',
            },
          ],
        },
      ],
      'proxy-providers': {
        'sub': {
          'type': 'http',
          'url': 'https://panel.example/api/sub/SECRETTOKEN1234567890',
          'interval': 3600,
        },
      },
      'proxy-groups': [
        {
          'name': 'VPN',
          'type': 'select',
          'proxies': ['Germany 1', 'Finland'],
        },
      ],
      'rules': ['DOMAIN-SUFFIX,example.com,VPN', 'MATCH,VPN'],
    };

void main() {
  group('redactConfigForDiagnostics', () {
    test('redacts top-level secrets, including list values', () {
      final out = redactConfigForDiagnostics(_sampleConfig());
      expect(out['secret'], '[REDACTED]');
      expect(out['authentication'], '[REDACTED]');
    });

    test('redacts nested secrets (reality-opts, wireguard peers)', () {
      final out = redactConfigForDiagnostics(_sampleConfig());
      final proxies = out['proxies'] as List;
      final de1 = proxies[0] as Map;
      expect(de1['uuid'], '[REDACTED]');
      final reality = de1['reality-opts'] as Map;
      expect(reality['public-key'], '[REDACTED]');
      expect(reality['short-id'], '[REDACTED]');
      final fi = proxies[2] as Map;
      expect(fi['password'], '[REDACTED]');
      expect(fi['obfs-password'], '[REDACTED]');
      final wg = proxies[3] as Map;
      expect(wg['private-key'], '[REDACTED]');
      final peer = (wg['peers'] as List).first as Map;
      expect(peer['public-key'], '[REDACTED]');
      expect(peer['pre-shared-key'], '[REDACTED]');
    });

    test('no secret value survives anywhere in the serialized output', () {
      final text = jsonEncode(redactConfigForDiagnostics(_sampleConfig()));
      for (final secret in [
        'api-secret-value',
        'user:pass',
        '11111111-2222-3333-4444-555555555555',
        'PUBKEYSECRET',
        'abcd1234',
        'hy2-pass',
        'obfs-secret',
        'WGPRIVATE',
        'PEERPUB',
        'PEERPSK',
        'SECRETTOKEN1234567890',
        'de1.example.net',
        'wg.example.net',
        'peer.example.net',
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('hashes proxy servers stably; distinct servers differ', () {
      final a = redactConfigForDiagnostics(_sampleConfig());
      final b = redactConfigForDiagnostics(_sampleConfig());
      final pa = a['proxies'] as List;
      final pb = b['proxies'] as List;
      final s0 = (pa[0] as Map)['server'] as String;
      final s1 = (pa[1] as Map)['server'] as String;
      final s2 = (pa[2] as Map)['server'] as String;
      expect(s0, matches(RegExp(r'^srv-[0-9a-f]{6}$')));
      expect(s0, s1, reason: 'same server → same token');
      expect(s0, isNot(s2), reason: 'different servers → different tokens');
      expect((pb[0] as Map)['server'], s0, reason: 'stable across runs');
      expect(s0, diagnosticsServerToken('de1.example.net'));
      final peer = ((pa[3] as Map)['peers'] as List).first as Map;
      expect(peer['server'], matches(RegExp(r'^srv-[0-9a-f]{6}$')));
    });

    test('redacts provider url tokens via redactUrls', () {
      final out = redactConfigForDiagnostics(_sampleConfig());
      final sub = (out['proxy-providers'] as Map)['sub'] as Map;
      expect(sub['url'], 'https://panel.example/api/[REDACTED]');
      expect(sub['interval'], 3600);
    });

    test('leaves unrelated keys untouched', () {
      final out = redactConfigForDiagnostics(_sampleConfig());
      expect(out['mixed-port'], 7890);
      final proxies = out['proxies'] as List;
      final de1 = proxies[0] as Map;
      expect(de1['name'], 'Germany 1');
      expect(de1['type'], 'vless');
      expect(de1['port'], 443);
      expect(de1['servername'], 'www.microsoft.com');
      expect((proxies[2] as Map)['sni'], 'fi.example.net');
      expect(out['proxy-groups'], _sampleConfig()['proxy-groups']);
      expect(out['rules'], _sampleConfig()['rules']);
      expect((out['dns'] as Map)['enable'], true);
    });

    test('does not mutate the input map', () {
      final input = _sampleConfig();
      final before = jsonEncode(input);
      redactConfigForDiagnostics(input);
      expect(jsonEncode(input), before);
    });

    test('accepts non-String-keyed nested maps (YAML shape)', () {
      final out = redactConfigForDiagnostics(<String, dynamic>{
        'proxies': [
          <dynamic, dynamic>{'name': 'x', 'password': 'p', 'server': 'h'},
        ],
      });
      final p = (out['proxies'] as List).first as Map;
      expect(p['password'], '[REDACTED]');
      expect(p['server'], diagnosticsServerToken('h'));
    });
  });

  group('redactHeadersForDiagnostics', () {
    test('keeps keys, redacts URL tokens in values', () {
      final out = redactHeadersForDiagnostics({
        'dropweb-cabinet': 'https://cab.example/u/SECRETTOKEN1234567890',
        'profile-title': 'dropweb',
        'subscription-userinfo': 'upload=1; download=2; total=3; expire=4',
      });
      expect(out.keys, [
        'dropweb-cabinet',
        'profile-title',
        'subscription-userinfo',
      ]);
      expect(out['dropweb-cabinet'], 'https://cab.example/u/[REDACTED]');
      expect(out['profile-title'], 'dropweb');
      expect(out['subscription-userinfo'],
          'upload=1; download=2; total=3; expire=4');
    });

    test('masks bare 32+ hex keys outside URLs (dropweb-music)', () {
      final out = redactHeadersForDiagnostics({
        'dropweb-music':
            '9783e8537d15b8f026bfdb0b20db3739,http://meow.example:8090',
        'dropweb-theme': 'fidelity,#29FF76,#000000,#2BFF7A,4',
      });
      expect(out['dropweb-music'], '[REDACTED],http://meow.example:8090');
      expect(out['dropweb-theme'], 'fidelity,#29FF76,#000000,#2BFF7A,4');
    });
  });

  group('buildDiagnosticsText', () {
    test('contains header, redacted url, config and logs sections', () {
      final text = buildDiagnosticsText(
        now: DateTime.utc(2026, 9, 26, 12, 0, 0),
        appVersion: '0.8.8+1',
        isPlayBuild: false,
        isDebug: true,
        androidSdk: 36,
        status: const {'running': true, 'workMode': 'standard'},
        groups: const [
          DiagnosticsGroup(
            name: 'VPN',
            type: 'Selector',
            now: 'Germany 1',
            members: [
              DiagnosticsMember(name: 'Germany 1', delay: 120),
              DiagnosticsMember(name: 'Finland', delay: -1),
              DiagnosticsMember(name: 'Other'),
            ],
          ),
        ],
        headers: const {
          'dropweb-cabinet': 'https://cab.example/u/SECRETTOKEN1234567890',
        },
        profileUrl: 'https://sub.dropweb.org/SECRETTOKEN1234567890',
        lastSetupAt: DateTime.utc(2026, 9, 26, 11, 59, 0),
        effectiveConfig: _sampleConfig(),
        logLines: const [
          'fetch https://panel.example/api/sub/SECRETTOKEN1234567890',
        ],
      );
      expect(text, contains('2026-09-26T12:00:00.000Z'));
      expect(text, contains('0.8.8+1'));
      expect(text, contains('androidSdk: 36'));
      expect(text, contains('--- effective config (redacted) ---'));
      expect(text, contains('--- last 300 logs ---'));
      expect(text, contains('Germany 1: 120 ms'));
      expect(text, contains('Finland: timeout'));
      expect(text, contains('Other: -'));
      expect(text, isNot(contains('SECRETTOKEN1234567890')));
      expect(text, isNot(contains('PUBKEYSECRET')));
      expect(text, contains('"mixed-port": 7890'));
    });

    test('says so when no setup has happened yet', () {
      final text = buildDiagnosticsText(
        now: DateTime.utc(2026),
        appVersion: '1',
        isPlayBuild: true,
        isDebug: false,
        status: const {},
        groups: const [],
        headers: const {},
        logLines: const [],
      );
      expect(text, contains('(no core setup yet)'));
    });
  });

  group('diagnostics files', () {
    test('timestamp is yyyyMMdd-HHmmss', () {
      expect(
        diagnosticsTimestamp(DateTime(2026, 9, 6, 7, 8, 9)),
        '20260906-070809',
      );
    });

    test('prunes oldest timestamped diag files beyond keep', () {
      final names = [
        'diag-20260101-000000.txt',
        'diag-latest.txt',
        'diag-20260103-000000.txt',
        'config-latest.json',
        'diag-20260102-000000.txt',
        'diag-20260105-000000.txt',
        'diag-20260104-000000.txt',
        'diag-20260106-000000.txt',
      ];
      expect(diagFilesToPrune(names, keep: 5), ['diag-20260101-000000.txt']);
      expect(diagFilesToPrune(names, keep: 3), [
        'diag-20260101-000000.txt',
        'diag-20260102-000000.txt',
        'diag-20260103-000000.txt',
      ]);
    });
  });
}
