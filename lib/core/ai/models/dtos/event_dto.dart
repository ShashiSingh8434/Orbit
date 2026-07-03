import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_dto.freezed.dart';
part 'event_dto.g.dart';

@freezed
abstract class EventDto with _$EventDto {
  const factory EventDto({
    required String title,
    String? originalId,
    String? description,
    required String eventDate, // "YYYY-MM-DD"
    String? time,
    String? location,
    double? aiConfidence,
  }) = _EventDto;

  factory EventDto.fromJson(Map<String, dynamic> json) =>
      _$EventDtoFromJson(json);
}
