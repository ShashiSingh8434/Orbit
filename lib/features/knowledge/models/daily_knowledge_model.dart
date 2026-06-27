import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_knowledge_model.freezed.dart';
part 'daily_knowledge_model.g.dart';

/// Represents a single extracted knowledge snapshot for one calendar day.  
///
/// Firestore path: `users/{uid}/dailyKnowledge/{yyyy-MM-dd}`
///
/// This document is written exclusively by the AI engine — never directly
/// from UI widgets or view models.
@freezed
abstract class DailyKnowledgeModel with _$DailyKnowledgeModel {
  const factory DailyKnowledgeModel({
    /// AI-generated summary of the day's reflections.
    @Default('') String summary,

    /// `"auto"` – regenerated each run; `"manual"` – user edited, never overwritten.
    @Default('auto') String summaryMode,

    /// Perceived mood on a 1–5 scale (1 = very low, 5 = excellent).
    int? mood,

    /// Perceived energy level on a 1–5 scale.
    int? energy,

    /// Tasks extracted or confirmed from reflections.
    @Default([]) List<KnowledgeTask> tasks,

    /// Key learnings extracted from reflections (deduplicated by similarity).
    @Default([]) List<String> learnings,

    /// Decisions made during the day (appended, never deduplicated).
    @Default([]) List<String> decisions,

    /// Events mentioned in reflections (deduplicated).
    @Default([]) List<String> events,

    /// Union of all tags across reflections.
    @Default([]) List<String> tags,

    /// Total number of reflections that contributed to this snapshot.
    @Default(0) int reflectionCount,

    /// Last time this document was updated by the merge engine.
    DateTime? lastUpdated,
  }) = _DailyKnowledgeModel;

  factory DailyKnowledgeModel.fromJson(Map<String, dynamic> json) =>
      _$DailyKnowledgeModelFromJson(json);
}

/// An individual task embedded in [DailyKnowledgeModel].
@freezed
abstract class KnowledgeTask with _$KnowledgeTask {
  const factory KnowledgeTask({
    required String title,
    @Default(false) bool isDone,
    @Default('ai') String source,
    DateTime? dueDate,
  }) = _KnowledgeTask;

  factory KnowledgeTask.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeTaskFromJson(json);
}
