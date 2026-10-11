import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Задача ALTCHA proof-of-work из `GET /cabinet/auth/email/challenge`.
/// Бэкенд требует её решение перед отправкой кода, чтобы боты не жгли
/// почтовую квоту.
class PowChallenge {
  const PowChallenge({
    required this.algorithm,
    required this.challenge,
    required this.salt,
    required this.signature,
    required this.maxNumber,
  });

  factory PowChallenge.fromJson(Map<String, dynamic> json) => PowChallenge(
        algorithm: json['algorithm'] as String,
        challenge: json['challenge'] as String,
        salt: json['salt'] as String,
        signature: json['signature'] as String,
        maxNumber: (json['maxnumber'] as num).toInt(),
      );

  final String algorithm;
  final String challenge;

  /// Соль вместе с `?expires=<ts>` — сервер хэширует её целиком.
  final String salt;
  final String signature;
  final int maxNumber;
}

class PowSolution {
  const PowSolution({required this.challenge, required this.number});

  final PowChallenge challenge;
  final int number;

  /// Ровно поле `pow` тела `/email/code/request` (схема PowSolution бэкенда).
  Map<String, dynamic> toJson() => {
        'algorithm': challenge.algorithm,
        'challenge': challenge.challenge,
        'number': number,
        'salt': challenge.salt,
        'signature': challenge.signature,
      };
}

class PowUnsolvableException implements Exception {
  const PowUnsolvableException(this.message);

  final String message;

  @override
  String toString() => 'PowUnsolvableException: $message';
}

/// Хэш ALTCHA так, как его считает бэкенд: sha256(f'{salt}{number}') в hex.
String powHash(String salt, int number) =>
    sha256.convert(utf8.encode('$salt$number')).toString();

/// Перебор number в [0, maxNumber] (граница включительно, как в бэкенде),
/// пока sha256(salt + number) не совпадёт с challenge.
PowSolution solvePowChallenge(PowChallenge challenge) {
  if (challenge.algorithm != 'SHA-256') {
    throw PowUnsolvableException(
        'unsupported algorithm ${challenge.algorithm}');
  }
  final target = challenge.challenge.toLowerCase();
  for (var number = 0; number <= challenge.maxNumber; number++) {
    if (powHash(challenge.salt, number) == target) {
      return PowSolution(challenge: challenge, number: number);
    }
  }
  throw const PowUnsolvableException('no number within maxnumber');
}

/// До 50 000 sha256 — это десятки-сотни миллисекунд на слабом телефоне,
/// поэтому перебор уходит в отдельный изолят, чтобы не подвешивать кадры.
Future<PowSolution> solvePowInIsolate(PowChallenge challenge) =>
    Isolate.run(() => solvePowChallenge(challenge));
