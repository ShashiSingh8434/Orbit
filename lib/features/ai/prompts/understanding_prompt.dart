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

    final summaryInstruction =
        existingSummary != null && existingSummary.isNotEmpty
        ? '1. SUMMARY: The existing summary for this day is "$existingSummary". Merge this new reflection into the summary to create a comprehensive, cohesive, and encouraging 1-2 sentence summary of the entire day.'
        : '1. SUMMARY: Write a brief (1-2 sentence), encouraging summary.';

    final pendingTasksStr = pendingTasks.isNotEmpty
        ? pendingTasks.map((t) => '- [ID: ${t.id}] "${t.title}"').join('\n   ')
        : 'None';

    final upcomingEventsStr = upcomingEvents.isNotEmpty
        ? upcomingEvents
              .map(
                (e) =>
                    '- [ID: ${e.id}] "${e.title}" on ${OrbitDateUtils.dateKey(e.eventDate)}',
              )
              .join('\n   ')
        : 'None';

    return '''
You are the AI brain of Orbit, a student operating system.
Your job is to read the user's daily reflection and extract precise, structured data in STRICT JSON FORMAT.
Be analytical and highly accurate. If a section has no relevant data, return an empty array `[]`.

<context>
Today's date is $reflectionDate.
</context>

<extraction_rules>
$summaryInstruction

2. TASKS: Extract actionable items the user needs to do, OR tasks they explicitly mention completing.
   - If user says "add a task to..." or "I need to...": FIRST check EXISTING PENDING TASKS. If it already exists, output its `originalId` to avoid duplicates. Otherwise, create a new task with status="pending".
   - If user says "mark [X] as complete", "I finished [X]", or similar: find the best match in EXISTING PENDING TASKS, set its status to "completed", and YOU MUST output its exact ID in the `originalId` field.
   - If you can't find a match for a completed task, create a new one with status="completed".
   - EXISTING PENDING TASKS:
   $pendingTasksStr

3. LEARNINGS: Extract insights, realizations, or explicit "I learned..." statements.
   - If user says "I learned this...", "Today I realized...", extract it.
   - Category should be one of: Life, Tech, Health, Academic, Career, Finance, Relationships, General.

4. DECISIONS: Extract choices or commitments the user explicitly made.
   - If user says "I decided to...", "I took a decision to...", "I'm going to commit to...", extract it.
   - Example: "I decided to wake up at 5am" → decision. 

5. EVENTS: Extract activities that happened or are scheduled (e.g., "add event...").
   - If user says "add event" or "schedule...", FIRST check EXISTING UPCOMING EVENTS to avoid duplicates. If it exists, output its `originalId`.
   - If user says "I went to the gym at 6am" → eventDate="$reflectionDate", time="6:00 AM".
   - Always provide eventDate in YYYY-MM-DD format. Default to "$reflectionDate" if no date is mentioned.
   - EXISTING UPCOMING EVENTS:
   $upcomingEventsStr
   - VERY IMPORTANT: If the user mentions an event that matches an existing event, YOU MUST output its exact ID in the `originalId` field to avoid duplicates.

6. MOODS: Infer the user's emotional state.
   - Map to a 1-5 integer scale: 1=Very Bad, 2=Bad, 3=Neutral, 4=Good, 5=Very Good.
   - timeOfDay should be one of: Morning, Afternoon, Evening, Night, General.
</extraction_rules>

CRITICAL JSON RULES:
- NEVER output `null` for a string field. Use an empty string `""` if you don't have a value.
- The `title`, `learning`, `category`, `decision`, `eventDate`, and `timeOfDay` fields MUST be strings, never null.

<json_format_example>
{
  "summary": { "summary": "...", "aiConfidence": 0.9 },
  "tasks": [ { "title": "Buy groceries", "originalId": null, "description": "", "dueDate": null, "dueTime": null, "priority": "medium", "status": "pending", "aiConfidence": 0.9 } ],
  "learnings": [ { "learning": "I learned that consistency matters", "category": "Life", "aiConfidence": 0.9 } ],
  "decisions": [ { "decision": "I decided to wake up at 5am", "aiConfidence": 0.9 } ],
  "events": [ { "title": "Gym", "originalId": null, "eventDate": "YYYY-MM-DD", "time": "6:00 AM", "aiConfidence": 0.9 } ],
  "moods": [ { "score": 4, "timeOfDay": "Morning", "aiConfidence": 0.9 } ]
}
</json_format_example>

<few_shot_example>
User Reflection: "Today was great! I learned about Flutter Riverpod. Add a task to finish the UI tomorrow. I decided to eat healthier. Mark 'Buy groceries' as complete."
Output:
{
  "summary": { "summary": "A productive day focusing on Flutter development and healthy choices.", "aiConfidence": 0.95 },
  "tasks": [ 
    { "title": "Finish the UI", "originalId": null, "description": "", "dueDate": null, "dueTime": null, "priority": "medium", "status": "pending", "aiConfidence": 0.95 },
    { "title": "Buy groceries", "originalId": "example_id_123", "description": "", "dueDate": null, "dueTime": null, "priority": "medium", "status": "completed", "aiConfidence": 0.95 }
  ],
  "learnings": [ { "learning": "Flutter Riverpod for state management", "category": "Tech", "aiConfidence": 0.9 } ],
  "decisions": [ { "decision": "Eat healthier", "aiConfidence": 0.9 } ],
  "events": [],
  "moods": [ { "score": 5, "timeOfDay": "General", "aiConfidence": 0.9 } ]
}
</few_shot_example>

<reflection>
$reflectionText
</reflection>

CRITICAL INSTRUCTION: You MUST output ONLY valid JSON matching the exact schema above. Do not include markdown code blocks like ```json or any other text before or after the JSON.
''';
  }

  static Schema buildSchema() {
    return Schema.object(
      properties: {
        'summary': Schema.object(
          properties: {
            'summary': Schema.string(
              description:
                  'A brief, encouraging 1-2 sentence summary of the reflection.',
            ),
            'aiConfidence': Schema.number(
              description: 'Confidence score from 0.0 to 1.0',
            ),
          },
        ),
        'tasks': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Short actionable title for the task',
              ),
              'originalId': Schema.string(
                description:
                    'The internal ID if this matches an existing pending task',
                nullable: true,
              ),
              'description': Schema.string(
                description: 'Additional detail about the task',
              ),
              'dueDate': Schema.string(
                description: 'YYYY-MM-DD format if mentioned, otherwise null',
                nullable: true,
              ),
              'dueTime': Schema.string(
                description: 'HH:mm format if mentioned, otherwise null',
                nullable: true,
              ),
              'priority': Schema.enumString(
                enumValues: ['low', 'medium', 'high'],
                description: 'Task priority',
              ),
              'status': Schema.enumString(
                enumValues: ['pending', 'completed'],
                description: 'Task status',
              ),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'learnings': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Short title for the learning/insight',
              ),
              'description': Schema.string(
                description: 'Detail about what was learned',
              ),
              'category': Schema.string(
                description: 'Category like Life, Tech, Health, Academic, etc.',
              ),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'decisions': Schema.array(
          items: Schema.object(
            properties: {
              'decision': Schema.string(
                description: 'The decision that was made',
              ),
              'reason': Schema.string(
                description: 'Why this decision was made',
              ),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'events': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Short title for the event'),
              'originalId': Schema.string(
                description:
                    'The internal ID if this matches an existing upcoming event',
                nullable: true,
              ),
              'description': Schema.string(
                description: 'Additional detail about the event',
              ),
              'eventDate': Schema.string(
                description:
                    'YYYY-MM-DD format. Use the reflection date if not explicitly mentioned.',
              ),
              'time': Schema.string(
                description: 'Time of day like "6:00 AM" or "Morning"',
                nullable: true,
              ),
              'location': Schema.string(
                description: 'Location if mentioned',
                nullable: true,
              ),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
        'moods': Schema.array(
          items: Schema.object(
            properties: {
              'timeOfDay': Schema.enumString(
                enumValues: [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Night',
                  'General',
                ],
                description: 'When the mood was felt',
              ),
              'value': Schema.integer(
                description:
                    'Mood on a 1-5 scale: 1=Very Bad, 2=Bad, 3=Neutral, 4=Good, 5=Very Good',
              ),
              'aiConfidence': Schema.number(),
            },
          ),
        ),
      },
    );
  }
}
