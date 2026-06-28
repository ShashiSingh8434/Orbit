import '../../../core/utils/date_utils.dart';

class DecisionAgentPromptBuilder {
  static String buildPrompt({
    required DateTime today,
    required String promptText,
  }) {
    final todayStr = OrbitDateUtils.dateKey(today);

    return '''
You are an AI decision extraction assistant. Your job is to parse the user's prompt and extract any decisions or commitments they have made.
Today's date is $todayStr.

Output MUST be in STRICT JSON format matching the schema below. If no decisions are found, return an empty array.

JSON Schema:
{
  "decisions": [
    {
      "decision": "string (the core decision description)",
      "reason": "string (any rationale or context provided, default empty string)",
      "status": "Active|Completed|Cancelled|Superseded (default 'Active')",
      "date": "YYYY-MM-DD (date of decision, defaults to $todayStr)"
    }
  ]
}

User Prompt: "$promptText"
Output:
''';
  }
}
