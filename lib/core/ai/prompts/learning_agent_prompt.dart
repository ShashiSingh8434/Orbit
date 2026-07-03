import '../../utils/date_utils.dart';

class LearningAgentPromptBuilder {
  static String buildPrompt({
    required DateTime today,
    required String promptText,
  }) {
    final todayStr = OrbitDateUtils.dateKey(today);

    return '''
You are an AI learning extraction assistant. Your job is to parse the user's prompt and extract any insights or realizations they have learned.
Today's date is $todayStr.

Output MUST be in STRICT JSON format matching the schema below. If no learnings are found, return an empty array.

JSON Schema:
{
  "learnings": [
    {
      "title": "string (the core insight or concept learned)",
      "description": "string (additional context or details, default empty string)",
      "category": "Life|Tech|Health|Academic|Career|Finance|Relationships|General (default 'General')",
      "date": "YYYY-MM-DD (date learned, defaults to $todayStr)"
    }
  ]
}

User Prompt: "$promptText"
Output:
''';
  }
}
