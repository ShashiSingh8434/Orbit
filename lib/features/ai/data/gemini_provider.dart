import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../reflection/models/reflection_model.dart';
import '../../knowledge/models/daily_knowledge_model.dart';
import '../models/ai_extraction_result.dart';
import 'ai_provider_interface.dart';

// ── Riverpod Binding ──────────────────────────────────────────────────────────

final aiProviderProvider = Provider<AIProvider>(
  (ref) => GeminiProvider(),
);

// ── Gemini Implementation ─────────────────────────────────────────────────────

class GeminiProvider implements AIProvider {
  late final GenerativeModel _model;

  GeminiProvider() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
      ),
    );
  }

  @override
  Future<AiExtractionResult> extractKnowledge(
    List<ReflectionModel> reflections,
  ) async {
    if (reflections.isEmpty) {
      return const AiExtractionResult();
    }

    final prompt = _buildPrompt(reflections);

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      final json = Map<String, dynamic>.from(jsonDecode(text) as Map);
      return _parseResponse(json);
    } catch (e) {
      return const AiExtractionResult();
    }
  }

  String _buildPrompt(List<ReflectionModel> reflections) {
    final joined = reflections
        .map((r) => '[${r.source.toUpperCase()} at ${_fmt(r.createdAt)}]\n${r.text}')
        .join('\n\n---\n\n');

    return '''
You are an intelligent personal assistant that analyses daily journal reflections.

Extract structured knowledge from the following reflections and return ONLY valid JSON
matching this exact schema:

{
  "summary": "string — concise 2-3 sentence summary of the day",
  "mood": "integer 1-5 or null — inferred from sentiment",
  "energy": "integer 1-5 or null — inferred from language",
  "tasks": [{"title": "string", "isDone": false, "source": "ai"}],
  "learnings": ["string"],
  "decisions": ["string"],
  "events": ["string"],
  "tags": ["string"]
}

Rules:
- Do not add fields not in the schema.
- tasks: only explicit tasks or action items mentioned.
- learnings: insights, new things learned, realisations.
- decisions: clear decisions made by the user.
- events: notable events or meetings mentioned.
- tags: 3-6 short lowercase topic tags.

Reflections:
$joined
''';
  }

  // ── Response Parser ──

  AiExtractionResult _parseResponse(Map<String, dynamic> json) {
    return AiExtractionResult(
      summary: json['summary'] as String? ?? '',
      mood: json['mood'] as int?,
      energy: json['energy'] as int?,
      tasks: _parseTasks(json['tasks']),
      learnings: _toStringList(json['learnings']),
      decisions: _toStringList(json['decisions']),
      events: _toStringList(json['events']),
      tags: _toStringList(json['tags']),
    );
  }

  List<KnowledgeTask> _parseTasks(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((t) {
      final m = Map<String, dynamic>.from(t as Map);
      return KnowledgeTask(
        title: m['title'] as String? ?? '',
        isDone: m['isDone'] as bool? ?? false,
        source: m['source'] as String? ?? 'ai',
      );
    }).toList();
  }

  List<String> _toStringList(dynamic raw) {
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
