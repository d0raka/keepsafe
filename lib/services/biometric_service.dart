import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional Touch ID / Face ID quick-unlock.
///
/// Design: after a normal password unlock, we cache the *derived vault key*
/// (never the master password) in the OS keychain. A biometric prompt
/// (`local_auth`) gates access to it, so the key only leaves the keychain after
/// the user authenticates. On password change the cached key is cleared.
final class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _keyName = 'keepsafe_vault_key_b64';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  /// Whether the device can do biometric (or device-credential) auth.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasEnabled() async {
    try {
      return await _storage.containsKey(key: _keyName);
    } catch (_) {
      return false;
    }
  }

  /// Prompt for biometrics. Returns true on success.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Cache the vault key after a successful biometric confirmation.
  Future<bool> enable(Uint8List keyBytes) async {
    final ok = await authenticate('Enable quick unlock for KeepSafe');
    if (!ok) return false;
    try {
      await _storage.write(key: _keyName, value: base64.encode(keyBytes));
      return true;
    } catch (_) {
      return false; // keychain unavailable — degrade gracefully
    }
  }

  /// Prompt for biometrics and return the cached key, or null.
  Future<Uint8List?> unlockKey() async {
    final ok = await authenticate('Unlock KeepSafe');
    if (!ok) return null;
    try {
      final b64 = await _storage.read(key: _keyName);
      if (b64 == null) return null;
      return base64.decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> disable() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {/* ignore */}
  }
}
