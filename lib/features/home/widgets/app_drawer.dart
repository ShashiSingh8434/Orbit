import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/provider/auth_provider.dart';
import '../../auth/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = AuthService.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          // ── Profile Header ──
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.onPrimary,
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
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

          // ── Menu Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.palette_rounded,
                  label: 'Appearance',
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeBottomSheet(context);
                  },
                ),
                const Divider(height: 32),
                _DrawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming Soon')),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                      applicationLegalese:
                          '© 2025 ${AppConstants.appName}. All rights reserved.',
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Logout Button ──
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              iconColor: colorScheme.error,
              textColor: colorScheme.error,
              onTap: () => _confirmLogout(context),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── Theme Selection Bottom Sheet ──

  void _showThemeBottomSheet(BuildContext context) {
    // Capture provider before opening the sheet — the drawer's context
    // becomes deactivated when MaterialApp rebuilds on theme change.
    final themeProvider = context.read<ThemeProvider>();

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 16),
                  child: Text(
                    'Appearance',
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                ),
                // Use StatefulBuilder so the radio tiles update in the sheet.
                StatefulBuilder(
                  builder: (context, setSheetState) {
                    final current = themeProvider.themeMode;
                    return RadioGroup<ThemeMode>(
                      groupValue: current,
                      onChanged: (mode) {
                        if (mode == null) return;
                        themeProvider.setThemeMode(mode);
                        setSheetState(() {});
                      },
                      child: Column(
                        children: [
                          _ThemeRadioTile(
                            icon: Icons.brightness_auto_rounded,
                            label: 'System',
                            value: ThemeMode.system,
                          ),
                          _ThemeRadioTile(
                            icon: Icons.light_mode_rounded,
                            label: 'Light',
                            value: ThemeMode.light,
                          ),
                          _ThemeRadioTile(
                            icon: Icons.dark_mode_rounded,
                            label: 'Dark',
                            value: ThemeMode.dark,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Logout Confirmation ──

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close drawer
              context.read<AuthProvider>().signOut();
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ??
            (selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor ??
                  (selected ? colorScheme.primary : colorScheme.onSurface),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      selected: selected,
      selectedTileColor: colorScheme.primary.withAlpha(20),
      onTap: onTap,
    );
  }
}

class _ThemeRadioTile extends StatelessWidget {
  const _ThemeRadioTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final ThemeMode value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      value: value,
    );
  }
}

