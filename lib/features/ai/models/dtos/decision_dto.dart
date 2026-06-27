import 'package:freezed_annotation/freezed_annotation.dart';

part 'decision_dto.freezed.dart';
part 'decision_dto.g.dart';

@freezed
abstract class DecisionDto with _$DecisionDto {
  const factory DecisionDto({
    required String decision,
    String? reason,
    double? aiConfidence,
  }) = _DecisionDto;

  factory DecisionDto.fromJson(Map<String, dynamic> json) =>
      _$DecisionDtoFromJson(json);
}
