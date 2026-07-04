import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/theme_notifier.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/ai/controllers/ai_settings_controller.dart';
import '../../../core/ai/engine/ai_health_monitor.dart';
import '../../../core/ai/views/ai_setup_wizard.dart';

/// Settings page — theme, AI preferences, account info, sign out.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  AiMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeNotifierProvider);
    final user = ref.watch(authStateProvider).value;
    final aiSettings = ref.watch(aiSettingsProvider);

    _selectedMode ??= aiSettings.mode;

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
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  ref.read(themeNotifierProvider.notifier).setThemeMode(value);
                }
              },
              child: const Column(
                children: [
                  _ThemeOptionTile(
                    icon: Icons.brightness_auto_rounded,
                    label: 'System Default',
                    value: ThemeMode.system,
                  ),
                  _ThemeOptionTile(
                    icon: Icons.light_mode_rounded,
                    label: 'Light Mode',
                    value: ThemeMode.light,
                  ),
                  _ThemeOptionTile(
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark Mode',
                    value: ThemeMode.dark,
                  ),
                ],
              ),
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
              selected: {_selectedMode!},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedMode = selection.first;
                });
              },
            ),
          ),

          if (_selectedMode != aiSettings.mode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FilledButton.icon(
                onPressed: () async {
                  if (_selectedMode == AiMode.userKey) {
                    final hasAnyKey = aiSettings.providers.values.any(
                      (p) => p.hasUserKey,
                    );
                    if (!hasAnyKey) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('No API Keys Connected'),
                          content: const Text(
                            'Please connect at least one AI provider (Google Gemini or Groq) with your own API key before switching to My API Key mode.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                  }
                  await ref
                      .read(aiSettingsProvider.notifier)
                      .setMode(_selectedMode!);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save AI Mode'),
              ),
            ),

          if (_selectedMode == AiMode.orbitDefault) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
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

          if (_selectedMode == AiMode.userKey) ...[
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

          // ListTile(
          //   leading: const Icon(Icons.gavel_rounded),
          //   title: const Text('Licences'),
          //   trailing: const Icon(Icons.chevron_right_rounded),
          //   onTap: () => showLicensePage(
          //     context: context,
          //     applicationName: AppConstants.appName,
          //     applicationVersion: AppConstants.appVersion,
          //   ),
          // ),
          const Divider(),

          // ── Sign Out ──────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.logout_rounded, color: colorScheme.error),
            title: Text('Sign Out', style: TextStyle(color: colorScheme.error)),
            onTap: () => _confirmSignOut(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
            title: Text('Delete Account', style: TextStyle(color: colorScheme.error)),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
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

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\n'
          'This action will remove all your data from the Orbit cloud database '
          'and is completely irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).deleteAccount();
            },
            child: Text(
              'Delete Permanently',
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
  });

  final IconData icon;
  final String label;
  final ThemeMode value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      value: value,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
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

    final statusColor = _statusColor(
      provider.status,
      colorScheme,
      provider.hasUserKey,
    );
    final statusLabel = _statusLabel(provider.status, provider.hasUserKey);

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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                      icon: Icon(
                        Icons.link_off_rounded,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      label: Text(
                        'Remove',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: () => AiSetupWizard.show(context, provider),
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

  Color _statusColor(
    ProviderHealthStatus status,
    ColorScheme cs,
    bool hasUserKey,
  ) {
    if (!hasUserKey) return cs.onSurfaceVariant;
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

  String _statusLabel(ProviderHealthStatus status, bool hasUserKey) {
    if (!hasUserKey) return 'Not Connected';
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
