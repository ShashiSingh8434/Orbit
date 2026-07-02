import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'ai_provider.dart';
import 'ai_request.dart';

/// Google Gemini implementation of [AiProvider].
///
/// Wraps the `google_generative_ai` package. This is the only place in the
/// entire codebase that imports that package directly.
class GeminiProvider extends AiProvider {
  final String _apiKey;
  final String _id;
  final String _name;
  final int _priority;
  final String _model;

  GeminiProvider({
    required this._apiKey,
    required this._model,
    required this._id,
    required this._name,
    required this._priority,
  });

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  String get model => _model;

  @override
  int get maxContextTokens => 1048576; // Gemini 2.5 Flash

  @override
  int get priority => _priority;

  @override
  bool get supportsJsonMode => true;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final stopwatch = Stopwatch()..start();

    try {
      final generativeModel = GenerativeModel(
        model: _model,
        apiKey: _apiKey,
        generationConfig: request.jsonMode
            ? GenerationConfig(
                responseMimeType: 'application/json',
                responseSchema: request.responseSchema as Schema?,
              )
            : null,
      );

      final response = await generativeModel.generateContent([
        Content.text(request.prompt),
      ]);

      stopwatch.stop();

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw const AiException(
          type: AiErrorType.serverError,
          message: 'Gemini returned null or empty response',
          providerId: 'gemini',
        );
      }

      // Extract token counts from usage metadata
      final usage = response.usageMetadata;

      return AiResponse(
        text: text,
        providerId: id,
        inputTokens: usage?.promptTokenCount,
        outputTokens: usage?.candidatesTokenCount,
        latency: stopwatch.elapsed,
      );
    } on GenerativeAIException catch (e) {
      stopwatch.stop();
      throw _mapGeminiError(e);
    } catch (e) {
      stopwatch.stop();
      if (e is AiException) rethrow;
      throw AiException(
        type: AiErrorType.unknown,
        message: e.toString(),
        providerId: 'gemini',
      );
    }
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final testModel = GenerativeModel(model: _model, apiKey: apiKey);
      await testModel.generateContent([Content.text('Hello')]);
      return true;
    } catch (e) {
      debugPrint('GeminiProvider.validateApiKey failed: $e');
      return false;
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final testModel = GenerativeModel(model: _model, apiKey: _apiKey);
      await testModel.generateContent([Content.text('ping')]);
      return true;
    } catch (e) {
      debugPrint('GeminiProvider.healthCheck failed: $e');
      return false;
    }
  }

  AiException _mapGeminiError(GenerativeAIException e) {
    final msg = e.message.toLowerCase();

    // Rate limit
    if (msg.contains('quota') ||
        msg.contains('rate') ||
        msg.contains('429') ||
        msg.contains('resource has been exhausted')) {
      // Try to extract retry-after duration
      Duration? retryAfter;
      final retryMatch = RegExp(r'retry in (\d+\.?\d*)s').firstMatch(msg);
      if (retryMatch != null) {
        final seconds = double.tryParse(retryMatch.group(1)!);
        if (seconds != null) {
          retryAfter = Duration(milliseconds: (seconds * 1000).round());
        }
      }
      return AiException(
        type: AiErrorType.rateLimited,
        message: e.message,
        providerId: _id,
        retryAfter: retryAfter,
      );
    }

    // Invalid API key
    if (msg.contains('api key') ||
        msg.contains('permission') ||
        msg.contains('401') ||
        msg.contains('403')) {
      return AiException(
        type: AiErrorType.invalidApiKey,
        message: e.message,
        providerId: _id,
      );
    }

    // Server error
    if (msg.contains('500') ||
        msg.contains('503') ||
        msg.contains('internal')) {
      return AiException(
        type: AiErrorType.serverError,
        message: e.message,
        providerId: _id,
      );
    }

    return AiException(
      type: AiErrorType.unknown,
      message: e.message,
      providerId: 'gemini',
    );
  }
}
