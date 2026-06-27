import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/entity_metadata.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

@freezed
abstract class TaskModel with _$TaskModel {
  const factory TaskModel({
    required String id,
    required String title,
    @Default('') String description,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    String? dueTime,
    @Default('medium') String priority,
    @Default('pending') String status,
    DateTime? completedAt,
    
    EntityMetadata? metadata,
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);
}
