import 'package:freezed_annotation/freezed_annotation.dart';

part 'day_model.freezed.dart';
part 'day_model.g.dart';

@freezed
abstract class DayModel with _$DayModel {
  const factory DayModel({
    required DateTime date,
    @Default('') String summary,
    @Default('auto') String summaryMode,
    @Default(0) int reflectionCount,
    double? averageMood,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? aiVersion,
  }) = _DayModel;

  factory DayModel.fromJson(Map<String, dynamic> json) =>
      _$DayModelFromJson(json);
}
