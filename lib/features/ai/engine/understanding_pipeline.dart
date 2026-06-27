import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/utils/date_utils.dart';
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
            'summary': Schema.string(description: 'A brief, encouraging 1-2 sentence summary of the reflection.'),
            'aiConfidence': Schema.number(description: 'Confidence score from 0.0 to 1.0'),
          },
        ),
        'tasks': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Short actionable title for the task'),
              'description': Schema.string(description: 'Additional detail about the task'),
              'dueDate': Schema.string(description: 'YYYY-MM-DD format if mentioned, otherwise null', nullable: true),
              'dueTime': Schema.string(description: 'HH:mm format if mentioned, otherwise null', nullable: true),
              'priority': Schema.enumString(enumValues: ['low', 'medium', 'high'], description: 'Task priority'),
              'status': Schema.enumString(enumValues: ['pending', 'completed'], description: 'Task status'),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'learnings': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Short title for the learning/insight'),
              'description': Schema.string(description: 'Detail about what was learned'),
              'category': Schema.string(description: 'Category like Life, Tech, Health, Academic, etc.'),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'decisions': Schema.array(
          items: Schema.object(
            properties: {
              'decision': Schema.string(description: 'The decision that was made'),
              'reason': Schema.string(description: 'Why this decision was made'),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'events': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Short title for the event'),
              'description': Schema.string(description: 'Additional detail about the event'),
              'eventDate': Schema.string(description: 'YYYY-MM-DD format. Use the reflection date if not explicitly mentioned.'),
              'time': Schema.string(description: 'Time of day like "6:00 AM" or "Morning"', nullable: true),
              'location': Schema.string(description: 'Location if mentioned', nullable: true),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'moods': Schema.array(
          items: Schema.object(
            properties: {
              'timeOfDay': Schema.enumString(enumValues: ['Morning', 'Afternoon', 'Evening', 'Night', 'General'], description: 'When the mood was felt'),
              'value': Schema.integer(description: 'Mood on a 1-5 scale: 1=Very Bad, 2=Bad, 3=Neutral, 4=Good, 5=Very Good'),
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

    final reflectionDate = OrbitDateUtils.dateKey(reflection.createdAt);

    final prompt = '''
You are the AI brain of Orbit, a student operating system.
Your job is to read the user's daily reflection and extract precise, structured data.
Be analytical and highly accurate. If a section has no relevant data, return an empty array.

Today's date is $reflectionDate.

Extraction rules:
1. SUMMARY: Write a brief (1-2 sentence), encouraging summary.
2. TASKS: Only extract actionable items the user needs to do. Do NOT treat past activities as tasks.
   - "I need to buy groceries" → task. "I went to the gym" → NOT a task.
   - Set priority to "medium" unless urgency is implied.
   - Set status to "pending" unless the user says they completed it.
3. LEARNINGS: Extract insights, realizations, or new knowledge gained.
   - "I learned that consistency matters" → learning.
   - Category should be one of: Life, Tech, Health, Academic, Career, Finance, Relationships, or General.
4. DECISIONS: Extract choices or commitments the user explicitly made.
   - "I decided to wake up at 5am" → decision. "I went to the gym" → NOT a decision.
5. EVENTS: Extract activities that happened or are scheduled.
   - "I went to the gym at 6am" → event with eventDate="$reflectionDate", time="6:00 AM".
   - "My project deadline is Sept 5" → event with eventDate="2026-09-05".
   - Always provide eventDate in YYYY-MM-DD format. Default to "$reflectionDate" if no date is mentioned.
6. MOODS: Infer the user's emotional state.
   - Map to a 1-5 integer scale: 1=Very Bad, 2=Bad, 3=Neutral, 4=Good, 5=Very Good.
   - timeOfDay should be one of: Morning, Afternoon, Evening, Night, General.

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
      taskSyncService.syncTasks(uid, tasks, reflectionId, dayDate),
      learningSyncService.syncLearnings(uid, learnings, reflectionId, dayDate),
      decisionSyncService.syncDecisions(uid, decisions, reflectionId, dayDate),
      eventSyncService.syncEvents(uid, events, reflectionId),
      moodSyncService.syncMoods(uid, dayDate, moods, reflectionId),
    ]);
  }
}
