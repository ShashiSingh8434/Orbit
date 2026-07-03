import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/widgets/ai_form.dart';
import '../../../shared/widgets/date_picker_tile.dart';
import '../../../shared/widgets/form_text_field.dart';
import '../../../shared/widgets/styled_tab_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../../../core/ai/engine/ai_request_manager.dart';
import '../../../core/ai/providers/ai_request.dart';
import '../../../core/ai/prompts/learning_agent_prompt.dart';
import '../data/learning_repository.dart';
import '../models/learning_model.dart';
import '../views/learning_list_page.dart';

class LearningEditPage extends ConsumerStatefulWidget {
  final dynamic learning; // LearningModel

  const LearningEditPage({super.key, this.learning});

  static Future<void> push(BuildContext context, {dynamic learning}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningEditPage(learning: learning),
        fullscreenDialog: learning == null,
      ),
    );
  }

  @override
  ConsumerState<LearningEditPage> createState() => _LearningEditPageState();
}

class _LearningEditPageState extends ConsumerState<LearningEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _categoryCtrl;
  late DateTime _selectedDate;

  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  bool get _isEditing => widget.learning != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 1 : 2, vsync: this);

    _titleCtrl = TextEditingController(text: widget.learning?.title ?? '');
    _descCtrl = TextEditingController(text: widget.learning?.description ?? '');
    _categoryCtrl = TextEditingController(
      text: widget.learning?.category ?? 'General',
    );
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

    if (_isEditing) {
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
      ref
          .read(paginatedLearningsProvider.notifier)
          .updateItem((l) => l.id == updated.id ? updated : l);
    } else {
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Learning'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref
        .read(learningRepositoryProvider)
        .deleteLearning(user.uid, widget.learning!.id);
    await ref
        .read(dayRepositoryProvider)
        .invalidateDayCache(user.uid, widget.learning!.createdAt);
    ref
        .read(paginatedLearningsProvider.notifier)
        .removeItem((l) => l.id == widget.learning!.id);

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
          requestId:
              'learning_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting learning...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> learningsList = data['learnings'] ?? [];

      if (learningsList.isEmpty) {
        throw Exception(
          'AI could not extract any learnings. Try to be more specific.',
        );
      }

      final List<LearningModel> createdLearnings = [];
      for (final learnData in learningsList) {
        final text = learnData['title'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final description = learnData['description'] as String? ?? '';
        final category = learnData['category'] as String? ?? 'General';
        final dateStr = learnData['date'] as String?;
        final parsedDate = dateStr != null
            ? DateTime.tryParse(dateStr) ?? DateTime.now()
            : DateTime.now();

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
          SnackBar(
            content: Text('Extracted ${createdLearnings.length} learning(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _aiError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Learning' : 'New Learning',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
        ],
        bottom: _isEditing
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: StyledTabBar(controller: _tabController),
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _LearningManualForm(
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            categoryCtrl: _categoryCtrl,
            selectedDate: _selectedDate,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onSave: _saveManual,
          ),
          if (!_isEditing)
            AiForm(
              promptCtrl: _aiPromptCtrl,
              isLoading: _isAiLoading,
              error: _aiError,
              hintText:
                  'e.g., Today I realized that debugging is easier if I write clear logs. Category is Tech.',
              onSubmit: _submitAi,
              infoText:
                  'Describe your learning in plain language — Orbit AI will extract and structure it for you.',
            ),
        ],
      ),
    );
  }
}

class _LearningManualForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController categoryCtrl;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onSave;

  const _LearningManualForm({
    required this.titleCtrl,
    required this.descCtrl,
    required this.categoryCtrl,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        TextField(
          controller: titleCtrl,
          maxLines: 2,
          decoration: fieldDecoration(
            'Learning *',
            hint: 'What did you learn?',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descCtrl,
          maxLines: 3,
          decoration: fieldDecoration('Description / Details'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: categoryCtrl,
          decoration: fieldDecoration(
            'Category',
            hint: 'e.g. Tech, Life, Health',
          ),
        ),
        const SizedBox(height: 16),
        DatePickerTile(
          selectedDate: selectedDate,
          onDateChanged: onDateChanged,
        ),
        const SizedBox(height: 28),
        saveButton(onSave: onSave, label: 'Save Learning'),
      ],
    );
  }
}
