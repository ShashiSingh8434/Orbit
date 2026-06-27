import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/learning_repository.dart';
import '../../../core/utils/date_utils.dart';

final dayLearningsProvider = StreamProvider.family<dynamic, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  return ref.watch(learningRepositoryProvider).watchLearnings(user.uid).map((learnings) {
    final key = OrbitDateUtils.dateKey(date);
    return learnings.where((l) => OrbitDateUtils.dateKey(l.createdAt) == key).toList();
  });
});

class LearningSection extends ConsumerWidget {
  final DateTime date;

  const LearningSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningsAsync = ref.watch(dayLearningsProvider(date));

    return learningsAsync.when(
      data: (learnings) {
        if (learnings == null || learnings.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Learnings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ...learnings.map((l) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                title: Text(l.title),
                subtitle: l.description.isNotEmpty ? Text(l.description) : null,
                trailing: l.occurrenceCount > 1 
                  ? Chip(label: Text('${l.occurrenceCount}x'))
                  : null,
              ),
            )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
