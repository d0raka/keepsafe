import 'dart:convert';
import 'dart:typed_data';

import '../core/constants.dart';
import '../core/result.dart';
import '../core/secure_random.dart';
import 'aead.dart';
import 'kdf.dart';
import 'key_material.dart';
import 'recovery_key.dart';

/// One wrapped copy of the Vault Encryption Key (VEK): the VEK encrypted under a
/// key derived from a secret (the master password or a recovery key).
final class KeySlot {
  const KeySlot({
    required this.salt,
    required this.nonce,
    required this.wrapped,
    required this.mac,
  });

  final Uint8List salt; // Argon2id salt for this slot's KEK
  final Uint8List nonce; // AES-GCM nonce
  final Uint8List wrapped; // AES-GCM ciphertext of the VEK
  final Uint8List mac; // AES-GCM tag

  Map<String, Object?> toJson() => {
        'salt': base64.encode(salt),
        'nonce': base64.encode(nonce),
        'ct': base64.encode(wrapped),
        'mac': base64.encode(mac),
      };

  factory KeySlot.fromJson(Map<dynamic, dynamic> j) => KeySlot(
        salt: base64.decode(j['salt'] as String),
        nonce: base64.decode(j['nonce'] as String),
        wrapped: base64.decode(j['ct'] as String),
        mac: base64.decode(j['mac'] as String),
      );
}

/// On-disk `.vault` envelope. v2 stores a random VEK wrapped by a master-password
/// KEK (and optionally a recovery-key KEK); the vault data is encrypted under the
/// VEK. v1 (legacy) encrypted the data directly with the master-derived key — it
/// is still read and migrated to v2 on unlock.
final class VaultEnvelope {
  const VaultEnvelope({
    required this.version,
    required this.params,
    required this.dataNonce,
    required this.dataMac,
    required this.ciphertext,
    this.v1Salt,
    this.master,
    this.recovery,
  });

  factory VaultEnvelope.v2({
    required Argon2idParams params,
    required KeySlot master,
    KeySlot? recovery,
    required Uint8List dataNonce,
    required Uint8List dataMac,
    required Uint8List ciphertext,
  }) =>
      VaultEnvelope(
        version: VaultFormat.formatVersion,
        params: params,
        master: master,
        recovery: recovery,
        dataNonce: dataNonce,
        dataMac: dataMac,
        ciphertext: ciphertext,
      );

  final int version;
  final Argon2idParams params;
  final Uint8List dataNonce;
  final Uint8List dataMac;
  final Uint8List ciphertext;
  final Uint8List? v1Salt; // v1 only
  final KeySlot? master; // v2 only
  final KeySlot? recovery; // v2 only

  bool get hasRecovery => recovery != null;
  bool get isLegacy => version == VaultFormat.legacyFormatVersion;

  /// AAD binding the cost params + version to the v2 data ciphertext.
  Uint8List aadBytes() => Uint8List.fromList(utf8.encode(jsonEncode({
        'v': version,
        'm': params.memoryKiB,
        'i': params.iterations,
        'p': params.parallelism,
      })));

  /// Reconstructs the exact v1 header that was used as AAD, so legacy files
  /// still decrypt. Must match the historical v1 serialisation byte-for-byte.
  Uint8List v1AadBytes() => Uint8List.fromList(utf8.encode(jsonEncode({
        'format': VaultFormat.formatId,
        'version': VaultFormat.legacyFormatVersion,
        'kdf': {
          'algorithm': CryptoParams.kdfAlgorithmId,
          'salt': base64.encode(v1Salt!),
          'memoryKiB': params.memoryKiB,
          'iterations': params.iterations,
          'parallelism': params.parallelism,
        },
        'cipher': {
          'algorithm': CryptoParams.cipherAlgorithmId,
          'nonce': base64.encode(dataNonce),
        },
      })));

  VaultEnvelope copyWithData(Uint8List nonce, Uint8List mac, Uint8List ct) =>
      VaultEnvelope.v2(
          params: params,
          master: master!,
          recovery: recovery,
          dataNonce: nonce,
          dataMac: mac,
          ciphertext: ct);

  VaultEnvelope copyWithMaster(KeySlot m) => VaultEnvelope.v2(
      params: params,
      master: m,
      recovery: recovery,
      dataNonce: dataNonce,
      dataMac: dataMac,
      ciphertext: ciphertext);

  VaultEnvelope withRecovery(KeySlot? r) => VaultEnvelope.v2(
      params: params,
      master: master!,
      recovery: r,
      dataNonce: dataNonce,
      dataMac: dataMac,
      ciphertext: ciphertext);

