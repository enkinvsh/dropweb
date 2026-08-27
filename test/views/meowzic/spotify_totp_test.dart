import 'dart:convert';

import 'package:dropweb/views/meowzic/spotify/totp.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TOTP is the one part of the Spotify handshake with no error message.
///
/// Everything else in the flow fails loudly — a dead socket, a 403, a missing
/// cookie. A wrong OTP comes back as a bare HTTP 400 "Unauthorized request",
/// which reads identically to an expired cookie and to a rotated secret. So
/// the algorithm is pinned to the published vectors here: when sign-in breaks
/// in the field, this test passing is what rules the arithmetic out and points
/// the search at the cookie or the secret instead.
void main() {
  // RFC 6238 Appendix B, the SHA-1 rows. The published vectors are eight
  // digits, so `digits: 8` here — Spotify itself asks for six, and that width
  // is exercised by the code path, not by a magic number of its own.
  group('spotifyTotp — RFC 6238 SHA-1 vectors', () {
    // The RFC's seed is the ASCII string "12345678901234567890"; this is that
    // string in base32, which is the form the function takes.
    const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    const vectors = <int, String>{
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
      20000000000: '65353130',
    };

    for (final vector in vectors.entries) {
      test('t=${vector.key} -> ${vector.value}', () {
        expect(
          spotifyTotp(secret, timestampSeconds: vector.key, digits: 8),
          vector.value,
        );
      });
    }
  });

  group('decodeBase32', () {
    // A secret taken live off Spotify's nuance feed, not a synthetic one. It
    // is 96 characters of base32 that decode to 60 bytes of ASCII digits —
    // an unusual shape, and one an over-eager decoder gets wrong by dropping
    // or inventing a trailing byte. That slip would still yield a six-digit
    // OTP, just never the right one.
    const liveSecret = 'GM3TMMJTGYZTQNZVGM4DINJZHA4TGOBYGMZTCMRTGEYDSMJRHE4T'
        'EOBUG4YTCMRUGQ4DQOJUGQYTAMRRGA2TCMJSHE3TCMBY';

    test('decodes the live Spotify secret to its 60 ASCII bytes', () {
      final bytes = decodeBase32(liveSecret);

      expect(bytes, hasLength(60));
      expect(
        utf8.decode(bytes),
        '376136387538459893883312310911992847112448894410210511297108',
      );
    });

    test('accepts lowercase and missing padding', () {
      expect(decodeBase32('mzxw6==='), decodeBase32('MZXW6'));
    });

    test('rejects a character outside the alphabet', () {
      expect(() => decodeBase32('MZXW6!'), throwsFormatException);
    });
  });
}
