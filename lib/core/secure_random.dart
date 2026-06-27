import 'dart:math';
import 'dart:typed_data';

/// Cryptographically secure random bytes via [Random.secure].
///
/// On all of KeepSafe's target platforms (macOS/iOS), `Random.secure()` is
/// backed by the OS CSPRNG (SecRandomCopyBytes / arc4random). Used for salts,
/// nonces, and password generation — never use `Random()` for these.
final class SecureRandom {
  SecureRandom._();

  static final Random _rng = Random.secure();

  /// Returns [length] cryptographically secure random bytes.
  static Uint8List bytes(int length) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'must be >= 0');
    }
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// A uniformly distributed integer in [0, max) without modulo bias.
  static int intBelow(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be > 0');
    }
    return _rng.nextInt(max);
  }
}
