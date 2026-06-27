import 'dart:typed_data';

import '../core/result.dart';
import '../core/secure_random.dart';
import '../crypto/kdf.dart';
import '../crypto/key_material.dart';
import '../crypto/recovery_key.dart';
import '../crypto/vault_crypto.dart';
import 'models/vault.dart';
import 'models/vault_item.dart';
import 'vault_file_store.dart';

/// Owns the unlocked vault state and mediates all encrypted persistence.
///
/// While unlocked it retains the decrypted Vault Encryption Key (VEK) and the
/// current [VaultEnvelope] (with its wrapped-key slots), so data saves and
/// password/recovery changes never re-run the slow KDF more than necessary.
/// [lock] zeroizes the VEK.
final class VaultRepository {
  VaultRepository({
    this._store = const VaultFileStore(),
    this._clock = DateTime.now,
  });

  final VaultFileStore _store;
  final DateTime Function() _clock;

  Vault? _vault;
  KeyMaterial? _vek;
  VaultEnvelope? _envelope;
  String? _path;

  bool get isUnlocked => _vault != null && _vek != null;
  Vault? get vault => _vault;
  String? get path => _path;
  bool get hasRecoveryKey => _envelope?.hasRecovery ?? false;

  Future<bool> vaultExistsAt(String path) => _store.exists(path);

