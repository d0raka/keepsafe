import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/result.dart';
import '../crypto/kdf.dart';
import '../data/models/vault_item.dart';
import '../data/vault_repository.dart';
import '../services/biometric_service.dart';
import '../services/clipboard_service.dart';
import '../services/import_export_service.dart';

/// Which top-level screen the app should show.
enum VaultStage { loading, onboarding, locked, unlocked }

/// Immutable snapshot of app state for the UI.
final class AppState {
  const AppState({
    required this.stage,
    this.items = const <VaultItem>[],
    this.autoLockMinutes = 5,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.hasRecoveryKey = false,
  });

  final VaultStage stage;
  final List<VaultItem> items;
  final int autoLockMinutes;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool hasRecoveryKey;

  AppState copyWith({
    VaultStage? stage,
    List<VaultItem>? items,
    int? autoLockMinutes,
    bool? biometricAvailable,
    bool? biometricEnabled,
    bool? hasRecoveryKey,
  }) =>
      AppState(
        stage: stage ?? this.stage,
        items: items ?? this.items,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        hasRecoveryKey: hasRecoveryKey ?? this.hasRecoveryKey,
      );
}

/// Default vault location: the app documents directory. Overridden in tests.
final vaultPathProvider = FutureProvider<String>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/keepsafe.vault';
});

/// Argon2id cost parameters. Overridden with cheap values in tests.
final kdfParamsProvider =
    Provider<Argon2idParams>((ref) => Argon2idParams.defaults);

/// Clipboard helper that auto-clears copied secrets.
final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final svc = ClipboardService();
  ref.onDispose(svc.dispose);
  return svc;
});

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

final importExportServiceProvider =
    Provider<ImportExportService>((ref) => const ImportExportService());

final appControllerProvider =
    NotifierProvider<AppController, AppState>(AppController.new);

/// Orchestrates the vault lifecycle and feeds the UI.
final class AppController extends Notifier<AppState> {
  final VaultRepository _repo = VaultRepository();
  Timer? _autoLockTimer;
  String? _path;

  @override
  AppState build() {
    ref.onDispose(() => _autoLockTimer?.cancel());
    return const AppState(stage: VaultStage.loading);
  }

  Argon2idParams get _params => ref.read(kdfParamsProvider);
  BiometricService get _bio => ref.read(biometricServiceProvider);
  ImportExportService get _io => ref.read(importExportServiceProvider);

  /// Resolves the vault path and decides onboarding vs locked. Call once at
  /// startup (from the root widget's initState).
  Future<void> initialize() async {
    _path = await ref.read(vaultPathProvider.future);
    final exists = await _repo.vaultExistsAt(_path!);
    final bioAvailable = await _bio.isAvailable();
    final bioEnabled = exists && await _bio.hasEnabled();
    state = state.copyWith(
      stage: exists ? VaultStage.locked : VaultStage.onboarding,
      biometricAvailable: bioAvailable,
      biometricEnabled: bioEnabled,
    );
  }

  Future<String?> createVault(String masterPassword) async {
    final res = await _repo.createVault(
      path: _path!,
      masterPassword: masterPassword,
      params: _params,
    );
    return _afterAuth(res);
  }

  Future<String?> unlock(String masterPassword) async {
    final res = await _repo.unlock(path: _path!, masterPassword: masterPassword);
    return _afterAuth(res);
  }

  void lock() {
    _autoLockTimer?.cancel();
    _repo.lock();
    state = state.copyWith(stage: VaultStage.locked, items: const []);
  }

  /// Reset the auto-lock countdown (call on user interaction).
  void poke() {
    if (state.stage == VaultStage.unlocked) _resetAutoLock();
  }

  void setAutoLockMinutes(int minutes) {
    state = state.copyWith(autoLockMinutes: minutes);
    if (state.stage == VaultStage.unlocked) _resetAutoLock();
  }

  Future<String?> addItem({
    required String title,
    VaultItemType type = VaultItemType.login,
    String username = '',
    String password = '',
    String url = '',
    String notes = '',
    String? totpSecret,
    List<String> tags = const <String>[],
  }) async {
    final res = await _repo.addItem(
      title: title,
      type: type,
      username: username,
      password: password,
      url: url,
      notes: notes,
      totpSecret: totpSecret,
      tags: tags,
    );
    return _afterMutation(res);
  }

  Future<String?> updateItem(VaultItem item) async =>
      _afterMutation(await _repo.updateItem(item));

  Future<String?> deleteItem(String id) async =>
      _afterMutation(await _repo.deleteItem(id));

  Future<String?> toggleFavorite(String id) async {
    final item = _repo.vault?.items.where((i) => i.id == id).firstOrNull;
    if (item == null) return null;
    return updateItem(item.copyWith(favorite: !item.favorite));
  }

