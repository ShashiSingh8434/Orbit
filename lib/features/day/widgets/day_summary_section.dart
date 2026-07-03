import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/day_model.dart';

class DaySummarySection extends StatelessWidget {
  final DayModel? day;
  final bool isLoading;
  final DateTime date;

  const DaySummarySection({
    super.key,
    required this.day,
    required this.isLoading,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsingSkeleton(width: 120, height: 24),
              const SizedBox(height: 12),
              PulsingSkeleton(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 16,
              ),
              const SizedBox(height: 8),
              PulsingSkeleton(
                width: MediaQuery.of(context).size.width * 0.6,
                height: 16,
              ),
            ],
          ),
        ),
      );
    }

    final isToday =
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    final emptyText = isToday
        ? 'No insights available for today. Write a reflection to capture your day!'
        : 'No insights available for this day.';

    if (day == null || day!.summary.isEmpty) {
      return OrbitCard(
        margin: const EdgeInsets.only(bottom: 8),
        leading: Icon(
          Icons.insights_rounded,
          color: colorScheme.primary,
        ),
        title: 'Orbit Insights',
        description: emptyText,
        descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return OrbitCard(
      margin: const EdgeInsets.only(bottom: 8),
      leading: Icon(
        Icons.insights_rounded,
        color: colorScheme.primary,
      ),
      title: 'Orbit Insights',
      description: day!.summary,
      bottomContent: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonalIcon(
          onPressed: () {
            context.push(
              AppRoutes.detailedSummary,
              extra: {'date': date},
            );
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Explore Orbit Deep Dive'),
        ),
      ),
    );
  }
}
