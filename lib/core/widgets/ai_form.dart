import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../voice/voice_input_button.dart';
import '../voice/voice_provider.dart';
import '../voice/voice_controller.dart';

class AiForm extends ConsumerStatefulWidget {
  final TextEditingController promptCtrl;
  final bool isLoading;
  final String? error;
  final String hintText;
  final VoidCallback onSubmit;
  final String? infoText;
  final String? buttonLabel;

  const AiForm({
    super.key,
    required this.promptCtrl,
    required this.isLoading,
    required this.error,
    required this.hintText,
    required this.onSubmit,
    this.infoText,
    this.buttonLabel,
  });

  @override
  ConsumerState<AiForm> createState() => _AiFormState();
}

class _AiFormState extends ConsumerState<AiForm> {
  late final ScrollController _scrollController;
  late final VoiceController _voiceController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _voiceController = ref.read(voiceControllerProvider.notifier);
  }

  @override
  void dispose() {
    _voiceController.destroy();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.primary.withAlpha(60)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.infoText ??
                      'Describe it in plain language — Orbit AI will extract and structure it for you.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: widget.promptCtrl,
          scrollController: _scrollController,
          autofocus: true,
          minLines: 5,
          maxLines: 8,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.outline.withAlpha(120)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.error!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton.icon(
                        onPressed: () {
                          // Stop voice input listening if it's active
                          _voiceController.stop();
                          widget.onSubmit();
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          widget.buttonLabel ?? 'Extract with AI',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            VoiceInputButton(
              controller: widget.promptCtrl,
              appendMode: true,
              buttonSize: 52,
              pauseFor: const Duration(seconds: 10),
              tooltip: 'Dictate your prompt',
              onTextChanged: (_) {
                // Scroll to the bottom when voice input updates text
                if (_scrollController.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
