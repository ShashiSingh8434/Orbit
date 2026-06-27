import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/decision_repository.dart';
import '../../../core/utils/date_utils.dart';

final dayDecisionsProvider = StreamProvider.family<dynamic, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  return ref.watch(decisionRepositoryProvider).watchDecisions(user.uid).map((decisions) {
    final key = OrbitDateUtils.dateKey(date);
    return decisions.where((d) => OrbitDateUtils.dateKey(d.createdAt) == key).toList();
  });
});

class DecisionSection extends ConsumerWidget {
  final DateTime date;

  const DecisionSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(dayDecisionsProvider(date));

    return decisionsAsync.when(
      data: (decisions) {
        if (decisions == null || decisions.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Decisions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ...decisions.map((d) => ListTile(
              leading: Icon(
                d.status == 'Superseded' ? Icons.cancel_outlined : Icons.check,
                color: d.status == 'Superseded' ? Colors.grey : Colors.blue,
              ),
              title: Text(
                d.decision,
                style: TextStyle(
                  decoration: d.status == 'Superseded' ? TextDecoration.lineThrough : null,
                  color: d.status == 'Superseded' ? Colors.grey : null,
                ),
              ),
              subtitle: d.reason.isNotEmpty ? Text(d.reason) : null,
            )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
