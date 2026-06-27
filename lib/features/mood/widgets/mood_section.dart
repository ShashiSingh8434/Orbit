import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../models/mood_model.dart';

class MoodSection extends StatelessWidget {
  final List<MoodModel>? moods;
  final bool isLoading;
  final DateTime date;

  const MoodSection({
    super.key,
    required this.moods,
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
            child: PulsingSkeleton(width: 120, height: 24),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (index) => const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: PulsingSkeleton(width: 80, height: 32, borderRadius: 16),
            )),
          ),
        ],
      );
    }

    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
    final emptyText = isToday ? 'No moods recorded today' : 'No moods recorded for this day';

    if (moods == null || moods!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.mood_outlined, color: colorScheme.onSurfaceVariant),
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
                    'Your emotional timeline will display here after you submit a reflection.',
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
            'Mood Timeline',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Wrap(
          spacing: 8.0,
          children: moods!.map<Widget>((m) => Chip(
            avatar: const Icon(Icons.mood, size: 16),
            label: Text('${m.timeOfDay}: ${m.value}/5'),
            backgroundColor: _getColorForMood(m.value, colorScheme),
          )).toList(),
        ),
      ],
    );
  }

  Color _getColorForMood(int value, ColorScheme colorScheme) {
    switch (value) {
      case 5: return Colors.green.shade200;
      case 4: return Colors.lightGreen.shade200;
      case 3: return Colors.yellow.shade200;
      case 2: return Colors.orange.shade200;
      case 1: return Colors.red.shade200;
      default: return colorScheme.surfaceVariant;
    }
  }
}
