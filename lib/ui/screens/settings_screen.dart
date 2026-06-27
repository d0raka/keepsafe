import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/password_strength_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final ctrl = ref.read(appControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          InsetSection(
            header: 'Security',
            children: [
              _Row(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFFF9500),
                title: 'Auto-lock',
                trailing: DropdownButton<int>(
                  value: state.autoLockMinutes,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [1, 2, 5, 10, 15, 30]
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (m) => m == null ? null : ctrl.setAutoLockMinutes(m),
                ),
              ),
              if (state.biometricAvailable)
                _Row(
                  icon: Icons.fingerprint,
                  iconColor: const Color(0xFFFF2D55),
                  title: 'Touch ID quick unlock',
                  trailing: Switch(
                    value: state.biometricEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final ok = await ctrl.enableBiometrics();
                        if (!ok && context.mounted) {
                          _toast(context, 'Could not enable Touch ID.');
                        }
                      } else {
                        await ctrl.disableBiometrics();
                      }
                    },
                  ),
                ),
              _Row(
                icon: Icons.key_outlined,
                iconColor: const Color(0xFF8E8E93),
                title: 'Change master password',
                showChevron: true,
                onTap: () => _changePassword(context, ref),
              ),
              _Row(
                icon: Icons.vpn_key_outlined,
                iconColor: const Color(0xFF5856D6),
                title: state.hasRecoveryKey
                    ? 'Recovery key'
                    : 'Set up recovery key',
                subtitle: state.hasRecoveryKey
                    ? 'A recovery key is set'
                    : 'Reset your master password if you forget it',
                showChevron: true,
                onTap: () => _recoveryKey(context, ref, state.hasRecoveryKey),
              ),
            ],
          ),
          InsetSection(
            header: 'Vault file',
            children: [
              _Row(
                icon: Icons.ios_share,
                iconColor: const Color(0xFF007AFF),
                title: 'Export vault…',
                subtitle: 'Save an encrypted .vault to sync yourself',
                showChevron: true,
                onTap: () async {
                  final path = await ctrl.exportVault();
                  if (context.mounted && path != null) {
                    _toast(context, 'Exported');
                  }
                },
              ),
              _Row(
                icon: Icons.download_outlined,
                iconColor: const Color(0xFF34C759),
                title: 'Import vault…',
                subtitle: 'Replace this device\'s vault with a .vault file',
                showChevron: true,
                onTap: () => _confirmImport(context, ref),
              ),
            ],
          ),
          InsetSection(
            header: 'Lock',
            children: [
              _Row(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF8E8E93),
                title: 'Lock now',
                onTap: ctrl.lock,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Strictly offline. KeepSafe makes no network connections; '
                    'your vault never leaves this device unless you export it.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmImport(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import vault?'),
        content: const Text(
            'This replaces the vault on this device. You will unlock the '
            'imported vault with its own master password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Choose file…')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(appControllerProvider.notifier).importVault();
    if (context.mounted && err != null) _toast(context, err);
  }

  Future<void> _recoveryKey(
      BuildContext context, WidgetRef ref, bool exists) async {
    final ctrl = ref.read(appControllerProvider.notifier);
    if (!exists) {
      final code = await ctrl.createRecoveryKey();
      if (!context.mounted) return;
      if (code == null) {
        _toast(context, 'Could not create a recovery key.');
      } else {
        await _showRecoveryCode(context, ref, code);
      }
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recovery key'),
        content: const Text(
            'A recovery key is already set. You can generate a new one '
            '(which replaces the old) or remove it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
          TextButton(
              onPressed: () => Navigator.pop(context, 'regen'),
              child: const Text('Generate new')),
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (action == 'remove') {
      await ctrl.removeRecoveryKey();
      if (context.mounted) _toast(context, 'Recovery key removed');
    } else if (action == 'regen') {
      final code = await ctrl.createRecoveryKey();
      if (context.mounted && code != null) {
        await _showRecoveryCode(context, ref, code);
      }
    }
  }

  Future<void> _showRecoveryCode(
      BuildContext context, WidgetRef ref, String code) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Save your recovery key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Store this somewhere safe (a printout, a safe, another '
                'password manager). It is the ONLY way back into your vault if '
                'you forget your master password — and it won\'t be shown again.'),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(dialogCtx)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(clipboardServiceProvider).copySensitive(code);
              if (dialogCtx.mounted) _toast(dialogCtx, 'Copied — clears in 30s');
            },
            child: const Text('Copy'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('I saved it')),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final pw = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) => AlertDialog(
          title: const Text('Change master password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pw,
                obscureText: true,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              PasswordStrengthBar(password: pw.text),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(dialogCtx).colorScheme.error)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (pw.text.length < 8) {
                  setLocal(() => error = 'Use at least 8 characters.');
                  return;
                }
                if (pw.text != confirm.text) {
                  setLocal(() => error = 'Passwords do not match.');
                  return;
                }
                final err = await ref
                    .read(appControllerProvider.notifier)
                    .changeMasterPassword(pw.text);
                if (!dialogCtx.mounted) return;
                if (err == null) {
                  Navigator.pop(dialogCtx, true);
                } else {
                  setLocal(() => error = err);
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
    pw.dispose();
    confirm.dispose();
    if (changed == true && context.mounted) {
      _toast(context, 'Master password changed');
    }
  }
}

/// A single inset-grouped settings row.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: onSurface.withValues(alpha: 0.5))),
                    ),
                ],
              ),
            ),
            ?trailing,
            if (showChevron)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right,
                    size: 20, color: onSurface.withValues(alpha: 0.25)),
              ),
          ],
        ),
      ),
    );
  }
}
