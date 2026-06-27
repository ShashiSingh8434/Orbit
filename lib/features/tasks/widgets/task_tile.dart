import 'package:flutter/material.dart';
import '../models/task_model.dart';

/// Displays a single [TaskModel] as a dismissible list tile.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskModel task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_rounded, color: colorScheme.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Checkbox(
            value: task.status == 'completed',
            onChanged: (v) => onToggle(v ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          title: Text(
            task.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
              color: task.status == 'completed' ? colorScheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: task.description.isNotEmpty
              ? Text(
                  task.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: task.metadata?.createdBy == 'ai'
              ? Tooltip(
                  message: 'Extracted by AI',
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: colorScheme.primary.withAlpha(150),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
