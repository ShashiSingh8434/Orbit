import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/theme_notifier.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../ai/controllers/ai_settings_controller.dart';
import '../../ai/engine/ai_health_monitor.dart';
import '../../ai/views/ai_setup_wizard.dart';

/// Settings page — theme, AI preferences, account info, sign out.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeNotifierProvider);
    final user = ref.watch(authStateProvider).value;
    final aiSettings = ref.watch(aiSettingsProvider);

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
              backgroundColor: colorScheme.primary,
              child: user?.photoURL == null
                  ? Icon(Icons.person_rounded, color: colorScheme.onPrimary)
                  : null,
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

          // ── AI Preferences Section ─────────────────────────────────────
          _SectionHeader(label: 'AI Preferences'),

          ListTile(
            leading: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
            title: const Text('AI Analytics Dashboard'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.aiAnalytics),
          ),

          // Mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<AiMode>(
              segments: const [
                ButtonSegment(
                  value: AiMode.orbitDefault,
                  label: Text('Orbit Default'),
                  icon: Icon(Icons.auto_awesome_rounded),
                ),
                ButtonSegment(
                  value: AiMode.userKey,
                  label: Text('My API Key'),
                  icon: Icon(Icons.key_rounded),
                ),
              ],
              selected: {aiSettings.mode},
              onSelectionChanged: (selection) {
                ref.read(aiSettingsProvider.notifier).setMode(selection.first);
              },
            ),
          ),

          if (aiSettings.mode == AiMode.orbitDefault) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Using Orbit\'s built-in AI. Connect your own key for unlimited access.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (aiSettings.mode == AiMode.userKey) ...[
            // Preferred provider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<String>(
                segments: aiSettings.providers.values.map((p) {
                  return ButtonSegment(
                    value: p.id,
                    label: Text(p.name),
                  );
                }).toList(),
                selected: {aiSettings.preferredProviderId},
                onSelectionChanged: (selection) {
                  ref
                      .read(aiSettingsProvider.notifier)
                      .setPreferredProvider(selection.first);
                },
              ),
            ),

            // Provider cards
            ...aiSettings.providers.values.map((provider) {
              return _ProviderCard(provider: provider);
            }),
          ],

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

/// Card showing a single provider's status with connect/disconnect actions.
class _ProviderCard extends ConsumerWidget {
  final ProviderInfo provider;

  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = _statusColor(provider.status, colorScheme);
    final statusLabel = _statusLabel(provider.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    provider.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (provider.hasUserKey) ...[
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ref
                            .read(aiSettingsProvider.notifier)
                            .testConnection(provider.id);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(aiSettingsProvider.notifier)
                            .disconnectProvider(provider.id);
                      },
                      icon: Icon(Icons.link_off_rounded,
                          size: 18, color: colorScheme.error),
                      label: Text('Remove',
                          style: TextStyle(color: colorScheme.error)),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: () =>
                          AiSetupWizard.show(context, provider),
                      icon: const Icon(Icons.add_link_rounded, size: 18),
                      label: const Text('Connect'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ProviderHealthStatus status, ColorScheme cs) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return Colors.green;
      case ProviderHealthStatus.rateLimited:
        return Colors.orange;
      case ProviderHealthStatus.offline:
        return cs.error;
      case ProviderHealthStatus.invalidKey:
        return cs.error;
      case ProviderHealthStatus.unknown:
        return cs.onSurfaceVariant;
    }
  }

  String _statusLabel(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return 'Connected';
      case ProviderHealthStatus.rateLimited:
        return 'Rate Limited';
      case ProviderHealthStatus.offline:
        return 'Offline';
      case ProviderHealthStatus.invalidKey:
        return 'Invalid Key';
      case ProviderHealthStatus.unknown:
        return 'Not Connected';
    }
  }
}
