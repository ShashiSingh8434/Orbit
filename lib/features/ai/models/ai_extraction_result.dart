import 'package:freezed_annotation/freezed_annotation.dart';
import '../../knowledge/models/daily_knowledge_model.dart';

part 'ai_extraction_result.freezed.dart';
part 'ai_extraction_result.g.dart';

@freezed
abstract class AiExtractionResult with _$AiExtractionResult {
  const factory AiExtractionResult({
    @Default('') String summary,

    int? mood,

    int? energy,

    @Default([]) List<KnowledgeTask> tasks,

    @Default([]) List<String> learnings,

    @Default([]) List<String> decisions,

    @Default([]) List<String> events,

    @Default([]) List<String> tags,
  }) = _AiExtractionResult;

  factory AiExtractionResult.fromJson(Map<String, dynamic> json) =>
      _$AiExtractionResultFromJson(json);
}
