import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/task_controller.dart';
import '../widgets/task_tile.dart';
import '../models/task_model.dart';
import '../../../core/utils/date_utils.dart';

enum TaskFilter { pending, completed, today }

/// Task list page. Users can add manual tasks, edit, filter, and toggle/delete them.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskFilter _currentFilter = TaskFilter.pending;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _currentFilter == TaskFilter.pending,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = TaskFilter.pending);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _currentFilter == TaskFilter.completed,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = TaskFilter.completed);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _currentFilter == TaskFilter.today,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = TaskFilter.today);
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
                          .deleteTask(task.id),
                      onEdit: () => _showTaskModal(context, ref, task: task),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskModal(context, ref),
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

    return filtered;
  }

  void _showTaskModal(BuildContext context, WidgetRef ref, {TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TaskModalContent(task: task, ref: ref),
    );
  }
}

class _TaskModalContent extends StatefulWidget {
  final TaskModel? task;
  final WidgetRef ref;

  const _TaskModalContent({this.task, required this.ref});

  @override
  State<_TaskModalContent> createState() => _TaskModalContentState();
}

class _TaskModalContentState extends State<_TaskModalContent> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _selectedDueDate = widget.task?.dueDate;
    if (widget.task?.dueTime != null) {
      try {
        final parts = widget.task!.dueTime!.split(':');
        _selectedDueTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 24, bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEditing ? 'Edit Task' : 'New Task', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Task title *', hintText: 'What do you need to do?'),
            autofocus: !isEditing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            textInputAction: TextInputAction.done,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _selectedDueDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(_selectedDueDate != null 
                    ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}' 
                    : 'Set Date'),
                ),
              ),
              if (_selectedDueDate != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedDueTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => _selectedDueTime = time);
                      }
                    },
                    icon: const Icon(Icons.access_time_rounded, size: 18),
                    label: Text(_selectedDueTime?.format(context) ?? 'Set Time'),
                  ),
                ),
              ],
            ],
          ),
          if (_selectedDueDate != null) 
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _selectedDueDate = null;
                  _selectedDueTime = null;
                }),
                child: const Text('Clear Date/Time'),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _saveTask(context),
              child: Text(isEditing ? 'Save Changes' : 'Add Task'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTask(BuildContext ctx) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    
    final dueTimeStr = _selectedDueTime != null 
      ? '${_selectedDueTime!.hour.toString().padLeft(2, '0')}:${_selectedDueTime!.minute.toString().padLeft(2, '0')}' 
      : null;

    Navigator.pop(ctx);
    
    if (widget.task != null) {
      await widget.ref.read(taskControllerProvider.notifier).editTask(
            widget.task!,
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    } else {
      await widget.ref.read(taskControllerProvider.notifier).addTask(
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

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
          Icon(Icons.task_alt_rounded, size: 64, color: colorScheme.primary.withAlpha(80)),
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
