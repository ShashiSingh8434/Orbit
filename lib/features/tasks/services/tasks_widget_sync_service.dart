import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../data/task_repository.dart';
import '../models/task_model.dart';

/// Service to synchronize task data with the native Android widget and handle toggles.
class TasksWidgetSyncService {
  static const String _dataKey = 'tasks_data';
  static const String _widgetName = 'TasksWidgetReceiver';
  static const String _androidProviderName = 'widget.TasksWidgetReceiver';

  /// Filters, sorts, and serializes Today's tasks to SharedPreferences for Glance widget.
  static Future<void> syncTasks(List<TaskModel> tasks) async {
    final todayKey = OrbitDateUtils.todayKey();
    
    // Filter Today's tasks matching the view logic
    final todayTasks = tasks.where((t) {
      if (t.dueDate != null) {
        return OrbitDateUtils.dateKey(t.dueDate!) == todayKey;
      }
      if (t.status == 'pending') {
        return true;
      } else {
        final completedDate = t.completedAt ?? t.createdAt;
        return OrbitDateUtils.dateKey(completedDate) == todayKey;
      }
    }).toList();

    // Sort today's tasks: pending first, then completed.
    todayTasks.sort((a, b) {
      if (a.status == b.status) {
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        } else {
          return b.createdAt.compareTo(a.createdAt);
        }
      }
      return a.status == 'pending' ? -1 : 1;
    });

    final serialized = todayTasks.map((t) {
      return {
        'id': t.id,
        'title': t.title,
        'status': t.status,
        'completedAt': t.completedAt?.toIso8601String(),
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(_dataKey, json.encode(serialized));

    // Request widget update from home_widget
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _androidProviderName,
    );
  }

  /// Checks if any task status changes were queued in SharedPreferences by the native widget,
  /// applies them to the database, and clears the queue.
  static Future<void> checkAndSyncToggles(dynamic ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    try {
      final pendingTogglesStr = await HomeWidget.getWidgetData<String>('pending_task_toggles');
      if (pendingTogglesStr != null && pendingTogglesStr.isNotEmpty && pendingTogglesStr != '{}') {
        final Map<String, dynamic> pending = json.decode(pendingTogglesStr);
        if (pending.isNotEmpty) {
          final repo = ref.read(taskRepositoryProvider);
          for (final entry in pending.entries) {
            final taskId = entry.key;
            final isCompleted = entry.value as bool;
            await repo.changeStatus(
              uid,
              taskId,
              isCompleted ? 'completed' : 'pending',
              completedAt: isCompleted ? DateTime.now() : null,
            );
            await ref.read(dayRepositoryProvider).invalidateDayCache(uid, DateTime.now());
          }

          // Clear queue in SharedPreferences
          await HomeWidget.saveWidgetData<String>('pending_task_toggles', '{}');

          // Push fresh state to the widget
          final tasks = await repo.getTasks(uid);
          await syncTasks(tasks);
        }
      }
    } catch (_) {
      // Fail silently to avoid breaking app lifecycle transitions
    }
  }
}
