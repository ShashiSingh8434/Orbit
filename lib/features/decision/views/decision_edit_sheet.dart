import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/decision_agent_prompt.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../views/decision_list_page.dart';
import '../../../core/utils/date_utils.dart';

class DecisionEditSheet extends ConsumerStatefulWidget {
  final DecisionModel? decision;

  const DecisionEditSheet({super.key, this.decision});

  @override
  ConsumerState<DecisionEditSheet> createState() => _DecisionEditSheetState();
}

class _DecisionEditSheetState extends ConsumerState<DecisionEditSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual form controllers
  late TextEditingController _decisionCtrl;
  late TextEditingController _reasonCtrl;
  late DateTime _selectedDate;
  late String _status;

  // AI assistant controllers
  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.decision == null ? 2 : 1, vsync: this);

    _decisionCtrl = TextEditingController(text: widget.decision?.decision ?? '');
    _reasonCtrl = TextEditingController(text: widget.decision?.reason ?? '');
    _selectedDate = widget.decision?.createdAt ?? DateTime.now();
    _status = widget.decision?.status ?? 'Active';

    _aiPromptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _decisionCtrl.dispose();
    _reasonCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManual() async {
    final text = _decisionCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final repo = ref.read(decisionRepositoryProvider);
    final dayRepo = ref.read(dayRepositoryProvider);

    if (widget.decision != null) {
      // Edit mode
      final updated = widget.decision!.copyWith(
        decision: text,
        reason: _reasonCtrl.text.trim(),
        status: _status,
        createdAt: _selectedDate,
        updatedAt: DateTime.now(),
      );
      await repo.updateDecision(user.uid, updated);
      await dayRepo.invalidateDayCache(user.uid, widget.decision!.createdAt);
      if (_selectedDate != widget.decision!.createdAt) {
        await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      }
      ref.read(paginatedDecisionsProvider.notifier).updateItem((d) => d.id == updated.id ? updated : d);
    } else {
      // Create mode
      final created = DecisionModel(
        id: const Uuid().v4(),
        decision: text,
        reason: _reasonCtrl.text.trim(),
        status: _status,
        createdAt: _selectedDate,
      );
      await repo.saveDecision(user.uid, created);
      await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      ref.read(paginatedDecisionsProvider.notifier).addItem(created);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.decision == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(decisionRepositoryProvider).deleteDecision(user.uid, widget.decision!.id);
    await ref.read(dayRepositoryProvider).invalidateDayCache(user.uid, widget.decision!.createdAt);
    ref.read(paginatedDecisionsProvider.notifier).removeItem((d) => d.id == widget.decision!.id);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitAi() async {
    final prompt = _aiPromptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final aiManager = ref.read(aiRequestManagerProvider);
      final repo = ref.read(decisionRepositoryProvider);
      final dayRepo = ref.read(dayRepositoryProvider);

      final promptText = DecisionAgentPromptBuilder.buildPrompt(
        today: DateTime.now(),
        promptText: prompt,
      );

      final response = await aiManager.generate(
        AiRequest(
          prompt: promptText,
          requestId: 'decision_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting decision...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> decisionsList = data['decisions'] ?? [];

      if (decisionsList.isEmpty) {
        throw Exception('AI could not extract any decisions. Try to be more specific.');
      }

      final List<DecisionModel> createdDecisions = [];
      for (final decData in decisionsList) {
        final text = decData['decision'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final reason = decData['reason'] as String? ?? '';
        final status = decData['status'] as String? ?? 'Active';
        final dateStr = decData['date'] as String?;
        final parsedDate = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

        final decision = DecisionModel(
          id: const Uuid().v4(),
          decision: text,
          reason: reason,
          status: status,
          createdAt: parsedDate,
        );

        await repo.saveDecision(user.uid, decision);
        await dayRepo.invalidateDayCache(user.uid, parsedDate);
        createdDecisions.add(decision);
      }

      if (createdDecisions.isEmpty) {
        throw Exception('No valid decision extracted.');
      }

      final notifier = ref.read(paginatedDecisionsProvider.notifier);
      for (final dec in createdDecisions) {
        notifier.addItem(dec);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully extracted ${createdDecisions.length} decision(s)')),
        );
      }
    } catch (e) {
      setState(() {
        _aiError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.decision != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEditing ? 'Edit Decision' : 'Add Decision',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual'),
                  Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'AI Assistant'),
                ],
              ),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Manual Form View
                  _buildManualForm(),
                  // AI Form View
                  if (!isEditing) _buildAiForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    final isEditing = widget.decision != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _decisionCtrl,
          decoration: const InputDecoration(
            labelText: 'Decision *',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason / Context',
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
        const SizedBox(height: 24),
        Row(
          children: [
            if (isEditing) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _saveManual,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Describe the decision you made in plain text, and Orbit AI will extract it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiPromptCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g., I decided to quit drinking coffee because it makes me anxious and will start tomorrow.',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        if (_aiError != null) ...[
          Text(
            _aiError!,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isAiLoading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: _submitAi,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Extract with AI'),
                ),
        ),
      ],
    );
  }
}
