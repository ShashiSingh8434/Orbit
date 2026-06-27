import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_provider.dart';
import 'ai_request.dart';

/// Groq implementation of [AiProvider].
///
/// Uses the Groq REST API which is OpenAI-compatible.
/// Free tier: 30 req/min, 14,400 req/day for most models.
class GroqProvider extends AiProvider {
  final String _apiKey;
  final String _id;
  final String _name;
  final int _priority;
  final String _model;

  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqProvider({
    required String apiKey,
    required String model,
    required String id,
    required String name,
    required int priority,
  })  : _apiKey = apiKey,
        _model = model,
        _id = id,
        _name = name,
        _priority = priority;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  String get model => _model;

  @override
  int get maxContextTokens => 128000; // llama-3.3-70b-versatile

  @override
  int get priority => _priority;

  @override
  bool get supportsJsonMode => false; // No schema support, uses prompt instructions

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final stopwatch = Stopwatch()..start();

    final systemPrompt = request.jsonMode
        ? 'You are an AI assistant. You MUST respond with valid JSON only. No markdown, no explanation, no wrapping. Just raw JSON.'
        : 'You are an AI assistant.';

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': request.prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 4096,
      if (request.jsonMode) 'response_format': {'type': 'json_object'},
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw const AiException(
            type: AiErrorType.serverError,
            message: 'Groq returned no choices',
            providerId: 'groq',
          );
        }

        final message = choices[0]['message'] as Map<String, dynamic>;
        final text = message['content'] as String? ?? '';

        // Extract usage
        final usage = data['usage'] as Map<String, dynamic>?;

        return AiResponse(
          text: text,
          providerId: id,
          inputTokens: usage?['prompt_tokens'] as int?,
          outputTokens: usage?['completion_tokens'] as int?,
          latency: stopwatch.elapsed,
        );
      }

      // Error handling
      stopwatch.stop();
      throw _mapHttpError(response);
    } on AiException {
      rethrow;
    } on http.ClientException catch (e) {
      stopwatch.stop();
      throw AiException(
        type: AiErrorType.networkError,
        message: 'Network error: ${e.message}',
        providerId: 'groq',
      );
    } catch (e) {
      stopwatch.stop();
      if (e is AiException) rethrow;
      throw AiException(
        type: AiErrorType.unknown,
        message: e.toString(),
        providerId: 'groq',
      );
    }
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('GroqProvider.validateApiKey failed: $e');
      return false;
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('GroqProvider.healthCheck failed: $e');
      return false;
    }
  }

  AiException _mapHttpError(http.Response response) {
    final statusCode = response.statusCode;
    String detail = '';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      detail = error?['message'] as String? ?? response.body;
    } catch (_) {
      detail = response.body;
    }

    // Rate limit
    if (statusCode == 429) {
      Duration? retryAfter;
      final retryHeader = response.headers['retry-after'];
      if (retryHeader != null) {
        final seconds = double.tryParse(retryHeader);
        if (seconds != null) {
          retryAfter = Duration(milliseconds: (seconds * 1000).round());
        }
      }
      return AiException(
        type: AiErrorType.rateLimited,
        message: 'Groq rate limited: $detail',
        providerId: _id,
        retryAfter: retryAfter,
      );
    }

    // Auth
    if (statusCode == 401 || statusCode == 403) {
      return AiException(
        type: AiErrorType.invalidApiKey,
        message: 'Groq auth error: $detail',
        providerId: _id,
      );
    }

    // Server errors
    if (statusCode >= 500) {
      return AiException(
        type: AiErrorType.serverError,
        message: 'Groq server error ($statusCode): $detail',
        providerId: _id,
      );
    }

    // Bad request
    if (statusCode >= 400) {
      return AiException(
        type: AiErrorType.badRequest,
        message: 'Groq bad request ($statusCode): $detail',
        providerId: _id,
      );
    }

    return AiException(
      type: AiErrorType.unknown,
      message: 'Groq unknown error ($statusCode): $detail',
      providerId: 'groq',
    );
  }
}
