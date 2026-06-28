import 'package:flutter/material.dart';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: overdue && !completed
            ? BorderSide(color: cs.error.withAlpha(80), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onEdit,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left colour accent bar ───────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                color: accentColor,
              ),

              // ── Checkbox ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Checkbox(
                    value: completed,
                    onChanged: (v) => onToggle(v ?? false),
                    activeColor: cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row with optional AI badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: cs.onSurfaceVariant,
                                color: completed
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                          if (task.metadata?.createdBy == 'ai') ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Extracted by AI',
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: cs.primary.withAlpha(160),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Description
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Due date chip
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 6),
                        _DueDateChip(
                          label: _formatDueDate(),
                          isOverdue: overdue,
                          isCompleted: completed,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Delete button ─────────────────────────────────────────────
              Center(
                child: IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red.withValues(alpha: 0.75),
                  ),
                  tooltip: 'Delete task',
                  splashRadius: 20,
                ),
              ),

              const SizedBox(width: 4),
            ],
          ),
        ),
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
