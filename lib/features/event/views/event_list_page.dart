import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';
import '../../../core/utils/date_utils.dart';

final allEventsProvider = StreamProvider<List<EventModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(eventRepositoryProvider).watchEvents(user.uid);
});

class EventListPage extends ConsumerWidget {
  const EventListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(allEventsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Text(
                'No events captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          // Group by Date
          final Map<String, List<EventModel>> grouped = {};
          for (final e in events) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(e.eventDate));
            grouped.putIfAbsent(dateKey, () => []).add(e);
          }

          return ListView.builder(
            itemCount: grouped.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final dayEvents = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      dateKey,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...dayEvents.map((e) {
                    return ListTile(
                      leading: Icon(Icons.event, color: colorScheme.primary),
                      title: Text(e.title),
                      subtitle: e.time != null ? Text('${e.time} - ${e.description}') : (e.description.isNotEmpty ? Text(e.description) : null),
                      trailing: e.metadata?.createdBy == 'ai'
                          ? Tooltip(
                              message: 'Extracted by AI',
                              child: Icon(Icons.auto_awesome_rounded, size: 14, color: colorScheme.primary.withAlpha(150)),
                            )
                          : null,
                    );
                  }),
                  const Divider(),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
