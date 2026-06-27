import 'package:flutter/material.dart';

import '../../data/models/vault_item.dart';
import '../item_visuals.dart';
import '../theme.dart';

/// Which collection the desktop list pane is showing.
enum SidebarFilter {
  all,
  favorites,
  security,
  login,
  secureNote,
  card,
  identity,
  tag,
}

extension SidebarFilterX on SidebarFilter {
  VaultItemType? get type => switch (this) {
        SidebarFilter.login => VaultItemType.login,
        SidebarFilter.secureNote => VaultItemType.secureNote,
        SidebarFilter.card => VaultItemType.card,
        SidebarFilter.identity => VaultItemType.identity,
        _ => null,
      };
}

/// The left navigation pane of the desktop layout.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.selected,
    required this.selectedTag,
    required this.items,
    required this.securityIssues,
    required this.onSelect,
    required this.onSelectTag,
    required this.onNewItem,
    required this.onSettings,
    required this.onLock,
  });

  final SidebarFilter selected;
  final String? selectedTag;
  final List<VaultItem> items;
  final int securityIssues;
  final ValueChanged<SidebarFilter> onSelect;
  final ValueChanged<String> onSelectTag;
  final VoidCallback onNewItem;
  final VoidCallback onSettings;
  final VoidCallback onLock;

  int _count(VaultItemType t) => items.where((i) => i.type == t).length;

  Map<String, int> _tagCounts() {
    final counts = <String, int>{};
    for (final i in items) {
      for (final t in i.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161618) : const Color(0xFFEAEAEE);

    return Container(
      width: 232,
      color: bg,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A84FF), Color(0xFF0040DD)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 15),
                ),
                const SizedBox(width: 9),
                Text('KeepSafe',
                    style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _SideRow(
                  icon: Icons.grid_view_rounded,
                  iconColor: const Color(0xFF8E8E93),
                  label: 'All Items',
                  trailing: '${items.length}',
                  selected: selected == SidebarFilter.all,
                  onTap: () => onSelect(SidebarFilter.all),
                ),
                _SideRow(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFCC00),
                  label: 'Favorites',
                  trailing: '${items.where((i) => i.favorite).length}',
                  selected: selected == SidebarFilter.favorites,
                  onTap: () => onSelect(SidebarFilter.favorites),
                ),
                _SideRow(
                  icon: Icons.health_and_safety_rounded,
                  iconColor: securityIssues > 0
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF34C759),
                  label: 'Security',
                  badge: securityIssues > 0 ? '$securityIssues' : null,
                  selected: selected == SidebarFilter.security,
                  onTap: () => onSelect(SidebarFilter.security),
                ),
                const _SectionLabel('Categories'),
                _SideRow(
                  icon: ItemVisuals.icon(VaultItemType.login),
                  iconColor: ItemVisuals.color(VaultItemType.login),
                  label: 'Logins',
                  trailing: '${_count(VaultItemType.login)}',
                  selected: selected == SidebarFilter.login,
                  onTap: () => onSelect(SidebarFilter.login),
                ),
                _SideRow(
                  icon: ItemVisuals.icon(VaultItemType.secureNote),
                  iconColor: ItemVisuals.color(VaultItemType.secureNote),
                  label: 'Secure Notes',
                  trailing: '${_count(VaultItemType.secureNote)}',
                  selected: selected == SidebarFilter.secureNote,
                  onTap: () => onSelect(SidebarFilter.secureNote),
                ),
                _SideRow(
                  icon: ItemVisuals.icon(VaultItemType.card),
                  iconColor: ItemVisuals.color(VaultItemType.card),
                  label: 'Cards',
                  trailing: '${_count(VaultItemType.card)}',
                  selected: selected == SidebarFilter.card,
                  onTap: () => onSelect(SidebarFilter.card),
                ),
                _SideRow(
                  icon: ItemVisuals.icon(VaultItemType.identity),
                  iconColor: ItemVisuals.color(VaultItemType.identity),
                  label: 'Identities',
                  trailing: '${_count(VaultItemType.identity)}',
                  selected: selected == SidebarFilter.identity,
                  onTap: () => onSelect(SidebarFilter.identity),
                ),
                ..._buildTagRows(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: Column(
              children: [
                _SideRow(
                  icon: Icons.add_circle,
                  iconColor: Theme.of(context).colorScheme.primary,
                  label: 'New Item',
                  onTap: onNewItem,
                ),
                _SideRow(
                  icon: Icons.settings,
                  iconColor: const Color(0xFF8E8E93),
                  label: 'Settings',
                  onTap: onSettings,
                ),
                _SideRow(
                  icon: Icons.lock,
                  iconColor: const Color(0xFF8E8E93),
                  label: 'Lock',
                  onTap: onLock,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTagRows() {
    final counts = _tagCounts();
    if (counts.isEmpty) return const [];
    final tags = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      const _SectionLabel('Tags'),
      for (final t in tags)
        _SideRow(
          icon: Icons.label_outline,
          iconColor: const Color(0xFF8E8E93),
          label: t,
          trailing: '${counts[t]}',
          selected: selected == SidebarFilter.tag && selectedTag == t,
          onTap: () => onSelectTag(t),
        ),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _SideRow extends StatefulWidget {
  const _SideRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.badge,
    this.selected = false,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SideRow> createState() => _SideRowState();
}

class _SideRowState extends State<_SideRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bg = widget.selected
        ? accent
        : _hovered
            ? onSurface.withValues(alpha: 0.06)
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
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: widget.selected ? Colors.white : widget.iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg)),
              ),
              if (widget.badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(widget.badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                )
              else if (widget.trailing != null)
                Text(widget.trailing!,
                    style: TextStyle(
                        fontSize: 13,
                        color: widget.selected
                            ? Colors.white.withValues(alpha: 0.8)
                            : onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
    );
  }
}
