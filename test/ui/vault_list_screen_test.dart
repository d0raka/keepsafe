import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/data/models/vault_item.dart';
import 'package:keepsafe/ui/screens/vault_list_screen.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  VaultItem item(String title, {String username = ''}) => VaultItem(
        id: title,
        type: VaultItemType.login,
        title: title,
        username: username,
        createdAt: now,
        updatedAt: now,
      );

  test('filtering an unmodifiable/empty list does not throw', () {
    // Reproduces the original crash: sorting a borrowed unmodifiable list.
    expect(filterAndSortVaultItems(const <VaultItem>[], ''), isEmpty);
    expect(
      filterAndSortVaultItems(
          List<VaultItem>.unmodifiable([item('B'), item('a')]), ''),
      hasLength(2),
    );
  });

  test('sorts by title case-insensitively without mutating the input', () {
    final input = List<VaultItem>.unmodifiable([item('Banana'), item('apple')]);
    final result = filterAndSortVaultItems(input, '');
    expect(result.map((e) => e.title), ['apple', 'Banana']);
  });

  test('filters across title, username, url, and tags', () {
    final items = [item('GitHub', username: 'octocat'), item('Bank')];
    expect(filterAndSortVaultItems(items, 'octo').single.title, 'GitHub');
    expect(filterAndSortVaultItems(items, 'zzz'), isEmpty);
  });
}
