import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/entity_metadata.dart';

part 'learning_model.freezed.dart';
part 'learning_model.g.dart';

@freezed
abstract class LearningModel with _$LearningModel {
  const factory LearningModel({
    required String id,
    required String title,
    @Default('') String description,
    @Default('general') String category,
    @Default(1) int occurrenceCount,
    DateTime? lastSeen,
    required DateTime createdAt,
    DateTime? updatedAt,
    EntityMetadata? metadata,
  }) = _LearningModel;

  factory LearningModel.fromJson(Map<String, dynamic> json) =>
      _$LearningModelFromJson(json);
}
