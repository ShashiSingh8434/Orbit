import 'package:freezed_annotation/freezed_annotation.dart';

part 'entity_metadata.freezed.dart';
part 'entity_metadata.g.dart';

@freezed
abstract class EntityMetadata with _$EntityMetadata {
  const factory EntityMetadata({
    String? originReflectionId,
    String? originReflectionText,
    double? aiConfidence,
    String? modelVersion,
    @Default([]) List<String> sourceTags,
    @Default('manual') String createdBy,
    @Default(false) bool manualOverride,
    DateTime? lastProcessedAt,
  }) = _EntityMetadata;

  factory EntityMetadata.fromJson(Map<String, dynamic> json) =>
      _$EntityMetadataFromJson(json);
}
