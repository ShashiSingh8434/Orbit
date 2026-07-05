import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../models/reflection_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final reflectionRepositoryProvider = Provider<ReflectionRepository>(
  (ref) => DriftReflectionRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class ReflectionRepository {
  /// Streams all non-deleted reflections for [uid] on [dateKey] (yyyy-MM-dd).
  Stream<List<ReflectionModel>> watchReflections(String uid, String dateKey);

  /// One-shot fetch (used for AI processing).
  Future<List<ReflectionModel>> getReflections(String uid, String dateKey);

  /// Creates or fully replaces a reflection document.
  Future<void> saveReflection(
    String uid,
    String dateKey,
    ReflectionModel reflection,
  );

  /// Soft-deletes a reflection by setting `deleted = true`.
  Future<void> deleteReflection(
    String uid,
    String dateKey,
    String reflectionId,
  );

  /// Marks a reflection's `aiProcessed` flag as true.
  Future<void> markAiProcessed(String uid, String dateKey, String reflectionId);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftReflectionRepository implements ReflectionRepository {
  DriftReflectionRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<List<ReflectionModel>> watchReflections(String uid, String dateKey) {
    sync.syncReflectionsForDate(uid, dateKey);

    return (db.select(db.reflectionsTable)
          ..where(
            (tbl) => tbl.dateKey.equals(dateKey) & tbl.deleted.equals(false),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch()
        .map((rows) => rows.map((r) => r.toModel()).toList());
  }

  // ── Get ──

  @override
  Future<List<ReflectionModel>> getReflections(
    String uid,
    String dateKey,
  ) async {
    await sync.syncReflectionsForDate(uid, dateKey);

    final rows =
        await (db.select(db.reflectionsTable)
              ..where(
                (tbl) =>
                    tbl.dateKey.equals(dateKey) & tbl.deleted.equals(false),
              )
              ..orderBy([
                (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map((r) => r.toModel()).toList();
  }

  // ── Save ──

  @override
  Future<void> saveReflection(
    String uid,
    String dateKey,
    ReflectionModel reflection,
  ) async {
    final refToSave = reflection.copyWith(updatedAt: DateTime.now());
    await db
        .into(db.reflectionsTable)
        .insertOnConflictUpdate(refToSave.toCompanion());

    final payload = refToSave.toJson();
    payload['dateKey'] = dateKey;
    await sync.enqueue(
      collection: 'reflections',
      operation: 'INSERT',
      id: refToSave.id,
      payload: payload,
    );
  }

  // ── Delete (soft) ──

  @override
  Future<void> deleteReflection(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    final local = await (db.select(
      db.reflectionsTable,
    )..where((tbl) => tbl.id.equals(reflectionId))).getSingleOrNull();
    if (local == null) return;

    final updated = local.toModel().copyWith(
      deleted: true,
      updatedAt: DateTime.now(),
    );
    await db
        .into(db.reflectionsTable)
        .insertOnConflictUpdate(updated.toCompanion());

    final payload = updated.toJson();
    payload['dateKey'] = dateKey;
    await sync.enqueue(
      collection: 'reflections',
      operation: 'UPDATE',
      id: reflectionId,
      payload: payload,
    );
  }

  @override
  Future<void> markAiProcessed(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    final local = await (db.select(
      db.reflectionsTable,
    )..where((tbl) => tbl.id.equals(reflectionId))).getSingleOrNull();
    if (local == null) return;

    final updated = local.toModel().copyWith(
      aiProcessed: true,
      updatedAt: DateTime.now(),
    );
    await db
        .into(db.reflectionsTable)
        .insertOnConflictUpdate(updated.toCompanion());

    final payload = updated.toJson();
    payload['dateKey'] = dateKey;
    await sync.enqueue(
      collection: 'reflections',
      operation: 'UPDATE',
      id: reflectionId,
      payload: payload,
    );
  }
}
