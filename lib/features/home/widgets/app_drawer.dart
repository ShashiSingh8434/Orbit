import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;

    return Drawer(
      child: Column(
        children: [
          // ── Profile Header ──────────────────────────────────────────────
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.onPrimary,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: colorScheme.primary,
                    )
                  : null,
            ),
            accountName: Text(
              user?.displayName ?? 'Orbit User',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimary.withAlpha(200),
              ),
            ),
          ),

          // ── Navigation Items ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                // Core
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected:
                      GoRouterState.of(context).matchedLocation ==
                      AppRoutes.home,
                  onTap: () {
                    Navigator.pop(context);
                    context.go(AppRoutes.home);
                  },
                ),

                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    'FEATURES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                _DrawerItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Reflections',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.reflections);
                  },
                ),
                _DrawerItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.tasks);
                  },
                ),
                _DrawerItem(
                  icon: Icons.gavel_rounded,
                  label: 'Decisions',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.decisions);
                  },
                ),
                _DrawerItem(
                  icon: Icons.event,
                  label: 'Events',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.events);
                  },
                ),
                _DrawerItem(
                  icon: Icons.lightbulb_outline,
                  label: 'Learnings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.learnings);
                  },
                ),

                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    'MORE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                _DrawerItem(
                  icon: Icons.help_outline_rounded,
                  label: 'How to use Orbit',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.guide);
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.settings);
                  },
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drawer Item ───────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: (selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: (selected ? colorScheme.primary : colorScheme.onSurface),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: colorScheme.primary.withAlpha(20),
      onTap: onTap,
    );
  }
}
