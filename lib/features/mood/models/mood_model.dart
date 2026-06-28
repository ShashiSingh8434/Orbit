import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/entity_metadata.dart';

part 'mood_model.freezed.dart';
part 'mood_model.g.dart';

@freezed
abstract class MoodModel with _$MoodModel {
  const factory MoodModel({
    required String id,
    required DateTime date,
    required String timeOfDay, // Morning, Afternoon, Evening, Night
    required int value, // 1-5 scale
    @Default(false) bool inferredByAi,
    required DateTime createdAt,
    DateTime? updatedAt,

    EntityMetadata? metadata,
  }) = _MoodModel;

  factory MoodModel.fromJson(Map<String, dynamic> json) =>
      _$MoodModelFromJson(json);
}
