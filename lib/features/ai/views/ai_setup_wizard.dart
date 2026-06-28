import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/ai_settings_controller.dart';

/// Bottom-sheet wizard that guides users through connecting an AI provider.
///
/// Steps: Open console → Create key → Paste → Test → Connected ✓
class AiSetupWizard extends ConsumerStatefulWidget {
  final ProviderInfo provider;

  const AiSetupWizard({super.key, required this.provider});

  /// Show the wizard as a modal bottom sheet.
  static Future<void> show(BuildContext context, ProviderInfo provider) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AiSetupWizard(provider: provider),
    );
  }

  @override
  ConsumerState<AiSetupWizard> createState() => _AiSetupWizardState();
}

class _AiSetupWizardState extends ConsumerState<AiSetupWizard> {
  final _keyController = TextEditingController();
  int _step = 0;
  bool _isConnecting = false;
  bool? _connectionResult;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // ── Header ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                'Connect ${widget.provider.name}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.provider.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // ── Steps ───────────────────────────────────────────────────
              _buildStep(
                stepNumber: 1,
                title: 'Get your API key',
                isActive: _step == 0,
                isCompleted: _step > 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open the ${widget.provider.name} console and create a free API key.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final uri = Uri.parse(widget.provider.setupUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                        setState(() => _step = 1);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('Open ${widget.provider.name} Console'),
                    ),
                  ],
                ),
              ),

              _buildStep(
                stepNumber: 2,
                title: 'Paste your API key',
                isActive: _step == 1,
                isCompleted: _step > 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        hintText: 'Paste your API key here',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste_rounded),
                          onPressed: () async {
                            // User can paste manually — this is just a hint icon
                          },
                        ),
                      ),
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _keyController.text.trim().isEmpty
                          ? null
                          : () => setState(() => _step = 2),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),

              _buildStep(
                stepNumber: 3,
                title: 'Test connection',
                isActive: _step == 2,
                isCompleted: _connectionResult == true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isConnecting) ...[
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Testing connection...'),
                        ],
                      ),
                    ] else if (_connectionResult == true) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Connected successfully!',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ] else ...[
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _testAndConnect,
                        child: const Text('Test Connection'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _testAndConnect() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _connectionResult = null;
    });

    final controller = ref.read(aiSettingsProvider.notifier);
    final success = await controller.connectProvider(
      widget.provider.id,
      _keyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _connectionResult = success;
        if (!success) {
          _errorMessage = 'Invalid API key. Please check and try again.';
        }
      });
    }
  }

  Widget _buildStep({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? colorScheme.primary
                  : isActive
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                  : Text(
                      '$stepNumber',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isActive
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive || isCompleted
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isActive) ...[const SizedBox(height: 12), child],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
