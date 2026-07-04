import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';
import '../../../features/reflection/models/reflection_model.dart';
import '../models/dtos/summary_dto.dart';
import '../models/dtos/task_dto.dart';
import '../models/dtos/learning_dto.dart';
import '../models/dtos/decision_dto.dart';
import '../models/dtos/event_dto.dart';
import '../sync_services/day_sync_service.dart';
import '../sync_services/task_sync_service.dart';
import '../sync_services/learning_sync_service.dart';
import '../sync_services/decision_sync_service.dart';
import '../sync_services/event_sync_service.dart';
import '../../../features/reflection/data/reflection_repository.dart';
import '../prompts/understanding_prompt.dart';
import '../providers/ai_request.dart';
import '../providers/ai_notification_provider.dart';
import 'ai_request_manager.dart';
import '../../utils/date_utils.dart';

final understandingPipelineProvider = Provider<UnderstandingPipeline>((ref) {
  return UnderstandingPipeline(
    ref: ref,
    aiRequestManager: ref.read(aiRequestManagerProvider),
    daySyncService: ref.read(daySyncServiceProvider),
    taskSyncService: ref.read(taskSyncServiceProvider),
    learningSyncService: ref.read(learningSyncServiceProvider),
    decisionSyncService: ref.read(decisionSyncServiceProvider),
    eventSyncService: ref.read(eventSyncServiceProvider),
    reflectionRepository: ref.read(reflectionRepositoryProvider),
  );
});

class UnderstandingPipeline {
  final Ref ref;
  final AiRequestManager aiRequestManager;
  final DaySyncService daySyncService;
  final TaskSyncService taskSyncService;
  final LearningSyncService learningSyncService;
  final DecisionSyncService decisionSyncService;
  final EventSyncService eventSyncService;
  final ReflectionRepository reflectionRepository;

  UnderstandingPipeline({
    required this.ref,
    required this.aiRequestManager,
    required this.daySyncService,
    required this.taskSyncService,
    required this.learningSyncService,
    required this.decisionSyncService,
    required this.eventSyncService,
    required this.reflectionRepository,
  });

  Future<void> onReflectionSaved(String uid, ReflectionModel reflection) async {
    AppLogger.info(
      'UnderstandingPipeline triggered for reflection: ${reflection.id}',
    );

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
      final response = await aiRequestManager.generate(
        AiRequest(
          prompt: prompt,
          jsonMode: true,
          responseSchema: schema,
          requestId: 'understanding_${reflection.id}',
          label: 'Analyzing reflection...',
        ),
      );

      var jsonString = response.text.trim();
      final firstBrace = jsonString.indexOf('{');
      final lastBrace = jsonString.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        jsonString = jsonString.substring(firstBrace, lastBrace + 1);
      }

      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Parse DTOs
      final summaryMap = data['summary'] as Map<String, dynamic>? ?? {};
      final summaryDto = SummaryDto(
        summary: summaryMap['summary'] as String? ?? 'Processed by AI',
        aiConfidence: (summaryMap['aiConfidence'] as num?)?.toDouble() ?? 1.0,
      );

      final extractedTasks = <TaskDto>[];
      for (final e in (data['tasks'] as List<dynamic>? ?? [])) {
        try {
          extractedTasks.add(TaskDto.fromJson(e as Map<String, dynamic>));
        } catch (err, stack) {
          AppLogger.error('Failed to parse task DTO: $e', err, stack);
        }
      }

      final extractedLearnings = <LearningDto>[];
      for (final e in (data['learnings'] as List<dynamic>? ?? [])) {
        try {
          final map = Map<String, dynamic>.from(e as Map);
          if (!map.containsKey('title') && map.containsKey('learning')) {
            map['title'] = map['learning'];
          }
          extractedLearnings.add(LearningDto.fromJson(map));
        } catch (err, stack) {
          AppLogger.error('Failed to parse learning DTO: $e', err, stack);
        }
      }

      final extractedDecisions = <DecisionDto>[];
      for (final e in (data['decisions'] as List<dynamic>? ?? [])) {
        try {
          extractedDecisions.add(
            DecisionDto.fromJson(e as Map<String, dynamic>),
          );
        } catch (err, stack) {
          AppLogger.error('Failed to parse decision DTO: $e', err, stack);
        }
      }

