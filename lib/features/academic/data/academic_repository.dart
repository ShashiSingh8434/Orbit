import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../../../core/ai/prompts/academic_timetable_prompt.dart';
import '../../../core/ai/services/multimodal_extraction_service.dart';
import '../models/academic_schedule.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final extractor = ref.read(multimodalExtractionServiceProvider);
  return DriftAcademicRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
    extractor: extractor,
  );
});

// ── Abstract Interface ────────────────────────────────────────────────────────

/// Repository responsible for handling Academic Timetable actions.
abstract class AcademicRepository {
  /// Sends the provided image bytes list to Gemini to parse into an [AcademicSchedule].
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  );

  /// Loads the academic schedule for [uid] from local Drift database.
  Future<AcademicSchedule?> getSchedule(String uid);

  /// Saves the schedule to local Drift database and queues sync to Firestore.
  Future<void> saveSchedule(String uid, AcademicSchedule schedule);

  /// Clears the schedule from Drift and queues delete sync to Firestore.
  Future<void> clearSchedule(String uid);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftAcademicRepository implements AcademicRepository {
  DriftAcademicRepository({
    required this.db,
    required this.sync,
    required this.extractor,
  });

  final AppDatabase db;
  final SyncService sync;
  final MultimodalExtractionService extractor;

  // ── Parse ──

  @override
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  ) async {
    final prompt = AcademicTimetablePromptBuilder.buildPrompt();
    final schema = AcademicTimetablePromptBuilder.buildSchema();
    final data = await extractor.extractData(
      imageBytesList: imageBytesList,
      mimeTypes: mimeTypes,
      prompt: prompt,
      responseSchema: schema,
    );
    return AcademicSchedule.fromJson(data);
  }

  // ── Get ──

  @override
  Future<AcademicSchedule?> getSchedule(String uid) async {
    final row = await (db.select(
      db.academicTable,
    )..where((tbl) => tbl.uid.equals(uid))).getSingleOrNull();
    if (row == null) return null;
    return AcademicSchedule.fromJson(row.schedule);
  }

  // ── Save ──

  @override
  Future<void> saveSchedule(String uid, AcademicSchedule schedule) async {
    final companion = AcademicTableCompanion(
      uid: Value(uid),
      schedule: Value(schedule.toJson()),
    );
    await db.into(db.academicTable).insertOnConflictUpdate(companion);

    await sync.enqueue(
      collection: 'academic',
      operation: 'INSERT',
      id: 'academic',
      payload: {'schedule': schedule.toJson()},
    );
  }

  // ── Clear ──

  @override
  Future<void> clearSchedule(String uid) async {
    await (db.delete(
      db.academicTable,
    )..where((tbl) => tbl.uid.equals(uid))).go();
    await sync.enqueue(
      collection: 'academic',
      operation: 'DELETE',
      id: 'academic',
      payload: {},
    );
  }
}
