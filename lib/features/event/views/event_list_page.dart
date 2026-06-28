import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/widgets/paginated_list_notifier.dart';
import 'event_edit_sheet.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const EventEditSheet(),
          );
        },
        child: const Icon(Icons.add_rounded),
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
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => EventEditSheet(event: e),
                            );
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
