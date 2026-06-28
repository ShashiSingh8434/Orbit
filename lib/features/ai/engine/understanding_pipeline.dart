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
import '../../reflection/data/reflection_repository.dart';
import '../prompts/understanding_prompt.dart';
import '../providers/ai_request.dart';
import '../engine/ai_request_manager.dart';
import '../../../core/utils/date_utils.dart';

final understandingPipelineProvider = Provider<UnderstandingPipeline>((ref) {
  return UnderstandingPipeline(
    aiRequestManager: ref.read(aiRequestManagerProvider),
    daySyncService: ref.read(daySyncServiceProvider),
    taskSyncService: ref.read(taskSyncServiceProvider),
    learningSyncService: ref.read(learningSyncServiceProvider),
    decisionSyncService: ref.read(decisionSyncServiceProvider),
    eventSyncService: ref.read(eventSyncServiceProvider),
    moodSyncService: ref.read(moodSyncServiceProvider),
    reflectionRepository: ref.read(reflectionRepositoryProvider),
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
  final ReflectionRepository reflectionRepository;

  UnderstandingPipeline({
    required this.aiRequestManager,
    required this.daySyncService,
    required this.taskSyncService,
    required this.learningSyncService,
    required this.decisionSyncService,
    required this.eventSyncService,
    required this.moodSyncService,
    required this.reflectionRepository,
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
        label: 'Analyzing reflection...',
      ));

      var jsonString = response.text.trim();
      if (jsonString.startsWith('```json')) {
        jsonString = jsonString.substring(7);
      } else if (jsonString.startsWith('```')) {
        jsonString = jsonString.substring(3);
      }
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
      jsonString = jsonString.trim();

      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Parse DTOs
      final summaryMap = data['summary'] as Map<String, dynamic>? ?? {};
      final summaryDto = SummaryDto(
        summary: summaryMap['summary'] as String? ?? 'Processed by AI',
        aiConfidence: (summaryMap['aiConfidence'] as num?)?.toDouble() ?? 1.0,
      );

      final extractedTasks = <TaskDto>[];
      for (final e in (data['tasks'] as List<dynamic>? ?? [])) {
        try { extractedTasks.add(TaskDto.fromJson(e as Map<String, dynamic>)); } catch (_) {}
      }

      final extractedLearnings = <LearningDto>[];
      for (final e in (data['learnings'] as List<dynamic>? ?? [])) {
        try {
          final map = Map<String, dynamic>.from(e as Map);
          if (!map.containsKey('title') && map.containsKey('learning')) {
            map['title'] = map['learning'];
          }
          extractedLearnings.add(LearningDto.fromJson(map));
        } catch (_) {}
      }

      final extractedDecisions = <DecisionDto>[];
      for (final e in (data['decisions'] as List<dynamic>? ?? [])) {
        try { extractedDecisions.add(DecisionDto.fromJson(e as Map<String, dynamic>)); } catch (_) {}
      }

      final extractedEvents = <EventDto>[];
      for (final e in (data['events'] as List<dynamic>? ?? [])) {
        try { extractedEvents.add(EventDto.fromJson(e as Map<String, dynamic>)); } catch (_) {}
      }

      final extractedMoods = <MoodDto>[];
      for (final e in (data['moods'] as List<dynamic>? ?? [])) {
        try {
          final map = Map<String, dynamic>.from(e as Map);
          if (!map.containsKey('value') && map.containsKey('score')) {
            map['value'] = map['score'];
          }
          extractedMoods.add(MoodDto.fromJson(map));
        } catch (_) {}
      }

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
      
      // Mark as processed so the QueueManager doesn't retry it
      await reflectionRepository.markAiProcessed(uid, OrbitDateUtils.dateKey(reflection.createdAt), reflection.id);
      
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
