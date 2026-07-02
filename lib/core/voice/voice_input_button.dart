import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_provider.dart';
import 'voice_controller.dart';

/// A self-contained microphone button that drives voice-to-text for any
/// [TextEditingController].
///
/// ## Minimal usage
/// ```dart
/// VoiceInputButton(controller: myController)
/// ```
///
/// ## With append/replace control
/// ```dart
/// VoiceInputButton(
///   controller: myController,
///   appendMode: false, // replace existing text
/// )
/// ```
///
/// ## With custom duration and callbacks
/// ```dart
/// VoiceInputButton(
///   controller: myController,
///   listenFor: const Duration(minutes: 10),
///   pauseFor:  const Duration(seconds: 6),
///   onListeningStarted: () => print('🎙 started'),
///   onListeningStopped: () => print('🎙 stopped'),
///   onTextChanged:      (t) => print('text: $t'),
///   onError:            (e) => print('error: $e'),
/// )
/// ```
///
/// ## Theme behaviour
/// - Idle:      [ColorScheme.surfaceContainerHighest] background.
/// - Listening: [ColorScheme.errorContainer] background + pulse animation.
/// - Unavailable / initialising: button is disabled.
///
/// No colours are hardcoded.
class VoiceInputButton extends ConsumerStatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.controller,

    // ── Behaviour ──
    this.appendMode = true,
    this.listenFor = const Duration(minutes: 5),
    this.pauseFor = const Duration(seconds: 8),
    this.localeId,

    // ── Callbacks ──
    this.onListeningStarted,
    this.onListeningStopped,
    this.onTextChanged,
    this.onError,

    // ── Appearance ──
    this.iconSize = 22,
    this.buttonSize = 40,
    this.tooltip,
  });

  /// The text field this button will write into.
  final TextEditingController controller;

  /// When true (default) recognised words are appended after existing text.
  /// When false the entire field is replaced by each recognition session.
  final bool appendMode;

  /// Maximum continuous listening duration before the mic auto-closes.
  /// Defaults to 5 minutes — generous for long dictation.
  final Duration listenFor;

  /// Silence duration before the mic auto-closes. Defaults to 8 seconds so
  /// users have time to think between sentences.
  final Duration pauseFor;

  /// BCP-47 locale string (e.g. "hi-IN", "en-US"). When null the device's
  /// default locale is used. Pass a value to enable language selection.
  final String? localeId;

  /// Called immediately when the microphone opens.
  final VoidCallback? onListeningStarted;

  /// Called when the microphone closes (user tap or timeout).
  final VoidCallback? onListeningStopped;

  /// Called after every partial or final text update.
  final void Function(String text)? onTextChanged;

  /// Called if the STT engine reports an error.
  final void Function(String error)? onError;

  /// Icon size in logical pixels.
  final double iconSize;

  /// Outer button diameter in logical pixels.
  final double buttonSize;

  /// Custom tooltip text. Falls back to a sensible default.
  final String? tooltip;

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  late final VoiceController _voiceController;

  @override
  void initState() {
    super.initState();
    _voiceController = ref.read(voiceControllerProvider.notifier);
  }

  @override
  void dispose() {
    // Cancel listening immediately when this button is removed from the widget tree
    // (e.g. when navigating away from the page).
    if (_voiceController.isListening) {
      _voiceController.destroy();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final bool processing = voiceState.isProcessing;
    final bool disabled = voiceState.isInitialising || !voiceState.isAvailable || processing;
    final bool listening = voiceState.isListening;

    final bgColor = listening
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;

    final iconColor = listening
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;

    final String resolvedTooltip =
        widget.tooltip ??
        (processing
            ? 'Processing transcription...'
            : disabled
            ? 'Voice input unavailable'
            : listening
            ? 'Stop listening'
            : 'Voice input');

    return Tooltip(
      message: resolvedTooltip,
      child: _AnimatedMicButton(
        listening: listening,
        processing: processing,
        disabled: disabled,
        size: widget.buttonSize,
        iconSize: widget.iconSize,
        backgroundColor: bgColor,
        iconColor: iconColor,
        onTap: disabled
            ? null
            : () => _voiceController.toggle(
                    widget.controller,
                    appendMode: widget.appendMode,
                    listenFor: widget.listenFor,
                    pauseFor: widget.pauseFor,
                    localeId: widget.localeId,
                    onListeningStarted: widget.onListeningStarted,
                    onListeningStopped: widget.onListeningStopped,
                    onTextChanged: widget.onTextChanged,
                    onError: widget.onError,
                  ),
      ),
    );
  }
}

// ── Internal animated button ──────────────────────────────────────────────────

/// Animated mic button with a gentle pulse when listening.
class _AnimatedMicButton extends StatefulWidget {
  const _AnimatedMicButton({
    required this.listening,
    required this.processing,
    required this.disabled,
    required this.size,
    required this.iconSize,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  final bool listening;
  final bool processing;
  final bool disabled;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  State<_AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<_AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _pulse.reverse();
          } else if (status == AnimationStatus.dismissed && widget.listening) {
            _pulse.forward();
          }
        });

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_AnimatedMicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.forward();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.disabled
                ? Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : widget.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: widget.processing
              ? Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.iconColor),
                  ),
                )
              : Icon(
                  widget.listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: widget.iconSize,
                  color: widget.disabled
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                      : widget.iconColor,
                ),
        ),
      ),
    );
  }
}
