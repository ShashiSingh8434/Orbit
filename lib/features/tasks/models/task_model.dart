import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

/// A user-created or AI-extracted task stored in Firestore.
///
/// Firestore path: `users/{uid}/tasks/{taskId}`
///
/// Tasks can originate from two sources:
/// - `"manual"`: directly created by the user in the Tasks UI.
/// - `"ai"`: extracted from a reflection by the AI engine and
///   promoted to the top-level task list by the user.
@freezed
abstract class TaskModel with _$TaskModel {
  const factory TaskModel({
    required String id,
    required String title,
    @Default('') String description,
    @Default(false) bool isDone,
    required DateTime createdAt,
    DateTime? dueDate,

    /// `"manual"` | `"ai"`
    @Default('manual') String source,
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);
}
