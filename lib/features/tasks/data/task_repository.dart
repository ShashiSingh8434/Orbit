import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/task_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => FirebaseTaskRepository(),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class TaskRepository {
  Stream<List<TaskModel>> watchTasks(String uid);
  Future<List<TaskModel>> getTasks(String uid);
  Future<void> saveTask(String uid, TaskModel task);
  Future<void> updateTask(String uid, TaskModel task);
  Future<void> deleteTask(String uid, String taskId);
  Future<void> changeStatus(String uid, String taskId, String status, {DateTime? completedAt});
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseTaskRepository implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  @override
  Stream<List<TaskModel>> watchTasks(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<List<TaskModel>> getTasks(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> saveTask(String uid, TaskModel task) async {
    await _col(uid).doc(task.id).set(_toMap(task));
  }

  @override
  Future<void> updateTask(String uid, TaskModel task) async {
    await _col(uid).doc(task.id).set(_toMap(task));
  }

  @override
  Future<void> deleteTask(String uid, String taskId) async {
    await _col(uid).doc(taskId).delete();
  }

  @override
  Future<void> changeStatus(String uid, String taskId, String status, {DateTime? completedAt}) async {
    final Map<String, dynamic> data = {'status': status};
    if (completedAt != null) {
      data['completedAt'] = Timestamp.fromDate(completedAt);
    }
    await _col(uid).doc(taskId).update(data);
  }

  // ── Serialisation ──

  TaskModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TaskModel(
      id: d['id'] as String,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : null,
      dueDate: d['dueDate'] != null ? (d['dueDate'] as Timestamp).toDate() : null,
      dueTime: d['dueTime'] as String?,
      priority: d['priority'] as String? ?? 'medium',
      status: d['status'] as String? ?? 'pending',
      completedAt: d['completedAt'] != null ? (d['completedAt'] as Timestamp).toDate() : null,
      metadata: d['metadata'] != null 
          ? EntityMetadata.fromJson(Map<String, dynamic>.from(d['metadata'] as Map))
          : null,
    );
  }

  Map<String, dynamic> _toMap(TaskModel t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'createdAt': Timestamp.fromDate(t.createdAt),
        'updatedAt': t.updatedAt != null ? Timestamp.fromDate(t.updatedAt!) : null,
        'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
        'dueTime': t.dueTime,
        'priority': t.priority,
        'status': t.status,
        'completedAt': t.completedAt != null ? Timestamp.fromDate(t.completedAt!) : null,
        if (t.metadata != null) 'metadata': t.metadata!.toJson(),
      };
}
