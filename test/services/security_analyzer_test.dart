import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/data/models/vault_item.dart';
import 'package:keepsafe/services/security_analyzer.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  VaultItem item(
    String id, {
    String password = '',
    VaultItemType type = VaultItemType.login,
    String? totp,
  }) =>
      VaultItem(
        id: id,
        type: type,
        title: id,
        password: password,
        totpSecret: totp,
        createdAt: now,
        updatedAt: now,
      );

  test('flags weak passwords', () {
    final r = SecurityAnalyzer.analyze([
      item('weak', password: 'aaaa', totp: 'X'),
      item('strong', password: 'Tr0ub4dor&3xKpq!mLz9', totp: 'X'),
    ]);
    expect(r.weak.map((e) => e.id), contains('weak'));
    expect(r.weak.map((e) => e.id), isNot(contains('strong')));
  });

  test('flags reused passwords (both items)', () {
    final r = SecurityAnalyzer.analyze([
      item('a', password: 'samePassw0rd!', totp: 'X'),
      item('b', password: 'samePassw0rd!', totp: 'X'),
      item('c', password: 'uniquePassw0rd!#', totp: 'X'),
    ]);
    expect(r.reused.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('flags logins without 2FA, ignoring notes and 2FA-enabled logins', () {
    final r = SecurityAnalyzer.analyze([
      item('login-no2fa', password: 'StrongPassw0rd!#9'),
      item('login-2fa', password: 'StrongPassw0rd!#9', totp: 'JBSWY3DP'),
      item('note', password: 'StrongPassw0rd!#9', type: VaultItemType.secureNote),
    ]);
    expect(r.noTwoFactor.map((e) => e.id), ['login-no2fa']);
  });

  test('clean vault reports no issues', () {
    final r = SecurityAnalyzer.analyze([
      item('a', password: 'Tr0ub4dor&3xKpq!mLz9', totp: 'JBSWY3DP'),
    ]);
    expect(r.isClean, isTrue);
    expect(r.issueCount, 0);
  });
}
