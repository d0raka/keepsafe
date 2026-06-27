import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/core/result.dart';
import 'package:keepsafe/crypto/aead.dart';
import 'package:keepsafe/crypto/kdf.dart';
import 'package:keepsafe/crypto/vault_crypto.dart';

void main() {
  const fast = Argon2idParams(memoryKiB: 256, iterations: 1, parallelism: 1);
  final secret = Uint8List.fromList(utf8.encode('{"items":["my password"]}'));

  Future<VaultEnvelope> newVault(String pw) async =>
      (await VaultCrypto.createNew(
              masterPassword: pw, plaintext: secret, params: fast))
          .envelope;

  test('createNew then openWithPassword round-trips', () async {
    final env = await newVault('master');
    final opened =
        await VaultCrypto.openWithPassword(envelope: env, password: 'master');
    expect(opened.isOk, isTrue);
    expect(opened.value.plaintext, equals(secret));
    expect(opened.value.migrated, isFalse);
    opened.value.vek.destroy();
  });

  test('wrong master password is rejected', () async {
    final env = await newVault('master');
    final opened =
        await VaultCrypto.openWithPassword(envelope: env, password: 'nope');
    expect(opened.errorOrNull, VaultError.wrongPasswordOrTampered);
  });

  test('envelope serialises and parses back', () async {
    final env = await newVault('master');
    final parsed = VaultEnvelope.fromBytes(env.toBytes());
    expect(parsed.isOk, isTrue);
    final opened = await VaultCrypto.openWithPassword(
        envelope: parsed.value, password: 'master');
    expect(opened.value.plaintext, equals(secret));
    opened.value.vek.destroy();
  });

  test('flipping a ciphertext byte is detected', () async {
    final env = await newVault('master');
    final tampered = env.copyWithData(
        env.dataNonce, env.dataMac, Uint8List.fromList(env.ciphertext)..[0] ^= 0xFF);
    final opened = await VaultCrypto.openWithPassword(
        envelope: tampered, password: 'master');
    expect(opened.errorOrNull, VaultError.wrongPasswordOrTampered);
  });

  group('recovery key', () {
    test('opens with the recovery code', () async {
      var env = await newVault('master');
      final vek =
          (await VaultCrypto.openWithPassword(envelope: env, password: 'master'))
              .value
              .vek;
      env = await VaultCrypto.addRecovery(
          envelope: env, vek: vek, recoveryCode: 'ABCDE-FGHJK', params: fast);
      vek.destroy();

      final opened = await VaultCrypto.openWithRecovery(
          envelope: env, recoveryCode: 'abcde-fghjk'); // case/format-insensitive
      expect(opened.isOk, isTrue);
      expect(opened.value.plaintext, equals(secret));
      opened.value.vek.destroy();
    });

    test('wrong recovery code is rejected', () async {
      var env = await newVault('master');
      final vek =
          (await VaultCrypto.openWithPassword(envelope: env, password: 'master'))
              .value
              .vek;
      env = await VaultCrypto.addRecovery(
          envelope: env, vek: vek, recoveryCode: 'RIGHT-CODE', params: fast);
      vek.destroy();
      final opened = await VaultCrypto.openWithRecovery(
          envelope: env, recoveryCode: 'WRONG-CODE');
      expect(opened.errorOrNull, VaultError.wrongPasswordOrTampered);
    });

    test('no recovery slot rejects recovery attempts', () async {
      final env = await newVault('master');
      final opened =
          await VaultCrypto.openWithRecovery(envelope: env, recoveryCode: 'X');
      expect(opened.isErr, isTrue);
    });
  });

  test('changing master password keeps VEK, recovery, and biometric key valid',
      () async {
    var env = await newVault('oldpw');
    final open1 =
        await VaultCrypto.openWithPassword(envelope: env, password: 'oldpw');
    final vek = open1.value.vek;
    final vekBytes = Uint8List.fromList(vek.bytes); // simulate biometric cache
    env = await VaultCrypto.addRecovery(
        envelope: env, vek: vek, recoveryCode: 'REC-CODE', params: fast);
    env = await VaultCrypto.rewrapMaster(
        envelope: env, vek: vek, newPassword: 'newpw', params: fast);
    vek.destroy();

    expect((await VaultCrypto.openWithPassword(envelope: env, password: 'oldpw'))
        .isErr, isTrue);
    final n = await VaultCrypto.openWithPassword(envelope: env, password: 'newpw');
    expect(n.value.plaintext, equals(secret));
    n.value.vek.destroy();
    final r = await VaultCrypto.openWithRecovery(
        envelope: env, recoveryCode: 'REC-CODE');
    expect(r.value.plaintext, equals(secret));
    r.value.vek.destroy();
    final b = await VaultCrypto.openWithKey(envelope: env, vekBytes: vekBytes);
    expect(b.value.plaintext, equals(secret)); // cached VEK still works
    b.value.vek.destroy();
  });

  test('reads and migrates a legacy v1 vault', () async {
    final v1Bytes = await _buildV1Vault(
        password: 'legacy', plaintext: secret, params: fast);
    final parsed = VaultEnvelope.fromBytes(v1Bytes);
    expect(parsed.value.isLegacy, isTrue);

    final opened = await VaultCrypto.openWithPassword(
        envelope: parsed.value, password: 'legacy');
    expect(opened.isOk, isTrue);
    expect(opened.value.plaintext, equals(secret));
    expect(opened.value.migrated, isTrue);

    // The migrated (v2) envelope re-opens with the same password.
    final reopened = await VaultCrypto.openWithPassword(
        envelope: VaultEnvelope.fromBytes(opened.value.envelope.toBytes()).value,
        password: 'legacy');
    expect(reopened.value.plaintext, equals(secret));
    opened.value.vek.destroy();
    reopened.value.vek.destroy();
  });
}

/// Reproduces the historical v1 on-disk format for migration testing.
Future<Uint8List> _buildV1Vault({
  required String password,
  required Uint8List plaintext,
  required Argon2idParams params,
}) async {
  final salt = Uint8List.fromList(List.generate(16, (i) => i + 3));
  final nonce = Uint8List.fromList(List.generate(12, (i) => i + 5));
  final key = await Kdf.deriveKey(password: password, salt: salt, params: params);
  final kdf = {
    'algorithm': 'argon2id',
    'salt': base64.encode(salt),
    'memoryKiB': params.memoryKiB,
    'iterations': params.iterations,
    'parallelism': params.parallelism,
  };
  final aad = Uint8List.fromList(utf8.encode(jsonEncode({
    'format': 'keepsafe-vault',
    'version': 1,
    'kdf': kdf,
    'cipher': {'algorithm': 'aes-256-gcm', 'nonce': base64.encode(nonce)},
  })));
  final res =
      await Aead.encrypt(key: key, plaintext: plaintext, aad: aad, nonce: nonce);
  key.destroy();
  return Uint8List.fromList(utf8.encode(jsonEncode({
    'format': 'keepsafe-vault',
    'version': 1,
    'kdf': kdf,
    'cipher': {
      'algorithm': 'aes-256-gcm',
      'nonce': base64.encode(res.nonce),
      'mac': base64.encode(res.mac),
    },
    'ciphertext': base64.encode(res.cipherText),
  })));
}
