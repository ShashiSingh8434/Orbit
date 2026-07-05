import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../../../core/models/paginated_result.dart';
import '../models/decision_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final decisionRepositoryProvider = Provider<DecisionRepository>(
  (ref) => DriftDecisionRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class DecisionRepository {
  Stream<List<DecisionModel>> watchDecisions(String uid);
  Future<List<DecisionModel>> getDecisions(String uid);
  Future<PaginatedResult<DecisionModel>> getDecisionsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  });
  Future<void> saveDecision(String uid, DecisionModel decision);
  Future<void> updateDecision(String uid, DecisionModel decision);
  Future<void> deleteDecision(String uid, String decisionId);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftDecisionRepository implements DecisionRepository {
  DriftDecisionRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<List<DecisionModel>> watchDecisions(String uid) {
    return (db.select(db.decisionsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows.map((r) => r.toModel()).toList());
  }

  // ── Get ──

  @override
  Future<List<DecisionModel>> getDecisions(String uid) async {
    final rows = await (db.select(db.decisionsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  @override
  Future<PaginatedResult<DecisionModel>> getDecisionsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  }) async {
    final offset = (startAfter is int) ? startAfter : 0;
    final rows = await (db.select(db.decisionsTable)
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
  Future<void> saveDecision(String uid, DecisionModel decision) async {
    final decisionToSave = decision.updatedAt == null
        ? decision.copyWith(updatedAt: DateTime.now())
        : decision;
    await db.into(db.decisionsTable).insertOnConflictUpdate(decisionToSave.toCompanion());
    await sync.enqueue(
      collection: 'decisions',
      operation: 'INSERT',
      id: decisionToSave.id,
      payload: decisionToSave.toJson(),
    );
  }

  @override
  Future<void> updateDecision(String uid, DecisionModel decision) async {
    final updated = decision.copyWith(updatedAt: DateTime.now());
    await db.into(db.decisionsTable).insertOnConflictUpdate(updated.toCompanion());
    await sync.enqueue(
      collection: 'decisions',
      operation: 'UPDATE',
      id: updated.id,
      payload: updated.toJson(),
    );
  }

  // ── Delete ──

  @override
  Future<void> deleteDecision(String uid, String decisionId) async {
    await (db.delete(db.decisionsTable)..where((tbl) => tbl.id.equals(decisionId))).go();
    await sync.enqueue(
      collection: 'decisions',
      operation: 'DELETE',
      id: decisionId,
      payload: {},
    );
  }
}
