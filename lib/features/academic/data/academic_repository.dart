import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/ai/prompts/academic_timetable_prompt.dart';
import '../../../core/ai/services/multimodal_extraction_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/academic_schedule.dart';

/// Provider for [AcademicRepository].
final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final extractor = ref.read(multimodalExtractionServiceProvider);
  return FirebaseAcademicRepository(prefs: prefs, extractor: extractor);
});

/// Repository responsible for handling Academic Timetable actions.
abstract class AcademicRepository {
  /// Sends the provided image bytes list to Gemini to parse into an [AcademicSchedule].
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  );

  /// Loads the academic schedule for the given user, checking local SharedPreferences cache
  /// and falling back to Firestore if the cache is empty.
  Future<AcademicSchedule?> getSchedule(String uid);

  /// Saves the schedule to local storage cache and Firestore under the user's ID.
  Future<void> saveSchedule(String uid, AcademicSchedule schedule);

  /// Clears the user's schedule from both local storage and Firestore.
  Future<void> clearSchedule(String uid);
}

/// Firebase and SharedPreferences implementation of [AcademicRepository].
class FirebaseAcademicRepository implements AcademicRepository {
  final SharedPreferences _prefs;
  final MultimodalExtractionService _extractor;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseAcademicRepository({required this._prefs, required this._extractor});

  @override
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  ) async {
    final prompt = AcademicTimetablePromptBuilder.buildPrompt();
    final schema = AcademicTimetablePromptBuilder.buildSchema();

    final data = await _extractor.extractData(
      imageBytesList: imageBytesList,
      mimeTypes: mimeTypes,
      prompt: prompt,
      responseSchema: schema,
    );

    return AcademicSchedule.fromJson(data);
  }

  @override
  Future<AcademicSchedule?> getSchedule(String uid) async {
    // 1. Try local cache
    final localJson = _prefs.getString('academic_timetable_$uid');
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(localJson);
        return AcademicSchedule.fromJson(data);
      } catch (_) {
        // ignore and fallback
      }
    }

    // 2. Try Firestore
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('academic')
          .doc('data')
          .get();

      if (doc.exists && doc.data() != null) {
        final schedule = AcademicSchedule.fromJson(doc.data()!);
        // Save back to local cache
        await _prefs.setString(
          'academic_timetable_$uid',
          jsonEncode(schedule.toJson()),
        );
        return schedule;
      }
    } catch (_) {
      // ignore, likely offline or not created
    }
    return null;
  }

  @override
  Future<void> saveSchedule(String uid, AcademicSchedule schedule) async {
    // 1. Save to local cache
    await _prefs.setString(
      'academic_timetable_$uid',
      jsonEncode(schedule.toJson()),
    );

    // 2. Save to Firestore (resilient background save)
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('academic')
          .doc('data')
          .set(schedule.toJson());
    } catch (e) {
      AppLogger.error(
        'FirebaseAcademicRepository: Failed to save schedule to Firestore: $e',
      );
    }
  }

  @override
  Future<void> clearSchedule(String uid) async {
    await _prefs.remove('academic_timetable_$uid');
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('academic')
          .doc('data')
          .delete();
    } catch (_) {}
  }
}
