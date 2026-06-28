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
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/decision_agent_prompt.dart';
import '../data/decision_repository.dart';
import '../models/decision_model.dart';
import '../views/decision_list_page.dart';

class DecisionEditPage extends ConsumerStatefulWidget {
  final DecisionModel? decision;

  const DecisionEditPage({super.key, this.decision});

  /// Push this page onto the navigator stack.
  static Future<void> push(BuildContext context, {DecisionModel? decision}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DecisionEditPage(decision: decision),
        fullscreenDialog: decision == null,
      ),
    );
  }

  @override
  ConsumerState<DecisionEditPage> createState() => _DecisionEditPageState();
}

class _DecisionEditPageState extends ConsumerState<DecisionEditPage>
    with SingleTickerProviderStateMixin {
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

  bool get _isEditing => widget.decision != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 1 : 2, vsync: this);

    _decisionCtrl = TextEditingController(
      text: widget.decision?.decision ?? '',
    );
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

    if (_isEditing) {
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
      ref
          .read(paginatedDecisionsProvider.notifier)
          .updateItem((d) => d.id == updated.id ? updated : d);
    } else {
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Decision'),
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
        .read(decisionRepositoryProvider)
        .deleteDecision(user.uid, widget.decision!.id);
    await ref
        .read(dayRepositoryProvider)
        .invalidateDayCache(user.uid, widget.decision!.createdAt);
    ref
        .read(paginatedDecisionsProvider.notifier)
        .removeItem((d) => d.id == widget.decision!.id);

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
          requestId:
              'decision_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting decision...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> decisionsList = data['decisions'] ?? [];

      if (decisionsList.isEmpty) {
        throw Exception(
          'AI could not extract any decisions. Try to be more specific.',
        );
      }

      final List<DecisionModel> createdDecisions = [];
      for (final decData in decisionsList) {
        final text = decData['decision'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final reason = decData['reason'] as String? ?? '';
        final status = decData['status'] as String? ?? 'Active';
        final dateStr = decData['date'] as String?;
        final parsedDate = dateStr != null
            ? DateTime.tryParse(dateStr) ?? DateTime.now()
            : DateTime.now();

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
          SnackBar(
            content: Text('Extracted ${createdDecisions.length} decision(s)'),
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
          _isEditing ? 'Edit Decision' : 'New Decision',
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
          _ManualForm(
            decisionCtrl: _decisionCtrl,
            reasonCtrl: _reasonCtrl,
            status: _status,
            selectedDate: _selectedDate,
            isEditing: _isEditing,
            onStatusChanged: (val) => setState(() => _status = val),
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onSave: _saveManual,
          ),
          if (!_isEditing)
            AiForm(
              promptCtrl: _aiPromptCtrl,
              isLoading: _isAiLoading,
              error: _aiError,
              hintText:
                  'e.g., I decided to quit drinking coffee because it makes me anxious and will start tomorrow.',
              onSubmit: _submitAi,
            ),
        ],
      ),
    );
  }
}

class _ManualForm extends StatelessWidget {
  final TextEditingController decisionCtrl;
  final TextEditingController reasonCtrl;
  final String status;
  final DateTime selectedDate;
  final bool isEditing;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onSave;

  const _ManualForm({
    required this.decisionCtrl,
    required this.reasonCtrl,
    required this.status,
    required this.selectedDate,
    required this.isEditing,
    required this.onStatusChanged,
    required this.onDateChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        TextField(
          controller: decisionCtrl,
          autofocus: !isEditing,
          maxLines: 3,
          decoration: fieldDecoration(
            'Decision *',
            hint: 'What did you decide?',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: fieldDecoration(
            'Reason / Context',
            hint: 'Why did you make this decision?',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: fieldDecoration('Status'),
          borderRadius: BorderRadius.circular(12),
          items: [
            'Active',
            'Completed',
            'Cancelled',
            'Superseded',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) {
            if (val != null) onStatusChanged(val);
          },
        ),
        const SizedBox(height: 16),
        DatePickerTile(
          selectedDate: selectedDate,
          onDateChanged: onDateChanged,
        ),
        const SizedBox(height: 28),
        saveButton(
          onSave: onSave,
          label: isEditing ? 'Save Changes' : 'Save Decision',
        ),
      ],
    );
  }
}
