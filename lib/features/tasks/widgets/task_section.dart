import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/pulsing_skeleton.dart';
import '../../../core/widgets/orbit_card.dart';
import '../models/task_model.dart';
import '../controllers/task_controller.dart';

class TaskSection extends ConsumerWidget {
  final List<TaskModel>? tasks;
  final bool isLoading;
  final DateTime date;

  const TaskSection({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: PulsingSkeleton(width: 80, height: 24),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            2,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  const PulsingSkeleton(
                    width: 24,
                    height: 24,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 16,
                        ),
                        const SizedBox(height: 6),
                        PulsingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.3,
                          height: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final isToday =
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    final emptyText = isToday ? 'No tasks for today' : 'No tasks for this day';

    if (tasks == null || tasks!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI will automatically capture items you need to work on from your reflection.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Tasks',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...tasks!.map<Widget>(
          (t) => OrbitCard(
            onTap: () => context.push(AppRoutes.tasks),
            margin: const EdgeInsets.only(bottom: 8),
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.39,
            ),
            borderColor: colorScheme.primary.withValues(alpha: 0.23),
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final nextDone = t.status != 'completed';
                ref
                    .read(taskControllerProvider.notifier)
                    .toggleDone(t, nextDone);
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  t.status == 'completed'
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: t.status == 'completed'
                      ? Colors.green
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: t.title,
            titleStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: t.status == 'completed'
                  ? colorScheme.onSurfaceVariant
                  : null,
            ),
            description: t.description.isNotEmpty ? t.description : null,
          ),
        ),
      ],
    );
  }
}
