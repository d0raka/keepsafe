import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vault_item.dart';
import '../../state/app_controller.dart';
import '../item_visuals.dart';
import '../theme.dart';
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';
import 'settings_screen.dart';

/// Filters [items] by [query] and returns a fresh, title-sorted list.
///
/// Always builds a NEW modifiable list before sorting — the source may be
/// unmodifiable (an empty vault's `const []`), and sorting in place would throw
/// "Cannot modify an unmodifiable list".
List<VaultItem> filterAndSortVaultItems(List<VaultItem> items, String query) {
  final q = query.trim().toLowerCase();
  return items
      .where((i) =>
          q.isEmpty ||
          i.title.toLowerCase().contains(q) ||
          i.username.toLowerCase().contains(q) ||
          i.url.toLowerCase().contains(q) ||
          i.tags.any((t) => t.toLowerCase().contains(q)))
      .toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
}

/// Main screen after unlock: searchable, grouped list of vault items.
class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(appControllerProvider.select((s) => s.items));
    final filtered = filterAndSortVaultItems(items, _query);
    final favorites = filtered.where((i) => i.favorite).toList();
    final others = filtered.where((i) => !i.favorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeepSafe'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(appControllerProvider.notifier).lock(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openItemEditor(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Search',
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(Theme.of(context).cardColor),
              leading: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(hasItems: items.isNotEmpty)
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      if (favorites.isNotEmpty)
                        InsetSection(
                          header: 'Favorites',
                          children: [
                            for (final i in favorites) _ItemRow(item: i),
                          ],
                        ),
                      if (others.isNotEmpty)
                        InsetSection(
                          header: favorites.isEmpty ? null : 'All Items',
                          children: [
                            for (final i in others) _ItemRow(item: i),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final VaultItem item;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            ItemVisuals.badge(item.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title.isEmpty ? '(no title)' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  if (item.username.isNotEmpty)
                    Text(item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            if (item.favorite)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded,
                    size: 18, color: Color(0xFFFFCC00)),
              ),
            Icon(Icons.chevron_right,
                size: 20, color: onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasItems});
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasItems ? Icons.search_off_rounded : Icons.key_off_outlined,
              size: 60, color: onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          Text(hasItems ? 'No matches' : 'No items yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(hasItems ? 'Try a different search' : 'Tap + to add your first',
              style: TextStyle(color: onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
