/// App-wide constants for KeepSafe.
///
/// These are intentionally centralised so the on-disk vault format stays
/// self-describing and forward-compatible: every `.vault` file embeds the
/// KDF/cipher parameters that were used, so defaults can be raised over time
/// without breaking older files.
library;

class AppInfo {
  static const String appName = 'KeepSafe';

  /// File extension for an exported/standalone vault document.
  static const String vaultFileExtension = 'vault';
}

/// On-disk envelope identifiers.
class VaultFormat {
  /// Magic string identifying a KeepSafe vault envelope.
  static const String formatId = 'keepsafe-vault';

  /// Current envelope format version we WRITE.
  ///   v1 — master-password-derived key encrypts the vault directly.
  ///   v2 — random Vault Encryption Key (VEK) wrapped by a master KEK and an
  ///        optional recovery KEK (enables a Recovery Key / password reset).
  /// v1 files are still read and transparently migrated to v2 on unlock.
  static const int formatVersion = 2;

  /// The earliest legacy version we can still read.
  static const int legacyFormatVersion = 1;

  /// Schema version of the decrypted vault document (the *contents*).
  static const int schemaVersion = 1;
}

/// Cryptographic parameters and defaults.
///
/// AES-256-GCM for authenticated encryption; Argon2id for memory-hard
/// key derivation from the master password.
class CryptoParams {
  // --- AES-256-GCM ---
  /// AES-256 key length in bytes.
  static const int keyLengthBytes = 32;

  /// GCM nonce length in bytes (96-bit nonce is the AES-GCM standard).
  static const int nonceLengthBytes = 12;

  /// GCM authentication tag length in bytes (128-bit tag).
  static const int macLengthBytes = 16;

  // --- Argon2id (defaults) ---
  /// Algorithm identifier persisted in the envelope header.
  static const String kdfAlgorithmId = 'argon2id';

  /// Cipher identifier persisted in the envelope header.
  static const String cipherAlgorithmId = 'aes-256-gcm';

  /// Salt length in bytes for Argon2id.
  static const int saltLengthBytes = 16;

  /// Default Argon2id memory cost in kibibytes (64 MiB).
  static const int defaultMemoryKiB = 65536;

  /// Default Argon2id time cost (iterations / passes).
  static const int defaultIterations = 3;

  /// Default Argon2id parallelism (lanes).
  static const int defaultParallelism = 4;
}
