import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../models/task_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => DriftTaskRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class TaskRepository {
  /// Streams all tasks for [uid], ordered newest first (by [createdAt]).
  Stream<List<TaskModel>> watchTasks(String uid);

  Future<List<TaskModel>> getTasks(String uid);
  Future<void> saveTask(String uid, TaskModel task);
  Future<void> updateTask(String uid, TaskModel task);
  Future<void> deleteTask(String uid, String taskId);

  /// Reads the task, updates its [status] (and optionally [completedAt]),
  /// and writes back to Drift & queue.
  Future<void> changeStatus(
    String uid,
    String taskId,
    String status, {
    DateTime? completedAt,
  });
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<List<TaskModel>> watchTasks(String uid) {
    return (db.select(db.tasksTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch()
        .map((rows) => rows.map((r) => r.toModel()).toList());
  }

  // ── Get ──

  @override
  Future<List<TaskModel>> getTasks(String uid) async {
    final rows =
        await (db.select(db.tasksTable)..orderBy([
              (tbl) => OrderingTerm(
                expression: tbl.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    return rows.map((r) => r.toModel()).toList();
  }

  // ── Save / Update ──

  @override
  Future<void> saveTask(String uid, TaskModel task) async {
    final taskToSave = task.updatedAt == null
        ? task.copyWith(updatedAt: DateTime.now())
        : task;
    await db
        .into(db.tasksTable)
        .insertOnConflictUpdate(taskToSave.toCompanion());
    await sync.enqueue(
      collection: 'tasks',
      operation: 'INSERT',
      id: taskToSave.id,
      payload: taskToSave.toJson(),
    );
  }

  @override
  Future<void> updateTask(String uid, TaskModel task) async {
    final updated = task.copyWith(updatedAt: DateTime.now());
    await db.into(db.tasksTable).insertOnConflictUpdate(updated.toCompanion());
    await sync.enqueue(
      collection: 'tasks',
      operation: 'UPDATE',
      id: updated.id,
      payload: updated.toJson(),
    );
  }

  // ── Delete ──

  @override
  Future<void> deleteTask(String uid, String taskId) async {
    await (db.delete(
      db.tasksTable,
    )..where((tbl) => tbl.id.equals(taskId))).go();
    await sync.enqueue(
      collection: 'tasks',
      operation: 'DELETE',
      id: taskId,
      payload: {},
    );
  }

  // ── Change Status ──

  @override
  Future<void> changeStatus(
    String uid,
    String taskId,
    String status, {
    DateTime? completedAt,
  }) async {
    final local = await (db.select(
      db.tasksTable,
    )..where((tbl) => tbl.id.equals(taskId))).getSingleOrNull();
    if (local == null) return;

    final updated = local.toModel().copyWith(
      status: status,
      completedAt: completedAt,
      updatedAt: DateTime.now(),
    );
    await db.into(db.tasksTable).insertOnConflictUpdate(updated.toCompanion());
    await sync.enqueue(
      collection: 'tasks',
      operation: 'UPDATE',
      id: taskId,
      payload: updated.toJson(),
    );
  }
}
