import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/task_repository.dart';
import '../../../core/utils/date_utils.dart';

final dayTasksProvider = StreamProvider.family<dynamic, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  // Naive filter for today's tasks in memory for Phase 3 UI demonstration.
  // In a real app, query by `dueDate` directly in Firestore.
  return ref.watch(taskRepositoryProvider).watchTasks(user.uid).map((tasks) {
    final key = OrbitDateUtils.dateKey(date);
    return tasks.where((t) => t.dueDate != null && OrbitDateUtils.dateKey(t.dueDate!) == key).toList();
  });
});

class TaskSection extends ConsumerWidget {
  final DateTime date;

  const TaskSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(dayTasksProvider(date));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks == null || tasks.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ...tasks.map((t) => ListTile(
              leading: Icon(
                t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
                color: t.status == 'completed' ? Colors.green : Colors.grey,
              ),
              title: Text(
                t.title,
                style: TextStyle(
                  decoration: t.status == 'completed' ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: t.description.isNotEmpty ? Text(t.description) : null,
            )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
