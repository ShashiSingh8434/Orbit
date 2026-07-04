import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../models/task_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => FirebaseTaskRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Plaintext fields kept outside the envelope.
///
/// - `id` — document addressing.
/// - `createdAt` — primary ordering (newest first).
/// - `updatedAt` — secondary ordering / last-modified indicator.
///
/// The encrypted envelope contains all other sensitive fields:
/// `title`, `description`, `priority`, `status`, `dueDate`, `dueTime`,
/// `completedAt`, and `metadata`.
const _kPlaintextFields = {'id', 'createdAt', 'updatedAt'};
const _kCollection = 'tasks';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class TaskRepository {
  /// Streams all tasks for [uid], ordered newest first (by [createdAt]).
  Stream<List<TaskModel>> watchTasks(String uid);

  Future<List<TaskModel>> getTasks(String uid);
  Future<void> saveTask(String uid, TaskModel task);
  Future<void> updateTask(String uid, TaskModel task);
  Future<void> deleteTask(String uid, String taskId);

  /// Reads the task, decrypts it, updates its [status] (and optionally
  /// [completedAt]), re-encrypts, and writes back.
  ///
  /// Because the entire document is a single encrypted blob, targeted
  /// Firestore `.update()` cannot reach individual fields — a full
  /// read-modify-write is required.
  Future<void> changeStatus(
    String uid,
    String taskId,
    String status, {
    DateTime? completedAt,
  });
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseTaskRepository implements TaskRepository {
  FirebaseTaskRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection);

  // ── Watch ──

  @override
  Stream<List<TaskModel>> watchTasks(String uid) {
    return _col(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().asyncMap((snap) async {
      final futures = snap.docs.map((doc) => _fromDoc(uid, doc));
      return Future.wait(futures);
    });
  }

  // ── Get ──

  @override
  Future<List<TaskModel>> getTasks(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return Future.wait(snap.docs.map((doc) => _fromDoc(uid, doc)));
  }

  // ── Save / Update ──

  @override
  Future<void> saveTask(String uid, TaskModel task) async {
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(task),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid).doc(task.id).set(encrypted);
  }

  @override
  Future<void> updateTask(String uid, TaskModel task) => saveTask(uid, task);

  // ── Delete ──

  @override
  Future<void> deleteTask(String uid, String taskId) async {
    await _col(uid).doc(taskId).delete();
  }

  // ── Change Status (read-modify-write) ──

  @override
  Future<void> changeStatus(
    String uid,
    String taskId,
    String status, {
    DateTime? completedAt,
  }) async {
    final docRef = _col(uid).doc(taskId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    // Decrypt the existing document
    final plain = await _enc.decryptDocument(uid, _kCollection, snap.data()!);

    // Mutate status fields
    plain['status'] = status;
    plain['updatedAt'] = Timestamp.now();
    if (completedAt != null) {
      plain['completedAt'] = Timestamp.fromDate(completedAt);
    }

    // Re-encrypt and write back
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      plain,
      plaintextFields: _kPlaintextFields,
    );
    await docRef.set(encrypted);
  }

  // ── Serialisation ──

  Future<TaskModel> _fromDoc(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final raw = doc.data()!;

    final plain = await _migration.migrateIfNeeded(
      uid,
      _kCollection,
      raw,
      plaintextFields: _kPlaintextFields,
      writer: (encrypted) async => _col(uid).doc(doc.id).set(encrypted),
    );

    return TaskModel(
      id: plain['id'] as String? ?? doc.id,
      title: plain['title'] as String? ?? '',
      description: plain['description'] as String? ?? '',
      createdAt: _toDateTime(plain['createdAt']),
      updatedAt: plain['updatedAt'] != null
          ? _toDateTime(plain['updatedAt'])
          : null,
      dueDate: plain['dueDate'] != null ? _toDateTime(plain['dueDate']) : null,
      dueTime: plain['dueTime'] as String?,
      priority: plain['priority'] as String? ?? 'medium',
      status: plain['status'] as String? ?? 'pending',
      completedAt: plain['completedAt'] != null
          ? _toDateTime(plain['completedAt'])
          : null,
      metadata: plain['metadata'] != null
          ? EntityMetadata.fromJson(
              Map<String, dynamic>.from(plain['metadata'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> _toPlainMap(TaskModel t) => {
    'id': t.id,
    'title': t.title,
    'description': t.description,
    'createdAt': Timestamp.fromDate(t.createdAt),
    'updatedAt': t.updatedAt != null
        ? Timestamp.fromDate(t.updatedAt!)
        : Timestamp.now(),
    'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
    'dueTime': t.dueTime,
    'priority': t.priority,
    'status': t.status,
    'completedAt': t.completedAt != null
        ? Timestamp.fromDate(t.completedAt!)
        : null,
    if (t.metadata != null) 'metadata': t.metadata!.toJson(),
  };

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
