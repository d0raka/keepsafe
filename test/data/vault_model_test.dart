import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/data/models/vault.dart';
import 'package:keepsafe/data/models/vault_item.dart';

void main() {
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);

  test('VaultItem JSON round-trips all fields', () {
    final item = VaultItem(
      id: 'abc123',
      type: VaultItemType.login,
      title: 'GitHub',
      username: 'octocat',
      password: 'hunter2',
      url: 'https://github.com',
      notes: 'work account',
      totpSecret: 'JBSWY3DPEHPK3PXP',
      tags: const ['work', 'dev'],
      createdAt: now,
      updatedAt: now,
    );
    final back = VaultItem.fromJson(item.toJson());
    expect(back.id, item.id);
    expect(back.type, item.type);
    expect(back.title, item.title);
    expect(back.username, item.username);
    expect(back.password, item.password);
    expect(back.url, item.url);
    expect(back.notes, item.notes);
    expect(back.totpSecret, item.totpSecret);
    expect(back.tags, item.tags);
    expect(back.createdAt, item.createdAt);
    expect(back.updatedAt, item.updatedAt);
  });

  test('Vault round-trips through plaintext bytes', () {
    final vault = Vault.empty(now: now).copyWith(
      items: [
        VaultItem(
          id: '1',
          type: VaultItemType.secureNote,
          title: 'Note',
          notes: 'remember this',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      updatedAt: now,
    );
    final back = Vault.fromPlaintextBytes(vault.toPlaintextBytes());
    expect(back.schemaVersion, vault.schemaVersion);
    expect(back.items, hasLength(1));
    expect(back.items.first.title, 'Note');
    expect(back.items.first.notes, 'remember this');
  });
}
