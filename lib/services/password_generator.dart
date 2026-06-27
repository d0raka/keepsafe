import 'dart:math' as math;

import '../core/secure_random.dart';

/// Options controlling generated password composition.
final class PasswordGenOptions {
  const PasswordGenOptions({
    this.length = 20,
    this.upper = true,
    this.lower = true,
    this.digits = true,
    this.symbols = true,
    this.avoidAmbiguous = false,
  });

  final int length;
  final bool upper;
  final bool lower;
  final bool digits;
  final bool symbols;
  final bool avoidAmbiguous;

  PasswordGenOptions copyWith({
    int? length,
    bool? upper,
    bool? lower,
    bool? digits,
    bool? symbols,
    bool? avoidAmbiguous,
  }) =>
      PasswordGenOptions(
        length: length ?? this.length,
        upper: upper ?? this.upper,
        lower: lower ?? this.lower,
        digits: digits ?? this.digits,
        symbols: symbols ?? this.symbols,
        avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
      );
}

/// Cryptographically secure password generator (uses [SecureRandom]).
final class PasswordGenerator {
  const PasswordGenerator._();

  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+[]{}:;,.?';
  static const _ambiguous = 'O0oIl1|';

  /// Generates a password honouring [o]. Guarantees at least one character
  /// from every selected category, then fills and securely shuffles.
  static String generate(PasswordGenOptions o) {
    String filter(String chars) => o.avoidAmbiguous
        ? chars.split('').where((c) => !_ambiguous.contains(c)).join()
        : chars;

    final pools = <String>[
      if (o.upper) filter(_upper),
      if (o.lower) filter(_lower),
      if (o.digits) filter(_digits),
      if (o.symbols) filter(_symbols),
    ].where((p) => p.isNotEmpty).toList();

    if (pools.isEmpty) {
      throw ArgumentError('Select at least one character set.');
    }

    final length = math.max(o.length, pools.length);
    final chars = <String>[
      // one guaranteed character from each selected pool
      for (final pool in pools) pool[SecureRandom.intBelow(pool.length)],
    ];

    final all = pools.join();
    while (chars.length < length) {
      chars.add(all[SecureRandom.intBelow(all.length)]);
    }

    // Fisher–Yates shuffle with a CSPRNG so guaranteed chars aren't front-loaded.
    for (var i = chars.length - 1; i > 0; i--) {
      final j = SecureRandom.intBelow(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }
}

/// Rough password-strength estimate based on character-class entropy.
///
/// This is a lightweight heuristic (length × log2(pool size)), not a full
/// dictionary/zxcvbn analysis — good enough for a live meter.
final class PasswordStrength {
  const PasswordStrength({
    required this.bits,
    required this.label,
    required this.fraction,
  });

  final double bits;
  final String label;

  /// 0.0–1.0 for a progress meter.
  final double fraction;

  static PasswordStrength estimate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(bits: 0, label: '', fraction: 0);
    }
    var pool = 0;
    if (password.contains(RegExp('[a-z]'))) pool += 26;
    if (password.contains(RegExp('[A-Z]'))) pool += 26;
    if (password.contains(RegExp('[0-9]'))) pool += 10;
    if (password.contains(RegExp('[^a-zA-Z0-9]'))) pool += 32;

    final bits = pool == 0 ? 0.0 : password.length * (math.log(pool) / math.ln2);
    final label = switch (bits) {
      < 40 => 'Weak',
      < 60 => 'Fair',
      < 80 => 'Good',
      _ => 'Strong',
    };
    return PasswordStrength(
      bits: bits,
      label: label,
      fraction: (bits / 100).clamp(0.0, 1.0),
    );
  }
}
