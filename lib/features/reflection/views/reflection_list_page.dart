import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/router/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/reflection_controller.dart';
import '../models/reflection_model.dart';
import '../widgets/reflection_card.dart';

/// Lists all reflections for a given [dateKey] (defaults to today).
/// Tapping the FAB opens [ReflectionEditPage] to create a new entry.
class ReflectionListPage extends ConsumerWidget {
  const ReflectionListPage({super.key, this.dateKey});

  /// Firestore date key (yyyy-MM-dd). Defaults to today if null.
  final String? dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedDate = dateKey ?? OrbitDateUtils.todayKey();
    final reflectionsAsync = ref.watch(reflectionsProvider(resolvedDate));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(OrbitDateUtils.friendlyLabel(resolvedDate)),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Pick date',
            onPressed: () => _pickDate(context, ref, resolvedDate),
          ),
        ],
      ),
      body: reflectionsAsync.when(
        data: (reflections) => reflections.isEmpty
            ? _EmptyState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          context.push(AppRoutes.detailedSummary, extra: {'date': OrbitDateUtils.parseKey(resolvedDate)});
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('See detailed summary'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: reflections.length,
                      itemBuilder: (_, i) {
                        final r = reflections[i];
                        return ReflectionCard(
                          reflection: r,
                          onEdit: () => context.push(
                            '/home/reflections/edit',
                            extra: {'dateKey': resolvedDate, 'reflectionId': r.id},
                          ),
                          onDelete: () => _confirmDelete(context, ref, r, resolvedDate),
                        );
                      },
                    ),
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/home/reflections/edit',
          extra: {'dateKey': resolvedDate},
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Reflect'),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, String current) async {
    final auth = ref.read(authStateProvider).value;
    final creationTime = auth?.metadata.creationTime ?? DateTime.now().subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: OrbitDateUtils.parseKey(current),
      firstDate: DateTime(creationTime.year, creationTime.month, creationTime.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && context.mounted) {
      context.go(AppRoutes.reflectionByDate(OrbitDateUtils.dateKey(picked)));
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ReflectionModel r,
    String dateKey,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reflection?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(reflectionControllerProvider.notifier).deleteReflection(
                    reflectionId: r.id,
                    dateKey: dateKey,
                  );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 64, color: colorScheme.primary.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No reflections yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to capture your first thought.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
