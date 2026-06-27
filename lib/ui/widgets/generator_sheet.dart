import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/password_generator.dart';
import 'password_strength_bar.dart';

/// A modal bottom sheet that generates a password. Returns the chosen password
/// via `Navigator.pop`, or null if dismissed.
Future<String?> showGeneratorSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _GeneratorSheet(),
  );
}

class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet();

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  PasswordGenOptions _opts = const PasswordGenOptions();
  late String _password = PasswordGenerator.generate(_opts);

  void _regenerate([PasswordGenOptions? opts]) {
    setState(() {
      if (opts != null) _opts = opts;
      try {
        _password = PasswordGenerator.generate(_opts);
      } on ArgumentError {
        _password = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generate password',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _password.isEmpty ? '—' : _password,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          PasswordStrengthBar(password: _password),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Length: ${_opts.length}'),
              Expanded(
                child: Slider(
                  value: _opts.length.toDouble(),
                  min: 8,
                  max: 64,
                  divisions: 56,
                  label: '${_opts.length}',
                  onChanged: (v) => _regenerate(_opts.copyWith(length: v.round())),
                ),
              ),
            ],
          ),
          _toggle('Uppercase (A-Z)', _opts.upper,
              (v) => _regenerate(_opts.copyWith(upper: v))),
          _toggle('Lowercase (a-z)', _opts.lower,
              (v) => _regenerate(_opts.copyWith(lower: v))),
          _toggle('Digits (0-9)', _opts.digits,
              (v) => _regenerate(_opts.copyWith(digits: v))),
          _toggle('Symbols (!@#…)', _opts.symbols,
              (v) => _regenerate(_opts.copyWith(symbols: v))),
          _toggle('Avoid ambiguous (O0Il1|)', _opts.avoidAmbiguous,
              (v) => _regenerate(_opts.copyWith(avoidAmbiguous: v))),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _regenerate(),
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _password.isEmpty
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(_password);
                      },
                icon: const Icon(Icons.check),
                label: const Text('Use'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
