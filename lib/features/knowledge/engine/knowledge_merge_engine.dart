import '../models/daily_knowledge_model.dart';
import '../../ai/models/ai_extraction_result.dart';

/// Merges an [AiExtractionResult] into an existing [DailyKnowledgeModel].
///
/// Merge rules (per spec):
/// - **Summary**: regenerated unless `summaryMode == "manual"`.
/// - **Tasks**: deduplicated by title; existing task updated if matched.
/// - **Learnings**: deduplicated by text similarity (word-overlap ≥ 70 %).
/// - **Decisions**: appended unconditionally.
/// - **Events**: deduplicated by exact title.
/// - **Mood / Energy**: replaced with latest values (non-null wins).
/// - **Tags**: union of existing + new tags.
/// - **reflectionCount**: incremented.
abstract final class KnowledgeMergeEngine {
  static DailyKnowledgeModel merge({
    required DailyKnowledgeModel existing,
    required AiExtractionResult incoming,
    required int totalReflectionCount,
  }) {
    return existing.copyWith(
      // ── Summary ──────────────────────────────────────────────────
      summary: existing.summaryMode == 'manual'
          ? existing.summary
          : incoming.summary.isNotEmpty
              ? incoming.summary
              : existing.summary,

      mood: incoming.mood ?? existing.mood,
      energy: incoming.energy ?? existing.energy,

      tasks: _mergeTasks(existing.tasks, incoming.tasks),

      learnings: _mergeLearnings(existing.learnings, incoming.learnings),

      decisions: [
        ...existing.decisions,
        ...incoming.decisions.where(
          (d) => !existing.decisions.contains(d),
        ),
      ],

      events: {
        ...existing.events,
        ...incoming.events,
      }.toList(),
      tags: {
        ...existing.tags,
        ...incoming.tags,
      }.toList(),

      reflectionCount: totalReflectionCount,
    );
  }

  // ── Task Merge ────────────────────────────────────────────────────────────

  static List<KnowledgeTask> _mergeTasks(
    List<KnowledgeTask> existing,
    List<KnowledgeTask> incoming,
  ) {
    final result = List<KnowledgeTask>.from(existing);

    for (final task in incoming) {
      final idx = result.indexWhere(
        (e) => _normalise(e.title) == _normalise(task.title),
      );
      if (idx >= 0) {
        result[idx] = result[idx].copyWith(
          source: task.source,
          dueDate: task.dueDate ?? result[idx].dueDate,
        );
      } else {
        result.add(task);
      }
    }

    return result;
  }

  // ── Learning Merge ────────────────────────────────────────────────────────

  static List<String> _mergeLearnings(
    List<String> existing,
    List<String> incoming,
  ) {
    final result = List<String>.from(existing);

    for (final learning in incoming) {
      final isDuplicate = result.any((e) => _areSimilar(e, learning));
      if (!isDuplicate) {
        result.add(learning);
      }
    }

    return result;
  }

  // ── Similarity Helpers ────────────────────────────────────────────────────

  static String _normalise(String s) => s.toLowerCase().trim();

  static bool _areSimilar(String a, String b) {
    final normA = _normalise(a);
    final normB = _normalise(b);

    if (normA == normB) return true;

    final wordsA = normA.split(RegExp(r'\s+')).toSet();
    final wordsB = normB.split(RegExp(r'\s+')).toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    return union > 0 && intersection / union >= 0.7;
  }
}
