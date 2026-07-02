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
    this.lastError,
  });

  /// Speech recognition is supported and permission was granted.
  final bool isAvailable;

  /// Microphone is actively capturing audio.
  final bool isListening;

  /// [VoiceService.initialize] has not yet completed.
  final bool isInitialising;

  /// Non-null when the last operation failed.
  final String? lastError;

  VoiceState copyWith({
    bool? isAvailable,
    bool? isListening,
    bool? isInitialising,
    String? lastError,
    bool clearError = false,
  }) {
    return VoiceState(
      isAvailable: isAvailable ?? this.isAvailable,
      isListening: isListening ?? this.isListening,
      isInitialising: isInitialising ?? this.isInitialising,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  String toString() =>
      'VoiceState(available=$isAvailable, listening=$isListening, '
      'initialising=$isInitialising, error=$lastError)';
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Riverpod controller that mediates between [VoiceInputButton] and
/// [VoiceService].
///
/// The UI never calls [SpeechToText] directly — it only calls methods on this
/// controller.
///
/// ## Insertion modes
/// - **Append mode** (default): recognised words are appended after any
///   existing text, with a space separator where needed.
/// - **Replace mode**: each recognition session replaces the controller's text.
///
/// ## Extensibility hooks
/// All callbacks ([onListeningStarted], [onListeningStopped],
/// [onTextChanged], [onError]) are optional and are provided per-call so
/// the controller remains stateless with respect to the target field.
class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._service) : super(const VoiceState()) {
    _init();
  }

  final VoiceService _service;

  /// Whether the voice controller is currently listening.
  bool get isListening => state.isListening;

  // Tracks the text that existed *before* the current listening session so
  // partial results can be appended repeatedly without duplication.
  String _textBeforeListening = '';

  // Accumulates committed segments of the current session when the speech engine resets.
  String _sessionText = '';

  // Tracks the last recognized phrase of the current session to detect resets.
  String _lastRecognizedWords = '';

  // Continuous listening / auto-restart support
  bool _shouldRestart = false;
  bool _isRestarting = false;
  int _listenSessionId = 0;
  TextEditingController? _activeController;
  bool _activeAppendMode = true;
  Duration _activeListenFor = const Duration(minutes: 5);
  Duration _activePauseFor = const Duration(seconds: 8);
  String? _activeLocaleId;
  VoidCallback? _activeOnListeningStarted;
  VoidCallback? _activeOnListeningStopped;
  void Function(String text)? _activeOnTextChanged;
  void Function(String error)? _activeOnError;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    state = state.copyWith(isInitialising: true);
    final available = await _service.initialize(
      onStatus: _onStatus,
      onError: (error) {
        if (state.isListening && !_shouldRestart) {
          state = state.copyWith(isListening: false, lastError: error.errorMsg);
        } else if (_shouldRestart) {
          _activeOnError?.call(error.errorMsg);
        }
      },
    );
    state = state.copyWith(
      isAvailable: available,
      isInitialising: false,
      clearError: true,
    );
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_shouldRestart) {
        _restartListening();
      } else if (state.isListening) {
        state = state.copyWith(isListening: false);
        _activeOnListeningStopped?.call();
        _clearActiveSession();
      }
    }
  }

  Future<void> _restartListening() async {
    if (_isRestarting) return;
    _isRestarting = true;

    try {
      if (_activeController == null) return;

      // Invalidate any late result callbacks from the previous session.
      _listenSessionId++;

      // Anchor the baseline text to whatever is currently in the controller.
      // When the speech-to-text restarts, it will start transcribing a new
      // phrase starting from empty, so appending it to the updated text
      // prevents any deletion/removal of what was said in previous segments.
      _textBeforeListening = _activeController!.text;
      _sessionText = '';
      _lastRecognizedWords = '';

      // Delay briefly to allow the native engine to fully transition to idle
      // before starting a new listening session, avoiding ERROR_BUSY.
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_shouldRestart) return;

      await _startServiceListening();
    } catch (e) {
      _shouldRestart = false;
      state = state.copyWith(isListening: false, lastError: e.toString());
      _activeOnListeningStopped?.call();
      _clearActiveSession();
    } finally {
      _isRestarting = false;
    }
  }

  Future<void> _startServiceListening() async {
    final sessionId = _listenSessionId;
    await _service.startListening(
      listenFor: _activeListenFor,
      pauseFor: _activePauseFor,
      localeId: _activeLocaleId,
      onResult: (result) {
        if (_activeController == null || sessionId != _listenSessionId) return;

        final words = result.recognizedWords;
        if (words.isEmpty) return;

        final lastNormalized = _lastRecognizedWords.trim().toLowerCase();
        final newNormalized = words.trim().toLowerCase();

        // If the recognized words decrease in length or do not start with the
        // previously recognized words, it indicates the native engine reset its phrase buffer.
        final isReset =
            lastNormalized.isNotEmpty &&
            (newNormalized.length < lastNormalized.length ||
                !newNormalized.startsWith(lastNormalized));

        if (isReset) {
          // Commit the last phrase into the session text accumulator
          _sessionText = _buildText(
            _sessionText,
            _lastRecognizedWords,
            appendMode: true,
          );
        }

        _lastRecognizedWords = words;

        // Combine segments spoken within this session, then append/replace to the initial baseline text.
        final currentWords = _buildText(_sessionText, words, appendMode: true);
        final base = _activeAppendMode ? _textBeforeListening : '';
        final updated = _buildText(
          base,
          currentWords,
          appendMode: _activeAppendMode,
        );

        _activeController!.text = updated;
        _activeController!.selection = TextSelection.collapsed(
          offset: updated.length,
        );
        _activeOnTextChanged?.call(updated);
      },
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

  /// Starts or stops listening, writing results into [controller].
  ///
  /// Parameters:
  /// - [appendMode]         When true, speech is appended to existing text.
  ///                        When false, speech replaces all text.
  /// - [listenFor]          Override the default 5-minute maximum duration.
  /// - [pauseFor]           Override the default 8-second pause timeout.
  /// - [localeId]           BCP-47 locale for future language selection.
  /// - [onListeningStarted] Called when the mic opens.
  /// - [onListeningStopped] Called when the mic closes (tap or timeout).
  /// - [onTextChanged]      Called after every partial/final update.
  /// - [onError]            Called on recognition failure.
  Future<void> toggle(
    TextEditingController controller, {
    bool appendMode = true,
    Duration listenFor = const Duration(minutes: 5),
    Duration pauseFor = const Duration(seconds: 8),
    String? localeId,
    VoidCallback? onListeningStarted,
    VoidCallback? onListeningStopped,
    void Function(String text)? onTextChanged,
    void Function(String error)? onError,
  }) async {
    if (state.isListening) {
      _shouldRestart = false;
      _listenSessionId++; // Invalidate any callbacks from the current session
      await _service.stopListening();
      state = state.copyWith(isListening: false);
      _activeOnListeningStopped?.call();
      _clearActiveSession();
      return;
    }

    // --- Start listening ---
    _activeController = controller;
    _activeAppendMode = appendMode;
    _activeListenFor = listenFor;
    _activePauseFor = pauseFor;
    _activeLocaleId = localeId;
    _activeOnListeningStarted = onListeningStarted;
    _activeOnListeningStopped = onListeningStopped;
    _activeOnTextChanged = onTextChanged;
    _activeOnError = onError;

    _textBeforeListening = controller.text;
    _sessionText = '';
    _lastRecognizedWords = '';
    _shouldRestart = true;
    _listenSessionId++; // Increment to start a fresh session ID
    state = state.copyWith(isListening: true, clearError: true);
    _activeOnListeningStarted?.call();

    try {
      await _startServiceListening();
    } catch (e) {
      _shouldRestart = false;
      state = state.copyWith(isListening: false, lastError: e.toString());
      _activeOnListeningStopped?.call();
      _clearActiveSession();
    }
  }

  /// Stops any active listening session unconditionally.
  Future<void> stop() async {
    _shouldRestart = false;
    _listenSessionId++; // Invalidate any running callbacks
    if (!state.isListening) return;
    await _service.stopListening();
    
    Future.microtask(() {
      if (mounted) {
        state = state.copyWith(isListening: false);
        _activeOnListeningStopped?.call();
        _clearActiveSession();
      }
    });
  }

  /// Cancels any active listening session immediately and clears state.
  Future<void> destroy() async {
    _shouldRestart = false;
    _listenSessionId++; // Invalidate any running callbacks
    await _service.cancelListening();
    
    Future.microtask(() {
      if (mounted) {
        state = state.copyWith(isListening: false);
        _activeOnListeningStopped?.call();
        _clearActiveSession();
      }
    });
  }


  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Builds the final string by appending [words] to [base] with proper
  /// spacing, or returning [words] alone in replace mode.
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
