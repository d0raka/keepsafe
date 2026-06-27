import 'package:flutter/material.dart';

import '../../services/password_generator.dart';

/// A thin strength meter + label driven by [PasswordStrength.estimate].
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final s = PasswordStrength.estimate(password);
    final color = switch (s.label) {
      'Weak' => Colors.red,
      'Fair' => Colors.orange,
      'Good' => Colors.lightGreen,
      'Strong' => Colors.green,
      _ => Colors.grey,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s.fraction,
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (s.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${s.label} · ${s.bits.round()} bits',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
