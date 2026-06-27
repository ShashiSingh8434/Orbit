import 'package:flutter/material.dart';
import '../models/daily_knowledge_model.dart';

class KnowledgeSummaryCard extends StatelessWidget {
  const KnowledgeSummaryCard({super.key, required this.knowledge});

  final DailyKnowledgeModel knowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary ──
            if (knowledge.summary.isNotEmpty) ...[
              _SectionTitle(icon: Icons.auto_awesome_rounded, label: 'Summary'),
              const SizedBox(height: 8),
              Text(knowledge.summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
            ],

            // ── Mood & Energy ──
            if (knowledge.mood != null || knowledge.energy != null) ...[
              Row(
                children: [
                  if (knowledge.mood != null)
                    _MetricBadge(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      label: 'Mood',
                      value: knowledge.mood!,
                      color: const Color(0xFF6C63FF),
                    ),
                  if (knowledge.mood != null && knowledge.energy != null)
                    const SizedBox(width: 12),
                  if (knowledge.energy != null)
                    _MetricBadge(
                      icon: Icons.bolt_rounded,
                      label: 'Energy',
                      value: knowledge.energy!,
                      color: const Color(0xFFFF7043),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Learnings ──
            if (knowledge.learnings.isNotEmpty) ...[
              _SectionTitle(icon: Icons.school_rounded, label: 'Learnings'),
              const SizedBox(height: 8),
              ...knowledge.learnings.map(
                (l) => _BulletItem(text: l, color: const Color(0xFF00BCD4)),
              ),
              const SizedBox(height: 12),
            ],

            // ── Decisions ──
            if (knowledge.decisions.isNotEmpty) ...[
              _SectionTitle(icon: Icons.gavel_rounded, label: 'Decisions'),
              const SizedBox(height: 8),
              ...knowledge.decisions.map(
                (d) => _BulletItem(text: d, color: const Color(0xFF4CAF50)),
              ),
              const SizedBox(height: 12),
            ],

            // ── Tasks ──
            if (knowledge.tasks.isNotEmpty) ...[
              _SectionTitle(icon: Icons.task_alt_rounded, label: 'Tasks'),
              const SizedBox(height: 8),
              ...knowledge.tasks.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        t.isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: t.isDone ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: t.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Tags ──
            if (knowledge.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: knowledge.tags
                    .map((t) => Chip(
                          label: Text(t, style: theme.textTheme.bodySmall),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value/5',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: CircleAvatar(radius: 3, backgroundColor: color),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
