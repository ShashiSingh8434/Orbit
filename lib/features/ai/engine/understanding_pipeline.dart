import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../reflection/models/reflection_model.dart';
import '../models/dtos/summary_dto.dart';
import '../models/dtos/task_dto.dart';
import '../models/dtos/learning_dto.dart';
import '../models/dtos/decision_dto.dart';
import '../models/dtos/event_dto.dart';
import '../models/dtos/mood_dto.dart';
import '../sync_services/day_sync_service.dart';
import '../sync_services/task_sync_service.dart';
import '../sync_services/learning_sync_service.dart';
import '../sync_services/decision_sync_service.dart';
import '../sync_services/event_sync_service.dart';
import '../sync_services/mood_sync_service.dart';

final understandingPipelineProvider = Provider<UnderstandingPipeline>((ref) {
  return UnderstandingPipeline(
    daySyncService: ref.read(daySyncServiceProvider),
    taskSyncService: ref.read(taskSyncServiceProvider),
    learningSyncService: ref.read(learningSyncServiceProvider),
    decisionSyncService: ref.read(decisionSyncServiceProvider),
    eventSyncService: ref.read(eventSyncServiceProvider),
    moodSyncService: ref.read(moodSyncServiceProvider),
  );
});

class UnderstandingPipeline {
  final DaySyncService daySyncService;
  final TaskSyncService taskSyncService;
  final LearningSyncService learningSyncService;
  final DecisionSyncService decisionSyncService;
  final EventSyncService eventSyncService;
  final MoodSyncService moodSyncService;

  UnderstandingPipeline({
    required this.daySyncService,
    required this.taskSyncService,
    required this.learningSyncService,
    required this.decisionSyncService,
    required this.eventSyncService,
    required this.moodSyncService,
  });

  Future<void> onReflectionSaved(String uid, ReflectionModel reflection) async {
    debugPrint('UnderstandingPipeline triggered for reflection: ${reflection.id}');

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Error: GEMINI_API_KEY not found in .env');
      return;
    }

    final schema = Schema.object(
      properties: {
        'summary': Schema.object(
          properties: {
            'summary': Schema.string(description: 'A brief, encouraging summary of the reflection.'),
            'aiConfidence': Schema.number(),
          },
        ),
        'tasks': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'description': Schema.string(),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'learnings': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'description': Schema.string(),
              'category': Schema.string(),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'decisions': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'context': Schema.string(),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'events': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'description': Schema.string(),
              'time': Schema.string(description: 'E.g., "6 a.m." or "Morning"', nullable: true),
              'location': Schema.string(nullable: true),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'moods': Schema.array(
          items: Schema.object(
            properties: {
              'mood': Schema.string(description: 'A single word describing the emotion (e.g., happy, sad, focused)'),
              'intensity': Schema.integer(description: '1 to 10'),
              'notes': Schema.string(),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
      },
    );

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
      ),
    );

    final prompt = '''
You are the AI brain of Orbit, a student operating system. 
Your job is to read the user's reflection and extract precise, structured data so that it can be synced to their modules. 
Be analytical and highly accurate. If a section has no relevant data, return an empty array for it.

Extraction Guidelines:
1. SUMMARY: Provide a brief (1-2 sentences), encouraging summary of the reflection in the third person (or addressing the user directly as "You").
2. TASKS: Identify actionable items the user needs to do in the future. E.g., "I need to buy groceries tomorrow" -> Title: "Buy groceries".
3. LEARNINGS: Extract new insights, facts, or realizations. E.g., "I realized that being happy is the best" -> Title: "Being happy is paramount", Category: "Life".
4. DECISIONS: Extract any choices or commitments the user made. E.g., "I decided to wake up at 5am daily" -> Title: "Wake up at 5am daily", Context: "To be more productive". 
5. EVENTS: Identify past occurrences or future scheduled events, including timelines or locations. E.g., "My project will be completed around Sept 5" -> Title: "Project Completion", Time: "Sept 5".
6. MOODS: Infer the emotional state of the user. Choose a single descriptive word (e.g., Happy, Stressed, Motivated) and assign an intensity from 1-10.

Reflection text:
"${reflection.text}"
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final jsonString = response.text;
      if (jsonString == null) throw Exception('Null response from Gemini');

      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Parse DTOs
      final summaryMap = data['summary'] as Map<String, dynamic>? ?? {};
      final summaryDto = SummaryDto(
        summary: summaryMap['summary'] as String? ?? 'Processed by AI',
        aiConfidence: (summaryMap['aiConfidence'] as num?)?.toDouble() ?? 1.0,
      );

      final extractedTasks = (data['tasks'] as List<dynamic>? ?? []).map((e) => TaskDto.fromJson(e as Map<String, dynamic>)).toList();
      final extractedLearnings = (data['learnings'] as List<dynamic>? ?? []).map((e) => LearningDto.fromJson(e as Map<String, dynamic>)).toList();
      final extractedDecisions = (data['decisions'] as List<dynamic>? ?? []).map((e) => DecisionDto.fromJson(e as Map<String, dynamic>)).toList();
      final extractedEvents = (data['events'] as List<dynamic>? ?? []).map((e) => EventDto.fromJson(e as Map<String, dynamic>)).toList();
      final extractedMoods = (data['moods'] as List<dynamic>? ?? []).map((e) => MoodDto.fromJson(e as Map<String, dynamic>)).toList();

      // Stage 4-7: Normalization, Merge, Synchronization, Repository Updates
      await _synchronize(
        uid: uid, 
        dayDate: reflection.createdAt,
        reflectionId: reflection.id,
        summary: summaryDto,
        tasks: extractedTasks,
        learnings: extractedLearnings,
        decisions: extractedDecisions,
        events: extractedEvents,
        moods: extractedMoods,
      );
      
      debugPrint('UnderstandingPipeline completed for reflection: ${reflection.id}');
    } catch (e) {
      debugPrint('UnderstandingPipeline error: $e');
    }
  }

  Future<void> _synchronize({
    required String uid,
    required DateTime dayDate,
    required String reflectionId,
    required SummaryDto summary,
    required List<TaskDto> tasks,
    required List<LearningDto> learnings,
    required List<DecisionDto> decisions,
    required List<EventDto> events,
    required List<MoodDto> moods,
  }) async {
    // Parallelize synchronization where possible, except Day which might depend on completion
    await Future.wait([
      daySyncService.syncDaySummary(uid, dayDate, summary),
      taskSyncService.syncTasks(uid, tasks, reflectionId),
      learningSyncService.syncLearnings(uid, learnings, reflectionId),
      decisionSyncService.syncDecisions(uid, decisions, reflectionId),
      eventSyncService.syncEvents(uid, events, reflectionId),
      moodSyncService.syncMoods(uid, dayDate, moods, reflectionId),
    ]);
  }
}
