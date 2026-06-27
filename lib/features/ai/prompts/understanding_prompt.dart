import 'package:google_generative_ai/google_generative_ai.dart';
import '../../tasks/models/task_model.dart';
import '../../event/models/event_model.dart';
import '../../../core/utils/date_utils.dart';

class UnderstandingPromptBuilder {
  static String buildPrompt({
    required DateTime createdAt,
    required String reflectionText,
    String? existingSummary,
    required List<TaskModel> pendingTasks,
    required List<EventModel> upcomingEvents,
  }) {
    final reflectionDate = OrbitDateUtils.dateKey(createdAt);
    
    final summaryInstruction = existingSummary != null && existingSummary.isNotEmpty
        ? '1. SUMMARY: The existing summary for this day is "$existingSummary". Merge this new reflection into the summary to create a comprehensive, cohesive, and encouraging 1-2 sentence summary of the entire day.'
        : '1. SUMMARY: Write a brief (1-2 sentence), encouraging summary.';

    final pendingTasksStr = pendingTasks.isNotEmpty 
        ? pendingTasks.map((t) => '- [ID: ${t.id}] "${t.title}"').join('\n   ')
        : 'None';
    
    final upcomingEventsStr = upcomingEvents.isNotEmpty 
        ? upcomingEvents.map((e) => '- [ID: ${e.id}] "${e.title}" on ${OrbitDateUtils.dateKey(e.eventDate)}').join('\n   ')
        : 'None';

    return '''
You are the AI brain of Orbit, a student operating system.
Your job is to read the user's daily reflection and extract precise, structured data.
Be analytical and highly accurate. If a section has no relevant data, return an empty array.

Today's date is $reflectionDate.

Extraction rules:
$summaryInstruction
2. TASKS: Only extract actionable items the user needs to do. Do NOT treat past activities as tasks.
   - "I need to buy groceries" → task. "I went to the gym" → NOT a task.
   - Set priority to "medium" unless urgency is implied.
   - Set status to "pending" unless the user says they completed it.
   - EXISTING PENDING TASKS:
   $pendingTasksStr
   - VERY IMPORTANT: If the user indicates they completed or updated an existing pending task, YOU MUST output its exact ID in the `originalId` field.
3. LEARNINGS: Extract insights, realizations, or new knowledge gained.
   - "I learned that consistency matters" → learning.
   - Category should be one of: Life, Tech, Health, Academic, Career, Finance, Relationships, or General.
4. DECISIONS: Extract choices or commitments the user explicitly made.
   - "I decided to wake up at 5am" → decision. "I went to the gym" → NOT a decision.
5. EVENTS: Extract activities that happened or are scheduled.
   - "I went to the gym at 6am" → event with eventDate="$reflectionDate", time="6:00 AM".
   - "My project deadline is Sept 5" → event with eventDate="2026-09-05".
   - Always provide eventDate in YYYY-MM-DD format. Default to "$reflectionDate" if no date is mentioned.
   - EXISTING UPCOMING EVENTS:
   $upcomingEventsStr
   - VERY IMPORTANT: If the user mentions an event that matches an existing event, YOU MUST output its exact ID in the `originalId` field to avoid duplicates.
6. MOODS: Infer the user's emotional state.
   - Map to a 1-5 integer scale: 1=Very Bad, 2=Bad, 3=Neutral, 4=Good, 5=Very Good.
   - timeOfDay should be one of: Morning, Afternoon, Evening, Night, General.

Reflection text:
"$reflectionText"
''';
  }

  static Schema buildSchema() {
    return Schema.object(
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
              'originalId': Schema.string(description: 'The internal ID if this matches an existing pending task', nullable: true),
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
              'originalId': Schema.string(description: 'The internal ID if this matches an existing upcoming event', nullable: true),
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
  }
}