  /// Always serialises as the current (v2) format.
  Uint8List toBytes() {
    final map = <String, Object?>{
      'format': VaultFormat.formatId,
      'version': VaultFormat.formatVersion,
      'kdf': {
        'algorithm': CryptoParams.kdfAlgorithmId,
        'memoryKiB': params.memoryKiB,
        'iterations': params.iterations,
        'parallelism': params.parallelism,
      },
      'master': master!.toJson(),
      'recovery': recovery?.toJson(),
      'cipher': {'algorithm': CryptoParams.cipherAlgorithmId},
      'data': {
        'nonce': base64.encode(dataNonce),
        'mac': base64.encode(dataMac),
      },
      'ciphertext': base64.encode(ciphertext),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static Result<VaultEnvelope> fromBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['format'] != VaultFormat.formatId) {
        return const Err(VaultError.notAVault);
      }
      final version = decoded['version'];
      if (version is! int) return const Err(VaultError.notAVault);

      final kdf = decoded['kdf'] as Map;
      final params = Argon2idParams(
        memoryKiB: kdf['memoryKiB'] as int,
        iterations: kdf['iterations'] as int,
        parallelism: kdf['parallelism'] as int,
      );

      if (version == VaultFormat.legacyFormatVersion) {
        final cipher = decoded['cipher'] as Map;
        return Ok(VaultEnvelope(
          version: 1,
          params: params,
          v1Salt: base64.decode(kdf['salt'] as String),
          dataNonce: base64.decode(cipher['nonce'] as String),
          dataMac: base64.decode(cipher['mac'] as String),
          ciphertext: base64.decode(decoded['ciphertext'] as String),
        ));
      } else if (version == VaultFormat.formatVersion) {
        final data = decoded['data'] as Map;
        final rec = decoded['recovery'];
        return Ok(VaultEnvelope.v2(
          params: params,
          master: KeySlot.fromJson(decoded['master'] as Map),
          recovery: rec == null ? null : KeySlot.fromJson(rec as Map),
          dataNonce: base64.decode(data['nonce'] as String),
          dataMac: base64.decode(data['mac'] as String),
          ciphertext: base64.decode(decoded['ciphertext'] as String),
        ));
      }
      return const Err(VaultError.unsupportedVersion);
    } catch (_) {
      return const Err(VaultError.notAVault);
    }
  }
}

/// Result of opening a vault: the plaintext, the live VEK (for saves), the
/// (possibly migrated) envelope, and whether a v1→v2 migration occurred.
final class OpenResult {
  const OpenResult({
    required this.plaintext,
    required this.vek,
    required this.envelope,
    required this.migrated,
  });

  final Uint8List plaintext;
  final KeyMaterial vek;
  final VaultEnvelope envelope;
  final bool migrated;
}

/// Key-wrapping vault cryptography (envelope v2).
final class VaultCrypto {
  const VaultCrypto._();

  static final Uint8List _noAad = Uint8List(0);

  // --- creation ---

