import '../core/secure_random.dart';

/// Generates and normalises Recovery Keys.
///
/// A Recovery Key is a high-entropy code shown to the user ONCE. It is never
/// stored — only a copy of the Vault Encryption Key wrapped by a key derived
/// from it lives in the vault file. Losing both the master password and the
/// recovery key means the vault cannot be recovered (zero-knowledge).
final class RecoveryKey {
  const RecoveryKey._();

  // Crockford-ish base32 alphabet, no easily-confused characters.
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// 25 base32 characters (~125 bits of entropy), formatted as 5 dash-separated
  /// groups of 5, e.g. `A1B2C-D3E4F-…`. Every character is a uniform CSPRNG pick.
  static String generate() {
    final raw = StringBuffer();
    for (var i = 0; i < 25; i++) {
      raw.write(_alphabet[SecureRandom.intBelow(_alphabet.length)]);
    }
    return _group(raw.toString());
  }

  /// Normalises user input for key derivation: uppercase, strip dashes/spaces.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '').trim();

  static String _group(String raw) {
    final groups = <String>[];
    for (var i = 0; i < raw.length; i += 5) {
      groups.add(raw.substring(i, (i + 5).clamp(0, raw.length)));
    }
    return groups.join('-');
  }
}
