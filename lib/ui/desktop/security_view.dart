import 'package:flutter/material.dart';

import '../../services/security_analyzer.dart';
import '../theme.dart';

/// The Security ("Password Health") overview shown in the detail pane.
class SecurityOverview extends StatelessWidget {
  const SecurityOverview({super.key, required this.report});

  final SecurityReport report;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      children: [
        Text('Security',
            style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: onSurface)),
        const SizedBox(height: 6),
        Text(
          report.isClean
              ? 'No issues found. Your passwords look healthy.'
              : '${report.issueCount} recommendation${report.issueCount == 1 ? '' : 's'} to review.',
          style: TextStyle(fontSize: 15, color: onSurface.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 24),
        if (report.isClean)
          _CleanState()
        else ...[
          _StatCard(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFF9500),
            title: 'Weak passwords',
            count: report.weak.length,
            description: 'Short or low-variety passwords that are easier to crack.',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.content_copy_rounded,
            color: const Color(0xFFFF3B30),
            title: 'Reused passwords',
            count: report.reused.length,
            description: 'The same password is used by more than one item.',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.shield_outlined,
            color: const Color(0xFF007AFF),
            title: 'Not protected by 2FA',
            count: report.noTwoFactor.length,
            description: 'Logins without a two-factor (verification code) secret.',
          ),
          const SizedBox(height: 20),
          Text('Select an item in the list to fix it.',
              style:
                  TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.4))),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final String description;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: TextStyle(
                        fontSize: 13,
                        color: onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$count',
              style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: count == 0 ? const Color(0xFF34C759) : color)),
        ],
      ),
    );
  }
}

class _CleanState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF34C759), size: 52),
        ),
        const SizedBox(height: 16),
        const Text('All clear',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
