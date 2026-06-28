import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

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
              border: Border.all(color: colorScheme.error.withAlpha(60)),
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
