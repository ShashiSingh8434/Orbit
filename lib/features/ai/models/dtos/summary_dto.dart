import 'package:freezed_annotation/freezed_annotation.dart';

part 'summary_dto.freezed.dart';
part 'summary_dto.g.dart';

@freezed
abstract class SummaryDto with _$SummaryDto {
  const factory SummaryDto({required String summary, double? aiConfidence}) =
      _SummaryDto;

  factory SummaryDto.fromJson(Map<String, dynamic> json) =>
      _$SummaryDtoFromJson(json);
}
