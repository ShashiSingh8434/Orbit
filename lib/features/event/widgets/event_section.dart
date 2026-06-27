import 'package:flutter/material.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../models/event_model.dart';

class EventSection extends StatelessWidget {
  final List<EventModel>? events;
  final bool isLoading;

  const EventSection({
    super.key,
    required this.events,
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
            child: PulsingSkeleton(width: 80, height: 24),
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
                    'No events for today',
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
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...events!.map<Widget>((e) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event, color: Colors.deepPurple),
          title: Text(e.title),
          subtitle: e.time != null ? Text(e.time!) : (e.description.isNotEmpty ? Text(e.description) : null),
          trailing: e.location != null ? const Icon(Icons.location_on_outlined) : null,
        )).toList(),
      ],
    );
  }
}