  Future<Result<void>> createVault({
    required String path,
    required String masterPassword,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final now = _clock().toUtc();
    final vault = Vault.empty(now: now);
    final created = await VaultCrypto.createNew(
      masterPassword: masterPassword,
      plaintext: vault.toPlaintextBytes(),
      params: params,
    );
    try {
      await _store.writeBytesAtomic(path, created.envelope.toBytes());
    } catch (_) {
      created.vek.destroy();
      return const Err(VaultError.ioFailure);
    }
    _adopt(vault: vault, vek: created.vek, envelope: created.envelope, path: path);
    return const Ok(null);
  }

  Future<Result<void>> unlock({
    required String path,
    required String masterPassword,
  }) async {
    final parsed = await _read(path);
    if (parsed is Err<VaultEnvelope>) return Err(parsed.error);

    final opened = await VaultCrypto.openWithPassword(
        envelope: parsed.value, password: masterPassword);
    return _adoptOpened(opened, path);
  }

  /// Reset path: unlock with the recovery key AND set a new master password.
  Future<Result<void>> resetWithRecovery({
    required String path,
    required String recoveryCode,
    required String newPassword,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final parsed = await _read(path);
    if (parsed is Err<VaultEnvelope>) return Err(parsed.error);

    final opened = await VaultCrypto.openWithRecovery(
        envelope: parsed.value, recoveryCode: recoveryCode);
    if (opened is Err<OpenResult>) return Err(opened.error);
    final result = opened.value;

    final Vault vault;
    try {
      vault = Vault.fromPlaintextBytes(result.plaintext);
    } catch (_) {
      result.vek.destroy();
      return const Err(VaultError.wrongPasswordOrTampered);
    }

    final rewrapped = await VaultCrypto.rewrapMaster(
        envelope: result.envelope,
        vek: result.vek,
        newPassword: newPassword,
        params: params);
    try {
      await _store.writeBytesAtomic(path, rewrapped.toBytes());
    } catch (_) {
      result.vek.destroy();
      return const Err(VaultError.ioFailure);
    }
    _adopt(vault: vault, vek: result.vek, envelope: rewrapped, path: path);
    return const Ok(null);
  }

  /// Biometric quick-unlock with a cached VEK (no KDF).
  Future<Result<void>> unlockWithKey({
    required String path,
    required Uint8List keyBytes,
  }) async {
    final parsed = await _read(path);
    if (parsed is Err<VaultEnvelope>) return Err(parsed.error);

    final opened = await VaultCrypto.openWithKey(
        envelope: parsed.value, vekBytes: keyBytes);
    return _adoptOpened(opened, path);
  }

  Future<Result<void>> save() async {
    final vault = _vault, vek = _vek, env = _envelope, path = _path;
    if (vault == null || vek == null || env == null || path == null) {
      return const Err(VaultError.ioFailure);
    }
    final updated = await VaultCrypto.reEncrypt(
        envelope: env, vek: vek, plaintext: vault.toPlaintextBytes());
    try {
      await _store.writeBytesAtomic(path, updated.toBytes());
      _envelope = updated;
      return const Ok(null);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
  }

  /// Re-wraps the VEK under a new master password. The VEK (and therefore the
  /// recovery slot and any cached biometric key) stays valid.
  Future<Result<void>> changeMasterPassword({
    required String newPassword,
    Argon2idParams params = Argon2idParams.defaults,
  }) async {
    final vek = _vek, env = _envelope, path = _path;
    if (vek == null || env == null || path == null) {
      return const Err(VaultError.ioFailure);
    }
    final updated = await VaultCrypto.rewrapMaster(
        envelope: env, vek: vek, newPassword: newPassword, params: params);
    try {
      await _store.writeBytesAtomic(path, updated.toBytes());
      _envelope = updated;
      return const Ok(null);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
  }

  /// Generates a recovery key, wraps the VEK under it, persists, and returns the
  /// code to show the user once.
  Future<Result<String>> createRecoveryKey() async {
    final vek = _vek, env = _envelope, path = _path;
    if (vek == null || env == null || path == null) {
      return const Err(VaultError.ioFailure);
    }
    final code = RecoveryKey.generate();
    final updated = await VaultCrypto.addRecovery(
        envelope: env, vek: vek, recoveryCode: code, params: env.params);
    try {
      await _store.writeBytesAtomic(path, updated.toBytes());
      _envelope = updated;
      return Ok(code);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
  }

  Future<Result<void>> removeRecoveryKey() async {
    final env = _envelope, path = _path;
    if (env == null || path == null) return const Err(VaultError.ioFailure);
    final updated = VaultCrypto.removeRecovery(env);
    try {
      await _store.writeBytesAtomic(path, updated.toBytes());
      _envelope = updated;
      return const Ok(null);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
  }

  Uint8List? exportKeyBytes() {
    final k = _vek;
    if (k == null || k.isDestroyed) return null;
    return Uint8List.fromList(k.bytes);
  }

  Future<Uint8List?> readVaultBytes() async {
    final p = _path;
    if (p == null) return null;
    try {
      return await _store.readBytes(p);
    } catch (_) {
      return null;
    }
  }

  Future<Result<void>> importBytesToPath(String path, Uint8List bytes) async {
    final parsed = VaultEnvelope.fromBytes(bytes);
    if (parsed is Err<VaultEnvelope>) return Err(parsed.error);
    try {
      await _store.writeBytesAtomic(path, bytes);
      return const Ok(null);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
  }

  void lock() {
    _vek?.destroy();
    _vek = null;
    _vault = null;
    _envelope = null;
    _path = null;
  }

  // --- Item mutations (each persists immediately) ---

  Future<Result<VaultItem>> addItem({
    required String title,
    VaultItemType type = VaultItemType.login,
    String username = '',
    String password = '',
    String url = '',
    String notes = '',
    String? totpSecret,
    List<String> tags = const <String>[],
  }) async {
    final vault = _vault;
    if (vault == null) return const Err(VaultError.ioFailure);
    final now = _clock().toUtc();
    final item = VaultItem(
      id: _newId(),
      type: type,
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      totpSecret: totpSecret,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    _vault = vault.copyWith(items: [...vault.items, item], updatedAt: now);
    final saved = await save();
    return saved is Err<void> ? Err(saved.error) : Ok(item);
  }

  Future<Result<void>> updateItem(VaultItem updated) async {
    final vault = _vault;
    if (vault == null) return const Err(VaultError.ioFailure);
    final now = _clock().toUtc();
    final items = vault.items.map((existing) {
      if (existing.id != updated.id) return existing;
      var next = updated.copyWith(updatedAt: now);
      // Record the previous password (keep the 10 most recent) when it changes.
      if (existing.password.isNotEmpty &&
          existing.password != updated.password) {
        next = next.copyWith(
          passwordHistory: [
            PasswordHistoryEntry(password: existing.password, changedAt: now),
            ...existing.passwordHistory,
          ].take(10).toList(),
        );
      }
      return next;
    }).toList();
    _vault = vault.copyWith(items: items, updatedAt: now);
    return save();
  }

  Future<Result<void>> deleteItem(String id) async {
    final vault = _vault;
    if (vault == null) return const Err(VaultError.ioFailure);
    final now = _clock().toUtc();
    final items = vault.items.where((e) => e.id != id).toList();
    _vault = vault.copyWith(items: items, updatedAt: now);
    return save();
  }

  // --- internals ---

  Future<Result<VaultEnvelope>> _read(String path) async {
    final Uint8List bytes;
    try {
      bytes = await _store.readBytes(path);
    } catch (_) {
      return const Err(VaultError.ioFailure);
    }
    return VaultEnvelope.fromBytes(bytes);
  }

  Future<Result<void>> _adoptOpened(
      Result<OpenResult> opened, String path) async {
    if (opened is Err<OpenResult>) return Err(opened.error);
    final result = opened.value;

    final Vault vault;
    try {
      vault = Vault.fromPlaintextBytes(result.plaintext);
    } catch (_) {
      result.vek.destroy();
      return const Err(VaultError.wrongPasswordOrTampered);
    }

    _adopt(
        vault: vault, vek: result.vek, envelope: result.envelope, path: path);

    // Persist a v1→v2 migration so the file is upgraded on disk.
    if (result.migrated) await save();
    return const Ok(null);
  }

  void _adopt({
    required Vault vault,
    required KeyMaterial vek,
    required VaultEnvelope envelope,
    required String path,
  }) {
    _vek?.destroy();
    _vault = vault;
    _vek = vek;
    _envelope = envelope;
    _path = path;
  }

  static String _newId() {
    final bytes = SecureRandom.bytes(16);
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
