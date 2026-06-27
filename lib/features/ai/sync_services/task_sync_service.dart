import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/models/task_model.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/dtos/task_dto.dart';

final taskSyncServiceProvider = Provider<TaskSyncService>((ref) {
  return TaskSyncService(ref.read(taskRepositoryProvider));
});

class TaskSyncService {
  final TaskRepository _repository;
  final _uuid = const Uuid();

  TaskSyncService(this._repository);

  String _normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Future<void> syncTasks(String uid, List<TaskDto> extractedTasks, String reflectionId, DateTime dayDate) async {
    // Fetch existing tasks to perform duplicate and completion detection
    final existingTasksStream = _repository.watchTasks(uid).first;
    final existingTasks = await existingTasksStream;

    for (final dto in extractedTasks) {
      final normalizedNewTitle = _normalize(dto.title);
      
      // Fuzzy title matching
      int existingIndex = existingTasks.indexWhere((t) => _normalize(t.title) == normalizedNewTitle);
      
      if (existingIndex != -1) {
        // Update existing task
        var existingTask = existingTasks[existingIndex];
        
        // Manual override preservation: don't overwrite user-set status or dates unless AI explicitly detects completion
        var updatedTask = existingTask.copyWith(
          updatedAt: DateTime.now(),
        );

        if (dto.status == 'completed' && existingTask.status != 'completed') {
          updatedTask = updatedTask.copyWith(
            status: 'completed',
            completedAt: DateTime.now(),
          );
        }

        if (dto.dueDate != null && existingTask.dueDate == null) {
          updatedTask = updatedTask.copyWith(
            dueDate: DateTime.tryParse(dto.dueDate!),
            dueTime: dto.dueTime,
          );
        }
        
        await _repository.updateTask(uid, updatedTask);
        
        // Update the list in memory for subsequent checks
        existingTasks[existingIndex] = updatedTask;

      } else {
        // Create new task
        final task = TaskModel(
          id: _uuid.v4(),
          title: dto.title,
          description: dto.description ?? '',
          createdAt: dayDate,
          dueDate: dto.dueDate != null ? DateTime.tryParse(dto.dueDate!) : null,
          dueTime: dto.dueTime,
          priority: dto.priority,
          status: dto.status,
          completedAt: dto.status == 'completed' ? DateTime.now() : null,
          metadata: EntityMetadata(
            originReflectionId: reflectionId,
            aiConfidence: dto.aiConfidence,
            createdBy: 'ai',
          ),
        );
        await _repository.saveTask(uid, task);
        existingTasks.add(task);
      }
    }
  }
}

