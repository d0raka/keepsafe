import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';
import '../theme.dart';

/// Shown when a vault exists but is locked: master password or biometrics.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  bool _triedBiometric = false;

  @override
  void initState() {
    super.initState();
    // Auto-offer biometrics on appear if enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometric());
  }

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _maybeBiometric() async {
    if (_triedBiometric) return;
    _triedBiometric = true;
    final st = ref.read(appControllerProvider);
    if (st.biometricAvailable && st.biometricEnabled) {
      await _biometric();
    }
  }

  Future<void> _biometric() async {
    final err = await ref.read(appControllerProvider.notifier).biometricUnlock();
    if (mounted && err != null) setState(() => _error = err);
  }

  Future<void> _forgotPassword() async {
    final code = TextEditingController();
    final pw = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    var processing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) => AlertDialog(
          title: const Text('Reset master password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter your recovery key and choose a new master password. '
                    'If you don\'t have a recovery key, the vault cannot be '
                    'recovered.'),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Recovery key'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pw,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'New master password'),
                ),
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
          ),
          actions: [
            TextButton(
                onPressed: processing
                    ? null
                    : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: processing
                  ? null
                  : () async {
                      if (code.text.trim().isEmpty) {
                        setLocal(() => error = 'Enter your recovery key.');
                        return;
                      }
                      if (pw.text.length < 8) {
                        setLocal(() => error = 'Use at least 8 characters.');
                        return;
                      }
                      if (pw.text != confirm.text) {
                        setLocal(() => error = 'Passwords do not match.');
                        return;
                      }
                      setLocal(() {
                        processing = true;
                        error = null;
                      });
                      final err = await ref
                          .read(appControllerProvider.notifier)
                          .resetWithRecovery(
                              recoveryCode: code.text, newPassword: pw.text);
                      if (!dialogCtx.mounted) return;
                      if (err == null) {
                        Navigator.pop(dialogCtx); // success → vault unlocks
                      } else {
                        setLocal(() {
                          processing = false;
                          error = err;
                        });
                      }
                    },
              child: processing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Reset & Unlock'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    pw.dispose();
    confirm.dispose();
  }

  Future<void> _unlock() async {
    if (_pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(appControllerProvider.notifier).unlock(_pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err != null) _pw.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(appControllerProvider);
    final showBiometric = st.biometricAvailable && st.biometricEnabled;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              _LockBadge(),
              const SizedBox(height: 18),
              Text('KeepSafe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text('Enter your master password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
              const SizedBox(height: 28),
              TextField(
                controller: _pw,
                obscureText: _obscure,
                autofocus: !showBiometric,
                onSubmitted: (_) => _unlock(),
                decoration: InputDecoration(
                  hintText: 'Master password',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Unlock'),
              ),
              if (showBiometric) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _busy ? null : _biometric,
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: const Text('Use Touch ID'),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: Text('Forgot password?',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A84FF), Color(0xFF0040DD)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 38),
      ),
    );
  }
}
