import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/orbit_logo.dart';
import '../controllers/auth_controller.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = _buildFade(0.0, 0.35);
    _logoSlide = _buildSlide(0.0, 0.35);

    _titleFade = _buildFade(0.15, 0.50);
    _titleSlide = _buildSlide(0.15, 0.50);

    _subtitleFade = _buildFade(0.30, 0.60);
    _subtitleSlide = _buildSlide(0.30, 0.60);

    _buttonFade = _buildFade(0.45, 0.75);
    _buttonSlide = _buildSlide(0.45, 0.75);

    _footerFade = _buildFade(0.65, 1.0);

    _controller.forward();
  }

  Animation<double> _buildFade(double begin, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _buildSlide(double begin, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                      // ── Logo ──
                      SlideTransition(
                        position: _logoSlide,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: const OrbitLogo(size: 100),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Title ──
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Text(
                            'Welcome to ${AppConstants.appName}',
                            style: theme.textTheme.headlineLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Subtitle ──
                      SlideTransition(
                        position: _subtitleSlide,
                        child: FadeTransition(
                          opacity: _subtitleFade,
                          child: Text(
                            AppConstants.appTagline,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ── Error Message ──
                      _ErrorBanner(
                        message: errorMessage,
                        onDismiss: () => ref.read(authControllerProvider.notifier).clearError(),
                      ),

                      // ── Google Sign-In Button ──
                      SlideTransition(
                        position: _buttonSlide,
                        child: FadeTransition(
                          opacity: _buttonFade,
                          child: GoogleSignInButton(
                            isLoading: isLoading,
                            onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                          ),
                        ),
                      ),

                      SizedBox(height: 48 + bottomPadding),

                      // ── Footer ──
                      FadeTransition(
                        opacity: _footerFade,
                        child: Text(
                          'Powered by ${AppConstants.appName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withAlpha(120),
                          ),
                          textAlign: TextAlign.center,
                        ),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.error.withAlpha(60),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                  ),
                ),
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colorScheme.onErrorContainer.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
