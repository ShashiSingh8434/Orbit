import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/providers/paginated_list_notifier.dart';
import 'decision_edit_page.dart';
import '../../../core/widgets/orbit_card.dart';
import '../../../core/security/exceptions/crypto_exceptions.dart';

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
            return Center(child: Text(state.error!.userFriendlyMessage));
          }

          if (state.items.isEmpty) {
            return Center(
              child: Text(
                'No decisions captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final Map<DateTime, List<DecisionModel>> grouped = {};
          for (final d in state.items) {
            final date = DateTime(
              d.createdAt.year,
              d.createdAt.month,
              d.createdAt.day,
            );
            grouped.putIfAbsent(date, () => []).add(d);
          }

          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          for (final date in sortedDates) {
            grouped[date]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                itemCount: sortedDates.length + (state.isLoadMore ? 1 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  if (index == sortedDates.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final date = sortedDates[index];
                  final dayDecisions = grouped[date]!;
                  final dateKey = OrbitDateUtils.friendlyLabel(
                    OrbitDateUtils.dateKey(date),
                  );

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
                        return OrbitCard(
                          title: d.decision,
                          titleStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          description: d.reason.isNotEmpty ? d.reason : null,
                          trailing: d.metadata?.createdBy == 'ai'
                              ? Tooltip(
                                  message: 'Extracted by AI',
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () =>
                              DecisionEditPage.push(context, decision: d),
                        );
                      }),
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
