import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Callback types for voice recognition events.
typedef VoiceResultCallback = void Function(SpeechRecognitionResult result);
typedef VoiceStatusCallback = void Function(String status);
typedef VoiceErrorCallback = void Function(SpeechRecognitionError error);

/// Encapsulates all [SpeechToText] interactions.
///
/// This is a pure service layer — no UI, no Riverpod, no Flutter widgets.
/// It owns a single [SpeechToText] instance for the lifetime of the app and
/// exposes a clean API for initialisation, listening, and disposal.

class VoiceService {
  VoiceService();

  static final SpeechToText _stt = SpeechToText();
  static bool _isAvailable = false;
  static bool _isListening = false;
  static Future<bool>? _initFuture;

  /// Whether the device supports speech recognition.
  bool get isAvailable => _isAvailable;

  /// Whether recognition is currently active.
  bool get isListening => _isListening;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<bool> initialize({
    VoiceStatusCallback? onStatus,
    VoiceErrorCallback? onError,
  }) async {
    if (_isAvailable) return true;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _stt.initialize(
      onStatus: (status) {
        // Sync internal state so callers can rely on [isListening].
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
        onStatus?.call(status);
      },
      onError: (error) {
        _isListening = false;
        onError?.call(error);
      },
      debugLogging: false,
    );

    try {
      _isAvailable = await _initFuture!;
    } catch (e) {
      _isAvailable = false;
      rethrow;
    } finally {
      _initFuture = null;
    }

    return _isAvailable;
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  /// Starts speech recognition.
  ///
  /// - [onResult]      fires on every partial and final recognition result.
  /// - [listenFor]     maximum listening duration before auto-stop.
  ///                   Defaults to 5 minutes so users can dictate long text.
  /// - [pauseFor]      silence duration before auto-stop. Defaults to 8 s,
  ///                   giving users time to think between sentences.
  /// - [localeId]      BCP-47 locale tag (e.g. "en-US"). Defaults to device
  ///                   locale when null — ready for future language selection.
  /// - [onSoundLevel] fired with dB values for future waveform visualisation.
  ///
  /// Has no effect if the service is unavailable or already listening.
  Future<void> startListening({
    required VoiceResultCallback onResult,
    Duration listenFor = const Duration(minutes: 5),
    Duration pauseFor = const Duration(seconds: 8),
    String? localeId,
    void Function(double level)? onSoundLevel,
  }) async {
    if (!_isAvailable || _isListening) return;

    _isListening = true;
    try {
      await _stt.listen(
        onResult: onResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        onSoundLevelChange: onSoundLevel,
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      _isListening = false;
      rethrow;
    }
  }

  /// Stops recognition immediately. Safe to call when not listening.
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }

  /// Cancels recognition without emitting a final result.
  Future<void> cancelListening() async {
    if (!_isListening) return;
    await _stt.cancel();
    _isListening = false;
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  /// Releases all STT resources. Call when the app is shutting down.
  void dispose() {
    _stt.stop();
  }
}
