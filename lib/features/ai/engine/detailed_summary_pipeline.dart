import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../reflection/data/reflection_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../event/data/event_repository.dart';
import '../../day/data/day_repository.dart';
import '../prompts/detailed_summary_prompt.dart';

import '../../../core/utils/date_utils.dart';

final detailedSummaryPipelineProvider = Provider<DetailedSummaryPipeline>((ref) {
  return DetailedSummaryPipeline(
    reflectionRepository: ref.read(reflectionRepositoryProvider),
    taskRepository: ref.read(taskRepositoryProvider),
    eventRepository: ref.read(eventRepositoryProvider),
    dayRepository: ref.read(dayRepositoryProvider),
  );
});

class DetailedSummaryPipeline {
  final ReflectionRepository reflectionRepository;
  final TaskRepository taskRepository;
  final EventRepository eventRepository;
  final DayRepository dayRepository;

  DetailedSummaryPipeline({
    required this.reflectionRepository,
    required this.taskRepository,
    required this.eventRepository,
    required this.dayRepository,
  });

  Future<({String? paragraph, String? bullet})> generateDetailedSummaries(String uid, DateTime dayDate) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Error: GEMINI_API_KEY not found in .env');
      return (paragraph: null, bullet: null);
    }

    // 1. Check if we already have it cached
    final existingDay = await dayRepository.getDay(uid, dayDate);
    if (existingDay != null && 
        existingDay.detailedSummary != null && existingDay.detailedSummary!.isNotEmpty &&
        existingDay.detailedSummaryBullet != null && existingDay.detailedSummaryBullet!.isNotEmpty) {
      return (paragraph: existingDay.detailedSummary, bullet: existingDay.detailedSummaryBullet);
    }

    // 2. Fetch all data for this day
    final dateKey = OrbitDateUtils.dateKey(dayDate);
    final reflectionsStream = reflectionRepository.watchReflections(uid, dateKey);
    final reflections = await reflectionsStream.first;
    
    final tasksStream = taskRepository.watchTasks(uid);
    final allTasks = await tasksStream.first;
    final dayTasks = allTasks.where((t) {
      // Check if task was created, due, or completed on this day
      final createdOnDay = t.createdAt.year == dayDate.year && t.createdAt.month == dayDate.month && t.createdAt.day == dayDate.day;
      final dueOnDay = t.dueDate != null && t.dueDate!.year == dayDate.year && t.dueDate!.month == dayDate.month && t.dueDate!.day == dayDate.day;
      final completedOnDay = t.completedAt != null && t.completedAt!.year == dayDate.year && t.completedAt!.month == dayDate.month && t.completedAt!.day == dayDate.day;
      return createdOnDay || dueOnDay || completedOnDay;
    }).toList();

    final eventsStream = eventRepository.watchEvents(uid);
    final allEvents = await eventsStream.first;
    final dayEvents = allEvents.where((e) {
      return e.eventDate.year == dayDate.year && e.eventDate.month == dayDate.month && e.eventDate.day == dayDate.day;
    }).toList();

    if (reflections.isEmpty && dayTasks.isEmpty && dayEvents.isEmpty) {
      final msg = "No data available for this day to generate a detailed summary.";
      return (paragraph: msg, bullet: msg);
    }

    // 3. Build prompts and generate concurrently
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

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    try {
      final responseParagraph = await model.generateContent([Content.text(promptParagraph)]);
      final paragraph = responseParagraph.text;

      // Add a small delay to prevent rate limiting on the free tier
      await Future.delayed(const Duration(milliseconds: 500));

      final responseBullet = await model.generateContent([Content.text(promptBullet)]);
      final bullet = responseBullet.text;

      if (paragraph != null && bullet != null && existingDay != null) {
        // Cache it
        final updatedDay = existingDay.copyWith(
          detailedSummary: paragraph,
          detailedSummaryBullet: bullet,
        );
        await dayRepository.saveDay(uid, updatedDay);
      }
      
      return (paragraph: paragraph, bullet: bullet);
    } catch (e) {
      debugPrint('DetailedSummaryPipeline error: $e');
      return (paragraph: null, bullet: null);
    }
  }
}
