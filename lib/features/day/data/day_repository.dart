import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../../../core/utils/date_utils.dart';
import '../models/day_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => DriftDayRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class DayRepository {
  Stream<DayModel?> watchDay(String uid, DateTime date);
  Future<DayModel?> getDay(String uid, DateTime date);
  Future<void> saveDay(String uid, DayModel day);
  Future<void> invalidateDayCache(String uid, DateTime date);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftDayRepository implements DayRepository {
  DriftDayRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<DayModel?> watchDay(String uid, DateTime date) {
    final key = OrbitDateUtils.dateKey(date);
    return (db.select(db.daysTable)..where((tbl) => tbl.date.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.toModel());
  }

  // ── Get ──

  @override
  Future<DayModel?> getDay(String uid, DateTime date) async {
    final key = OrbitDateUtils.dateKey(date);
    final row = await (db.select(
      db.daysTable,
    )..where((tbl) => tbl.date.equals(key))).getSingleOrNull();
    return row?.toModel();
  }

  // ── Save ──

  @override
  Future<void> saveDay(String uid, DayModel day) async {
    final dayToSave = day.updatedAt == null
        ? day.copyWith(updatedAt: DateTime.now())
        : day;
    await db.into(db.daysTable).insertOnConflictUpdate(dayToSave.toCompanion());
    await sync.enqueue(
      collection: 'days',
      operation: 'INSERT',
      id: OrbitDateUtils.dateKey(dayToSave.date),
      payload: dayToSave.toJson(),
    );
  }

  // ── Invalidate Cache ──

  @override
  Future<void> invalidateDayCache(String uid, DateTime date) async {
    final day = await getDay(uid, date);
    if (day != null) {
      final updated = day.copyWith(
        detailedSummary: null,
        detailedSummaryBullet: null,
        updatedAt: DateTime.now(),
      );
      await saveDay(uid, updated);
    }
  }
}
