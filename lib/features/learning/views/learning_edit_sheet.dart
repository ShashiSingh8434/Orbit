import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/learning_agent_prompt.dart';
import '../data/learning_repository.dart';
import '../models/learning_model.dart';
import '../views/learning_list_page.dart';
import '../../../core/utils/date_utils.dart';

class LearningEditSheet extends ConsumerStatefulWidget {
  final LearningModel? learning;

  const LearningEditSheet({super.key, this.learning});

  @override
  ConsumerState<LearningEditSheet> createState() => _LearningEditSheetState();
}

class _LearningEditSheetState extends ConsumerState<LearningEditSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual form controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _categoryCtrl;
  late DateTime _selectedDate;

  // AI assistant controllers
  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.learning == null ? 2 : 1, vsync: this);

    _titleCtrl = TextEditingController(text: widget.learning?.title ?? '');
    _descCtrl = TextEditingController(text: widget.learning?.description ?? '');
    _categoryCtrl = TextEditingController(text: widget.learning?.category ?? 'General');
    _selectedDate = widget.learning?.createdAt ?? DateTime.now();

    _aiPromptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManual() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final repo = ref.read(learningRepositoryProvider);
    final dayRepo = ref.read(dayRepositoryProvider);

    if (widget.learning != null) {
      // Edit mode
      final updated = widget.learning!.copyWith(
        title: title,
        description: _descCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        createdAt: _selectedDate,
        updatedAt: DateTime.now(),
      );
      await repo.updateLearning(user.uid, updated);
      await dayRepo.invalidateDayCache(user.uid, widget.learning!.createdAt);
      if (_selectedDate != widget.learning!.createdAt) {
        await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      }
      ref.read(paginatedLearningsProvider.notifier).updateItem((l) => l.id == updated.id ? updated : l);
    } else {
      // Create mode
      final created = LearningModel(
        id: const Uuid().v4(),
        title: title,
        description: _descCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        createdAt: _selectedDate,
      );
      await repo.saveLearning(user.uid, created);
      await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      ref.read(paginatedLearningsProvider.notifier).addItem(created);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.learning == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(learningRepositoryProvider).deleteLearning(user.uid, widget.learning!.id);
    await ref.read(dayRepositoryProvider).invalidateDayCache(user.uid, widget.learning!.createdAt);
    ref.read(paginatedLearningsProvider.notifier).removeItem((l) => l.id == widget.learning!.id);

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
      final repo = ref.read(learningRepositoryProvider);
      final dayRepo = ref.read(dayRepositoryProvider);

      final promptText = LearningAgentPromptBuilder.buildPrompt(
        today: DateTime.now(),
        promptText: prompt,
      );

      final response = await aiManager.generate(
        AiRequest(
          prompt: promptText,
          requestId: 'learning_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting learning...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> learningsList = data['learnings'] ?? [];

      if (learningsList.isEmpty) {
        throw Exception('AI could not extract any learnings. Try to be more specific.');
      }

      final List<LearningModel> createdLearnings = [];
      for (final learnData in learningsList) {
        final text = learnData['title'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final description = learnData['description'] as String? ?? '';
        final category = learnData['category'] as String? ?? 'General';
        final dateStr = learnData['date'] as String?;
        final parsedDate = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

        final learning = LearningModel(
          id: const Uuid().v4(),
          title: text,
          description: description,
          category: category,
          createdAt: parsedDate,
        );

        await repo.saveLearning(user.uid, learning);
        await dayRepo.invalidateDayCache(user.uid, parsedDate);
        createdLearnings.add(learning);
      }

      if (createdLearnings.isEmpty) {
        throw Exception('No valid learning extracted.');
      }

      final notifier = ref.read(paginatedLearningsProvider.notifier);
      for (final learn in createdLearnings) {
        notifier.addItem(learn);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully extracted ${createdLearnings.length} learning(s)')),
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
    final isEditing = widget.learning != null;
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
              isEditing ? 'Edit Learning' : 'Add Learning',
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
    final isEditing = widget.learning != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Learning *',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description / Details',
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
          'Describe the insight or lesson you learned in plain text, and Orbit AI will extract it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiPromptCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g., Today I realized that debugging is easier if I write clear logs. Category is Tech.',
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
