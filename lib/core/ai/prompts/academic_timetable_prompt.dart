import 'package:google_generative_ai/google_generative_ai.dart';

/// Prompt builder and schema definition for the Academic Timetable Parser.
class AcademicTimetablePromptBuilder {
  /// Builds the prompt instructions for extracting the academic timetable.
  static String buildPrompt() {
    return '''
You are an expert AI document parser specializing in extracting registered courses from university timetable documents.
Your task is to analyze the provided image(s) and extract the list of all unique registered courses.

Follow these strict instructions:
1. READ ALL IMAGES: Analyze all uploaded images carefully. They may contain different parts of the course registration details list.
2. DETAILED COURSE INFO: Extract a list of all unique courses from the registered courses details table. For each course, identify:
   - `code`: e.g. "CSE3001"
   - `name`: e.g. "Database Management Systems"
   - `faculty`: e.g. "Rajneesh Kumar Patel"
   - `room`: e.g. "LC-002" (Look for columns named "Venue", "Room", or "Classroom" in the timetable to extract this)
   - `slot`: e.g. "A11+A12+A13" (This represents the slots, combine them exactly as shown with +)
   - `credits`: e.g. 4 (as an integer)
   - `type`: e.g. "Lecture" or "Lab" or "Lecture and Tutorial"
   - `category`: e.g. "Programme Core"
   - `classNo`: e.g. "BL2026270100478" (sometimes labelled as class number, class no., number, etc.)
3. CLEAN AND DE-DUPLICATE: Ignore duplicated courses.
4. MISSING FIELDS: If any field cannot be found or is not applicable, use an empty string "" for strings, or null/default value where appropriate. Do not guess.
5. RETURN ONLY VALID JSON: Return only a JSON object matching the requested schema. No markdown formatting (like ```json), no comments, no explanations.
''';
  }

  /// Builds the Google Generative AI Schema for structural enforcement.
  static Schema buildSchema() {
    return Schema.object(
      properties: {
        'courses': Schema.array(
          description:
              'List of all unique courses found in the timetable documents.',
          items: Schema.object(
            properties: {
              'code': Schema.string(description: 'Course code, e.g., CSE3001'),
              'name': Schema.string(
                description: 'Course name, e.g., Database Management Systems',
              ),
              'faculty': Schema.string(
                description: 'Faculty or instructor name',
              ),
              'room': Schema.string(
                description: 'Room, Venue or classroom location, e.g., LC-002',
              ),
              'slot': Schema.string(
                description: 'Slot name, e.g., A11+A12+A13',
              ),
              'credits': Schema.integer(
                description: 'Number of credits for the course',
              ),
              'type': Schema.string(description: 'Lecture, Lab, Seminar, etc.'),
              'category': Schema.string(
                description: 'Programme Core, University Elective, etc.',
              ),
              'classNo': Schema.string(
                description: 'Unique class or registration number',
              ),
            },
            requiredProperties: ['code', 'name'],
          ),
        ),
      },
      requiredProperties: ['courses'],
    );
  }
}
