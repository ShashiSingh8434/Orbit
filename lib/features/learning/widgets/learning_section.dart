import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/learning_model.dart';

class LearningSection extends StatelessWidget {
  final List<LearningModel>? learnings;
  final bool isLoading;
  final DateTime date;

  const LearningSection({
    super.key,
    required this.learnings,
    required this.isLoading,
    required this.date,
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
            child: PulsingSkeleton(width: 100, height: 24),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            2,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  const PulsingSkeleton(
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 16,
                        ),
                        const SizedBox(height: 6),
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final isToday =
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    final emptyText = isToday
        ? 'No learnings captured today'
        : 'No learnings captured for this day';

    if (learnings == null || learnings!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share any realizations or insights in your reflection to record them.',
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
            'Learnings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...learnings!.map<Widget>(
          (l) => OrbitCard(
            margin: const EdgeInsets.only(bottom: 8),
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.39,
            ),
            borderColor: colorScheme.primary.withValues(alpha: 0.23),
            leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
            title: l.title,
            description: l.description,
            trailing: l.occurrenceCount > 1
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${l.occurrenceCount}x',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
