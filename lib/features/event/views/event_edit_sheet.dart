import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../../ai/engine/ai_request_manager.dart';
import '../../ai/providers/ai_request.dart';
import '../../ai/prompts/event_agent_prompt.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';
import '../views/event_list_page.dart';
import '../../../core/utils/date_utils.dart';

class EventEditSheet extends ConsumerStatefulWidget {
  final EventModel? event;

  const EventEditSheet({super.key, this.event});

  @override
  ConsumerState<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends ConsumerState<EventEditSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual form controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _locationCtrl;
  late DateTime _selectedDate;

  // AI assistant controllers
  late TextEditingController _aiPromptCtrl;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.event == null ? 2 : 1, vsync: this);

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

    if (widget.event != null) {
      // Edit mode
      final updated = widget.event!.copyWith(
        title: title,
        description: _descCtrl.text.trim(),
        time: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        eventDate: _selectedDate,
        updatedAt: DateTime.now(),
      );
      await repo.updateEvent(user.uid, updated);
      await dayRepo.invalidateDayCache(user.uid, widget.event!.eventDate);
      if (_selectedDate != widget.event!.eventDate) {
        await dayRepo.invalidateDayCache(user.uid, _selectedDate);
      }
      ref.read(paginatedEventsProvider.notifier).updateItem((e) => e.id == updated.id ? updated : e);
    } else {
      // Create mode
      final created = EventModel(
        id: const Uuid().v4(),
        title: title,
        description: _descCtrl.text.trim(),
        time: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
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
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(eventRepositoryProvider).deleteEvent(user.uid, widget.event!.id);
    await ref.read(dayRepositoryProvider).invalidateDayCache(user.uid, widget.event!.eventDate);
    ref.read(paginatedEventsProvider.notifier).removeItem((e) => e.id == widget.event!.id);

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
          requestId: 'event_extraction_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Extracting event...',
          jsonMode: true,
        ),
      );

      final Map<String, dynamic> data = json.decode(response.text);
      final List<dynamic> eventsList = data['events'] ?? [];

      if (eventsList.isEmpty) {
        throw Exception('AI could not extract any events. Try to be more specific.');
      }

      final List<EventModel> createdEvents = [];
      for (final eventData in eventsList) {
        final text = eventData['title'] as String? ?? '';
        if (text.trim().isEmpty) continue;

        final description = eventData['description'] as String? ?? '';
        final dateStr = eventData['eventDate'] as String?;
        final parsedDate = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
        final time = eventData['time'] as String?;
        final location = eventData['location'] as String?;

        final event = EventModel(
          id: const Uuid().v4(),
          title: text,
          description: description,
          eventDate: parsedDate,
          time: time != null && time.trim().isNotEmpty ? time.trim() : null,
          location: location != null && location.trim().isNotEmpty ? location.trim() : null,
          createdAt: DateTime.now(),
        );

        await repo.saveEvent(user.uid, event);
        await dayRepo.invalidateDayCache(user.uid, parsedDate);
        createdEvents.add(event);
      }

      if (createdEvents.isEmpty) {
        throw Exception('No valid event extracted.');
      }

      final notifier = ref.read(paginatedEventsProvider.notifier);
      for (final ev in createdEvents) {
        notifier.addItem(ev);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully extracted ${createdEvents.length} event(s)')),
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
    final isEditing = widget.event != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
              isEditing ? 'Edit Event' : 'Add Event',
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
    final isEditing = widget.event != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Event Title *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _timeCtrl,
          decoration: const InputDecoration(
            labelText: 'Time (e.g. 2:00 PM)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text('Event Date'),
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
          'Describe the event or meeting details in plain text, and Orbit AI will extract it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiPromptCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g., Schedule a Team Meeting tomorrow at 3:00 PM in Conference Room B.',
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
