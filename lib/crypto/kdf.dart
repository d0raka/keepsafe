import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/constants.dart';
import 'key_material.dart';

/// Argon2id cost parameters. Persisted (unencrypted) in each vault envelope so
/// a file is self-describing and costs can be raised over time.
final class Argon2idParams {
  const Argon2idParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP-aligned defaults (64 MiB, 3 passes, 4 lanes).
  static const Argon2idParams defaults = Argon2idParams(
    memoryKiB: CryptoParams.defaultMemoryKiB,
    iterations: CryptoParams.defaultIterations,
    parallelism: CryptoParams.defaultParallelism,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toHeaderJson() => {
        'algorithm': CryptoParams.kdfAlgorithmId,
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
      };

  @override
  bool operator ==(Object other) =>
      other is Argon2idParams &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);
}

/// Memory-hard key derivation from the master password.
///
/// Uses the `cryptography` package's pure-Dart Argon2id implementation, which
/// internally offloads the heavy memory-fill to worker isolates — so awaiting
/// this does not block the UI isolate. The KDF is intentionally slow; that is
/// the point.
final class Kdf {
  const Kdf._();

  /// Derives a 256-bit key from [password] + [salt] using [params].
  static Future<KeyMaterial> deriveKey({
    required String password,
    required Uint8List salt,
    required Argon2idParams params,
  }) async {
    final algorithm = Argon2id(
      parallelism: params.parallelism,
      memory: params.memoryKiB, // "memory" == number of 1 KiB blocks
      iterations: params.iterations,
      hashLength: CryptoParams.keyLengthBytes,
    );

    final secretKey = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt, // "nonce" is the salt in cryptography's KDF API
    );
    final bytes = await secretKey.extractBytes();
    return KeyMaterial(Uint8List.fromList(bytes));
  }
}
