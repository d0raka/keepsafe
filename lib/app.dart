import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_controller.dart';
import 'ui/home_screen.dart';
import 'ui/screens/item_edit_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/unlock_screen.dart';
import 'ui/theme.dart';

/// Single app navigator, so the native menu bar can push routes / show dialogs.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Root widget. Routes to the right screen based on the vault [VaultStage].
class KeepSafeApp extends StatelessWidget {
  const KeepSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeepSafe',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => _AppMenuBar(child: child ?? const SizedBox()),
      home: const _Root(),
    );
  }
}

/// Native macOS menu bar (File / Vault / Window). On non-macOS it just renders
/// its child. Items are enabled only when the vault is unlocked.
class _AppMenuBar extends ConsumerWidget {
  const _AppMenuBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked =
        ref.watch(appControllerProvider.select((s) => s.stage)) ==
            VaultStage.unlocked;
    final ctrl = ref.read(appControllerProvider.notifier);

    BuildContext ctx() => appNavigatorKey.currentContext ?? context;
    void toast(String m) => ScaffoldMessenger.of(ctx()).showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'KeepSafe',
          menus: [
            const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.about),
            PlatformMenuItem(
              label: 'Settings…',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: unlocked
                  ? () => Navigator.of(ctx()).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen()))
                  : null,
            ),
            const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.servicesSubmenu),
            const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.hide),
            const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Item',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
              onSelected: unlocked ? () => openItemEditor(ctx()) : null,
            ),
            PlatformMenuItem(
              label: 'Lock Vault',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
              onSelected: unlocked ? ctrl.lock : null,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Vault',
          menus: [
            PlatformMenuItem(
              label: 'Export Vault…',
              onSelected: unlocked
                  ? () async {
                      final path = await ctrl.exportVault();
                      if (path != null) toast('Exported');
                    }
                  : null,
            ),
            PlatformMenuItem(
              label: 'Import Vault…',
              onSelected: unlocked ? () => _import(ctrl, ctx, toast) : null,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.minimizeWindow),
            PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.zoomWindow),
            PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.toggleFullScreen),
          ],
        ),
      ],
      child: child,
    );
  }

  Future<void> _import(
      AppController ctrl, BuildContext Function() ctx, void Function(String) toast) async {
    final ok = await showDialog<bool>(
      context: ctx(),
      builder: (_) => AlertDialog(
        title: const Text('Import vault?'),
        content: const Text(
            'This replaces the vault on this device. You will unlock the '
            'imported vault with its own master password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx(), false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx(), true),
              child: const Text('Choose file…')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ctrl.importVault();
    if (err != null) toast(err);
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(appControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appControllerProvider.select((s) => s.stage), (prev, next) {
      if (next == VaultStage.locked || next == VaultStage.onboarding) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    final stage = ref.watch(appControllerProvider.select((s) => s.stage));

    final Widget child = switch (stage) {
      VaultStage.loading =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      VaultStage.onboarding => const OnboardingScreen(),
      VaultStage.locked => const UnlockScreen(),
      VaultStage.unlocked => const HomeScreen(),
    };

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(appControllerProvider.notifier).poke(),
      child: child,
    );
  }
}
