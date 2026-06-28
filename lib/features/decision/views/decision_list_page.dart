import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/widgets/paginated_list_notifier.dart';
import 'decision_edit_page.dart';

final paginatedDecisionsProvider =
    StateNotifierProvider<
      PaginatedListNotifier<DecisionModel>,
      PaginatedState<DecisionModel>
    >((ref) {
      final user = ref.watch(authStateProvider).value;
      final repo = ref.watch(decisionRepositoryProvider);
      return PaginatedListNotifier<DecisionModel>(
        fetchPage: (startAfter) {
          if (user == null) {
            return Future.value(
              PaginatedResult(items: [], lastDoc: null, hasMore: false),
            );
          }
          return repo.getDecisionsPaginated(user.uid, startAfter: startAfter);
        },
      );
    });

class DecisionListPage extends ConsumerWidget {
  const DecisionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paginatedDecisionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Decisions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => DecisionEditPage.push(context),
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
                'No decisions captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final Map<String, List<DecisionModel>> grouped = {};
          for (final d in state.items) {
            final dateKey = OrbitDateUtils.friendlyLabel(
              OrbitDateUtils.dateKey(d.createdAt),
            );
            grouped.putIfAbsent(dateKey, () => []).add(d);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (info) {
              if (info.metrics.pixels >= info.metrics.maxScrollExtent - 200) {
                ref.read(paginatedDecisionsProvider.notifier).loadNextPage();
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paginatedDecisionsProvider.notifier).refresh(),
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
                  final dayDecisions = grouped[dateKey]!;

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
                      ...dayDecisions.map((d) {
                        final isSuperseded = d.status == 'Superseded';
                        return ListTile(
                          leading: Icon(
                            isSuperseded
                                ? Icons.cancel_outlined
                                : Icons.check_circle,
                            color: isSuperseded
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.primary,
                          ),
                          title: Text(
                            d.decision,
                            style: TextStyle(
                              decoration: isSuperseded
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isSuperseded
                                  ? colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          subtitle: d.reason.isNotEmpty ? Text(d.reason) : null,
                          trailing: d.metadata?.createdBy == 'ai'
                              ? Tooltip(
                                  message: 'Extracted by AI',
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: colorScheme.primary.withAlpha(150),
                                  ),
                                )
                              : null,
                          onTap: () =>
                              DecisionEditPage.push(context, decision: d),
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
