import '../../../core/utils/date_utils.dart';

class EventAgentPromptBuilder {
  static String buildPrompt({
    required DateTime today,
    required String promptText,
  }) {
    final todayStr = OrbitDateUtils.dateKey(today);

    return '''
You are an AI event extraction assistant. Your job is to parse the user's prompt and extract any events or meetings scheduled.
Today's date is $todayStr.

Output MUST be in STRICT JSON format matching the schema below. If no events are found, return an empty array.

JSON Schema:
{
  "events": [
    {
      "title": "string (the event name/title)",
      "description": "string (additional description/notes, default empty string)",
      "eventDate": "YYYY-MM-DD (date of the event, defaults to $todayStr)",
      "time": "string (optional time, e.g. '3:00 PM', else empty string)",
      "location": "string (optional location, else empty string)"
    }
  ]
}

User Prompt: "$promptText"
Output:
''';
  }
}
