import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/app_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = AuthService.instance.currentUser;
    final firstName = _extractFirstName(user?.displayName);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Greeting ──
              Icon(
                Icons.rocket_launch_rounded,
                size: 64,
                color: colorScheme.primary.withAlpha(180),
              ),
              const SizedBox(height: 24),
              Text(
                firstName != null ? 'Hello, $firstName 👋' : 'Welcome 👋',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your personal orbit starts here.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
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
