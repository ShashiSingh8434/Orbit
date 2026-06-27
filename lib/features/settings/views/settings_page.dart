import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_notifier.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';

/// Settings page — theme selection, account info, sign out.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeNotifierProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account Section ───────────────────────────────────────────
          _SectionHeader(label: 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person_rounded, color: colorScheme.onPrimary)
                  : null,
              backgroundColor: colorScheme.primary,
            ),
            title: Text(user?.displayName ?? 'Orbit User'),
            subtitle: Text(user?.email ?? ''),
          ),

          const Divider(),

          // ── Appearance Section ────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _ThemeOptionTile(
                  icon: Icons.brightness_auto_rounded,
                  label: 'System Default',
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (m) =>
                      ref.read(themeNotifierProvider.notifier).setThemeMode(m!),
                ),
                _ThemeOptionTile(
                  icon: Icons.light_mode_rounded,
                  label: 'Light Mode',
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (m) =>
                      ref.read(themeNotifierProvider.notifier).setThemeMode(m!),
                ),
                _ThemeOptionTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark Mode',
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (m) =>
                      ref.read(themeNotifierProvider.notifier).setThemeMode(m!),
                ),
              ],
            ),
          ),

          const Divider(),

          // ── About ────────────────────────────────────────────────────
          _SectionHeader(label: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing: Text(
              AppConstants.appVersion,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('Licences'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            ),
          ),

          const Divider(),

          // ── Sign Out ──────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.logout_rounded, color: colorScheme.error),
            title: Text(
              'Sign Out',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode?> onChanged;

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
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
