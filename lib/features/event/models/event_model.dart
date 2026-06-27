import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/entity_metadata.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

@freezed
abstract class EventModel with _$EventModel {
  const factory EventModel({
    required String id,
    required String title,
    @Default('') String description,
    required DateTime eventDate,
    String? time,
    String? location,
    required DateTime createdAt,
    DateTime? updatedAt,
    
    EntityMetadata? metadata,
  }) = _EventModel;

  factory EventModel.fromJson(Map<String, dynamic> json) =>
      _$EventModelFromJson(json);
}
