import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/task_repository.dart';
import '../models/task_model.dart';

// ── Stream Provider ───────────────────────────────────────────────────────────

/// Streams all tasks for the current user.
final tasksProvider = StreamProvider<List<TaskModel>>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Stream.empty();
    return ref.watch(taskRepositoryProvider).watchTasks(user.uid);
  },
);

// ── Action Controller ─────────────────────────────────────────────────────────

final taskControllerProvider =
    NotifierProvider<TaskController, void>(TaskController.new);

class TaskController extends Notifier<void> {
  late TaskRepository _repo;

  @override
  void build() {
    _repo = ref.watch(taskRepositoryProvider);
  }

  Future<void> addTask({
    required String title,
    String description = '',
    DateTime? dueDate,
    String? dueTime,
  }) async {
    final uid = _requireUid();
    final task = TaskModel(
      id: _generateId(),
      title: title.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
      dueDate: dueDate,
      dueTime: dueTime,
    );
    await _repo.saveTask(uid, task);
  }

  Future<void> editTask(
    TaskModel task, {
    required String title,
    String description = '',
    DateTime? dueDate,
    String? dueTime,
  }) async {
    final uid = _requireUid();
    final updatedTask = task.copyWith(
      title: title.trim(),
      description: description.trim(),
      dueDate: dueDate,
      dueTime: dueTime,
      updatedAt: DateTime.now(),
      metadata: task.metadata?.copyWith(manualOverride: true),
    );
    await _repo.updateTask(uid, updatedTask);
  }

  Future<void> toggleDone(TaskModel task, bool isDone) async {
    final uid = _requireUid();
    final updatedTask = task.copyWith(
      status: isDone ? 'completed' : 'pending',
      completedAt: isDone ? DateTime.now() : null,
      metadata: task.metadata?.copyWith(manualOverride: true),
    );
    await _repo.updateTask(uid, updatedTask);
  }

  Future<void> deleteTask(String taskId) async {
    final uid = _requireUid();
    await _repo.deleteTask(uid, taskId);
  }

  // ── Private ──

  String _requireUid() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) throw StateError('User is not authenticated');
    return uid;
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
}
