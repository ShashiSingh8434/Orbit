import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../models/decision_model.dart';

class DecisionSection extends StatelessWidget {
  final List<DecisionModel>? decisions;
  final bool isLoading;

  const DecisionSection({
    super.key,
    required this.decisions,
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
            child: PulsingSkeleton(width: 90, height: 24),
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
            Icon(Icons.check_circle_outline, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No decisions made today',
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
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...decisions!.map<Widget>((d) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            d.status == 'Superseded' ? Icons.cancel_outlined : Icons.check_circle_outline,
            color: d.status == 'Superseded' ? colorScheme.onSurfaceVariant : colorScheme.primary,
          ),
          title: Text(
            d.decision,
            style: TextStyle(
              decoration: d.status == 'Superseded' ? TextDecoration.lineThrough : null,
              color: d.status == 'Superseded' ? colorScheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: d.reason.isNotEmpty ? Text(d.reason) : null,
        )).toList(),
      ],
    );
  }
}
