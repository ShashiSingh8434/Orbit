import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/decision_model.dart';

class DecisionSection extends StatelessWidget {
  final List<DecisionModel>? decisions;
  final bool isLoading;
  final DateTime date;

  const DecisionSection({
    super.key,
    required this.decisions,
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
            child: PulsingSkeleton(width: 90, height: 24),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            2,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  const PulsingSkeleton(
                    width: 24,
                    height: 24,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 16,
                        ),
                        const SizedBox(height: 6),
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.3,
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
        ? 'No decisions made today'
        : 'No decisions made on this day';

    if (decisions == null || decisions!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.call_split, color: colorScheme.onSurfaceVariant),
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
                    'Commitments or choices from your reflection will show up here.',
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
            'Decisions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...decisions!.map<Widget>(
          (d) => OrbitCard(
            margin: const EdgeInsets.only(bottom: 8),
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.39,
            ),
            borderColor: colorScheme.primary.withValues(alpha: 0.23),
            leading: Icon(
              d.status == 'Superseded'
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline,
              color: d.status == 'Superseded'
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
            ),
            title: d.decision,
            titleStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: d.status == 'Superseded'
                  ? TextDecoration.lineThrough
                  : null,
              color: d.status == 'Superseded'
                  ? colorScheme.onSurfaceVariant
                  : null,
            ),
            description: d.reason.isNotEmpty ? d.reason : null,
          ),
        ),
      ],
    );
  }
}
