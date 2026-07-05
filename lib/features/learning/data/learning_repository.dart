import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../../../core/models/paginated_result.dart';
import '../models/learning_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => DriftLearningRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class LearningRepository {
  Stream<List<LearningModel>> watchLearnings(String uid);
  Future<List<LearningModel>> getLearnings(String uid);
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  });
  Future<void> saveLearning(String uid, LearningModel learning);
  Future<void> updateLearning(String uid, LearningModel learning);
  Future<void> deleteLearning(String uid, String learningId);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftLearningRepository implements LearningRepository {
  DriftLearningRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<List<LearningModel>> watchLearnings(String uid) {
    return (db.select(db.learningsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows.map((r) => r.toModel()).toList());
  }

  // ── Get ──

  @override
  Future<List<LearningModel>> getLearnings(String uid) async {
    final rows = await (db.select(db.learningsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  @override
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  }) async {
    final offset = (startAfter is int) ? startAfter : 0;
    final rows = await (db.select(db.learningsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(limit, offset: offset))
        .get();
    final items = rows.map((r) => r.toModel()).toList();
    final newOffset = offset + items.length;
    final hasMore = items.length == limit;

    return PaginatedResult(
      items: items,
      lastDoc: hasMore ? newOffset : null,
      hasMore: hasMore,
    );
  }

  // ── Save / Update ──

  @override
  Future<void> saveLearning(String uid, LearningModel learning) async {
    final learningToSave = learning.updatedAt == null
        ? learning.copyWith(updatedAt: DateTime.now())
        : learning;
    await db.into(db.learningsTable).insertOnConflictUpdate(learningToSave.toCompanion());
    await sync.enqueue(
      collection: 'learnings',
      operation: 'INSERT',
      id: learningToSave.id,
      payload: learningToSave.toJson(),
    );
  }

  @override
  Future<void> updateLearning(String uid, LearningModel learning) async {
    final updated = learning.copyWith(updatedAt: DateTime.now());
    await db.into(db.learningsTable).insertOnConflictUpdate(updated.toCompanion());
    await sync.enqueue(
      collection: 'learnings',
      operation: 'UPDATE',
      id: updated.id,
      payload: updated.toJson(),
    );
  }

  // ── Delete ──

  @override
  Future<void> deleteLearning(String uid, String learningId) async {
    await (db.delete(db.learningsTable)..where((tbl) => tbl.id.equals(learningId))).go();
    await sync.enqueue(
      collection: 'learnings',
      operation: 'DELETE',
      id: learningId,
      payload: {},
    );
  }
}