  Future<String?> changeMasterPassword(String newPassword) async {
    final res =
        await _repo.changeMasterPassword(newPassword: newPassword, params: _params);
    if (res is Err) return _message(res.errorOrNull!);
    // The VEK is unchanged, so biometrics and the recovery key stay valid.
    _resetAutoLock();
    return null;
  }

  // --- Recovery key ---

  /// Generates a recovery key, persists its wrapped slot, and returns the code
  /// to display once. Returns null on failure.
  Future<String?> createRecoveryKey() async {
    final res = await _repo.createRecoveryKey();
    if (res is Err) return null;
    state = state.copyWith(hasRecoveryKey: true);
    return res.value;
  }

  Future<void> removeRecoveryKey() async {
    await _repo.removeRecoveryKey();
    state = state.copyWith(hasRecoveryKey: false);
  }

  /// "Forgot password" flow: unlock with the recovery key and set a new master
  /// password. Returns an error message, or null on success (vault unlocked).
  Future<String?> resetWithRecovery({
    required String recoveryCode,
    required String newPassword,
  }) async {
    final res = await _repo.resetWithRecovery(
      path: _path!,
      recoveryCode: recoveryCode,
      newPassword: newPassword,
      params: _params,
    );
    if (res is Err) return _message(res.errorOrNull!);
    _resetAutoLock();
    state = state.copyWith(
      stage: VaultStage.unlocked,
      items: _repo.vault?.items ?? const [],
      hasRecoveryKey: _repo.hasRecoveryKey,
    );
    return null;
  }

  // --- Biometric quick-unlock ---

  /// Caches the current vault key behind a biometric prompt. Returns true if
  /// enabled. Requires the vault to be unlocked.
  Future<bool> enableBiometrics() async {
    final keyBytes = _repo.exportKeyBytes();
    if (keyBytes == null) return false;
    final ok = await _bio.enable(keyBytes);
    keyBytes.fillRange(0, keyBytes.length, 0);
    if (ok) state = state.copyWith(biometricEnabled: true);
    return ok;
  }

  Future<void> disableBiometrics() async {
    await _bio.disable();
    state = state.copyWith(biometricEnabled: false);
  }

  /// Prompts for biometrics and unlocks without the master password.
  /// Returns an error message, or null on success/cancel.
  Future<String?> biometricUnlock() async {
    final keyBytes = await _bio.unlockKey();
    if (keyBytes == null) return null; // cancelled or unavailable
    final res = await _repo.unlockWithKey(path: _path!, keyBytes: keyBytes);
    keyBytes.fillRange(0, keyBytes.length, 0);
    if (res is Err) {
      // Stale key (e.g. vault replaced via import) — fall back to password.
      await disableBiometrics();
      return 'Biometric unlock failed — please use your master password.';
    }
    return _afterAuth(res);
  }

  // --- Import / export ---

  /// Exports the active vault file to a user-chosen location.
  /// Returns the written path, or null if cancelled.
  Future<String?> exportVault() async {
    final bytes = await _repo.readVaultBytes();
    if (bytes == null) return null;
    return _io.exportBytes(bytes);
  }

  /// Imports a `.vault` file chosen by the user, replacing the active vault.
  /// Returns an error message, or null on success/cancel. On success the vault
  /// is locked so the user can unlock it with that file's master password.
  Future<String?> importVault() async {
    final bytes = await _io.pickImportBytes();
    if (bytes == null) return null; // cancelled
    final res = await _repo.importBytesToPath(_path!, bytes);
    if (res is Err) return _message(res.errorOrNull!);
    _autoLockTimer?.cancel();
    _repo.lock();
    await _bio.disable(); // imported vault has a different key
    state = state.copyWith(
      stage: VaultStage.locked,
      items: const [],
      biometricEnabled: false,
    );
    return null;
  }

  // --- helpers ---

  String? _afterAuth(Result<void> res) {
    if (res is Err) return _message(res.errorOrNull!);
    _resetAutoLock();
    state = state.copyWith(
      stage: VaultStage.unlocked,
      items: _repo.vault?.items ?? const [],
      hasRecoveryKey: _repo.hasRecoveryKey,
    );
    return null;
  }

  String? _afterMutation(Result<dynamic> res) {
    if (res is Err) return _message(res.errorOrNull!);
    _resetAutoLock();
    state = state.copyWith(items: _repo.vault?.items ?? const []);
    return null;
  }

  void _resetAutoLock() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(Duration(minutes: state.autoLockMinutes), lock);
  }

  String _message(VaultError e) => switch (e) {
        VaultError.wrongPasswordOrTampered =>
          'Incorrect master password, or the vault file is corrupted.',
        VaultError.notAVault => 'That file is not a KeepSafe vault.',
        VaultError.unsupportedVersion =>
          'This vault was created by a newer version of KeepSafe.',
        VaultError.ioFailure => 'Could not read or write the vault file.',
      };
}
