import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/event_repository.dart';
import '../../../core/utils/date_utils.dart';

final dayEventsProvider = StreamProvider.family<dynamic, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  return ref.watch(eventRepositoryProvider).watchEvents(user.uid).map((events) {
    final key = OrbitDateUtils.dateKey(date);
    return events.where((e) => OrbitDateUtils.dateKey(e.eventDate) == key).toList();
  });
});

class EventSection extends ConsumerWidget {
  final DateTime date;

  const EventSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(dayEventsProvider(date));

    return eventsAsync.when(
      data: (events) {
        if (events == null || events.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ...events.map((e) => ListTile(
              leading: const Icon(Icons.event, color: Colors.deepPurple),
              title: Text(e.title),
              subtitle: e.time != null ? Text(e.time!) : (e.description.isNotEmpty ? Text(e.description) : null),
              trailing: e.location != null ? const Icon(Icons.location_on_outlined) : null,
            )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
