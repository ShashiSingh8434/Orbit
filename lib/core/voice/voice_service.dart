import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../ai/storage/secure_key_storage.dart';
import '../ai/analytics/ai_analytics_service.dart';
import '../ai/analytics/ai_usage_log.dart';
import '../utils/app_logger.dart';

/// Encapsulates all audio recording and transcription interactions.
class VoiceService {
  final AiAnalyticsService? _analytics;
  VoiceService({AiAnalyticsService? analytics}) : _analytics = analytics;

  static final AudioRecorder _recorder = AudioRecorder();
  static bool _isAvailable = false;
  static bool _isListening = false;
  static Future<bool>? _initFuture;
  static String? _tempFilePath;

  /// Whether microphone permission has been granted.
  bool get isAvailable => _isAvailable;

  /// Whether recording is currently active.
  bool get isListening => _isListening;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (_isAvailable) return true;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _recorder.hasPermission();
    try {
      _isAvailable = await _initFuture!;
    } catch (e) {
      _isAvailable = false;
      AppLogger.error('VoiceService initialization failed', e);
    } finally {
      _initFuture = null;
    }

    return _isAvailable;
  }

  // ── Recording & Transcription ─────────────────────────────────────────────

  /// Starts recording audio to a temporary file.
  Future<void> startListening() async {
    if (!_isAvailable || _isListening) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;

    final tempDir = await getTemporaryDirectory();
    _tempFilePath =
        '${tempDir.path}/voice_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

    _isListening = true;
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _tempFilePath!,
      );
    } catch (e) {
      _isListening = false;
      rethrow;
    }
  }

  /// Stops recording and transcribes the audio using a prioritized fallback list:
  /// 1. whisper-large-v3-turbo (Groq)
  /// 2. gemini-2.5-flash (Gemini)
  /// 3. whisper-large-v3 (Groq)
  Future<String> stopListeningAndTranscribe() async {
    if (!_isListening || _tempFilePath == null) return '';

    _isListening = false;
    final path = await _recorder.stop();
    if (path == null) return '';

    final file = File(path);
    if (!await file.exists()) return '';

    // Load API Keys
    final orbitGeminiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    final userGeminiKey = await SecureKeyStorage.getKey('gemini');
    final hasUserGemini = userGeminiKey != null && userGeminiKey.trim().isNotEmpty;

    final orbitGroqKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';
    final userGroqKey = await SecureKeyStorage.getKey('groq');
    final hasUserGroq = userGroqKey != null && userGroqKey.trim().isNotEmpty;

    Future<String?> tryUserGroq(String modelName, String modelId) async {
      if (!hasUserGroq) return null;
      final stopwatch = Stopwatch()..start();
      try {
        AppLogger.info(
          'VoiceService: Attempting $modelId transcription on Groq using USER API key...',
        );
        final text = await _transcribeWithGroq(file, modelId, userGroqKey.trim());
        if (text.isNotEmpty) {
          AppLogger.info('VoiceService: $modelId using USER API key succeeded.');
          _logTranscription(
            provider: 'Groq (Voice)',
            modelName: modelName,
            modelId: modelId,
            isUserKey: true,
            responseTimeMs: stopwatch.elapsedMilliseconds,
            success: true,
          );
          return text;
        }
      } catch (e) {
        AppLogger.warning(
          'VoiceService: $modelId using USER API key failed',
          e,
        );
        _logTranscription(
          provider: 'Groq (Voice)',
          modelName: modelName,
          modelId: modelId,
          isUserKey: true,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          success: false,
          errorType: e.toString(),
        );
      }
      return null;
    }

    Future<String?> tryUserGemini(String modelName, String modelId) async {
      if (!hasUserGemini) return null;
      final stopwatch = Stopwatch()..start();
      try {
        AppLogger.info(
          'VoiceService: Attempting $modelId transcription on Gemini using USER API key...',
        );
        final text = await _transcribeWithGemini(file, modelId, userGeminiKey.trim());
        if (text.isNotEmpty) {
          AppLogger.info('VoiceService: $modelId using USER API key succeeded.');
          _logTranscription(
            provider: 'Gemini (Voice)',
            modelName: modelName,
            modelId: '$modelId-voice',
            isUserKey: true,
            responseTimeMs: stopwatch.elapsedMilliseconds,
            success: true,
          );
          return text;
        }
      } catch (e) {
        AppLogger.warning(
          'VoiceService: $modelId using USER API key failed',
          e,
        );
        _logTranscription(
          provider: 'Gemini (Voice)',
          modelName: modelName,
          modelId: '$modelId-voice',
          isUserKey: true,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          success: false,
          errorType: e.toString(),
        );
      }
      return null;
    }

    Future<String?> tryOrbitGroq(String modelName, String modelId) async {
      if (orbitGroqKey.isEmpty) return null;
      final stopwatch = Stopwatch()..start();
      try {
        AppLogger.info(
          'VoiceService: Attempting $modelId transcription on Groq using ORBIT default API key...',
        );
        final text = await _transcribeWithGroq(file, modelId, orbitGroqKey);
        if (text.isNotEmpty) {
          AppLogger.info('VoiceService: $modelId using ORBIT key succeeded.');
          _logTranscription(
            provider: 'Groq (Voice)',
            modelName: modelName,
            modelId: modelId,
            isUserKey: false,
            responseTimeMs: stopwatch.elapsedMilliseconds,
            success: true,
          );
          return text;
        }
      } catch (e) {
        AppLogger.warning(
          'VoiceService: $modelId using ORBIT key failed',
          e,
        );
        _logTranscription(
          provider: 'Groq (Voice)',
          modelName: modelName,
          modelId: modelId,
          isUserKey: false,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          success: false,
          errorType: e.toString(),
        );
      }
      return null;
    }

    Future<String?> tryOrbitGemini(String modelName, String modelId) async {
      if (orbitGeminiKey.isEmpty) return null;
      final stopwatch = Stopwatch()..start();
      try {
        AppLogger.info(
          'VoiceService: Attempting $modelId transcription on Gemini using ORBIT default API key...',
        );
        final text = await _transcribeWithGemini(file, modelId, orbitGeminiKey);
        if (text.isNotEmpty) {
          AppLogger.info('VoiceService: $modelId using ORBIT key succeeded.');
          _logTranscription(
            provider: 'Gemini (Voice)',
            modelName: modelName,
            modelId: '$modelId-voice',
            isUserKey: false,
            responseTimeMs: stopwatch.elapsedMilliseconds,
            success: true,
          );
          return text;
        }
      } catch (e) {
        AppLogger.warning(
          'VoiceService: $modelId using ORBIT key failed',
          e,
        );
        _logTranscription(
          provider: 'Gemini (Voice)',
          modelName: modelName,
          modelId: '$modelId-voice',
          isUserKey: false,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          success: false,
          errorType: e.toString(),
        );
      }
      return null;
    }

    try {
      // ── First Priority: USER API Keys (in order) ──────────────────────────
      final textUser1 = await tryUserGroq('Whisper Large V3 Turbo', 'whisper-large-v3-turbo');
      if (textUser1 != null) return textUser1;

      final textUser2 = await tryUserGemini('Gemini 2.5 Flash (Voice)', 'gemini-2.5-flash');
      if (textUser2 != null) return textUser2;

      final textUser3 = await tryUserGroq('Whisper Large V3', 'whisper-large-v3');
      if (textUser3 != null) return textUser3;

      // ── Second Priority: ORBIT Default Keys (in order) ─────────────────────
      final textOrbit1 = await tryOrbitGroq('Whisper Large V3 Turbo', 'whisper-large-v3-turbo');
      if (textOrbit1 != null) return textOrbit1;

      final textOrbit2 = await tryOrbitGemini('Gemini 2.5 Flash (Voice)', 'gemini-2.5-flash');
      if (textOrbit2 != null) return textOrbit2;

      final textOrbit3 = await tryOrbitGroq('Whisper Large V3', 'whisper-large-v3');
      if (textOrbit3 != null) return textOrbit3;

      throw Exception(
        'All transcription providers failed or no API keys were configured.',
      );
    } finally {
      // Clean up the temp file
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _tempFilePath = null;
    }
  }

  void _logTranscription({
    required String provider,
    required String modelName,
    required String modelId,
    required bool isUserKey,
    required int responseTimeMs,
    required bool success,
    String? errorType,
  }) {
    if (_analytics == null) return;

    final log = AiUsageLog(
      provider: provider,
      modelName: modelName,
      modelId: modelId,
      aiMode: isUserKey ? 'User' : 'Orbit',
      apiSource: isUserKey ? 'My API' : 'Orbit API',
      timestamp: DateTime.now(),
      success: success,
      errorType: errorType,
      retryCount: 0,
      responseTimeMs: responseTimeMs,
      inputTokens: null,
      outputTokens: null,
      totalTokens: null,
      cached: false,
      queueWaitTimeMs: 0,
      processingTimeMs: responseTimeMs,
    );
    _analytics!.logRequest(log);
  }

  /// Transcribes using Groq's speech-to-text API.
  Future<String> _transcribeWithGroq(
    File file,
    String model,
    String apiKey,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['model'] = model;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text']?.toString().trim() ?? '';
    } else {
      throw Exception('Groq error (${response.statusCode}): ${response.body}');
    }
  }

  /// Transcribes using Gemini's API.
  Future<String> _transcribeWithGemini(
    File file,
    String modelName,
    String apiKey,
  ) async {
    final model = GenerativeModel(model: modelName, apiKey: apiKey);

    final bytes = await file.readAsBytes();
    final audioPart = DataPart('audio/m4a', bytes);

    final response = await model.generateContent([
      Content.multi([
        TextPart(
          'Transcribe this voice recording into clear text. '
          'Do not summarize, translate, or explain. '
          'Only write down the exact spoken words, maintaining proper punctuation and casing.',
        ),
        audioPart,
      ]),
    ]);

    return response.text?.trim() ?? '';
  }

  /// Cancels recording and discards the file.
  Future<void> cancelListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _recorder.stop();
    if (_tempFilePath != null) {
      try {
        final file = File(_tempFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _tempFilePath = null;
    }
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  void dispose() {
    _recorder.dispose();
  }
}
