import '../../tasks/models/task_model.dart';
import '../../../core/utils/date_utils.dart';

class TaskAgentPromptBuilder {
  static String buildPrompt({
    required DateTime today,
    required String promptText,
    required List<TaskModel> pendingTasks,
  }) {
    final todayStr = OrbitDateUtils.dateKey(today);
    final pendingTasksStr = pendingTasks.isNotEmpty
        ? pendingTasks.map((t) => '- [ID: ${t.id}] "${t.title}" (Priority: ${t.priority}, Due: ${t.dueDate != null ? OrbitDateUtils.dateKey(t.dueDate!) : 'None'})').join('\n   ')
        : 'None';

    return '''
You are an AI task assistant. Your job is to parse the user's prompt and determine which tasks should be created or updated.
Today's date is $todayStr.

Based on the user's prompt and the list of current pending tasks, return a JSON output to either create new tasks or update existing ones (change priority, due date, status to completed, etc.).
Be analytical. If no tasks are to be created or updated, return empty arrays.

EXISTING PENDING TASKS:
$pendingTasksStr

CRITICAL INSTRUCTIONS:
1. To mark a task as completed or update it, you MUST find its match in the EXISTING PENDING TASKS list and output its exact ID in the update block.
2. If the user mentions doing or finishing something, set status to "completed" in the update or create block.
3. Output MUST be in STRICT JSON format matching the schema below.

JSON Schema:
{
  "create": [
    {
      "title": "string (required)",
      "description": "string (optional description)",
      "dueDate": "YYYY-MM-DD (optional, use today's year if date/day mentioned)",
      "dueTime": "string (optional, e.g. '2:00 PM')",
      "priority": "low|medium|high (default 'medium')"
    }
  ],
  "update": [
    {
      "id": "string (required ID from existing pending tasks)",
      "title": "string (optional, if renaming)",
      "description": "string (optional, to update description)",
      "dueDate": "YYYY-MM-DD (optional)",
      "dueTime": "string (optional)",
      "priority": "low|medium|high (optional)",
      "status": "pending|completed (optional)"
    }
  ]
}

User Prompt: "$promptText"
Output:
''';
  }
}
