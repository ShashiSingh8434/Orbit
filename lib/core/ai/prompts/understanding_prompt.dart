import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../features/tasks/models/task_model.dart';
import '../../../features/event/models/event_model.dart';
import '../../utils/date_utils.dart';

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
        ? pendingTasks
              .map(
                (t) =>
                    '- [ID: ${t.id}] "${t.title}" (Due: ${t.dueDate != null ? OrbitDateUtils.dateKey(t.dueDate!) : "None"})',
              )
              .join('\n   ')
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
Your job is to read the user's daily reflection and extract precise, structured data in STRICT JSON FORMAT matching the schema.
Be analytical and highly accurate. If a section has no relevant data, return an empty array `[]`.

<context>
Today's date is $reflectionDate.
</context>

<extraction_rules>
$summaryInstruction

2. TASKS: Extract actionable items the user needs to do, tasks they explicitly mention completing, or requests to update existing tasks.
   - If user says "add a task to..." or "I need to...": FIRST check EXISTING PENDING TASKS. If a task with a similar title already exists, output its `originalId` to avoid duplicates. Otherwise, create a new task with status="pending".
   - If user says "mark [X] as complete", "I finished [X]", or similar: find the best match in EXISTING PENDING TASKS, set its status to "completed", and YOU MUST output its exact ID in the `originalId` field.
   - If user says "reschedule task [X] to [Date]" or "change due date of task [X] to [Date]": find the best match in EXISTING PENDING TASKS, set status="pending", output its exact ID in the `originalId` field, and populate the new `dueDate` and optional `dueTime`.
   - If you can't find a match for a completed/updated task, create a new task with status="completed" or "pending" accordingly.
   - EXISTING PENDING TASKS:
   $pendingTasksStr

3. LEARNINGS: Extract insights, realizations, lessons learned, or explicit "I learned..." statements.
   - Generate a short, appropriate title for the `title` field.
   - Use the `description` field for detail or elaboration on what was learned.
   - Category should be one of: Life, Tech, Health, Academic, Career, Finance, Relationships, General.

4. DECISIONS: Extract choices, decisions, or commitments the user explicitly made (e.g. "I decided to...", "I'm committing to...").
   - Populate the `decision` field.
   - Populate the `reason` field if they mention why they made this choice.

5. EVENTS: Extract events scheduled, created, or attended (e.g. "create an event xyz", "schedule xyz", "I went to gym").
   - If user says "add event", "create event", or "schedule...": FIRST check EXISTING UPCOMING EVENTS to avoid duplicates. If it exists, output its `originalId`.
   - If user says "change the date of event [X] to [Date]", "reschedule event [X] to [Date]", or "move event [X] to [Date]": find the best match in EXISTING UPCOMING EVENTS, output its exact ID in the `originalId` field, and set the new `eventDate`.
   - If user says "I went to the gym at 6am" → eventDate="$reflectionDate", time="6:00 AM".
   - Always provide eventDate in YYYY-MM-DD format. Default to "$reflectionDate" if no date is mentioned.
   - EXISTING UPCOMING EVENTS:
   $upcomingEventsStr
   - VERY IMPORTANT: If the user mentions/updates an event that matches an existing event, YOU MUST output its exact ID in the `originalId` field to avoid duplicates.
</extraction_rules>

CRITICAL JSON RULES:
- NEVER output `null` for a required string field.
- The `title`, `decision`, and `eventDate` fields MUST be strings.
- Non-required fields (like `originalId`, `description`, `dueDate`, `dueTime`, `reason`, `time`, `location`) should be filled with null or appropriate values as per instructions.

<json_format_example>
{
  "summary": { "summary": "A brief summary.", "aiConfidence": 0.95 },
  "tasks": [ { "title": "Buy groceries", "originalId": null, "description": null, "dueDate": null, "dueTime": null, "priority": "medium", "status": "pending", "aiConfidence": 0.9 } ],
  "learnings": [ { "title": "Consistency", "description": "Doing a little bit every day builds momentum.", "category": "Life", "aiConfidence": 0.9 } ],
  "decisions": [ { "decision": "Wake up at 5am", "reason": "To get coding work done early", "aiConfidence": 0.9 } ],
  "events": [ { "title": "Gym Session", "originalId": null, "description": null, "eventDate": "YYYY-MM-DD", "time": "6:00 AM", "location": null, "aiConfidence": 0.9 } ]
}
</json_format_example>

<few_shot_example>
User Reflection: "Today was great! I learned about Flutter Riverpod, specifically how it helps with state management. Create an event Gym at 6 PM. I decided to eat healthier so that I have more energy. Mark 'Buy groceries' as complete. Change the due date of task UI design to tomorrow."
Output:
{
  "summary": { "summary": "A productive day focusing on Flutter state management, healthy eating, and updating tasks.", "aiConfidence": 0.95 },
  "tasks": [ 
    { "title": "Buy groceries", "originalId": "example_task_id_123", "description": null, "dueDate": null, "dueTime": null, "priority": "medium", "status": "completed", "aiConfidence": 0.95 },
    { "title": "UI design", "originalId": "example_task_id_456", "description": null, "dueDate": "2026-07-05", "dueTime": null, "priority": "medium", "status": "pending", "aiConfidence": 0.95 }
  ],
  "learnings": [ { "title": "Flutter Riverpod", "description": "Learned about state management and providers", "category": "Tech", "aiConfidence": 0.9 } ],
  "decisions": [ { "decision": "Eat healthier", "reason": "To have more energy", "aiConfidence": 0.95 } ],
  "events": [ { "title": "Gym", "originalId": null, "description": null, "eventDate": "2026-07-04", "time": "6:00 PM", "location": null, "aiConfidence": 0.95 } ]
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
          requiredProperties: ['summary', 'aiConfidence'],
        ),
        'tasks': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Short actionable title for the task',
              ),
              'originalId': Schema.string(
                description:
                    'The internal ID if this matches/updates an existing pending task',
                nullable: true,
              ),
              'description': Schema.string(
                description: 'Additional detail about the task',
                nullable: true,
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
            requiredProperties: ['title', 'priority', 'status', 'aiConfidence'],
          ),
        ),
        'learnings': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Short clear title for the learning/insight',
              ),
              'description': Schema.string(
                description: 'Detail about what was learned',
                nullable: true,
              ),
              'category': Schema.string(
                description: 'Category like Life, Tech, Health, Academic, etc.',
              ),
              'aiConfidence': Schema.number(),
            },
            requiredProperties: ['title', 'category', 'aiConfidence'],
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
                nullable: true,
              ),
              'aiConfidence': Schema.number(),
            },
            requiredProperties: ['decision', 'aiConfidence'],
          ),
        ),
        'events': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Short title for the event'),
              'originalId': Schema.string(
                description:
                    'The internal ID if this matches/updates an existing upcoming event',
                nullable: true,
              ),
              'description': Schema.string(
                description: 'Additional detail about the event',
                nullable: true,
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
            requiredProperties: ['title', 'eventDate', 'aiConfidence'],
          ),
        ),
      },
      requiredProperties: [
        'summary',
        'tasks',
        'learnings',
        'decisions',
        'events',
      ],
    );
  }
}
