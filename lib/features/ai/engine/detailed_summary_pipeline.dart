import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../reflection/data/reflection_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../event/data/event_repository.dart';
import '../../day/data/day_repository.dart';
import '../prompts/detailed_summary_prompt.dart';
import '../providers/ai_request.dart';
import '../engine/ai_request_manager.dart';

import '../../../core/utils/date_utils.dart';

final detailedSummaryPipelineProvider = Provider<DetailedSummaryPipeline>((
  ref,
) {
  return DetailedSummaryPipeline(
    aiRequestManager: ref.read(aiRequestManagerProvider),
    reflectionRepository: ref.read(reflectionRepositoryProvider),
    taskRepository: ref.read(taskRepositoryProvider),
    eventRepository: ref.read(eventRepositoryProvider),
    dayRepository: ref.read(dayRepositoryProvider),
  );
});

class DetailedSummaryPipeline {
  final AiRequestManager aiRequestManager;
  final ReflectionRepository reflectionRepository;
  final TaskRepository taskRepository;
  final EventRepository eventRepository;
  final DayRepository dayRepository;

  DetailedSummaryPipeline({
    required this.aiRequestManager,
    required this.reflectionRepository,
    required this.taskRepository,
    required this.eventRepository,
    required this.dayRepository,
  });

  Future<({String? paragraph, String? bullet})> generateDetailedSummaries(
    String uid,
    DateTime dayDate,
  ) async {
    // 1. Check if we already have it cached
    final existingDay = await dayRepository.getDay(uid, dayDate);
    if (existingDay != null &&
        existingDay.detailedSummary != null &&
        existingDay.detailedSummary!.isNotEmpty &&
        existingDay.detailedSummaryBullet != null &&
        existingDay.detailedSummaryBullet!.isNotEmpty) {
      return (
        paragraph: existingDay.detailedSummary,
        bullet: existingDay.detailedSummaryBullet,
      );
    }

    // 2. Fetch all data for this day
    final dateKey = OrbitDateUtils.dateKey(dayDate);
    final reflections = await reflectionRepository.getReflections(uid, dateKey);

    final allTasks = await taskRepository.getTasks(uid);
    final dayTasks = allTasks.where((t) {
      final createdOnDay =
          t.createdAt.year == dayDate.year &&
          t.createdAt.month == dayDate.month &&
          t.createdAt.day == dayDate.day;
      final dueOnDay =
          t.dueDate != null &&
          t.dueDate!.year == dayDate.year &&
          t.dueDate!.month == dayDate.month &&
          t.dueDate!.day == dayDate.day;
      final completedOnDay =
          t.completedAt != null &&
          t.completedAt!.year == dayDate.year &&
          t.completedAt!.month == dayDate.month &&
          t.completedAt!.day == dayDate.day;
      return createdOnDay || dueOnDay || completedOnDay;
    }).toList();

    final allEvents = await eventRepository.getEvents(uid);
    final dayEvents = allEvents.where((e) {
      return e.eventDate.year == dayDate.year &&
          e.eventDate.month == dayDate.month &&
          e.eventDate.day == dayDate.day;
    }).toList();

    if (reflections.isEmpty && dayTasks.isEmpty && dayEvents.isEmpty) {
      final msg =
          "No data available for this day to generate a detailed summary.";
      return (paragraph: msg, bullet: msg);
    }

    // 3. Build prompts and generate sequentially through the queue
    final promptParagraph = DetailedSummaryPromptBuilder.buildPrompt(
      date: dayDate,
      reflections: reflections,
      tasks: dayTasks,
      events: dayEvents,
      isBulletPoint: false,
    );

    final promptBullet = DetailedSummaryPromptBuilder.buildPrompt(
      date: dayDate,
      reflections: reflections,
      tasks: dayTasks,
      events: dayEvents,
      isBulletPoint: true,
    );

    try {
      // Both requests go through the AI Request Manager (queued, retried, fallback-aware)
      final responseParagraph = await aiRequestManager.generate(
        AiRequest(
          prompt: promptParagraph,
          requestId: 'detailed_paragraph_$dateKey',
          label: 'Generating daily summary...',
        ),
      );
      final paragraph = responseParagraph.text;

      final responseBullet = await aiRequestManager.generate(
        AiRequest(
          prompt: promptBullet,
          requestId: 'detailed_bullet_$dateKey',
          label: 'Generating summary highlights...',
        ),
      );
      final bullet = responseBullet.text;

      if (existingDay != null) {
        // Cache it
        final updatedDay = existingDay.copyWith(
          detailedSummary: paragraph,
          detailedSummaryBullet: bullet,
        );
        await dayRepository.saveDay(uid, updatedDay);
      }

      return (paragraph: paragraph, bullet: bullet);
    } catch (e, stackTrace) {
      AppLogger.error('DetailedSummaryPipeline error', e, stackTrace);
      return (paragraph: null, bullet: null);
    }
  }
}
