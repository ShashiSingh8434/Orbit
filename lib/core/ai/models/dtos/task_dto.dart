import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_dto.freezed.dart';
part 'task_dto.g.dart';

@freezed
abstract class TaskDto with _$TaskDto {
  const factory TaskDto({
    required String title,
    String? originalId,
    String? description,
    String? dueDate, // Keep as string from AI (e.g. "YYYY-MM-DD")
    String? dueTime, // Keep as string (e.g. "14:30")
    @Default('medium') String priority,
    @Default('pending') String status,
    double? aiConfidence,
  }) = _TaskDto;

  factory TaskDto.fromJson(Map<String, dynamic> json) =>
      _$TaskDtoFromJson(json);
}
