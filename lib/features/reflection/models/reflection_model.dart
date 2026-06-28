import 'package:freezed_annotation/freezed_annotation.dart';

part 'reflection_model.freezed.dart';
part 'reflection_model.g.dart';

// Represents a single reflection entry created by the user.
// Firestore path: `users/{uid}/reflections/{yyyy-MM-dd}/{id}`

@freezed
abstract class ReflectionModel with _$ReflectionModel {
  const factory ReflectionModel({
    /// Unique reflection ID (UUID v4 generated on the client).
    required String id,

    /// The reflection text body.
    required String text,

    /// When this reflection was first created.
    required DateTime createdAt,

    /// When this reflection was last edited.
    required DateTime updatedAt,

    /// User-applied tags (e.g. `["grateful", "focus", "learning"]`).
    @Default([]) List<String> tags,

    /// How the reflection was captured: `"manual"` (typed) or `"voice"` (STT).
    @Default('manual') String source,

    /// Whether the AI engine has already extracted knowledge from this reflection.
    @Default(false) bool aiProcessed,

    /// Soft-delete flag; filtered out on all reads.
    @Default(false) bool deleted,
  }) = _ReflectionModel;

  factory ReflectionModel.fromJson(Map<String, dynamic> json) =>
      _$ReflectionModelFromJson(json);
}
