/// The one-time password Spotify's web player signs its token request with.
///
/// Written out here rather than pulled from a pub package for the same reason
/// the rest of this directory is: the whole algorithm is RFC 4226 plus a
/// base32 decoder, roughly sixty lines, and every published Dart OTP package
/// brings a transitive dependency tree along with it for that. A VPN client
/// shipping on Google Play answers for every line in its lockfile.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 4648 alphabet. Index in this string IS the 5-bit value, which is what
/// makes [decodeBase32] a lookup rather than a table.
const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Decodes an RFC 4648 base32 string into the bytes it stands for.
///
/// Lowercase is accepted and `=` padding is optional, because the secret
/// arrives from a gist maintained by strangers and has already been seen in
/// both shapes. Rejecting an unpadded secret would take the feature down over
/// formatting, which is not a fault worth failing on.
///
/// Any character outside the alphabet throws — a secret with a typo in it
/// would otherwise silently produce a wrong-but-plausible OTP, and the only
/// symptom would be an HTTP 400 from Spotify with no hint as to why.
Uint8List decodeBase32(String input) {
  final normalized = input.toUpperCase().replaceAll('=', '').trim();
  final bytes = BytesBuilder();

  // The classic bit accumulator: shift each 5-bit group in from the right and
  // emit a byte whenever eight bits have piled up. Leftover bits at the end
  // are padding by construction and are dropped.
  var buffer = 0;
  var bitsHeld = 0;
  for (final unit in normalized.codeUnits) {
    final value = _base32Alphabet.indexOf(String.fromCharCode(unit));
    if (value < 0) {
      throw FormatException('not base32', input);
    }
    buffer = (buffer << 5) | value;
    bitsHeld += 5;
    if (bitsHeld >= 8) {
      bitsHeld -= 8;
      bytes.addByte((buffer >> bitsHeld) & 0xff);
    }
  }

  return bytes.takeBytes();
}

/// The TOTP for [base32Secret] at [timestampSeconds].
///
/// [timestampSeconds] is a required argument rather than a default of "now"
/// on purpose. Spotify rejects an OTP computed against the device clock the
/// moment that clock has drifted, and a phone that has been off for a week is
/// exactly the phone somebody signs in from. The caller is made to say which
/// clock it is using, so the answer can be Spotify's own `server-time` rather
/// than whatever the handset believes.
String spotifyTotp(
  String base32Secret, {
  required int timestampSeconds,
  int digits = 6,
  int period = 30,
}) {
  final counter = timestampSeconds ~/ period;

  // Big-endian eight-byte counter, per RFC 4226 §5.1. Written a byte at a
  // time instead of through ByteData.setUint64: on the web that method is
  // unavailable, and while this app does not ship a web target today, an
  // algorithm this self-contained should not be the reason it cannot.
  final message = Uint8List(8);
  var remaining = counter;
  for (var i = 7; i >= 0; i--) {
    message[i] = remaining & 0xff;
    remaining >>= 8;
  }

  final digest =
      Hmac(sha1, decodeBase32(base32Secret)).convert(message).bytes;

  // Dynamic truncation: the low nibble of the last byte picks where in the
  // digest the four significant bytes start, and the top bit is masked off so
  // the result is read as a positive 31-bit integer.
  final offset = digest[digest.length - 1] & 0x0f;
  final binary = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);

  // Left-padded, because the modulo drops leading zeros and Spotify compares
  // the string, not the number. A code of "081804" sent as "81804" is simply
  // wrong, and it would fail on roughly one attempt in ten — often enough to
  // read as flakiness rather than as a bug.
  return (binary % _pow10(digits)).toString().padLeft(digits, '0');
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
