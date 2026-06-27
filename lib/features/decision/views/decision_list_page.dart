import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../../../core/utils/date_utils.dart';

final allDecisionsProvider = StreamProvider<List<DecisionModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(decisionRepositoryProvider).watchDecisions(user.uid);
});

class DecisionListPage extends ConsumerWidget {
  const DecisionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(allDecisionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Decisions'),
      ),
      body: decisionsAsync.when(
        data: (decisions) {
          if (decisions.isEmpty) {
            return Center(
              child: Text(
                'No decisions captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          // Group by Date
          final Map<String, List<DecisionModel>> grouped = {};
          for (final d in decisions) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(d.createdAt));
            grouped.putIfAbsent(dateKey, () => []).add(d);
          }

          return ListView.builder(
            itemCount: grouped.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
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
                        isSuperseded ? Icons.cancel_outlined : Icons.check_circle,
                        color: isSuperseded ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                      title: Text(
                        d.decision,
                        style: TextStyle(
                          decoration: isSuperseded ? TextDecoration.lineThrough : null,
                          color: isSuperseded ? colorScheme.onSurfaceVariant : null,
                        ),
                      ),
                      subtitle: d.reason.isNotEmpty ? Text(d.reason) : null,
                      trailing: d.metadata?.createdBy == 'ai'
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
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
