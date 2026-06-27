import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => FirebaseTaskRepository(),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class TaskRepository {
  Stream<List<TaskModel>> watchTasks(String uid);
  Future<void> saveTask(String uid, TaskModel task);
  Future<void> updateTask(String uid, TaskModel task);
  Future<void> deleteTask(String uid, String taskId);
  Future<void> toggleDone(String uid, String taskId, bool isDone);
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
  Future<void> toggleDone(String uid, String taskId, bool isDone) async {
    await _col(uid).doc(taskId).update({'isDone': isDone});
  }

  // ── Serialisation ──

  TaskModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TaskModel(
      id: d['id'] as String,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      isDone: d['isDone'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      dueDate: d['dueDate'] != null ? (d['dueDate'] as Timestamp).toDate() : null,
      source: d['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> _toMap(TaskModel t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'isDone': t.isDone,
        'createdAt': Timestamp.fromDate(t.createdAt),
        'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
        'source': t.source,
      };
}
