import 'package:flutter/material.dart';
import '../models/task_model.dart';

/// Displays a single [TaskModel] as a dismissible list tile.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final TaskModel task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String? dueDateStr;
    if (task.dueDate != null) {
      dueDateStr = '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}';
      if (task.dueTime != null) {
        dueDateStr = '$dueDateStr, ${task.dueTime}';
      }
    }

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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
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
            subtitle: (task.description.isNotEmpty || dueDateStr != null)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.description.isNotEmpty)
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (dueDateStr != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              dueDateStr,
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ],
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
      ),
    );
  }
}
