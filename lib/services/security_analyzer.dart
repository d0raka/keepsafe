import '../data/models/vault_item.dart';
import 'password_generator.dart';

/// Result of a vault security audit ("Password Health").
final class SecurityReport {
  const SecurityReport({
    required this.weak,
    required this.reused,
    required this.noTwoFactor,
  });

  /// Items whose password is weak (low entropy).
  final List<VaultItem> weak;

  /// Items that share a password with at least one other item.
  final List<VaultItem> reused;

  /// Login items with a password but no 2FA secret configured.
  final List<VaultItem> noTwoFactor;

  int get issueCount => weak.length + reused.length + noTwoFactor.length;
  bool get isClean => issueCount == 0;
}

/// Audits a vault for common password-hygiene problems. Pure and synchronous.
final class SecurityAnalyzer {
  const SecurityAnalyzer._();

  /// Below this many bits of estimated entropy a password is "weak".
  static const double weakBitsThreshold = 50;

  static SecurityReport analyze(List<VaultItem> items) {
    int byTitle(VaultItem a, VaultItem b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());

    final withPassword = items.where((i) => i.password.isNotEmpty).toList();

    final weak = withPassword
        .where((i) =>
            PasswordStrength.estimate(i.password).bits < weakBitsThreshold)
        .toList()
      ..sort(byTitle);

    final byPassword = <String, List<VaultItem>>{};
    for (final i in withPassword) {
      byPassword.putIfAbsent(i.password, () => []).add(i);
    }
    final reused = <VaultItem>[
      for (final group in byPassword.values)
        if (group.length > 1) ...group,
    ]..sort(byTitle);

    final noTwoFactor = items
        .where((i) =>
            i.type == VaultItemType.login &&
            i.password.isNotEmpty &&
            (i.totpSecret == null || i.totpSecret!.trim().isEmpty))
        .toList()
      ..sort(byTitle);

    return SecurityReport(
      weak: weak,
      reused: reused,
      noTwoFactor: noTwoFactor,
    );
  }
}
