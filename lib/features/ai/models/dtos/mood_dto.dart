import 'package:freezed_annotation/freezed_annotation.dart';

part 'mood_dto.freezed.dart';
part 'mood_dto.g.dart';

@freezed
abstract class MoodDto with _$MoodDto {
  const factory MoodDto({
    required String timeOfDay, // Morning, Afternoon, Evening, Night
    required int value, // 1-5 scale
    double? aiConfidence,
  }) = _MoodDto;

  factory MoodDto.fromJson(Map<String, dynamic> json) =>
      _$MoodDtoFromJson(json);
}
