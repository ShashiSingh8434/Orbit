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
import '../../ai/prompts/event_agent_prompt.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';
import '../views/event_list_page.dart';

class EventEditPage extends ConsumerStatefulWidget {
  final dynamic event; // EventModel

  const EventEditPage({super.key, this.event});

  static Future<void> push(BuildContext context, {dynamic event}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditPage(event: event),
        fullscreenDialog: event == null,
      ),
    );
  }

  @override
  ConsumerState<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends ConsumerState<EventEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _locationCtrl;
  late DateTime _selectedDate;

  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 1 : 2, vsync: this);

    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _descCtrl = TextEditingController(text: widget.event?.description ?? '');
    _timeCtrl = TextEditingController(text: widget.event?.time ?? '');
    _locationCtrl = TextEditingController(text: widget.event?.location ?? '');
    _selectedDate = widget.event?.eventDate ?? DateTime.now();

    _aiPromptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManual() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final repo = ref.read(eventRepositoryProvider);
    final dayRepo = ref.read(dayRepositoryProvider);

    if (_isEditing) {
      final updated = widget.event!.copyWith(
        title: title,
        description: _descCtrl.text.trim(),
        time: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        eventDate: _selectedDate,
        updatedAt: DateTime.now(),
      );
      await repo.updateEvent(user.uid, updated);
      await dayRepo.invalidateDayCache(user.uid, widget.event!.eventDate);
      if (_selectedDate != widget.event!.eventDate) {
        await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      }
      ref
          .read(paginatedEventsProvider.notifier)
          .updateItem((e) => e.id == updated.id ? updated : e);
    } else {
      final created = EventModel(
        id: const Uuid().v4(),
        title: title,
        description: _descCtrl.text.trim(),
        time: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        eventDate: _selectedDate,
        createdAt: DateTime.now(),
      );
      await repo.saveEvent(user.uid, created);
      await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      ref.read(paginatedEventsProvider.notifier).addItem(created);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.event == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
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
        .read(eventRepositoryProvider)
        .deleteEvent(user.uid, widget.event!.id);
    await ref
        .read(dayRepositoryProvider)
        .invalidateDayCache(user.uid, widget.event!.eventDate);
    ref
        .read(paginatedEventsProvider.notifier)
        .removeItem((e) => e.id == widget.event!.id);

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
      final repo = ref.read(eventRepositoryProvider);
      final dayRepo = ref.read(dayRepositoryProvider);

      final promptText = EventAgentPromptBuilder.buildPrompt(
        today: DateTime.now(),
        promptText: prompt,
      );

      final response = await aiManager.generate(
        AiRequest(
          prompt: promptText,
          requestId:
              'event_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting event...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> eventsList = data['events'] ?? [];

      if (eventsList.isEmpty) {
        throw Exception(
          'AI could not extract any events. Try to be more specific.',
        );
      }

      final List<EventModel> createdEvents = [];
      for (final eventData in eventsList) {
        final text = eventData['title'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final description = eventData['description'] as String? ?? '';
        final dateStr = eventData['eventDate'] as String?;
        final parsedDate = dateStr != null
            ? DateTime.tryParse(dateStr) ?? DateTime.now()
            : DateTime.now();
        final time = eventData['time'] as String?;
        final location = eventData['location'] as String?;

        final event = EventModel(
          id: const Uuid().v4(),
          title: text,
          description: description,
          eventDate: parsedDate,
          time: time != null && time.trim().isNotEmpty ? time.trim() : null,
          location: location != null && location.trim().isNotEmpty
              ? location.trim()
              : null,
          createdAt: DateTime.now(),
        );

        await repo.saveEvent(user.uid, event);
        await dayRepo.invalidateDayCache(user.uid, parsedDate);
        createdEvents.add(event);
      }

      if (createdEvents.isEmpty) throw Exception('No valid event extracted.');

      final notifier = ref.read(paginatedEventsProvider.notifier);
      for (final ev in createdEvents) {
        notifier.addItem(ev);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted ${createdEvents.length} event(s)'),
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
          _isEditing ? 'Edit Event' : 'New Event',
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
          _EventManualForm(
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            timeCtrl: _timeCtrl,
            locationCtrl: _locationCtrl,
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
                  'e.g., Schedule a Team Meeting tomorrow at 3:00 PM in Conference Room B.',
              onSubmit: _submitAi,
              infoText:
                  'Describe your event in plain language — Orbit AI will extract and schedule it for you.',
            ),
        ],
      ),
    );
  }
}

class _EventManualForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController timeCtrl;
  final TextEditingController locationCtrl;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onSave;

  const _EventManualForm({
    required this.titleCtrl,
    required this.descCtrl,
    required this.timeCtrl,
    required this.locationCtrl,
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
          decoration: fieldDecoration('Event Title *'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descCtrl,
          maxLines: 3,
          decoration: fieldDecoration('Description'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: timeCtrl,
          decoration: fieldDecoration('Time', hint: 'e.g. 2:00 PM'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationCtrl,
          decoration: fieldDecoration('Location'),
        ),
        const SizedBox(height: 16),
        DatePickerTile(
          selectedDate: selectedDate,
          onDateChanged: onDateChanged,
        ),
        const SizedBox(height: 28),
        saveButton(onSave: onSave, label: 'Save Event'),
      ],
    );
  }
}
