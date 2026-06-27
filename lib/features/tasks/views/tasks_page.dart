import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/task_controller.dart';
import '../widgets/task_tile.dart';

/// Task list page. Users can add manual tasks and toggle/delete existing ones.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: tasksAsync.when(
        data: (tasks) => tasks.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  final task = tasks[i];
                  return TaskTile(
                    task: task,
                    onToggle: (done) => ref
                        .read(taskControllerProvider.notifier)
                        .toggleDone(task.id, done),
                    onDelete: () => ref
                        .read(taskControllerProvider.notifier)
                        .deleteTask(task.id),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTask(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddTask(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Task', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Task title *',
                hintText: 'What do you need to do?',
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTask(ctx, ref, titleCtrl, descCtrl),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _saveTask(ctx, ref, titleCtrl, descCtrl),
                child: const Text('Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTask(
    BuildContext ctx,
    WidgetRef ref,
    TextEditingController titleCtrl,
    TextEditingController descCtrl,
  ) async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(ctx);
    await ref.read(taskControllerProvider.notifier).addTask(
          title: title,
          description: descCtrl.text.trim(),
        );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded, size: 64, color: colorScheme.primary.withAlpha(80)),
          const SizedBox(height: 16),
          Text('No tasks yet', style: Theme.of(context).textTheme.headlineSmall),
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
