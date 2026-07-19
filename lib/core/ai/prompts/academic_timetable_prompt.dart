import 'package:google_generative_ai/google_generative_ai.dart';

/// Prompt builder and schema definition for the Academic Timetable Parser.
class AcademicTimetablePromptBuilder {
  /// Builds the prompt instructions for extracting the academic timetable.
  static String buildPrompt() {
    return '''
Extract all registered courses from the university timetable image(s). Output ONLY a raw JSON object — no markdown, no explanation, no <think> blocks.

Output format (example row):
{"courses":[{"code":"CSE3001","name":"Database Management Systems","faculty":"Rajneesh Kumar Patel","room":"LC-002","slot":"A11+A12+A13","credits":4,"type":"Lecture and Tutorial","category":"Programme Core","classNo":"BL2026270100478"}]}

Fields:
- code: course code (e.g. CSE3001)
- name: plain course title only, no parentheticals
- faculty: instructor name in title case; strip department tags (SCOPE/SCAI/SASL/SMEC)
- room: room code only (e.g. LC-002, AB02-409); venue cell may have slot on line 1, room on line 2
- slot: compound slot joined with + (e.g. A11+A12+A13); use "" if NIL
- credits: total credits integer from L-T-P-J-C column (last number)
- type: from course name parenthetical — Lecture/Lab/Lecture and Tutorial/Practical Hours Only/Project Only
- category: category column value (e.g. Programme Core, Programme Elective)
- classNo: class ID/registration number

Rules: include all images, deduplicate by code, use "" for missing strings, 0 for missing credits, output nothing but the JSON object.
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
