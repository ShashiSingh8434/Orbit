import 'package:google_generative_ai/google_generative_ai.dart';

/// Prompt builder and schema definition for the Academic Timetable Parser.
///
/// Design goal: minimise AI output tokens.
/// The AI returns ONLY raw course rows. All derived data (schedule mapping,
/// deduplication, chronological sort) is computed in-app by
/// [MultimodalExtractionService._parseJsonResponse].
class AcademicTimetablePromptBuilder {
  /// Builds the prompt instructions for extracting the academic timetable.
  ///
  /// Kept intentionally compact — every saved input token lowers the chance
  /// of hitting Groq's 8 K TPM free-tier limit across concurrent requests.
  static String buildPrompt() {
    return '''
You are a data-extraction engine. Look at the timetable image(s) and return ONLY a compact raw JSON object — no markdown fences, no prose, no <think> blocks.

Schema (one object per course row):
{"courses":[{"code":"","name":"","faculty":"","room":"","slot":"","credits":0,"type":"","category":"","classNo":""}]}

Field mapping (column → field):
- Course Code → code
- Course Title → name (title only, strip parentheticals)
- Faculty column → faculty (Title Case; remove dept tags: SCOPE/SCAI/SASL/SMEC/ACAD)
- Venue column → room (room code only e.g. AB02-018)
- Slot column → slot (join multiple with +, e.g. A11+A12+A13; "" if NIL/blank)
- L T P J C column → credits (last integer only)
- Course Type column → type
- Course Category column → category
- Class No. column → classNo

Constraints: scan ALL image pages, "" for missing strings, 0 for missing credits, output ONLY the JSON object starting with { and ending with }.
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
