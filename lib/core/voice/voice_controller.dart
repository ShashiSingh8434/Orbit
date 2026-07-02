import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable snapshot of the voice input system.
class VoiceState {
  const VoiceState({
    this.isAvailable = false,
    this.isListening = false,
    this.isInitialising = true,
    this.isProcessing = false,
    this.lastError,
  });

  /// Audio recorder permission was granted.
  final bool isAvailable;

  /// Microphone is actively capturing audio.
  final bool isListening;

  /// [VoiceService.initialize] has not yet completed.
  final bool isInitialising;

  /// True when the recorded audio is being transcribed via Gemini.
  final bool isProcessing;

  /// Non-null when the last operation failed.
  final String? lastError;

  VoiceState copyWith({
    bool? isAvailable,
    bool? isListening,
    bool? isInitialising,
    bool? isProcessing,
    String? lastError,
    bool clearError = false,
  }) {
    return VoiceState(
      isAvailable: isAvailable ?? this.isAvailable,
      isListening: isListening ?? this.isListening,
      isInitialising: isInitialising ?? this.isInitialising,
      isProcessing: isProcessing ?? this.isProcessing,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  String toString() =>
      'VoiceState(available=$isAvailable, listening=$isListening, '
      'initialising=$isInitialising, processing=$isProcessing, error=$lastError)';
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Riverpod controller that mediates between [VoiceInputButton] and
/// [VoiceService].
class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._service) : super(const VoiceState()) {
    _init();
  }

  final VoiceService _service;

  /// Whether the voice controller is currently listening.
  bool get isListening => state.isListening;

  // Tracks the text that existed *before* the current listening session.
  String _textBeforeListening = '';

  TextEditingController? _activeController;
  bool _activeAppendMode = true;
  VoidCallback? _activeOnListeningStarted;
  VoidCallback? _activeOnListeningStopped;
  void Function(String text)? _activeOnTextChanged;
  void Function(String error)? _activeOnError;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    state = state.copyWith(isInitialising: true);
    final available = await _service.initialize();
    state = state.copyWith(
      isAvailable: available,
      isInitialising: false,
      clearError: true,
    );
  }

  void _clearActiveSession() {
    _activeController = null;
    _activeOnListeningStarted = null;
    _activeOnListeningStopped = null;
    _activeOnTextChanged = null;
    _activeOnError = null;
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  /// Starts or stops listening, transcribing and writing results into [controller] on stop.
  Future<void> toggle(
    TextEditingController controller, {
    bool appendMode = true,
    Duration listenFor = const Duration(minutes: 5), // Keep for API compatibility
    Duration pauseFor = const Duration(seconds: 8),  // Keep for API compatibility
    String? localeId,                                // Keep for API compatibility
    VoidCallback? onListeningStarted,
    VoidCallback? onListeningStopped,
    void Function(String text)? onTextChanged,
    void Function(String error)? onError,
  }) async {
    if (state.isListening) {
      await stop();
      return;
    }

    // --- Start recording ---
    _activeController = controller;
    _activeAppendMode = appendMode;
    _activeOnListeningStarted = onListeningStarted;
    _activeOnListeningStopped = onListeningStopped;
    _activeOnTextChanged = onTextChanged;
    _activeOnError = onError;

    _textBeforeListening = controller.text;
    state = state.copyWith(isListening: true, clearError: true);
    _activeOnListeningStarted?.call();

    try {
      await _service.startListening();
    } catch (e) {
      state = state.copyWith(isListening: false, lastError: e.toString());
      _activeOnListeningStopped?.call();
      _clearActiveSession();
    }
  }

  /// Stops recording, triggers Gemini transcription, and appends/replaces the text in the controller.
  Future<void> stop() async {
    if (!state.isListening) return;

    state = state.copyWith(isListening: false, isProcessing: true);
    _activeOnListeningStopped?.call();

    final targetController = _activeController;
    final appendMode = _activeAppendMode;
    final textBefore = _textBeforeListening;
    final onTextChanged = _activeOnTextChanged;
    final onError = _activeOnError;

    try {
      final transcript = await _service.stopListeningAndTranscribe();
      if (transcript.isNotEmpty && targetController != null) {
        final base = appendMode ? textBefore : '';
        final updated = _buildText(base, transcript, appendMode: appendMode);
        
        targetController.text = updated;
        targetController.selection = TextSelection.collapsed(offset: updated.length);
        onTextChanged?.call(updated);
      }
    } catch (e) {
      onError?.call(e.toString());
      state = state.copyWith(lastError: e.toString());
    } finally {
      Future.microtask(() {
        if (mounted) {
          state = state.copyWith(isProcessing: false);
          _clearActiveSession();
        }
      });
    }
  }

  /// Cancels recording immediately and discards any audio data.
  Future<void> destroy() async {
    if (!state.isListening) return;
    await _service.cancelListening();
    
    Future.microtask(() {
      if (mounted) {
        state = state.copyWith(isListening: false, isProcessing: false);
        _activeOnListeningStopped?.call();
        _clearActiveSession();
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Builds the final string by prepending/appending words with correct spacing.
  static String _buildText(
    String base,
    String words, {
    required bool appendMode,
  }) {
    if (!appendMode || base.isEmpty) return words;
    if (base.endsWith(' ') || base.endsWith('\n')) return '$base$words';
    return '$base $words';
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
