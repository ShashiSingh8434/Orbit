import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isLoading
                ? colorScheme.outlineVariant
                : colorScheme.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppConstants.googleImgPath,
                      width: 22,
                      height: 22,
                      semanticLabel: 'Google logo',
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
