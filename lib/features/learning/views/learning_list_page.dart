import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/learning_repository.dart';
import '../models/learning_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/widgets/paginated_list_notifier.dart';

final paginatedLearningsProvider = StateNotifierProvider<PaginatedListNotifier<LearningModel>, PaginatedState<LearningModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final repo = ref.watch(learningRepositoryProvider);
  return PaginatedListNotifier<LearningModel>(
    fetchPage: (startAfter) {
      if (user == null) {
        return Future.value(PaginatedResult(items: [], lastDoc: null, hasMore: false));
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
      appBar: AppBar(
        title: const Text('My Learnings'),
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

          // Group by Date
          final Map<String, List<LearningModel>> grouped = {};
          for (final l in state.items) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(l.createdAt));
            grouped.putIfAbsent(dateKey, () => []).add(l);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                ref.read(paginatedLearningsProvider.notifier).loadNextPage();
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(paginatedLearningsProvider.notifier).refresh(),
              child: ListView.builder(
                itemCount: grouped.length + (state.isLoadMore ? 1 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  if (index == grouped.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
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
                          onTap: () {
                            final user = ref.read(authStateProvider).value;
                            if (user != null) {
                              showDialog(
                                context: context,
                                builder: (context) => _EditLearningDialog(
                                  learning: l,
                                  userId: user.uid,
                                  repository: ref.read(learningRepositoryProvider),
                                ),
                              );
                            }
                          },
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

class _EditLearningDialog extends ConsumerStatefulWidget {
  final LearningModel learning;
  final String userId;
  final LearningRepository repository;

  const _EditLearningDialog({
    required this.learning,
    required this.userId,
    required this.repository,
  });

  @override
  ConsumerState<_EditLearningDialog> createState() => _EditLearningDialogState();
}

class _EditLearningDialogState extends ConsumerState<_EditLearningDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _categoryCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.learning.title);
    _descriptionCtrl = TextEditingController(text: widget.learning.description);
    _categoryCtrl = TextEditingController(text: widget.learning.category);
    _selectedDate = widget.learning.createdAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Learning'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Learning',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Context',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Date'),
              subtitle: Text(OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(_selectedDate))),
              trailing: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: const Text('Change'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_titleCtrl.text.trim().isEmpty) return;
            final updated = widget.learning.copyWith(
              title: _titleCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              category: _categoryCtrl.text.trim(),
              createdAt: _selectedDate,
              updatedAt: DateTime.now(),
            );
            await widget.repository.updateLearning(widget.userId, updated);
            ref.read(paginatedLearningsProvider.notifier).updateItem((l) => l.id == updated.id ? updated : l);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
