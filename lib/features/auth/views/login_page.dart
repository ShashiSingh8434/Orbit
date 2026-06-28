import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/orbit_logo.dart';
import '../controllers/auth_controller.dart';
import '../widgets/error_banner.dart';
import '../widgets/google_sign_in_slider.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch the controller state for loading / error info
    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;
    final errorMessage = controllerState.error?.toString();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive horizontal padding
            final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 28.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      const OrbitLogo(size: 100),
                      const SizedBox(height: 40),
                      Text(
                        'Welcome to ${AppConstants.appName}',
                        style: theme.textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.appTagline,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      ErrorBanner(
                        message: errorMessage,
                        onDismiss: () => ref
                            .read(authControllerProvider.notifier)
                            .clearError(),
                      ),

                      // ── Slide to Sign In Button ──
                      SlideToSignInButton(
                        isLoading: isLoading,
                        onSignIn: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                      ),

                      SizedBox(height: 48 + bottomPadding),

                      Text(
                        'Powered by ${AppConstants.appName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withAlpha(120),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
