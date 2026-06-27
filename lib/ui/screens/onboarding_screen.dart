import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/password_strength_bar.dart';

/// First-run screen: choose the master password that protects the vault.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _error = null);
    if (_pw.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (_pw.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    final err =
        await ref.read(appControllerProvider.notifier).createVault(_pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF34C759), Color(0xFF248A3D)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 18),
              Text('Create your vault',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: onSurface)),
              const SizedBox(height: 8),
              Text(
                'Your master password encrypts everything on this device. '
                'It is never stored and cannot be recovered — choose carefully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: onSurface.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _pw,
                obscureText: _obscure,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Master password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PasswordStrengthBar(password: _pw.text),
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                onSubmitted: (_) => _create(),
                decoration: const InputDecoration(
                    hintText: 'Confirm master password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create vault'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
