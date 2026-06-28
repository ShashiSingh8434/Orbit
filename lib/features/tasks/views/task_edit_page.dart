import 'dart:convert';
import '../../../shared/widgets/ai_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/task_agent_prompt.dart';
import '../data/task_repository.dart';
import '../controllers/task_controller.dart';
import '../models/task_model.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final TaskModel? task;

  const TaskEditPage({super.key, this.task});

  /// Push this page onto the navigator. Used by the arc FAB and task list.
  static Future<void> push(BuildContext context, {TaskModel? task}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: task)),
    );
  }

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage>
    with SingleTickerProviderStateMixin {
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

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    // Editing: only Manual tab. New task: Manual + AI tabs.
    _tabController = TabController(length: _isEditing ? 1 : 2, vsync: this);

    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _selectedDueDate = widget.task?.dueDate;
    if (widget.task?.dueTime != null) {
      try {
        final parts = widget.task!.dueTime!.split(':');
        _selectedDueTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
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

  Future<void> _saveManual() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final dueTimeStr = _selectedDueTime != null
        ? '${_selectedDueTime!.hour.toString().padLeft(2, '0')}:${_selectedDueTime!.minute.toString().padLeft(2, '0')}'
        : null;

    if (_isEditing) {
      await ref
          .read(taskControllerProvider.notifier)
          .editTask(
            widget.task!,
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    } else {
      await ref
          .read(taskControllerProvider.notifier)
          .addTask(
            title: title,
            description: _descCtrl.text.trim(),
            dueDate: _selectedDueDate,
            dueTime: dueTimeStr,
          );
    }

    if (mounted) Navigator.pop(context);
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

      final repo = ref.read(taskRepositoryProvider);
      final pendingTasks = await repo.getTasks(user.uid);
      final activePending = pendingTasks
          .where((t) => t.status == 'pending')
          .toList();

      final fullPrompt = TaskAgentPromptBuilder.buildPrompt(
        today: DateTime.now(),
        promptText: promptText,
        pendingTasks: activePending,
        existingTasks: activePending,
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
        throw Exception(
          'AI did not extract any task additions or updates. Try being more specific.',
        );
      }

      int createdCount = 0;
      int updatedCount = 0;

      // 1. Process Creates
      for (final item in createList) {
        final title = item['title'] as String? ?? '';
        if (title.trim().isEmpty) continue;
        final description = item['description'] as String? ?? '';
        final dueDateStr = item['dueDate'] as String?;
        final parsedDate = dueDateStr != null
            ? DateTime.tryParse(dueDateStr)
            : null;
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
        final description =
            item['description'] as String? ?? matchedTask.description;
        final dueDateStr = item['dueDate'] as String?;
        final parsedDate = dueDateStr != null
            ? DateTime.tryParse(dueDateStr)
            : matchedTask.dueDate;
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
          SnackBar(
            content: Text(
              'AI created $createdCount and updated $updatedCount task(s)',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _aiError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        bottom: _isEditing
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual'),
                  Tab(
                    icon: Icon(Icons.auto_awesome_rounded),
                    text: 'AI Assistant',
                  ),
                ],
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildManualForm(),
          if (!_isEditing)
            AiForm(
              promptCtrl: _aiPromptCtrl,
              isLoading: _isAiLoading,
              error: _aiError,
              hintText:
                  'e.g., Create a task to buy groceries for tomorrow and complete the project review task.',
              onSubmit: _submitAi,
              infoText:
                  'Manage tasks in natural language. Orbit AI can create new tasks or update, prioritize, or complete existing pending ones.',
              buttonLabel: 'Execute with AI',
            ),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Task title *',
            hintText: 'What do you need to do?',
          ),
          autofocus: !_isEditing,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
          ),
          textInputAction: TextInputAction.done,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
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
                label: Text(
                  _selectedDueDate != null
                      ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                      : 'Set Date',
                ),
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
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _saveManual,
          child: Text(_isEditing ? 'Save Changes' : 'Add Task'),
        ),
      ],
    );
  }


}
