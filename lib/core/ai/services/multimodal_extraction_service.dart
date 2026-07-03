import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../engine/ai_request_manager.dart';
import '../storage/secure_key_storage.dart';
import '../../utils/app_logger.dart';
import '../../../features/academic/data/static_slots.dart';

/// Provider for [MultimodalExtractionService].
final multimodalExtractionServiceProvider = Provider<MultimodalExtractionService>((ref) {
  return MultimodalExtractionService(ref);
});

/// A simplified service for extracting structured JSON data from documents/images
/// using Groq's API models with automatic fallbacks.
class MultimodalExtractionService {
  final Ref _ref;

  MultimodalExtractionService(this._ref);

  static const List<String> _models = [
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'qwen/qwen3.6-27b',
  ];

  /// Updates the AI processing status displayed in the global notch.
  void _updateStatus(bool isProcessing, String? message) {
    _ref.read(aiStatusProvider.notifier).state = AiStatus(
      isProcessing: isProcessing,
      message: message,
    );
  }

  /// Extracts structured information from a list of images using a fallback order of Groq models.
  Future<Map<String, dynamic>> extractData({
    required List<Uint8List> imageBytesList,
    required List<String> mimeTypes,
    required String prompt,
    required Schema responseSchema, // Kept in signature to match repository callers
  }) async {
    if (imageBytesList.isEmpty) {
      throw ArgumentError('At least one image is required for document extraction.');
    }

    _updateStatus(true, 'Resolving document keys...');
    try {
      final key = await _resolveGroqKey();
      if (key.isEmpty) {
        throw StateError(
          'Groq API key is missing. Please configure valid credentials in your settings or .env file.',
        );
      }

      Object? lastError;

      for (final modelName in _models) {
        try {
          _updateStatus(true, 'Extracting with $modelName...');
          AppLogger.info(
            'MultimodalExtractionService: Trying extraction with Groq model "$modelName"...',
          );

          final result = await _extractWithGroq(
            apiKey: key,
            modelName: modelName,
            imageBytesList: imageBytesList,
            mimeTypes: mimeTypes,
            prompt: prompt,
          );

          AppLogger.info('MultimodalExtractionService: Extraction succeeded using model $modelName.');
          return result;
        } catch (e, stackTrace) {
          lastError = e;
          AppLogger.warning(
            'MultimodalExtractionService: Model $modelName failed. Trying next fallback.',
            e,
            stackTrace,
          );
        }
      }

      throw lastError ??
          StateError(
            'All Groq models in the fallback chain failed. Please verify your internet connection and API key.',
          );
    } finally {
      _updateStatus(false, null);
    }
  }

  // ── API Key Resolution ─────────────────────────────────────────────────────

  Future<String> _resolveGroqKey() async {
    final orbitGroqKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';
    final userGroqKey = await SecureKeyStorage.getKey('groq');
    return (userGroqKey != null && userGroqKey.trim().isNotEmpty)
        ? userGroqKey.trim()
        : orbitGroqKey;
  }

  // ── Groq Extraction ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _extractWithGroq({
    required String apiKey,
    required String modelName,
    required List<Uint8List> imageBytesList,
    required List<String> mimeTypes,
    required String prompt,
  }) async {
    final List<Map<String, dynamic>> userContent = [
      {
        "type": "text",
        "text": prompt,
      }
    ];

    for (int i = 0; i < imageBytesList.length; i++) {
      final bytes = imageBytesList[i];
      final mimeType = mimeTypes.length > i ? mimeTypes[i] : 'image/jpeg';
      final base64Str = base64Encode(bytes);
      userContent.add({
        "type": "image_url",
        "image_url": {
          "url": "data:$mimeType;base64,$base64Str",
        }
      });
    }

    final systemPrompt =
        'You are an AI assistant. You MUST respond with valid JSON matching the requested structure. '
        'No markdown formatting (like ```json), no comments, no explanations. Just raw JSON.';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = responseBody['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API returned no choices.');
      }
      final text = choices[0]['message']['content'] as String? ?? '';
      return _parseJsonResponse(text);
    } else {
      throw Exception('API error (${response.statusCode}): ${response.body}');
    }
  }

  // ── JSON Helper ────────────────────────────────────────────────────────────

  Map<String, dynamic> _parseJsonResponse(String text) {
    AppLogger.info('MultimodalExtractionService: Raw response from model: $text');
    var cleanText = text.trim();
    final firstBrace = cleanText.indexOf('{');
    final lastBrace = cleanText.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleanText = cleanText.substring(firstBrace, lastBrace + 1);
    }
    final data = jsonDecode(cleanText);
    if (data is! Map<String, dynamic>) {
      throw Exception('Response is not a valid JSON object.');
    }

    // 1. De-duplicate courses by course code
    final uniqueCourses = [];
    if (data.containsKey('courses') && data['courses'] is List) {
      final coursesList = data['courses'] as List;
      final seenCodes = <String>{};
      for (final item in coursesList) {
        if (item is Map) {
          final code = (item['code'] as String? ?? '').trim().toUpperCase();
          if (code.isNotEmpty && !seenCodes.contains(code)) {
            seenCodes.add(code);
            uniqueCourses.add(item);
          }
        }
      }
    }
    data['courses'] = uniqueCourses;

    // 2. Generate the weekly schedule dynamically using the static slot mapping
    final Map<String, dynamic> staticSlotMapRaw = jsonDecode(staticSlotsJson);
    final Map<String, List<Map<String, String>>> staticSlotMap = staticSlotMapRaw.map((key, value) {
      return MapEntry(
        key,
        (value as List).map((item) => Map<String, String>.from(item as Map)).toList(),
      );
    });

    final generatedSchedule = <String, List<dynamic>>{};
    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
      generatedSchedule[day] = [];
    }

    for (final course in uniqueCourses) {
      if (course is Map) {
        final rawSlots = course['slot'] as String? ?? '';
        final courseSlots = rawSlots.toUpperCase()
            .split(RegExp(r'[\+\s,\/]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        for (final day in staticSlotMap.keys) {
          for (final slotInfo in staticSlotMap[day]!) {
            final slotCode = slotInfo['slot']!.toUpperCase();
            if (courseSlots.contains(slotCode)) {
              generatedSchedule[day]!.add({
                'startTime': slotInfo['startTime'],
                'endTime': slotInfo['endTime'],
                'code': course['code'],
                'name': course['name'],
                'faculty': course['faculty'] ?? '',
                'room': course['room'] ?? '',
                'slot': slotCode,
              });
            }
          }
        }
      }
    }

    // Sort class sessions chronologically by startTime
    for (final day in generatedSchedule.keys) {
      generatedSchedule[day]!.sort((a, b) {
        final aTime = a['startTime'] as String? ?? '00:00';
        final bTime = b['startTime'] as String? ?? '00:00';
        return aTime.compareTo(bTime);
      });
    }

    data['schedule'] = generatedSchedule;
    AppLogger.info('MultimodalExtractionService: Successfully parsed and normalized JSON data.');
    return data;
  }
}
