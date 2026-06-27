import 'package:flutter/material.dart';

import 'desktop/desktop_home.dart';
import 'screens/vault_list_screen.dart';

/// Chooses the layout by available width: a three-pane desktop shell on wide
/// windows (macOS), the single-column stack on narrow ones (iPhone/compact).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Min width for the three-pane layout (sidebar 232 + list 320 + detail).
  static const double _desktopBreakpoint = 820;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return const DesktopHome();
        }
        return const VaultListScreen();
      },
    );
  }
}
