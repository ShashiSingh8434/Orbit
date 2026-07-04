import '../../../features/tasks/models/task_model.dart';
import '../../../features/event/models/event_model.dart';
import '../../../features/reflection/models/reflection_model.dart';
import '../../utils/date_utils.dart';

class DetailedSummaryPromptBuilder {
  static String buildPrompt({
    required DateTime date,
    required List<ReflectionModel> reflections,
    required List<TaskModel> tasks,
    required List<EventModel> events,
    required bool isBulletPoint,
  }) {
    final dateKey = OrbitDateUtils.dateKey(date);

    final reflectionsStr = reflections.isNotEmpty
        ? reflections
              .map(
                (r) =>
                    '- [${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}] ${r.text}',
              )
              .join('\n')
        : 'No reflections for this day.';

    final tasksStr = tasks.isNotEmpty
        ? tasks
              .map((t) => '- [${t.status.toUpperCase()}] ${t.title}')
              .join('\n')
        : 'No tasks for this day.';

    final eventsStr = events.isNotEmpty
        ? events
              .map((e) => '- ${e.title} (Time: ${e.time ?? "Unknown"})')
              .join('\n')
        : 'No events for this day.';

    final styleInstruction = isBulletPoint
        ? '''
4. Format: Use ONLY concise, punchy bullet points. Group them under headers like "The Vibe", "Wins", and "Insights". Avoid long paragraphs.
5. Tone & Length: Keep it ultra-compact, modern, and highly readable.
'''
        : '''
4. Format: Write 2-3 short, engaging paragraphs. Use headers to separate thoughts if needed, but the core should be beautifully written prose.
5. Tone & Length: Keep it compact, human-like, and highly readable. Avoid overly lengthy blocks of text.
''';

    return '''
You are Orbit's intelligent companion. You deeply analyze the user's day to provide meaningful insights.
Your goal is to understand their context—their achievements, struggles, and events—and provide a compact, engaging summary.

Date: $dateKey

--- USER'S DAY DATA ---

[Reflections]:
$reflectionsStr

[Tasks]:
$tasksStr

[Events]:
$eventsStr

--- INSTRUCTIONS ---
1. Context: Read between the lines. Reflect the "vibe" of their day.
2. Synthesis: Connect reflections, tasks, and events into a complete story.
3. Empathy: Acknowledge effort. Be encouraging.
$styleInstruction
6. Output: Return ONLY pure Markdown text. Do NOT wrap in JSON.
''';
  }
}
