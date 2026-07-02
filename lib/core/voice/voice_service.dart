import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/ai/storage/secure_key_storage.dart';
import '../utils/app_logger.dart';

/// Encapsulates all audio recording and transcription interactions.
class VoiceService {
  VoiceService();

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
    _tempFilePath = '${tempDir.path}/voice_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
    final geminiApiKey = (userGeminiKey != null && userGeminiKey.trim().isNotEmpty)
        ? userGeminiKey.trim()
        : orbitGeminiKey;

    final orbitGroqKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';
    final userGroqKey = await SecureKeyStorage.getKey('groq');
    final groqApiKey = (userGroqKey != null && userGroqKey.trim().isNotEmpty)
        ? userGroqKey.trim()
        : orbitGroqKey;

    try {
      // 1. Try Groq whisper-large-v3-turbo
      if (groqApiKey.isNotEmpty) {
        try {
          AppLogger.info('VoiceService: Attempting whisper-large-v3-turbo transcription on Groq...');
          final text = await _transcribeWithGroq(file, 'whisper-large-v3-turbo', groqApiKey);
          if (text.isNotEmpty) {
            AppLogger.info('VoiceService: whisper-large-v3-turbo succeeded.');
            return text;
          }
        } catch (e) {
          AppLogger.warning('VoiceService: whisper-large-v3-turbo transcription failed, trying fallback', e);
        }
      }

      // 2. Try Gemini gemini-2.5-flash
      if (geminiApiKey.isNotEmpty) {
        try {
          AppLogger.info('VoiceService: Attempting gemini-2.5-flash transcription on Gemini...');
          final text = await _transcribeWithGemini(file, 'gemini-2.5-flash', geminiApiKey);
          if (text.isNotEmpty) {
            AppLogger.info('VoiceService: gemini-2.5-flash succeeded.');
            return text;
          }
        } catch (e) {
          AppLogger.warning('VoiceService: gemini-2.5-flash transcription failed, trying fallback', e);
        }
      }

      // 3. Try Groq whisper-large-v3
      if (groqApiKey.isNotEmpty) {
        try {
          AppLogger.info('VoiceService: Attempting whisper-large-v3 transcription on Groq...');
          final text = await _transcribeWithGroq(file, 'whisper-large-v3', groqApiKey);
          if (text.isNotEmpty) {
            AppLogger.info('VoiceService: whisper-large-v3 succeeded.');
            return text;
          }
        } catch (e) {
          AppLogger.error('VoiceService: whisper-large-v3 transcription failed', e);
          rethrow;
        }
      }

      throw Exception('All transcription providers failed or no API keys were configured.');
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

  /// Transcribes using Groq's speech-to-text API.
  Future<String> _transcribeWithGroq(File file, String model, String apiKey) async {
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
  Future<String> _transcribeWithGemini(File file, String modelName, String apiKey) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );

    final bytes = await file.readAsBytes();
    final audioPart = DataPart('audio/m4a', bytes);

    final response = await model.generateContent([
      Content.multi([
        TextPart(
          'Transcribe this voice recording into clear text. '
          'Do not summarize, translate, or explain. '
          'Only write down the exact spoken words, maintaining proper punctuation and casing.'
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