      final extractedEvents = <EventDto>[];
      for (final e in (data['events'] as List<dynamic>? ?? [])) {
        try {
          extractedEvents.add(EventDto.fromJson(e as Map<String, dynamic>));
        } catch (err, stack) {
          AppLogger.error('Failed to parse event DTO: $e', err, stack);
        }
      }

      // Normalization, Merge, Synchronization, Repository Updates
      final stats = await _synchronize(
        uid: uid,
        dayDate: reflection.createdAt,
        reflectionId: reflection.id,
        summary: summaryDto,
        tasks: extractedTasks,
        learnings: extractedLearnings,
        decisions: extractedDecisions,
        events: extractedEvents,
      );

      // Mark as processed so the QueueManager doesn't retry it
      await reflectionRepository.markAiProcessed(
        uid,
        OrbitDateUtils.dateKey(reflection.createdAt),
        reflection.id,
      );

      final tasksCreated = stats['tasks']!.$1;
      final tasksUpdated = stats['tasks']!.$2;
      final learningsCreated = stats['learnings']!.$1;
      final learningsUpdated = stats['learnings']!.$2;
      final decisionsCreated = stats['decisions']!.$1;
      final decisionsUpdated = stats['decisions']!.$2;
      final eventsCreated = stats['events']!.$1;
      final eventsUpdated = stats['events']!.$2;

      // Construct a nice message of what got created / updated
      final List<String> msgParts = [];
      if (tasksCreated > 0) msgParts.add('$tasksCreated task${tasksCreated > 1 ? 's' : ''} created');
      if (tasksUpdated > 0) msgParts.add('$tasksUpdated task${tasksUpdated > 1 ? 's' : ''} updated');
      if (learningsCreated > 0) msgParts.add('$learningsCreated learning${learningsCreated > 1 ? 's' : ''} created');
      if (learningsUpdated > 0) msgParts.add('$learningsUpdated learning${learningsUpdated > 1 ? 's' : ''} updated');
      if (decisionsCreated > 0) msgParts.add('$decisionsCreated decision${decisionsCreated > 1 ? 's' : ''} created');
      if (decisionsUpdated > 0) msgParts.add('$decisionsUpdated decision${decisionsUpdated > 1 ? 's' : ''} updated');
      if (eventsCreated > 0) msgParts.add('$eventsCreated event${eventsCreated > 1 ? 's' : ''} created');
      if (eventsUpdated > 0) msgParts.add('$eventsUpdated event${eventsUpdated > 1 ? 's' : ''} updated');

      if (msgParts.isNotEmpty) {
        final message = 'Insights extracted:\n${msgParts.join(',\n')}.';
        ref.read(aiNotificationProvider.notifier).notify(message);
      } else {
        ref.read(aiNotificationProvider.notifier).notify('Reflection analyzed. No new insights to update.');
      }

      AppLogger.info(
        'UnderstandingPipeline completed for reflection: ${reflection.id}',
      );
    } catch (e, stackTrace) {
      AppLogger.error('UnderstandingPipeline error', e, stackTrace);
    }
  }

  Future<Map<String, (int, int)>> _synchronize({
    required String uid,
    required DateTime dayDate,
    required String reflectionId,
    required SummaryDto summary,
    required List<TaskDto> tasks,
    required List<LearningDto> learnings,
    required List<DecisionDto> decisions,
    required List<EventDto> events,
  }) async {
    // Parallelize synchronization
    final results = await Future.wait([
      taskSyncService.syncTasks(uid, tasks, reflectionId, dayDate),
      learningSyncService.syncLearnings(uid, learnings, reflectionId, dayDate),
      decisionSyncService.syncDecisions(uid, decisions, reflectionId, dayDate),
      eventSyncService.syncEvents(uid, events, reflectionId),
      daySyncService.syncDaySummary(uid, dayDate, summary),
    ]);

    final taskResult = results[0] as (int, int);
    final learningResult = results[1] as (int, int);
    final decisionResult = results[2] as (int, int);
    final eventResult = results[3] as (int, int);

    return {
      'tasks': taskResult,
      'learnings': learningResult,
      'decisions': decisionResult,
      'events': eventResult,
    };
  }
}
