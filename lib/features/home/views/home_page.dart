import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../app/router/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/app_drawer.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;
    final firstName = _extractFirstName(user?.displayName);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName != null ? 'Hello, $firstName 👋' : 'Welcome 👋',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your personal orbit starts here.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Quick Actions Grid ────────────────────────────────────
              _QuickActionsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  static String? _extractFirstName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return null;
    return displayName.trim().split(' ').first;
  }
}

// ── Quick Actions Grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Reflect',
        subtitle: 'Capture thoughts',
        color: const Color(0xFF6C63FF),
        route: AppRoutes.reflections,
      ),
      _QuickAction(
        icon: Icons.psychology_rounded,
        label: 'Knowledge',
        subtitle: 'AI insights',
        color: const Color(0xFF00BCD4),
        route: AppRoutes.knowledge,
      ),
      _QuickAction(
        icon: Icons.task_alt_rounded,
        label: 'Tasks',
        subtitle: 'Stay on track',
        color: const Color(0xFF4CAF50),
        route: AppRoutes.tasks,
      ),
      _QuickAction(
        icon: Icons.settings_rounded,
        label: 'Settings',
        subtitle: 'Preferences',
        color: const Color(0xFFFF7043),
        route: AppRoutes.settings,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => context.push(action.route),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    action.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
