import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vault_item.dart';
import '../../state/app_controller.dart';
import '../item_visuals.dart';
import '../theme.dart';
import 'totp_tile.dart';

/// The scrollable detail content for one item: badge, fields (copy + reveal),
/// 2FA code, notes, tags, and delete. Reused by the mobile screen and the
/// desktop detail pane (no Scaffold/AppBar of its own).
class ItemDetailView extends ConsumerWidget {
  const ItemDetailView({super.key, required this.item, this.onDeleted});

  final VaultItem item;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 8),
        Center(child: ItemVisuals.badge(item.type, size: 64)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            item.title.isEmpty ? '(no title)' : item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: onSurface),
          ),
        ),
        Center(
          child: Text(ItemVisuals.label(item.type),
              style: TextStyle(color: onSurface.withValues(alpha: 0.5))),
        ),
        const SizedBox(height: 20),
        if (item.username.isNotEmpty ||
            item.password.isNotEmpty ||
            item.url.isNotEmpty)
          InsetSection(
            children: [
              if (item.username.isNotEmpty)
                _CopyRow(label: 'Username', value: item.username),
              if (item.password.isNotEmpty)
                _CopyRow(label: 'Password', value: item.password, secret: true),
              if (item.url.isNotEmpty) _CopyRow(label: 'Website', value: item.url),
            ],
          ),
        if (item.totpSecret != null && item.totpSecret!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          InsetSection(
            header: 'Two-factor',
            children: [
              TotpTile(
                secret: item.totpSecret!,
                onCopy: (code) => _copy(context, ref, code),
              ),
            ],
          ),
        ],
        if (item.notes.isNotEmpty)
          InsetSection(
            header: 'Notes',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(item.notes,
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        if (item.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.tags
                  .map((t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
        if (item.passwordHistory.isNotEmpty)
          InsetSection(
            header: 'Password History',
            children: [
              for (final entry in item.passwordHistory) _HistoryRow(entry: entry),
            ],
          ),
        const SizedBox(height: 8),
        InsetSection(
          children: [
            InkWell(
              onTap: () => _confirmDelete(context, ref),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: Text('Delete',
                      style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _copy(BuildContext context, WidgetRef ref, String value) async {
    await ref.read(clipboardServiceProvider).copySensitive(value);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied — clears in 30s'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"${item.title}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appControllerProvider.notifier).deleteItem(item.id);
      onDeleted?.call();
    }
  }
}

class _HistoryRow extends ConsumerStatefulWidget {
  const _HistoryRow({required this.entry});
  final PasswordHistoryEntry entry;

  @override
  ConsumerState<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends ConsumerState<_HistoryRow> {
  bool _obscure = true;

  String get _date {
    final d = widget.entry.changedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final value = widget.entry.password;
    final display = _obscure ? '•' * value.length.clamp(1, 20) : value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Changed $_date',
                    style: TextStyle(
                        fontSize: 12, color: onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            tooltip: _obscure ? 'Show' : 'Hide',
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                size: 18, color: onSurface.withValues(alpha: 0.5)),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy, size: 16, color: onSurface.withValues(alpha: 0.4)),
            onPressed: () async {
              await ref.read(clipboardServiceProvider).copySensitive(value);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied — clears in 30s'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends ConsumerStatefulWidget {
  const _CopyRow({required this.label, required this.value, this.secret = false});

  final String label;
  final String value;
  final bool secret;

  @override
  ConsumerState<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends ConsumerState<_CopyRow> {
  late bool _obscure = widget.secret;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final display =
        _obscure ? '•' * widget.value.length.clamp(1, 20) : widget.value;
    return InkWell(
      onTap: () async {
        await ref.read(clipboardServiceProvider).copySensitive(widget.value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied — clears in 30s'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 2),
                  Text(display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontFamily: widget.secret ? 'monospace' : null,
                          color: onSurface)),
                ],
              ),
            ),
            if (widget.secret)
              IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20, color: onSurface.withValues(alpha: 0.5)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            Icon(Icons.copy, size: 18, color: onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
