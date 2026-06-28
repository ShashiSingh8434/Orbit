import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/widgets/paginated_list_notifier.dart';

final paginatedEventsProvider = StateNotifierProvider<PaginatedListNotifier<EventModel>, PaginatedState<EventModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final repo = ref.watch(eventRepositoryProvider);
  return PaginatedListNotifier<EventModel>(
    fetchPage: (startAfter) {
      if (user == null) {
        return Future.value(PaginatedResult(items: [], lastDoc: null, hasMore: false));
      }
      return repo.getEventsPaginated(user.uid, startAfter: startAfter);
    },
  );
});

class EventListPage extends ConsumerWidget {
  const EventListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paginatedEventsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.items.isEmpty) {
            return Center(child: Text('Error: ${state.error}'));
          }

          if (state.items.isEmpty) {
            return Center(
              child: Text(
                'No events captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          // Group by Date
          final Map<String, List<EventModel>> grouped = {};
          for (final e in state.items) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(e.eventDate));
            grouped.putIfAbsent(dateKey, () => []).add(e);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                ref.read(paginatedEventsProvider.notifier).loadNextPage();
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(paginatedEventsProvider.notifier).refresh(),
              child: ListView.builder(
                itemCount: grouped.length + (state.isLoadMore ? 1 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  if (index == grouped.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

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
                          onTap: () {
                            final user = ref.read(authStateProvider).value;
                            if (user != null) {
                              showDialog(
                                context: context,
                                builder: (context) => _EditEventDialog(
                                  event: e,
                                  userId: user.uid,
                                  repository: ref.read(eventRepositoryProvider),
                                ),
                              );
                            }
                          },
                        );
                      }),
                      const Divider(),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditEventDialog extends ConsumerStatefulWidget {
  final EventModel event;
  final String userId;
  final EventRepository repository;

  const _EditEventDialog({
    required this.event,
    required this.userId,
    required this.repository,
  });

  @override
  ConsumerState<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends ConsumerState<_EditEventDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _locationCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event.title);
    _descriptionCtrl = TextEditingController(text: widget.event.description);
    _timeCtrl = TextEditingController(text: widget.event.time ?? '');
    _locationCtrl = TextEditingController(text: widget.event.location ?? '');
    _selectedDate = widget.event.eventDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeCtrl,
              decoration: const InputDecoration(
                labelText: 'Time (e.g. 2:00 PM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Event Date'),
              subtitle: Text(OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(_selectedDate))),
              trailing: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: const Text('Change'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_titleCtrl.text.trim().isEmpty) return;
            final updated = widget.event.copyWith(
              title: _titleCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              time: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
              location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
              eventDate: _selectedDate,
              updatedAt: DateTime.now(),
            );
            await widget.repository.updateEvent(widget.userId, updated);
            ref.read(paginatedEventsProvider.notifier).updateItem((e) => e.id == updated.id ? updated : e);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
