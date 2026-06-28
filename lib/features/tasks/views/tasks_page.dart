import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/task_agent_prompt.dart';
import '../data/task_repository.dart';
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
        title: const Text('My Tasks'),
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
              error: (e, _) => Center(child: Text('Error: $e')),
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

  void _showTaskModal(BuildContext context, {TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TaskEditSheet(task: task),
    );
  }
}

class TaskEditSheet extends ConsumerStatefulWidget {
  final TaskModel? task;

  const TaskEditSheet({super.key, this.task});

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual Form State
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;

  // AI Form State
  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.task == null ? 2 : 1, vsync: this);

    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _selectedDueDate = widget.task?.dueDate;
    if (widget.task?.dueTime != null) {
      try {
        final parts = widget.task!.dueTime!.split(':');
        _selectedDueTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    _aiPromptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManual(BuildContext ctx) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final dueTimeStr = _selectedDueTime != null
        ? '${_selectedDueTime!.hour.toString().padLeft(2, '0')}:${_selectedDueTime!.minute.toString().padLeft(2, '0')}'
        : null;

    Navigator.pop(ctx);

    if (widget.task != null) {
      await ref.read(taskControllerProvider.notifier).editTask(
            widget.task!,
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    } else {
      await ref.read(taskControllerProvider.notifier).addTask(
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    }
  }

  Future<void> _submitAi() async {
    final promptText = _aiPromptCtrl.text.trim();
    if (promptText.isEmpty) return;

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final aiManager = ref.read(aiRequestManagerProvider);
      final controller = ref.read(taskControllerProvider.notifier);

      // Fetch active pending tasks as context
      final repo = ref.read(taskRepositoryProvider);
      final pendingTasks = await repo.getTasks(user.uid);
      final activePending = pendingTasks.where((t) => t.status == 'pending').toList();

      final fullPrompt = TaskAgentPromptBuilder.buildPrompt(
        today: DateTime.now(),
        promptText: promptText,
        pendingTasks: activePending,
      );

      final response = await aiManager.generate(
        AiRequest(
          prompt: fullPrompt,
          requestId: 'task_agent_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Processing tasks with AI...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> createList = data['create'] ?? [];
      final List<dynamic> updateList = data['update'] ?? [];

      if (createList.isEmpty && updateList.isEmpty) {
        throw Exception('AI did not extract any task additions or updates. Try being more specific.');
      }

      int createdCount = 0;
      int updatedCount = 0;

      // 1. Process Creates
      for (final item in createList) {
        final title = item['title'] as String? ?? '';
        if (title.trim().isEmpty) continue;
        final description = item['description'] as String? ?? '';
        final dueDateStr = item['dueDate'] as String?;
        final parsedDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
        final dueTime = item['dueTime'] as String?;

        await controller.addTask(
          title: title,
          description: description,
          dueDate: parsedDate,
          dueTime: dueTime,
        );
        createdCount++;
      }

      // 2. Process Updates
      for (final item in updateList) {
        final id = item['id'] as String? ?? '';
        if (id.isEmpty) continue;

        final matchedTask = pendingTasks.where((t) => t.id == id).firstOrNull;
        if (matchedTask == null) continue;

        final title = item['title'] as String? ?? matchedTask.title;
        final description = item['description'] as String? ?? matchedTask.description;
        final dueDateStr = item['dueDate'] as String?;
        final parsedDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : matchedTask.dueDate;
        final dueTime = item['dueTime'] as String? ?? matchedTask.dueTime;
        final status = item['status'] as String? ?? matchedTask.status;

        if (status == 'completed' && matchedTask.status != 'completed') {
          await controller.toggleDone(matchedTask, true);
        } else {
          await controller.editTask(
            matchedTask,
            title: title,
            description: description,
            dueDate: parsedDate,
            dueTime: dueTime,
          );
        }
        updatedCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI created $createdCount and updated $updatedCount task(s)')),
        );
      }
    } catch (e) {
      setState(() {
        _aiError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEditing ? 'Edit Task' : 'New Task',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual'),
                  Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'AI Assistant'),
                ],
              ),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Manual Form View
                  _buildManualForm(),
                  // AI Form View
                  if (!isEditing) _buildAiForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    final isEditing = widget.task != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
            onPressed: () => _saveManual(context),
            child: Text(isEditing ? 'Save Changes' : 'Add Task'),
          ),
        ),
      ],
    );
  }

  Widget _buildAiForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Manage tasks in natural language. Orbit AI can create new tasks or update, prioritize, or complete existing pending ones.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiPromptCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g., Create a task to buy groceries for tomorrow and complete the project review task.',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        if (_aiError != null) ...[
          Text(
            _aiError!,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isAiLoading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: _submitAi,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Execute with AI'),
                ),
        ),
      ],
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
