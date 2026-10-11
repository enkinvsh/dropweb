import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Детерминированный ключ маяка для тестов: seed из одного повторённого байта.
class TestBeaconKey {
  TestBeaconKey(this.seedByte);

  final int seedByte;

  List<int> get seed => List<int>.filled(32, seedByte);

  Future<SimpleKeyPair> get _keyPair => Ed25519().newKeyPairFromSeed(seed);

  Future<String> publicKeyBase64() async =>
      base64.encode((await (await _keyPair).extractPublicKey()).bytes);

  /// Документ маяка над [payloadBytes] как есть — чтобы тесты могли подписать
  /// и заведомо кривой payload.
  Future<String> signBytes(List<int> payloadBytes) async {
    final signature =
        await Ed25519().sign(payloadBytes, keyPair: await _keyPair);
    return json.encode({
      'payload': base64.encode(payloadBytes),
      'sig': base64.encode(signature.bytes),
    });
  }

  Future<String> sign(Map<String, Object?> payload) =>
      signBytes(utf8.encode(json.encode(payload)));
}
