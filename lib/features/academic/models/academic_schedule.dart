// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'academic_schedule.freezed.dart';
part 'academic_schedule.g.dart';

@freezed
abstract class Course with _$Course {
  const factory Course({
    required String code,
    required String name,
    @Default('') String faculty,
    @Default('') String room,
    @Default('') String slot,
    @Default(0) int credits,
    @Default('') String type,
    @Default('') String category,
    @Default('') String classNo,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
}

@freezed
abstract class ClassSession with _$ClassSession {
  const factory ClassSession({
    required String startTime,
    required String endTime,
    required String code,
    required String name,
    @Default('') String faculty,
    @Default('') String room,
    @Default('') String slot,
  }) = _ClassSession;

  factory ClassSession.fromJson(Map<String, dynamic> json) => _$ClassSessionFromJson(json);
}

@freezed
abstract class WeekSchedule with _$WeekSchedule {
  @JsonSerializable(explicitToJson: true)
  const factory WeekSchedule({
    @JsonKey(name: 'Monday') @Default([]) List<ClassSession> monday,
    @JsonKey(name: 'Tuesday') @Default([]) List<ClassSession> tuesday,
    @JsonKey(name: 'Wednesday') @Default([]) List<ClassSession> wednesday,
    @JsonKey(name: 'Thursday') @Default([]) List<ClassSession> thursday,
    @JsonKey(name: 'Friday') @Default([]) List<ClassSession> friday,
    @JsonKey(name: 'Saturday') @Default([]) List<ClassSession> saturday,
    @JsonKey(name: 'Sunday') @Default([]) List<ClassSession> sunday,
  }) = _WeekSchedule;

  factory WeekSchedule.fromJson(Map<String, dynamic> json) => _$WeekScheduleFromJson(json);
}

@freezed
abstract class AcademicSchedule with _$AcademicSchedule {
  @JsonSerializable(explicitToJson: true)
  const factory AcademicSchedule({
    required List<Course> courses,
    required WeekSchedule schedule,
  }) = _AcademicSchedule;

  factory AcademicSchedule.fromJson(Map<String, dynamic> json) => _$AcademicScheduleFromJson(json);
}
