import 'package:flutter/material.dart';

import '../data/models/vault_item.dart';

/// Icon + tint per item type, in the spirit of SF Symbols on a tinted circle.
class ItemVisuals {
  ItemVisuals._();

  static IconData icon(VaultItemType type) => switch (type) {
        VaultItemType.login => Icons.language,
        VaultItemType.secureNote => Icons.sticky_note_2_outlined,
        VaultItemType.card => Icons.credit_card,
        VaultItemType.identity => Icons.badge_outlined,
      };

  static Color color(VaultItemType type) => switch (type) {
        VaultItemType.login => const Color(0xFF007AFF), // blue
        VaultItemType.secureNote => const Color(0xFFFF9500), // orange
        VaultItemType.card => const Color(0xFF34C759), // green
        VaultItemType.identity => const Color(0xFFAF52DE), // purple
      };

  static String label(VaultItemType type) => switch (type) {
        VaultItemType.login => 'Login',
        VaultItemType.secureNote => 'Secure note',
        VaultItemType.card => 'Card',
        VaultItemType.identity => 'Identity',
      };

  /// A rounded-square tinted icon badge, like an app/list glyph.
  static Widget badge(VaultItemType type, {double size = 36}) {
    final c = color(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, Color.lerp(c, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon(type), color: Colors.white, size: size * 0.55),
    );
  }
}
