import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/event_model.dart';

class EventSection extends StatelessWidget {
  final List<EventModel>? events;
  final bool isLoading;
  final DateTime date;

  const EventSection({
    super.key,
    required this.events,
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
            child: PulsingSkeleton(width: 80, height: 24),
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
        ? 'No events for today'
        : 'No events for this day';

    if (events == null || events!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: colorScheme.onSurfaceVariant),
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
                    'Events or calendar items mentioned in your reflection will be listed here.',
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
            'Events',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._getSortedEvents().map<Widget>(
          (e) => OrbitCard(
            margin: const EdgeInsets.only(bottom: 8),
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.39,
            ),
            borderColor: colorScheme.primary.withValues(alpha: 0.23),
            leading: const Icon(Icons.event, color: Colors.deepPurple),
            title: e.title,
            description: e.time != null
                ? '${e.time}${e.description.isNotEmpty ? ' · ${e.description}' : ''}'
                : (e.description.isNotEmpty ? e.description : null),
            trailing: e.location != null
                ? Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  List<EventModel> _getSortedEvents() {
    if (events == null) return [];
    final sorted = List<EventModel>.from(events!);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
