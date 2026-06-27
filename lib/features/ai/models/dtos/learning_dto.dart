import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_dto.freezed.dart';
part 'learning_dto.g.dart';

@freezed
abstract class LearningDto with _$LearningDto {
  const factory LearningDto({
    required String title,
    String? description,
    @Default('general') String category,
    double? aiConfidence,
  }) = _LearningDto;

  factory LearningDto.fromJson(Map<String, dynamic> json) =>
      _$LearningDtoFromJson(json);
}
