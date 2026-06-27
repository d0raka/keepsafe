import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';
import '../widgets/item_detail_view.dart';
import 'item_edit_screen.dart';

/// Mobile/full-screen item detail. Wraps the shared [ItemDetailView] in a
/// Scaffold with favorite + edit actions.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(appControllerProvider.select((s) => s.items));
    final item = items.where((i) => i.id == itemId).firstOrNull;

    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            tooltip: item.favorite ? 'Unfavorite' : 'Favorite',
            icon: Icon(
              item.favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.favorite ? const Color(0xFFFFCC00) : null,
            ),
            onPressed: () =>
                ref.read(appControllerProvider.notifier).toggleFavorite(item.id),
          ),
          TextButton(
            onPressed: () => openItemEditor(context, existing: item),
            child: const Text('Edit'),
          ),
        ],
      ),
      body: ItemDetailView(
        item: item,
        onDeleted: () {
          if (context.mounted) Navigator.of(context).maybePop();
        },
      ),
    );
  }
}
