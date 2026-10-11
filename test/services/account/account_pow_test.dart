import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dropweb/services/account/account_pow.dart';
import 'package:flutter_test/flutter_test.dart';

String _hash(String salt, int number) =>
    sha256.convert(utf8.encode('$salt$number')).toString();

void main() {
  const salt = '0123456789abcdef01234567?expires=1791676800';

  test('находит число, из которого сервер построил challenge', () {
    final challenge = PowChallenge(
      algorithm: 'SHA-256',
      challenge: _hash(salt, 31337),
      salt: salt,
      signature: 'f' * 64,
      maxNumber: 50000,
    );

    final solution = solvePowChallenge(challenge);

    expect(solution.number, 31337);
    expect(solution.toJson(), {
      'algorithm': 'SHA-256',
      'challenge': challenge.challenge,
      'number': 31337,
      'salt': salt,
      'signature': 'f' * 64,
    });
  });

  test('граница maxnumber включительно', () {
    final challenge = PowChallenge(
      algorithm: 'SHA-256',
      challenge: _hash(salt, 500),
      salt: salt,
      signature: 'a' * 64,
      maxNumber: 500,
    );
    expect(solvePowChallenge(challenge).number, 500);
  });

  test('число за пределами maxnumber не ищется — ошибка', () {
    final challenge = PowChallenge(
      algorithm: 'SHA-256',
      challenge: _hash(salt, 501),
      salt: salt,
      signature: 'a' * 64,
      maxNumber: 500,
    );
    expect(
      () => solvePowChallenge(challenge),
      throwsA(isA<PowUnsolvableException>()),
    );
  });

  test('неизвестный алгоритм отклоняется сразу', () {
    final challenge = PowChallenge(
      algorithm: 'SHA-512',
      challenge: _hash(salt, 1),
      salt: salt,
      signature: 'a' * 64,
      maxNumber: 10,
    );
    expect(
      () => solvePowChallenge(challenge),
      throwsA(isA<PowUnsolvableException>()),
    );
  });

  test('fromJson читает живой ответ /challenge', () {
    final parsed = PowChallenge.fromJson({
      'algorithm': 'SHA-256',
      'challenge': 'c' * 64,
      'salt': salt,
      'signature': 'd' * 64,
      'maxnumber': 50000,
    });
    expect(parsed.maxNumber, 50000);
    expect(parsed.salt, salt);
  });

  test('solvePowInIsolate решает вне UI-потока', () async {
    final challenge = PowChallenge(
      algorithm: 'SHA-256',
      challenge: _hash(salt, 42),
      salt: salt,
      signature: 'b' * 64,
      maxNumber: 50000,
    );
    final solution = await solvePowInIsolate(challenge);
    expect(solution.number, 42);
  });
}
