import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../models/task_model.dart';

class TaskSection extends StatelessWidget {
  final List<TaskModel>? tasks;
  final bool isLoading;

  const TaskSection({
    super.key,
    required this.tasks,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: PulsingSkeleton(width: 80, height: 24),
          ),
          const SizedBox(height: 8),
          ...List.generate(2, (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                const PulsingSkeleton(width: 24, height: 24, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PulsingSkeleton(width: MediaQuery.of(context).size.width * 0.5, height: 16),
                      const SizedBox(height: 6),
                      PulsingSkeleton(width: MediaQuery.of(context).size.width * 0.3, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      );
    }

    if (tasks == null || tasks!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.task_alt_outlined, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No tasks for today',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI will automatically capture items you need to work on from your reflection.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Tasks',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...tasks!.map<Widget>((t) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
            color: t.status == 'completed' ? Colors.green : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            t.title,
            style: TextStyle(
              decoration: t.status == 'completed' ? TextDecoration.lineThrough : null,
              color: t.status == 'completed' ? colorScheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: t.description.isNotEmpty ? Text(t.description) : null,
        )).toList(),
      ],
    );
  }
}
