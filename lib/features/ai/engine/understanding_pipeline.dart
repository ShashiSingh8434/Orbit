import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
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
import '../prompts/understanding_prompt.dart';
import '../providers/ai_request.dart';
import '../engine/ai_request_manager.dart';

final understandingPipelineProvider = Provider<UnderstandingPipeline>((ref) {
  return UnderstandingPipeline(
    aiRequestManager: ref.read(aiRequestManagerProvider),
    daySyncService: ref.read(daySyncServiceProvider),
    taskSyncService: ref.read(taskSyncServiceProvider),
    learningSyncService: ref.read(learningSyncServiceProvider),
    decisionSyncService: ref.read(decisionSyncServiceProvider),
    eventSyncService: ref.read(eventSyncServiceProvider),
    moodSyncService: ref.read(moodSyncServiceProvider),
  );
});

class UnderstandingPipeline {
  final AiRequestManager aiRequestManager;
  final DaySyncService daySyncService;
  final TaskSyncService taskSyncService;
  final LearningSyncService learningSyncService;
  final DecisionSyncService decisionSyncService;
  final EventSyncService eventSyncService;
  final MoodSyncService moodSyncService;

  UnderstandingPipeline({
    required this.aiRequestManager,
    required this.daySyncService,
    required this.taskSyncService,
    required this.learningSyncService,
    required this.decisionSyncService,
    required this.eventSyncService,
    required this.moodSyncService,
  });

  Future<void> onReflectionSaved(String uid, ReflectionModel reflection) async {
    debugPrint('UnderstandingPipeline triggered for reflection: ${reflection.id}');

    final schema = UnderstandingPromptBuilder.buildSchema();

    final existingDay = await daySyncService.getDay(uid, reflection.createdAt);
    final existingSummary = existingDay?.summary;
    
    // Fetch context to prevent duplicates and enable task completion
    final pendingTasks = await taskSyncService.getPendingTasks(uid);
    final upcomingEvents = await eventSyncService.getUpcomingEvents(uid);

    final prompt = UnderstandingPromptBuilder.buildPrompt(
      createdAt: reflection.createdAt,
      reflectionText: reflection.text,
      existingSummary: existingSummary,
      pendingTasks: pendingTasks,
      upcomingEvents: upcomingEvents,
    );

    try {
      final response = await aiRequestManager.generate(AiRequest(
        prompt: prompt,
        jsonMode: true,
        responseSchema: schema,
        requestId: 'understanding_${reflection.id}',
      ));

      final jsonString = response.text;

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
