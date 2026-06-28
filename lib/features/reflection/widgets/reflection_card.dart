import 'package:flutter/material.dart';
import '../models/reflection_model.dart';
import 'reflection_tag_chip.dart';

/// Displays a single [ReflectionModel] in a card.
class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    this.onEdit,
    this.onDelete,
  });

  final ReflectionModel reflection;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeLabel = _formatTime(reflection.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(
                  reflection.source == 'voice'
                      ? Icons.mic_rounded
                      : Icons.edit_note_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (reflection.aiProcessed) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: colorScheme.primary.withAlpha(150),
                  ),
                ],
                const Spacer(),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Body ──
            Text(reflection.text, style: theme.textTheme.bodyLarge),

            // ── Tags ──
            if (reflection.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: reflection.tags
                    .map((t) => ReflectionTagChip(label: t))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
