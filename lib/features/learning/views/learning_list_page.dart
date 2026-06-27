import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/learning_repository.dart';
import '../models/learning_model.dart';
import '../../../core/utils/date_utils.dart';

final allLearningsProvider = StreamProvider<List<LearningModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(learningRepositoryProvider).watchLearnings(user.uid);
});

class LearningListPage extends ConsumerWidget {
  const LearningListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningsAsync = ref.watch(allLearningsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Learnings'),
      ),
      body: learningsAsync.when(
        data: (learnings) {
          if (learnings.isEmpty) {
            return Center(
              child: Text(
                'No learnings captured yet.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          // Group by Date
          final Map<String, List<LearningModel>> grouped = {};
          for (final l in learnings) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(l.createdAt));
            grouped.putIfAbsent(dateKey, () => []).add(l);
          }

          return ListView.builder(
            itemCount: grouped.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
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
                  ...dayLearnings.map((l) {
                    return ListTile(
                      leading: Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                      title: Text(l.title),
                      subtitle: l.description.isNotEmpty ? Text(l.description) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (l.occurrenceCount > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${l.occurrenceCount}x', style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer)),
                            ),
                          if (l.metadata?.createdBy == 'ai') ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Extracted by AI',
                              child: Icon(Icons.auto_awesome_rounded, size: 14, color: colorScheme.primary.withAlpha(150)),
                            ),
                          ],
                        ],
                      ),
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
