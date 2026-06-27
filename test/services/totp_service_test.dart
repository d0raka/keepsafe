import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/services/totp_service.dart';

void main() {
  // RFC 6238 Appendix B seed "12345678901234567890" (SHA-1) in Base32.
  const seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  DateTime at(int epochSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);

  test('matches RFC 6238 test vectors (6-digit truncation)', () {
    expect(TotpService.currentCode(seed, now: at(59)), '287082');
    expect(TotpService.currentCode(seed, now: at(1111111109)), '081804');
    expect(TotpService.currentCode(seed, now: at(1111111111)), '050471');
  });

  test('lowercase and spaced secrets still decode', () {
    expect(
      TotpService.currentCode('gezd gnbv gy3t qojq gezd gnbv gy3t qojq',
          now: at(59)),
      '287082',
    );
  });

  test('invalid base32 returns null', () {
    expect(TotpService.currentCode('not-base32!', now: at(59)), isNull);
    expect(TotpService.currentCode('', now: at(59)), isNull);
  });

  test('secondsRemaining counts down within the 30s window', () {
    expect(TotpService.secondsRemaining(now: at(0)), 30);
    expect(TotpService.secondsRemaining(now: at(1)), 29);
    expect(TotpService.secondsRemaining(now: at(29)), 1);
  });
}
