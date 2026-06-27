import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6238 TOTP (time-based one-time passwords) using HMAC-SHA1.
///
/// Lets KeepSafe show live 2FA verification codes for items that store a TOTP
/// secret (the same thing Apple's Passwords app does). All computed locally.
final class TotpService {
  const TotpService._();

  /// Returns the current code, or null if [base32Secret] is not valid base32.
  static String? currentCode(
    String base32Secret, {
    int digits = 6,
    int periodSeconds = 30,
    DateTime? now,
  }) {
    final key = _decodeBase32(base32Secret);
    if (key == null || key.isEmpty) return null;

    final seconds =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final counter = seconds ~/ periodSeconds;

    final message = ByteData(8)..setUint64(0, counter, Endian.big);
    final hmac =
        Hmac(sha1, key).convert(message.buffer.asUint8List()).bytes;

    final offset = hmac[hmac.length - 1] & 0x0f;
    final binary = ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);

    final mod = _pow10(digits);
    return (binary % mod).toString().padLeft(digits, '0');
  }

  /// Seconds remaining in the current [periodSeconds] window (for a countdown).
  static int secondsRemaining({int periodSeconds = 30, DateTime? now}) {
    final seconds =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    return periodSeconds - (seconds % periodSeconds);
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static Uint8List? _decodeBase32(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean =
        input.toUpperCase().replaceAll('=', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;

    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.codeUnits) {
      final val = alphabet.indexOf(String.fromCharCode(ch));
      if (val < 0) return null; // invalid character
      buffer = (buffer << 5) | val;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }
}
