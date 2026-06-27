import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/entity_metadata.dart';

part 'decision_model.freezed.dart';
part 'decision_model.g.dart';

@freezed
abstract class DecisionModel with _$DecisionModel {
  const factory DecisionModel({
    required String id,
    required String decision,
    @Default('') String reason,
    @Default('Active') String status, // Active, Completed, Cancelled, Superseded
    required DateTime createdAt,
    DateTime? updatedAt,
    
    EntityMetadata? metadata,
  }) = _DecisionModel;

  factory DecisionModel.fromJson(Map<String, dynamic> json) =>
      _$DecisionModelFromJson(json);
}
