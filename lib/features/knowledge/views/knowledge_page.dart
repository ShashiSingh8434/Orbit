import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart';
import '../controllers/knowledge_controller.dart';
import '../widgets/knowledge_summary_card.dart';

class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key, this.dateKey});

  final String? dateKey;

  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  late String _resolvedDate;

  @override
  void initState() {
    super.initState();
    _resolvedDate = widget.dateKey ?? OrbitDateUtils.todayKey();
  }

  Future<void> _refresh() async {
    await ref.read(knowledgeControllerProvider.notifier).refreshToday();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final knowledgeAsync = ref.watch(knowledgeProvider(_resolvedDate));
    final isRefreshing = ref.watch(knowledgeControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Knowledge'),
            Text(
              OrbitDateUtils.friendlyLabel(_resolvedDate),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'Refresh AI insights',
              onPressed: _refresh,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Pick date',
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: knowledgeAsync.when(
          data: (knowledge) {
            if (knowledge == null) {
              return _EmptyState(onProcess: _refresh);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Reflection count badge
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Based on ${knowledge.reflectionCount} reflection${knowledge.reflectionCount != 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                KnowledgeSummaryCard(knowledge: knowledge),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: OrbitDateUtils.parseKey(_resolvedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _resolvedDate = OrbitDateUtils.dateKey(picked));
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onProcess});

  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_rounded, size: 64, color: colorScheme.primary.withAlpha(80)),
            const SizedBox(height: 16),
            Text('No AI insights yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add some reflections then tap the ✨ button to extract knowledge.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onProcess,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Process Today'),
            ),
          ],
        ),
      ),
    );
  }
}
