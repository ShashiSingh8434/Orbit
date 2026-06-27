import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/orbit_logo.dart';
import '../controllers/auth_controller.dart';

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

                      _ErrorBanner(
                        message: errorMessage,
                        onDismiss: () => ref.read(authControllerProvider.notifier).clearError(),
                      ),

                      // ── Slide to Sign In Button ──
                      _SlideToSignInButton(
                        isLoading: isLoading,
                        onSignIn: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
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

class _SlideToSignInButton extends StatefulWidget {
  final VoidCallback onSignIn;
  final bool isLoading;

  const _SlideToSignInButton({
    required this.onSignIn,
    required this.isLoading,
  });

  @override
  State<_SlideToSignInButton> createState() => _SlideToSignInButtonState();
}

class _SlideToSignInButtonState extends State<_SlideToSignInButton> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isFinished = false;
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springController.addListener(() {
      setState(() {
        _dragPosition = _springAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double maxWidth) {
    if (widget.isLoading || _isFinished) return;
    
    setState(() {
      _dragPosition += details.delta.dx;
      if (_dragPosition < 0) _dragPosition = 0;
      if (_dragPosition > maxWidth - 56) _dragPosition = maxWidth - 56; // 56 is ball size
    });
  }

  void _onPanEnd(DragEndDetails details, double maxWidth) {
    if (widget.isLoading || _isFinished) return;
    
    if (_dragPosition > (maxWidth - 56) * 0.8) {
      // Trigger sign in
      setState(() {
        _dragPosition = maxWidth - 56;
        _isFinished = true;
      });
      widget.onSignIn();
    } else {
      // Snap back
      _springAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      );
      _springController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(_SlideToSignInButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading && _isFinished) {
      // Reset if it stopped loading (e.g. failed login or dialog closed)
      _isFinished = false;
      _springAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      );
      _springController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const ballSize = 56.0;
        
        return Container(
          height: ballSize,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ballSize / 2),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              // Filled track background when sliding
              Container(
                width: _dragPosition + ballSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(50),
                  borderRadius: BorderRadius.circular(ballSize / 2),
                ),
              ),
              
              // Text
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: ballSize * 0.5),
                  child: Opacity(
                    // Fade out text as we drag
                    opacity: (1.0 - (_dragPosition / (maxWidth - ballSize))).clamp(0.0, 1.0),
                    child: Text(
                      'Slide to Sign in',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Draggable Ball
              Positioned(
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (d) => _onPanUpdate(d, maxWidth),
                  onPanEnd: (d) => _onPanEnd(d, maxWidth),
                  child: Container(
                    width: ballSize,
                    height: ballSize,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Image.asset(
                                AppConstants.googleImgPath,
                                width: 22,
                                height: 22,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
