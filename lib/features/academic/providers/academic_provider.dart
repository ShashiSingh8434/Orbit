import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/academic_repository.dart';
import '../models/academic_schedule.dart';
import '../data/static_slots.dart';

/// Represents the local state of the academic schedule module.
class AcademicState {
  /// The currently loaded timetable schedule.
  final AcademicSchedule? schedule;

  /// Whether the module is performing an asynchronous operation.
  final bool isLoading;

  /// Whether image files are currently being read/uploaded.
  final bool isUploading;

  /// Whether Gemini is currently extracting information from the images.
  final bool isParsing;

  /// Error message, if any operation failed.
  final String? errorMessage;

  /// Whether the last operation completed successfully.
  final bool isSuccess;

  const AcademicState({
    this.schedule,
    this.isLoading = false,
    this.isUploading = false,
    this.isParsing = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AcademicState copyWith({
    AcademicSchedule? schedule,
    bool? isLoading,
    bool? isUploading,
    bool? isParsing,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AcademicState(
      schedule: schedule ?? this.schedule,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      isParsing: isParsing ?? this.isParsing,
      errorMessage: errorMessage, // nullable, will clear error if null
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Provider for the [AcademicController].
final academicStateProvider = NotifierProvider<AcademicController, AcademicState>(
  AcademicController.new,
);

/// Controller managing state and user actions for the Academic feature.
class AcademicController extends Notifier<AcademicState> {
  late AcademicRepository _repo;

  @override
  AcademicState build() {
    _repo = ref.watch(academicRepositoryProvider);
    // Load local/Firestore schedule on creation
    _loadSchedule();
    return const AcademicState(isLoading: true);
  }

  Future<void> _loadSchedule() async {
    final uid = _getUid();
    if (uid == null) {
      state = const AcademicState();
      return;
    }

    try {
      final schedule = await _repo.getSchedule(uid);
      state = AcademicState(schedule: schedule, isSuccess: true);
    } catch (e) {
      state = AcademicState(errorMessage: e.toString());
    }
  }

  String? _getUid() {
    return ref.read(authStateProvider).value?.uid;
  }

  /// Takes user screenshots/images, uploads to Gemini, parses JSON, and saves locally/remotely.
  Future<void> uploadAndParseTimetable(List<XFile> images) async {
    final uid = _getUid();
    if (uid == null) return;

    state = state.copyWith(isLoading: true, isUploading: true, errorMessage: null);

    try {
      final List<Uint8List> bytesList = [];
      final List<String> mimeTypes = [];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        bytesList.add(bytes);
        final ext = image.path.split('.').last.toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        mimeTypes.add(mimeType);
      }

      state = state.copyWith(isUploading: false, isParsing: true);

      final parsedSchedule = await _repo.parseTimetable(bytesList, mimeTypes);
      await _repo.saveSchedule(uid, parsedSchedule);

      state = AcademicState(
        schedule: parsedSchedule,
        isSuccess: true,
      );
    } catch (e) {
      state = AcademicState(
        schedule: state.schedule,
        errorMessage: e.toString(),
      );
    }
  }

  /// Saves the complete schedule to state, cache, and database.
  Future<void> updateSchedule(AcademicSchedule updated) async {
    final uid = _getUid();
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.saveSchedule(uid, updated);
      state = AcademicState(schedule: updated, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save schedule: $e',
      );
    }
  }

  /// Updates a course details globally and regenerates the weekly schedule.
  Future<void> editCourse(String oldCode, Course updatedCourse) async {
    final schedule = state.schedule ?? const AcademicSchedule(courses: [], schedule: WeekSchedule());
    
    // 1. Update the course in the unique courses list
    final courses = List<Course>.from(schedule.courses);
    final index = courses.indexWhere((c) => c.code.trim().toUpperCase() == oldCode.trim().toUpperCase());
    if (index != -1) {
      courses[index] = updatedCourse;
    } else {
      courses.add(updatedCourse);
    }

    // 2. Regenerate the weekly schedule dynamically using the updated courses list
    final WeekSchedule regeneratedWeek = _generateScheduleFromCourses(courses);

    final updatedSchedule = schedule.copyWith(
      courses: courses,
      schedule: regeneratedWeek,
    );

    await updateSchedule(updatedSchedule);
  }

  /// Deletes a course globally and regenerates the weekly schedule.
  Future<void> deleteCourse(String code) async {
    final schedule = state.schedule;
    if (schedule == null) return;

    final courses = List<Course>.from(schedule.courses);
    courses.removeWhere((c) => c.code.trim().toUpperCase() == code.trim().toUpperCase());

    final WeekSchedule regeneratedWeek = _generateScheduleFromCourses(courses);

    final updatedSchedule = schedule.copyWith(
      courses: courses,
      schedule: regeneratedWeek,
    );

    await updateSchedule(updatedSchedule);
  }

  /// Adds a course globally and regenerates the weekly schedule.
  Future<void> addCourse(Course newCourse) async {
    final schedule = state.schedule ?? const AcademicSchedule(courses: [], schedule: WeekSchedule());
    final courses = List<Course>.from(schedule.courses);
    
    // Check if course already exists
    final exists = courses.any((c) => c.code.trim().toUpperCase() == newCourse.code.trim().toUpperCase());
    if (!exists) {
      courses.add(newCourse);
    } else {
      final idx = courses.indexWhere((c) => c.code.trim().toUpperCase() == newCourse.code.trim().toUpperCase());
      if (idx != -1) courses[idx] = newCourse;
    }

    final WeekSchedule regeneratedWeek = _generateScheduleFromCourses(courses);

    final updatedSchedule = schedule.copyWith(
      courses: courses,
      schedule: regeneratedWeek,
    );

    await updateSchedule(updatedSchedule);
  }

  WeekSchedule _generateScheduleFromCourses(List<Course> uniqueCourses) {
    final Map<String, dynamic> staticSlotMapRaw = jsonDecode(staticSlotsJson);
    final Map<String, List<Map<String, String>>> staticSlotMap = staticSlotMapRaw.map((key, value) {
      return MapEntry(
        key,
        (value as List).map((item) => Map<String, String>.from(item as Map)).toList(),
      );
    });

    final generatedSchedule = <String, List<ClassSession>>{};
    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
      generatedSchedule[day] = [];
    }

    for (final course in uniqueCourses) {
      final rawSlots = course.slot;
      final courseSlots = rawSlots.toUpperCase()
          .split(RegExp(r'[\+\s,\/]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final day in staticSlotMap.keys) {
        for (final slotInfo in staticSlotMap[day]!) {
          final slotCode = slotInfo['slot']!.toUpperCase();
          if (courseSlots.contains(slotCode)) {
            generatedSchedule[day]!.add(ClassSession(
              startTime: slotInfo['startTime']!,
              endTime: slotInfo['endTime']!,
              code: course.code,
              name: course.name,
              faculty: course.faculty,
              room: course.room,
              slot: slotCode,
            ));
          }
        }
      }
    }

    // Sort class sessions chronologically by startTime
    for (final day in generatedSchedule.keys) {
      generatedSchedule[day]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return WeekSchedule(
      monday: generatedSchedule['Monday']!,
      tuesday: generatedSchedule['Tuesday']!,
      wednesday: generatedSchedule['Wednesday']!,
      thursday: generatedSchedule['Thursday']!,
      friday: generatedSchedule['Friday']!,
      saturday: generatedSchedule['Saturday']!,
      sunday: generatedSchedule['Sunday']!,
    );
  }

  /// Adds a class session manually on a specific day.
  Future<void> addSession(String day, ClassSession newSession) async {
    final schedule = state.schedule ?? const AcademicSchedule(courses: [], schedule: WeekSchedule());
    final week = schedule.schedule;
    List<ClassSession> list;
    switch (day) {
      case 'Monday': list = List.from(week.monday); break;
      case 'Tuesday': list = List.from(week.tuesday); break;
      case 'Wednesday': list = List.from(week.wednesday); break;
      case 'Thursday': list = List.from(week.thursday); break;
      case 'Friday': list = List.from(week.friday); break;
      case 'Saturday': list = List.from(week.saturday); break;
      case 'Sunday': list = List.from(week.sunday); break;
      default: return;
    }

    list.add(newSession);
    list.sort((a, b) => a.startTime.compareTo(b.startTime));

    final updatedWeek = _updateWeekDayList(week, day, list);

    // Ensure course exists in course metadata list
    final courses = List<Course>.from(schedule.courses);
    final hasCourse = courses.any((c) => c.code.trim().toUpperCase() == newSession.code.trim().toUpperCase());
    if (!hasCourse) {
      courses.add(Course(
        code: newSession.code,
        name: newSession.name,
        faculty: newSession.faculty,
        room: newSession.room,
        slot: newSession.slot,
      ));
    }

    final updatedSchedule = schedule.copyWith(
      schedule: updatedWeek,
      courses: courses,
    );

    await updateSchedule(updatedSchedule);
  }

  /// Edits an existing class session.
  Future<void> editSession(String day, int index, ClassSession updatedSession) async {
    final schedule = state.schedule;
    if (schedule == null) return;

    final week = schedule.schedule;
    List<ClassSession> list;
    switch (day) {
      case 'Monday': list = List.from(week.monday); break;
      case 'Tuesday': list = List.from(week.tuesday); break;
      case 'Wednesday': list = List.from(week.wednesday); break;
      case 'Thursday': list = List.from(week.thursday); break;
      case 'Friday': list = List.from(week.friday); break;
      case 'Saturday': list = List.from(week.saturday); break;
      case 'Sunday': list = List.from(week.sunday); break;
      default: return;
    }

    if (index >= 0 && index < list.length) {
      list[index] = updatedSession;
    } else {
      return;
    }

    list.sort((a, b) => a.startTime.compareTo(b.startTime));

    final updatedWeek = _updateWeekDayList(week, day, list);
    final updatedSchedule = schedule.copyWith(schedule: updatedWeek);

    await updateSchedule(updatedSchedule);
  }

  /// Deletes a class session.
  Future<void> deleteSession(String day, int index) async {
    final schedule = state.schedule;
    if (schedule == null) return;

    final week = schedule.schedule;
    List<ClassSession> list;
    switch (day) {
      case 'Monday': list = List.from(week.monday); break;
      case 'Tuesday': list = List.from(week.tuesday); break;
      case 'Wednesday': list = List.from(week.wednesday); break;
      case 'Thursday': list = List.from(week.thursday); break;
      case 'Friday': list = List.from(week.friday); break;
      case 'Saturday': list = List.from(week.saturday); break;
      case 'Sunday': list = List.from(week.sunday); break;
      default: return;
    }

    if (index >= 0 && index < list.length) {
      list.removeAt(index);
    } else {
      return;
    }

    final updatedWeek = _updateWeekDayList(week, day, list);
    final updatedSchedule = schedule.copyWith(schedule: updatedWeek);

    await updateSchedule(updatedSchedule);
  }

  /// Deletes the complete schedule.
  Future<void> clearSchedule() async {
    final uid = _getUid();
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.clearSchedule(uid);
      state = const AcademicState(isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete schedule: $e',
      );
    }
  }

  WeekSchedule _updateWeekDayList(WeekSchedule week, String day, List<ClassSession> list) {
    switch (day) {
      case 'Monday': return week.copyWith(monday: list);
      case 'Tuesday': return week.copyWith(tuesday: list);
      case 'Wednesday': return week.copyWith(wednesday: list);
      case 'Thursday': return week.copyWith(thursday: list);
      case 'Friday': return week.copyWith(friday: list);
      case 'Saturday': return week.copyWith(saturday: list);
      case 'Sunday': return week.copyWith(sunday: list);
      default: return week;
    }
  }
}

// ── Individual Sub-providers ──────────────────────────────────────────────────

/// Exposes whether any action is loading.
final academicLoadingProvider = Provider<bool>((ref) {
  return ref.watch(academicStateProvider).isLoading;
});

/// Exposes the current error message.
final academicErrorProvider = Provider<String?>((ref) {
  return ref.watch(academicStateProvider).errorMessage;
});

/// Exposes whether the timetable is empty.
final academicEmptyProvider = Provider<bool>((ref) {
  final state = ref.watch(academicStateProvider);
  return state.schedule == null && !state.isLoading;
});

/// Exposes whether the timetable has been successfully loaded.
final academicLoadedProvider = Provider<bool>((ref) {
  return ref.watch(academicStateProvider).schedule != null;
});

/// Exposes whether images are currently uploading.
final academicUploadingProvider = Provider<bool>((ref) {
  return ref.watch(academicStateProvider).isUploading;
});

/// Exposes whether Gemini is currently parsing.
final academicParsingProvider = Provider<bool>((ref) {
  return ref.watch(academicStateProvider).isParsing;
});

/// Exposes whether the last operation succeeded.
final academicSuccessProvider = Provider<bool>((ref) {
  return ref.watch(academicStateProvider).isSuccess;
});
