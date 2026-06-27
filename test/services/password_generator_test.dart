import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/services/password_generator.dart';

void main() {
  test('respects the requested length', () {
    final pw = PasswordGenerator.generate(const PasswordGenOptions(length: 24));
    expect(pw.length, 24);
  });

  test('includes at least one of each selected character class', () {
    final pw = PasswordGenerator.generate(const PasswordGenOptions(length: 40));
    expect(pw.contains(RegExp('[a-z]')), isTrue);
    expect(pw.contains(RegExp('[A-Z]')), isTrue);
    expect(pw.contains(RegExp('[0-9]')), isTrue);
    expect(pw.contains(RegExp('[^a-zA-Z0-9]')), isTrue);
  });

  test('avoidAmbiguous removes look-alike characters', () {
    for (var i = 0; i < 20; i++) {
      final pw = PasswordGenerator.generate(
          const PasswordGenOptions(length: 40, avoidAmbiguous: true));
      expect(RegExp('[O0oIl1|]').hasMatch(pw), isFalse, reason: pw);
    }
  });

  test('throws when no character set is selected', () {
    expect(
      () => PasswordGenerator.generate(const PasswordGenOptions(
          upper: false, lower: false, digits: false, symbols: false)),
      throwsArgumentError,
    );
  });

  test('two generations differ (sanity check on randomness)', () {
    final a = PasswordGenerator.generate(const PasswordGenOptions(length: 32));
    final b = PasswordGenerator.generate(const PasswordGenOptions(length: 32));
    expect(a, isNot(equals(b)));
  });

  test('strength rises with length and variety', () {
    final weak = PasswordStrength.estimate('aaaa');
    final strong = PasswordStrength.estimate('Tr0ub4dor&3xKpq!mLz');
    expect(strong.bits, greaterThan(weak.bits));
    expect(strong.label, anyOf('Good', 'Strong'));
  });
}