  /// Creates a fresh vault: random VEK, wrapped by the master password.
  static Future<({VaultEnvelope envelope, KeyMaterial vek})> createNew({
    required String masterPassword,
    required Uint8List plaintext,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final vek = SecureRandom.bytes(CryptoParams.keyLengthBytes);
    final master = await _wrap(vek, masterPassword,
        SecureRandom.bytes(CryptoParams.saltLengthBytes), params);
    final base = VaultEnvelope.v2(
      params: params,
      master: master,
      dataNonce: Uint8List(0),
      dataMac: Uint8List(0),
      ciphertext: Uint8List(0),
    );
    final envelope = await _reEncrypt(base, vek, plaintext);
    return (envelope: envelope, vek: KeyMaterial(Uint8List.fromList(vek)));
  }

  // --- opening ---

  static Future<Result<OpenResult>> openWithPassword({
    required VaultEnvelope envelope,
    required String password,
  }) async {
    if (envelope.isLegacy) return _openAndMigrateV1(envelope, password);

    final vek = await _unwrap(envelope.master!, password, envelope.params);
    if (vek == null) return const Err(VaultError.wrongPasswordOrTampered);
    return _decryptData(envelope, vek, migrated: false);
  }

  static Future<Result<OpenResult>> openWithRecovery({
    required VaultEnvelope envelope,
    required String recoveryCode,
  }) async {
    final slot = envelope.recovery;
    if (slot == null) return const Err(VaultError.wrongPasswordOrTampered);
    final vek =
        await _unwrap(slot, RecoveryKey.normalize(recoveryCode), envelope.params);
    if (vek == null) return const Err(VaultError.wrongPasswordOrTampered);
    return _decryptData(envelope, vek, migrated: false);
  }

  /// Decrypts using a cached VEK (biometric quick-unlock); no KDF.
  static Future<Result<OpenResult>> openWithKey({
    required VaultEnvelope envelope,
    required Uint8List vekBytes,
  }) async {
    return _decryptData(envelope, Uint8List.fromList(vekBytes), migrated: false);
  }

  // --- mutation (all keep the same VEK) ---

  /// Re-encrypts the vault data under the existing VEK with a fresh nonce.
  static Future<VaultEnvelope> reEncrypt({
    required VaultEnvelope envelope,
    required KeyMaterial vek,
    required Uint8List plaintext,
  }) =>
      _reEncrypt(envelope, vek.bytes, plaintext);

  /// Re-wraps the VEK under a new master password (recovery slot untouched).
  static Future<VaultEnvelope> rewrapMaster({
    required VaultEnvelope envelope,
    required KeyMaterial vek,
    required String newPassword,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final slot = await _wrap(vek.bytes, newPassword,
        SecureRandom.bytes(CryptoParams.saltLengthBytes), params);
    return envelope.copyWithMaster(slot);
  }

  /// Adds (or replaces) the recovery slot wrapping the VEK under [recoveryCode].
  static Future<VaultEnvelope> addRecovery({
    required VaultEnvelope envelope,
    required KeyMaterial vek,
    required String recoveryCode,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final slot = await _wrap(vek.bytes, RecoveryKey.normalize(recoveryCode),
        SecureRandom.bytes(CryptoParams.saltLengthBytes), params);
    return envelope.withRecovery(slot);
  }

  static VaultEnvelope removeRecovery(VaultEnvelope envelope) =>
      envelope.withRecovery(null);

  // --- internals ---

  static Future<Result<OpenResult>> _decryptData(
      VaultEnvelope envelope, Uint8List vek,
      {required bool migrated}) async {
    final aad = envelope.isLegacy ? envelope.v1AadBytes() : envelope.aadBytes();
    final pt = await Aead.decrypt(
      key: KeyMaterial(Uint8List.fromList(vek)),
      nonce: envelope.dataNonce,
      cipherText: envelope.ciphertext,
      mac: envelope.dataMac,
      aad: aad,
    );
    if (pt == null) return const Err(VaultError.wrongPasswordOrTampered);
    return Ok(OpenResult(
      plaintext: pt,
      vek: KeyMaterial(vek),
      envelope: envelope,
      migrated: migrated,
    ));
  }

  /// Decrypts a v1 vault and re-packages it as v2 (reusing the v1-derived key as
  /// the master KEK with the original salt, so no password re-prompt is needed).
  static Future<Result<OpenResult>> _openAndMigrateV1(
      VaultEnvelope envelope, String password) async {
    final kek = await Kdf.deriveKey(
        password: password, salt: envelope.v1Salt!, params: envelope.params);
    try {
      final pt = await Aead.decrypt(
        key: kek,
        nonce: envelope.dataNonce,
        cipherText: envelope.ciphertext,
        mac: envelope.dataMac,
        aad: envelope.v1AadBytes(),
      );
      if (pt == null) return const Err(VaultError.wrongPasswordOrTampered);

      final vek = SecureRandom.bytes(CryptoParams.keyLengthBytes);
      final master = await _wrapWithKek(vek, kek, envelope.v1Salt!);
      final base = VaultEnvelope.v2(
        params: envelope.params,
        master: master,
        dataNonce: Uint8List(0),
        dataMac: Uint8List(0),
        ciphertext: Uint8List(0),
      );
      final migratedEnv = await _reEncrypt(base, vek, pt);
      return Ok(OpenResult(
        plaintext: pt,
        vek: KeyMaterial(Uint8List.fromList(vek)),
        envelope: migratedEnv,
        migrated: true,
      ));
    } finally {
      kek.destroy();
    }
  }

  static Future<VaultEnvelope> _reEncrypt(
      VaultEnvelope base, Uint8List vek, Uint8List plaintext) async {
    final result = await Aead.encrypt(
      key: KeyMaterial(Uint8List.fromList(vek)),
      plaintext: plaintext,
      aad: base.aadBytes(),
      nonce: SecureRandom.bytes(CryptoParams.nonceLengthBytes),
    );
    return base.copyWithData(result.nonce, result.mac, result.cipherText);
  }

  static Future<KeySlot> _wrap(
      Uint8List vek, String secret, Uint8List salt, Argon2idParams params) async {
    final kek = await Kdf.deriveKey(password: secret, salt: salt, params: params);
    try {
      // MUST await before the finally destroys the kek buffer — SecretKey aliases
      // it, so zeroing early would encrypt under an all-zero key.
      return await _wrapWithKek(vek, kek, salt);
    } finally {
      kek.destroy();
    }
  }

  static Future<KeySlot> _wrapWithKek(
      Uint8List vek, KeyMaterial kek, Uint8List salt) async {
    final result = await Aead.encrypt(
      key: kek,
      plaintext: vek,
      aad: _noAad,
      nonce: SecureRandom.bytes(CryptoParams.nonceLengthBytes),
    );
    return KeySlot(
        salt: salt,
        nonce: result.nonce,
        wrapped: result.cipherText,
        mac: result.mac);
  }

  static Future<Uint8List?> _unwrap(
      KeySlot slot, String secret, Argon2idParams params) async {
    final kek =
        await Kdf.deriveKey(password: secret, salt: slot.salt, params: params);
    try {
      return await Aead.decrypt(
        key: kek,
        nonce: slot.nonce,
        cipherText: slot.wrapped,
        mac: slot.mac,
        aad: _noAad,
      );
    } finally {
      kek.destroy();
    }
  }
}
