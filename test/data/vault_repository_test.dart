import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/core/result.dart';
import 'package:keepsafe/crypto/kdf.dart';
import 'package:keepsafe/data/vault_repository.dart';

void main() {
  const fast = Argon2idParams(memoryKiB: 256, iterations: 1, parallelism: 1);
  DateTime clock() => DateTime.utc(2026, 6, 25, 12, 0, 0);

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('keepsafe_repo_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('create → add item → lock → unlock recovers data', () async {
    final path = '${tmp.path}/my.vault';
    final repo = VaultRepository(clock: clock);

    final created = await repo.createVault(
        path: path, masterPassword: 'master-pw', params: fast);
    expect(created.isOk, isTrue);
    expect(repo.isUnlocked, isTrue);

    await repo.addItem(title: 'Email', username: 'me@x.com', password: 's3cret');
    expect(repo.vault!.items, hasLength(1));

    repo.lock();
    expect(repo.isUnlocked, isFalse);
    expect(repo.vault, isNull);

    final repo2 = VaultRepository(clock: clock);
    final unlocked = await repo2.unlock(path: path, masterPassword: 'master-pw');
    expect(unlocked.isOk, isTrue);
    expect(repo2.vault!.items, hasLength(1));
    expect(repo2.vault!.items.first.title, 'Email');
    expect(repo2.vault!.items.first.password, 's3cret');
  });

  test('wrong master password is rejected', () async {
    final path = '${tmp.path}/my.vault';
    final repo = VaultRepository(clock: clock);
    await repo.createVault(
        path: path, masterPassword: 'right', params: fast);
    repo.lock();

    final repo2 = VaultRepository(clock: clock);
    final res = await repo2.unlock(path: path, masterPassword: 'wrong');
    expect(res.isErr, isTrue);
    expect(res.errorOrNull, VaultError.wrongPasswordOrTampered);
    expect(repo2.isUnlocked, isFalse);
  });

  test('exported file imports on another device (copy round-trip)', () async {
    final srcPath = '${tmp.path}/device-a.vault';
    final repoA = VaultRepository(clock: clock);
    await repoA.createVault(
        path: srcPath, masterPassword: 'shared-pw', params: fast);
    await repoA.addItem(title: 'WiFi', notes: 'password is hunter2');

    // Simulate manual sync: copy the .vault file to "device B".
    final dstPath = '${tmp.path}/device-b.vault';
    await File(srcPath).copy(dstPath);

    final repoB = VaultRepository(clock: clock);
    final res = await repoB.unlock(path: dstPath, masterPassword: 'shared-pw');
    expect(res.isOk, isTrue);
    expect(repoB.vault!.items.first.title, 'WiFi');
  });

  test('changing the master password re-seals; old password fails', () async {
    final path = '${tmp.path}/my.vault';
    final repo = VaultRepository(clock: clock);
    await repo.createVault(path: path, masterPassword: 'old-pw', params: fast);
    await repo.addItem(title: 'Bank');

    final changed =
        await repo.changeMasterPassword(newPassword: 'new-pw', params: fast);
    expect(changed.isOk, isTrue);
    repo.lock();

    final repo2 = VaultRepository(clock: clock);
    expect((await repo2.unlock(path: path, masterPassword: 'old-pw')).isErr,
        isTrue);
    expect((await repo2.unlock(path: path, masterPassword: 'new-pw')).isOk,
        isTrue);
    expect(repo2.vault!.items.first.title, 'Bank');
  });

  test('recovery key resets a forgotten master password', () async {
    final path = '${tmp.path}/my.vault';
    final repo = VaultRepository(clock: clock);
    await repo.createVault(
        path: path, masterPassword: 'orig-pw', params: fast);
    await repo.addItem(title: 'Email');
    final created = await repo.createRecoveryKey();
    expect(created.isOk, isTrue);
    expect(repo.hasRecoveryKey, isTrue);
    final code = created.value;
    repo.lock();

    // Forgot 'orig-pw' → reset using the recovery code, on a fresh instance.
    final repo2 = VaultRepository(clock: clock);
    final reset = await repo2.resetWithRecovery(
        path: path, recoveryCode: code, newPassword: 'fresh-pw', params: fast);
    expect(reset.isOk, isTrue);
    expect(repo2.isUnlocked, isTrue);
    expect(repo2.vault!.items.first.title, 'Email');
    repo2.lock();

    // The new password works; the original no longer does.
    final repo3 = VaultRepository(clock: clock);
    expect((await repo3.unlock(path: path, masterPassword: 'fresh-pw')).isOk,
        isTrue);
    expect((await repo3.unlock(path: path, masterPassword: 'orig-pw')).isErr,
        isTrue);
  });

  test('updating an item records password history on change only', () async {
    final path = '${tmp.path}/h.vault';
    final repo = VaultRepository(clock: clock);
    await repo.createVault(path: path, masterPassword: 'pw', params: fast);
    final item = (await repo.addItem(title: 'Site', password: 'first')).value;

    await repo.updateItem(item.copyWith(password: 'second'));
    var current = repo.vault!.items.first;
    expect(current.password, 'second');
    expect(current.passwordHistory.map((e) => e.password), ['first']);

    await repo.updateItem(current.copyWith(password: 'third'));
    current = repo.vault!.items.first;
    expect(current.passwordHistory.map((e) => e.password), ['second', 'first']);

    // Editing a non-password field does not add a history entry.
    await repo.updateItem(current.copyWith(notes: 'a note'));
    expect(repo.vault!.items.first.passwordHistory.length, 2);
  });
}
