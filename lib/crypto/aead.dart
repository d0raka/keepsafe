import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/constants.dart';
import 'key_material.dart';

/// Output of an AES-256-GCM encryption: the random nonce, the ciphertext, and
/// the 128-bit authentication tag (kept separate per the `cryptography` API).
final class AeadResult {
  const AeadResult({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

/// Thin wrapper over AES-256-GCM authenticated encryption.
///
/// GCM authenticates both the ciphertext and any [aad] (additional authenticated
/// data). We bind the vault header as AAD so the KDF parameters, version, and
/// nonce cannot be tampered with without failing decryption.
final class Aead {
  const Aead._();

  static final AesGcm _algorithm = AesGcm.with256bits();

  static Future<AeadResult> encrypt({
    required KeyMaterial key,
    required Uint8List plaintext,
    required Uint8List aad,
    required Uint8List nonce,
  }) async {
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: key.toSecretKey(),
      nonce: nonce,
      aad: aad,
    );
    return AeadResult(
      nonce: Uint8List.fromList(box.nonce),
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  /// Decrypts and verifies. Returns the plaintext, or `null` when the
  /// authentication tag does not verify — i.e. wrong key (wrong master
  /// password) or the file/AAD was tampered with.
  static Future<Uint8List?> decrypt({
    required KeyMaterial key,
    required Uint8List nonce,
    required Uint8List cipherText,
    required Uint8List mac,
    required Uint8List aad,
  }) async {
    if (nonce.length != CryptoParams.nonceLengthBytes ||
        mac.length != CryptoParams.macLengthBytes) {
      return null;
    }
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    try {
      final clear = await _algorithm.decrypt(
        box,
        secretKey: key.toSecretKey(),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }
}
