import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vault_item.dart';
import '../../services/security_analyzer.dart';
import '../../state/app_controller.dart';
import '../item_visuals.dart';
import '../screens/item_edit_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/item_detail_view.dart';
import 'desktop_sidebar.dart';
import 'security_view.dart';

/// macOS three-pane layout: sidebar · list · detail, with keyboard shortcuts.
class DesktopHome extends ConsumerStatefulWidget {
  const DesktopHome({super.key});

  @override
  ConsumerState<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends ConsumerState<DesktopHome> {
  SidebarFilter _filter = SidebarFilter.all;
  String? _selectedTag;
  String? _selectedId;
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _newItem() => openItemEditor(context);
  void _openSettings() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(appControllerProvider.select((s) => s.items));
    final report = SecurityAnalyzer.analyze(items);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newItem,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            ref.read(appControllerProvider.notifier).lock,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _openSettings,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              DesktopSidebar(
                selected: _filter,
                selectedTag: _selectedTag,
                items: items,
                securityIssues: report.issueCount,
                onSelect: (f) => setState(() {
                  _filter = f;
                  _selectedTag = null;
                  _selectedId = null;
                }),
                onSelectTag: (t) => setState(() {
                  _filter = SidebarFilter.tag;
                  _selectedTag = t;
                  _selectedId = null;
                }),
                onNewItem: _newItem,
                onSettings: _openSettings,
                onLock: ref.read(appControllerProvider.notifier).lock,
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: 320, child: _listPane(items, report)),
              const VerticalDivider(width: 1),
              Expanded(child: _detailPane(items, report)),
            ],
          ),
        ),
      ),
    );
  }

  // --- List pane ---

  Widget _listPane(List<VaultItem> items, SecurityReport report) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: _SearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: _listChildren(items, report),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _listChildren(List<VaultItem> items, SecurityReport report) {
    final q = _query.trim().toLowerCase();
    bool matches(VaultItem i) =>
        q.isEmpty ||
        i.title.toLowerCase().contains(q) ||
        i.username.toLowerCase().contains(q) ||
        i.url.toLowerCase().contains(q);

    if (_filter == SidebarFilter.security) {
      final groups = <(String, List<VaultItem>)>[
        ('Weak Passwords', report.weak),
        ('Reused Passwords', report.reused),
        ('Not Protected by 2FA', report.noTwoFactor),
      ];
      final children = <Widget>[];
      for (final (label, list) in groups) {
        final filtered = list.where(matches).toList();
        if (filtered.isEmpty) continue;
        children.add(_GroupHeader(label: label, count: filtered.length));
        children.addAll(filtered.map(_row));
      }
      if (children.isEmpty) {
        children.add(_hint(report.isClean ? 'No issues 🎉' : 'No matches'));
      }
      return children;
    }

    Iterable<VaultItem> base = switch (_filter) {
      SidebarFilter.favorites => items.where((i) => i.favorite),
      SidebarFilter.tag =>
        items.where((i) => i.tags.contains(_selectedTag)),
      _ when _filter.type != null =>
        items.where((i) => i.type == _filter.type),
      _ => items,
    };

    final list = base.where(matches).toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    if (list.isEmpty) return [_hint('No items')];
    return list.map(_row).toList();
  }

  Widget _row(VaultItem item) => _ListRow(
        item: item,
        selected: item.id == _selectedId,
        onTap: () => setState(() => _selectedId = item.id),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Text(text,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4))),
        ),
      );

  // --- Detail pane ---

  Widget _detailPane(List<VaultItem> items, SecurityReport report) {
    final selected = _selectedId == null
        ? null
        : items.where((i) => i.id == _selectedId).firstOrNull;

    Widget content;
    if (selected != null) {
      content = Column(
        children: [
          _DetailToolbar(item: selected),
          const Divider(height: 1),
          Expanded(
            child: ItemDetailView(
              key: ValueKey(selected.id),
              item: selected,
              onDeleted: () => setState(() => _selectedId = null),
            ),
          ),
        ],
      );
    } else if (_filter == SidebarFilter.security) {
      content = SecurityOverview(report: report);
    } else {
      content = _EmptyDetail();
    }

    return Container(color: Theme.of(context).cardColor, child: content);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller, required this.focusNode, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE3E3E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.search,
              size: 17,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'Search',
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Text('${label.toUpperCase()}  ·  $count',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
    );
  }
}

class _ListRow extends StatefulWidget {
  const _ListRow(
      {required this.item, required this.selected, required this.onTap});
  final VaultItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final item = widget.item;
    final bg = widget.selected
        ? accent
        : _hovered
            ? onSurface.withValues(alpha: 0.05)
            : Colors.transparent;
    final fg = widget.selected ? Colors.white : onSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              ItemVisuals.badge(item.type, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title.isEmpty ? '(no title)' : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: fg)),
                    if (item.username.isNotEmpty)
                      Text(item.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: widget.selected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              if (item.favorite)
                Icon(Icons.star_rounded,
                    size: 15,
                    color: widget.selected
                        ? Colors.white
                        : const Color(0xFFFFCC00)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailToolbar extends ConsumerWidget {
  const _DetailToolbar({required this.item});
  final VaultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: item.favorite ? 'Unfavorite' : 'Favorite',
              icon: Icon(
                item.favorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: item.favorite ? const Color(0xFFFFCC00) : null,
              ),
              onPressed: () => ref
                  .read(appControllerProvider.notifier)
                  .toggleFavorite(item.id),
            ),
            FilledButton.tonal(
              onPressed: () => openItemEditor(context, existing: item),
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 56, color: onSurface.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Text('Select an item',
              style: TextStyle(
                  fontSize: 16, color: onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
