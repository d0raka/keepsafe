import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Holds a derived symmetric key in memory with **best-effort** zeroization.
///
/// Dart is a garbage-collected language, so we cannot guarantee a key is never
/// copied or that every copy is wiped. What we *can* do — and do here — is keep
/// the canonical key bytes in a single mutable [Uint8List] and overwrite them
/// with zeros the moment the vault is locked, minimising the window in which
/// key material sits in heap memory.
final class KeyMaterial {
  KeyMaterial(this._bytes);

  final Uint8List _bytes;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  int get length => _bytes.length;

  /// A `cryptography` [SecretKey] backed by these bytes.
  ///
  /// Note: `SecretKey` may copy the bytes internally; that copy is outside our
  /// control. Treat zeroization as defence-in-depth, not a hard guarantee.
  SecretKey toSecretKey() {
    _ensureAlive();
    return SecretKey(_bytes);
  }

  /// Raw key bytes — caller must not retain a reference past [destroy].
  Uint8List get bytes {
    _ensureAlive();
    return _bytes;
  }

  /// Overwrites the key with zeros. Idempotent. After this the key is unusable.
  void destroy() {
    if (_destroyed) return;
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }

  void _ensureAlive() {
    if (_destroyed) {
      throw StateError('KeyMaterial has been destroyed (vault locked).');
    }
  }
}
