import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/crypto/kdf.dart';

void main() {
  const fast = Argon2idParams(memoryKiB: 256, iterations: 1, parallelism: 1);
  final salt = Uint8List.fromList(List.generate(16, (i) => i));

  test('derives a 256-bit (32-byte) key', () async {
    final key = await Kdf.deriveKey(
        password: 'correct horse battery staple', salt: salt, params: fast);
    expect(key.length, 32);
    key.destroy();
  });

  test('is deterministic for the same password, salt, and params', () async {
    final a = await Kdf.deriveKey(password: 'pw', salt: salt, params: fast);
    final b = await Kdf.deriveKey(password: 'pw', salt: salt, params: fast);
    expect(a.bytes, equals(b.bytes));
    a.destroy();
    b.destroy();
  });

  test('different password yields a different key', () async {
    final a = await Kdf.deriveKey(password: 'pw1', salt: salt, params: fast);
    final b = await Kdf.deriveKey(password: 'pw2', salt: salt, params: fast);
    expect(a.bytes, isNot(equals(b.bytes)));
    a.destroy();
    b.destroy();
  });

  test('different salt yields a different key', () async {
    final salt2 = Uint8List.fromList(List.generate(16, (i) => i + 100));
    final a = await Kdf.deriveKey(password: 'pw', salt: salt, params: fast);
    final b = await Kdf.deriveKey(password: 'pw', salt: salt2, params: fast);
    expect(a.bytes, isNot(equals(b.bytes)));
    a.destroy();
    b.destroy();
  });

  test('production default params produce a valid key', () async {
    final key = await Kdf.deriveKey(
      password: 'pw',
      salt: salt,
      params: Argon2idParams.defaults,
    );
    expect(key.length, 32);
    key.destroy();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
