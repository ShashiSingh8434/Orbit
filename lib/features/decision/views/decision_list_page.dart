import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/widgets/paginated_list_notifier.dart';

final paginatedDecisionsProvider = StateNotifierProvider<PaginatedListNotifier<DecisionModel>, PaginatedState<DecisionModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final repo = ref.watch(decisionRepositoryProvider);
  return PaginatedListNotifier<DecisionModel>(
    fetchPage: (startAfter) {
      if (user == null) {
        return Future.value(PaginatedResult(items: [], lastDoc: null, hasMore: false));
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
      appBar: AppBar(
        title: const Text('My Decisions'),
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

          // Group by Date
          final Map<String, List<DecisionModel>> grouped = {};
          for (final d in state.items) {
            final dateKey = OrbitDateUtils.friendlyLabel(OrbitDateUtils.dateKey(d.createdAt));
            grouped.putIfAbsent(dateKey, () => []).add(d);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                ref.read(paginatedDecisionsProvider.notifier).loadNextPage();
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(paginatedDecisionsProvider.notifier).refresh(),
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
                          onTap: () {
                            final user = ref.read(authStateProvider).value;
                            if (user != null) {
                              showDialog(
                                context: context,
                                builder: (context) => _EditDecisionDialog(
                                  decision: d,
                                  userId: user.uid,
                                  repository: ref.read(decisionRepositoryProvider),
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

class _EditDecisionDialog extends ConsumerStatefulWidget {
  final DecisionModel decision;
  final String userId;
  final DecisionRepository repository;

  const _EditDecisionDialog({
    required this.decision,
    required this.userId,
    required this.repository,
  });

  @override
  ConsumerState<_EditDecisionDialog> createState() => _EditDecisionDialogState();
}

class _EditDecisionDialogState extends ConsumerState<_EditDecisionDialog> {
  late TextEditingController _decisionCtrl;
  late TextEditingController _reasonCtrl;
  late DateTime _selectedDate;
  late String _status;

  @override
  void initState() {
    super.initState();
    _decisionCtrl = TextEditingController(text: widget.decision.decision);
    _reasonCtrl = TextEditingController(text: widget.decision.reason);
    _selectedDate = widget.decision.createdAt;
    _status = widget.decision.status;
  }

  @override
  void dispose() {
    _decisionCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Decision'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _decisionCtrl,
              decoration: const InputDecoration(
                labelText: 'Decision',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / Details',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['Active', 'Completed', 'Cancelled', 'Superseded']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _status = val);
                }
              },
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
            if (_decisionCtrl.text.trim().isEmpty) return;
            final updated = widget.decision.copyWith(
              decision: _decisionCtrl.text.trim(),
              reason: _reasonCtrl.text.trim(),
              status: _status,
              createdAt: _selectedDate,
              updatedAt: DateTime.now(),
            );
            await widget.repository.updateDecision(widget.userId, updated);
            ref.read(paginatedDecisionsProvider.notifier).updateItem((d) => d.id == updated.id ? updated : d);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
