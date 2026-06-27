import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/crypto/aead.dart';
import 'package:keepsafe/crypto/key_material.dart';

void main() {
  KeyMaterial keyOf(int fill) =>
      KeyMaterial(Uint8List.fromList(List.filled(32, fill)));
  Uint8List nonce() => Uint8List.fromList(List.generate(12, (i) => i + 1));
  final plaintext = Uint8List.fromList(utf8.encode('top secret payload'));
  final aad = Uint8List.fromList(utf8.encode('authenticated header'));

  test('AES-256-GCM round-trips the plaintext', () async {
    final enc = await Aead.encrypt(
        key: keyOf(7), plaintext: plaintext, aad: aad, nonce: nonce());
    expect(enc.nonce, hasLength(12));
    expect(enc.mac, hasLength(16));
    expect(enc.cipherText, isNot(equals(plaintext)));

    final dec = await Aead.decrypt(
      key: keyOf(7),
      nonce: enc.nonce,
      cipherText: enc.cipherText,
      mac: enc.mac,
      aad: aad,
    );
    expect(dec, equals(plaintext));
  });

  test('wrong key fails authentication (returns null)', () async {
    final enc = await Aead.encrypt(
        key: keyOf(7), plaintext: plaintext, aad: aad, nonce: nonce());
    final dec = await Aead.decrypt(
      key: keyOf(8), // different key
      nonce: enc.nonce,
      cipherText: enc.cipherText,
      mac: enc.mac,
      aad: aad,
    );
    expect(dec, isNull);
  });

  test('tampered ciphertext fails authentication', () async {
    final enc = await Aead.encrypt(
        key: keyOf(7), plaintext: plaintext, aad: aad, nonce: nonce());
    final tampered = Uint8List.fromList(enc.cipherText);
    tampered[0] ^= 0xFF;
    final dec = await Aead.decrypt(
      key: keyOf(7),
      nonce: enc.nonce,
      cipherText: tampered,
      mac: enc.mac,
      aad: aad,
    );
    expect(dec, isNull);
  });

  test('tampered AAD (header) fails authentication', () async {
    final enc = await Aead.encrypt(
        key: keyOf(7), plaintext: plaintext, aad: aad, nonce: nonce());
    final wrongAad = Uint8List.fromList(utf8.encode('different header'));
    final dec = await Aead.decrypt(
      key: keyOf(7),
      nonce: enc.nonce,
      cipherText: enc.cipherText,
      mac: enc.mac,
      aad: wrongAad,
    );
    expect(dec, isNull);
  });

  test('malformed nonce/mac lengths are rejected', () async {
    final enc = await Aead.encrypt(
        key: keyOf(7), plaintext: plaintext, aad: aad, nonce: nonce());
    final dec = await Aead.decrypt(
      key: keyOf(7),
      nonce: Uint8List(4), // wrong length
      cipherText: enc.cipherText,
      mac: enc.mac,
      aad: aad,
    );
    expect(dec, isNull);
  });
}
