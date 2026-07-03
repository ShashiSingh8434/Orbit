import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/learning_repository.dart';
import '../models/learning_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/providers/paginated_list_notifier.dart';
import 'learning_edit_page.dart';
import '../../../core/widgets/orbit_card.dart';

final paginatedLearningsProvider =
    StateNotifierProvider<
      PaginatedListNotifier<LearningModel>,
      PaginatedState<LearningModel>
    >((ref) {
      final user = ref.watch(authStateProvider).value;
      final repo = ref.watch(learningRepositoryProvider);
      return PaginatedListNotifier<LearningModel>(
        fetchPage: (startAfter) {
          if (user == null) {
            return Future.value(
              PaginatedResult(items: [], lastDoc: null, hasMore: false),
            );
          }
          return repo.getLearningsPaginated(user.uid, startAfter: startAfter);
        },
      );
    });

class LearningListPage extends ConsumerWidget {
  const LearningListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paginatedLearningsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Learnings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => LearningEditPage.push(context),
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
                'No learnings captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final Map<String, List<LearningModel>> grouped = {};
          for (final l in state.items) {
            final dateKey = OrbitDateUtils.friendlyLabel(
              OrbitDateUtils.dateKey(l.createdAt),
            );
            grouped.putIfAbsent(dateKey, () => []).add(l);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (info) {
              if (info.metrics.pixels >= info.metrics.maxScrollExtent - 200) {
                ref.read(paginatedLearningsProvider.notifier).loadNextPage();
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paginatedLearningsProvider.notifier).refresh(),
              child: ListView.builder(
                itemCount: grouped.length + (state.isLoadMore ? 1 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  if (index == grouped.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final dateKey = grouped.keys.elementAt(index);
                  final dayLearnings = grouped[dateKey]!;

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
                      ...dayLearnings.map(
                        (l) => OrbitCard(
                          title: l.title,
                          description: l.description,
                          onTap: () =>
                              LearningEditPage.push(context, learning: l),
                          trailing:
                              (l.occurrenceCount > 1 ||
                                  l.metadata?.createdBy == 'ai')
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (l.occurrenceCount > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${l.occurrenceCount}x',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    if (l.metadata?.createdBy == 'ai') ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Extracted by AI',
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : null,
                        ),
                      ),
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
