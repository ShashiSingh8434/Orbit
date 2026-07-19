import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/task_controller.dart';
import '../widgets/task_tile.dart';
import '../models/task_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/security/exceptions/crypto_exceptions.dart';
import 'task_edit_page.dart';
import '../../academic/services/home_widget_pin_service.dart';

enum TaskFilter { pending, completed, today }

/// Task list page. Users can add manual tasks, edit, filter, and toggle/delete them.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskFilter _currentFilter = TaskFilter.pending;

  Future<void> _handlePinWidget() async {
    final isSupported = await HomeWidgetPinService.isWidgetPinningSupported();
    if (!mounted) return;
    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Home screen widget pinning is not supported by your launcher.',
          ),
        ),
      );
      return;
    }
    await HomeWidgetPinService.requestWidgetPin(widgetType: 'tasks');
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets_outlined),
            tooltip: 'Pin Widget',
            onPressed: _handlePinWidget,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Pending'),
                  selected: _currentFilter == TaskFilter.pending,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentFilter = TaskFilter.pending);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _currentFilter == TaskFilter.completed,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentFilter = TaskFilter.completed);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Today'),
                  selected: _currentFilter == TaskFilter.today,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentFilter = TaskFilter.today);
                    }
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filteredTasks = _filterAndSortTasks(tasks);

                if (filteredTasks.isEmpty) {
                  return _EmptyState(filter: _currentFilter);
                }

                if (_currentFilter == TaskFilter.completed) {
                  final Map<DateTime, List<TaskModel>> grouped = {};
                  for (final t in filteredTasks) {
                    final completionDate =
                        t.dueDate ?? t.completedAt ?? t.createdAt;
                    final date = DateTime(
                      completionDate.year,
                      completionDate.month,
                      completionDate.day,
                    );
                    grouped.putIfAbsent(date, () => []).add(t);
                  }

                  final sortedDates = grouped.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  for (final date in sortedDates) {
                    grouped[date]!.sort((a, b) {
                      final aTime = a.updatedAt ?? a.createdAt;
                      final bTime = b.updatedAt ?? b.createdAt;
                      return bTime.compareTo(aTime);
                    });
                  }

                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final dayTasks = grouped[date]!;
                      final dateKey = OrbitDateUtils.friendlyLabel(
                        OrbitDateUtils.dateKey(date),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                            child: Text(
                              dateKey,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...dayTasks.map(
                            (task) => TaskTile(
                              task: task,
                              onToggle: (done) => ref
                                  .read(taskControllerProvider.notifier)
                                  .toggleDone(task, done),
                              onDelete: () => ref
                                  .read(taskControllerProvider.notifier)
                                  .deleteTask(task),
                              onEdit: () => _showTaskModal(context, task: task),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (_, i) {
                    final task = filteredTasks[i];
                    return TaskTile(
                      task: task,
                      onToggle: (done) => ref
                          .read(taskControllerProvider.notifier)
                          .toggleDone(task, done),
                      onDelete: () => ref
                          .read(taskControllerProvider.notifier)
                          .deleteTask(task),
                      onEdit: () => _showTaskModal(context, task: task),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.userFriendlyMessage)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskModal(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  List<TaskModel> _filterAndSortTasks(List<TaskModel> tasks) {
    // 1. Filter
    final todayKey = OrbitDateUtils.todayKey();
    var filtered = tasks.where((t) {
      switch (_currentFilter) {
        case TaskFilter.pending:
          return t.status == 'pending';
        case TaskFilter.completed:
          return t.status == 'completed';
        case TaskFilter.today:
          if (t.dueDate != null) {
            return OrbitDateUtils.dateKey(t.dueDate!) == todayKey;
          }
          if (t.status == 'pending') {
            return true;
          } else {
            final completedDate = t.completedAt ?? t.createdAt;
            return OrbitDateUtils.dateKey(completedDate) == todayKey;
          }
      }
    }).toList();

    // 2. Sort
    if (_currentFilter == TaskFilter.completed) {
      filtered.sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    } else {
      filtered.sort((a, b) {
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        } else {
          return b.createdAt.compareTo(a.createdAt);
        }
      });
    }

    return filtered;
  }

  void _showTaskModal(BuildContext context, {TaskModel? task}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: task)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TaskFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String title = 'No tasks yet';
    if (filter == TaskFilter.completed) title = 'No completed tasks';
    if (filter == TaskFilter.today) title = 'No tasks for today';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: colorScheme.primary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a task, or let the AI extract them from your reflections.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
