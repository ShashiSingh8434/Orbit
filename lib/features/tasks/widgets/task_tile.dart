import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/task_model.dart';

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isCompleted => task.status == 'completed';

  bool get _isOverdue {
    if (_isCompleted || task.dueDate == null) return false;
    final now = DateTime.now();
    final due = task.dueDate!;
    // Overdue if due date is strictly before today (ignore time for simplicity)
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  String _formatDueDate() {
    if (task.dueDate == null) return '';
    final d = task.dueDate!;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return task.dueTime != null ? '$dateStr · ${task.dueTime}' : dateStr;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '"${task.title}" will be permanently removed.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    onDelete();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final overdue = _isOverdue;
    final completed = _isCompleted;

    // Left accent colour
    final Color accentColor = completed
        ? cs.outlineVariant
        : overdue
        ? cs.error
        : cs.primary;

    return OrbitCard(
      margin: const EdgeInsets.only(bottom: 8),
      accentColor: accentColor,
      borderColor: overdue && !completed ? cs.error.withValues(alpha: 0.3) : null,
      onTap: onEdit,
      leading: GestureDetector(
        onTap: () => onToggle(!completed),
        child: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : cs.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      title: task.title,
      titleStyle: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        decorationColor: cs.onSurfaceVariant,
        color: completed ? cs.onSurfaceVariant : cs.onSurface,
      ),
      description: task.description.isNotEmpty ? task.description : null,
      bottomContent: task.dueDate != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: _DueDateChip(
                label: _formatDueDate(),
                isOverdue: overdue,
                isCompleted: completed,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (task.metadata?.createdBy == 'ai') ...[
            Tooltip(
              message: 'Extracted by AI',
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: cs.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: Colors.red.withValues(alpha: 0.75),
            ),
            tooltip: 'Delete task',
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Due date chip ─────────────────────────────────────────────────────────────

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({
    required this.label,
    required this.isOverdue,
    required this.isCompleted,
  });

  final String label;
  final bool isOverdue;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color chipColor = isCompleted
        ? cs.outlineVariant.withAlpha(60)
        : isOverdue
        ? cs.errorContainer
        : cs.primaryContainer.withAlpha(180);

    final Color textColor = isCompleted
        ? cs.onSurfaceVariant
        : isOverdue
        ? cs.error
        : cs.primary;

    final IconData icon = isOverdue && !isCompleted
        ? Icons.warning_amber_rounded
        : Icons.calendar_today_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            isOverdue && !isCompleted ? 'Overdue · $label' : label,
            style: textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
