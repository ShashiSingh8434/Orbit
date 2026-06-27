import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/reflection_controller.dart';
import '../models/reflection_model.dart';
import '../widgets/reflection_tag_chip.dart';

/// Full-screen editor for creating or editing a reflection.
///
/// Behaviour:
/// - On open: loads offline draft (if creating) or existing reflection (if editing).
/// - Auto-saves draft to SharedPreferences as the user types.
/// - Voice-to-text mic button appends transcribed speech to the text field.
/// - On save: writes to Firestore, clears draft, pops back.
class ReflectionEditPage extends ConsumerStatefulWidget {
  const ReflectionEditPage({
    super.key,
    this.dateKey,
    this.existingReflectionId,
  });

  /// Target date for the reflection. Defaults to today.
  final String? dateKey;

  /// If set, the page loads and edits this existing reflection.
  final String? existingReflectionId;

  @override
  ConsumerState<ReflectionEditPage> createState() => _ReflectionEditPageState();
}

class _ReflectionEditPageState extends ConsumerState<ReflectionEditPage> {
  late final TextEditingController _textCtrl;
  final List<String> _tags = [];
  final _tagInputCtrl = TextEditingController();
  bool _isSaving = false;

  // ── Voice-to-Text ──
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;

  late String _resolvedDate;
  ReflectionModel? _existingReflection;

  // Preset tags for quick selection
  static const _presetTags = [
    'grateful', 'learning', 'focus', 'energy', 'mood',
    'decision', 'challenge', 'win', 'idea', 'social',
  ];

  @override
  void initState() {
    super.initState();
    _resolvedDate = widget.dateKey ?? OrbitDateUtils.todayKey();
    _textCtrl = TextEditingController();
    _initPage();
    _initStt();
  }

  Future<void> _initPage() async {
    if (widget.existingReflectionId != null) {
      // Editing an existing reflection — load it from the stream's cached value
      final reflections = ref.read(reflectionsProvider(_resolvedDate)).value ?? [];
      _existingReflection = reflections
          .where((r) => r.id == widget.existingReflectionId)
          .firstOrNull;
      if (_existingReflection != null) {
        _textCtrl.text = _existingReflection!.text;
        _tags.addAll(_existingReflection!.tags);
        setState(() {});
      }
    } else {
      // New reflection — restore offline draft if present
      final draft = ref.read(reflectionControllerProvider.notifier).loadDraft();
      if (draft != null) {
        _textCtrl.text = draft.text;
        _tags.addAll(draft.tags);
        setState(() {});
      }
    }
  }

  String _textBeforeListening = '';

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (errorNotification) {
        if (mounted && _isListening) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _tagInputCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  // ── Voice to Text ──────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _textBeforeListening = _textCtrl.text;
      });
      await _stt.listen(
        onResult: (result) {
          final current = _textBeforeListening;
          final appended = current.isEmpty
              ? result.recognizedWords
              : current.endsWith(' ') || current.endsWith('\n')
                  ? '$current${result.recognizedWords}'
                  : '$current ${result.recognizedWords}';
          
          _textCtrl.text = appended;
          _textCtrl.selection =
              TextSelection.collapsed(offset: _textCtrl.text.length);

          if (result.finalResult) {
            _textBeforeListening = _textCtrl.text;
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      );
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something first.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(reflectionControllerProvider.notifier);
      if (_existingReflection != null) {
        await controller.editReflection(
          original: _existingReflection!,
          newText: text,
          newTags: List.from(_tags),
          dateKey: _resolvedDate,
        );
      } else {
        DateTime baseDate = OrbitDateUtils.parseKey(_resolvedDate);
        DateTime finalDate;
        if (_resolvedDate == OrbitDateUtils.todayKey()) {
          finalDate = DateTime.now();
        } else {
          final now = DateTime.now();
          finalDate = DateTime(baseDate.year, baseDate.month, baseDate.day, now.hour, now.minute, now.second);
        }

        await controller.addReflection(
          text: text,
          tags: List.from(_tags),
          source: _isListening ? 'voice' : 'manual',
          date: finalDate,
        );
        await controller.clearDraft();
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Auto-save draft ───────────────────────────────────────────────────────

  void _onTextChanged(String value) {
    if (widget.existingReflectionId == null) {
      ref.read(reflectionControllerProvider.notifier).saveDraft(value, _tags);
    }
  }

  // ── Add Tag ───────────────────────────────────────────────────────────────

  void _addTag(String tag) {
    final normalised = tag.toLowerCase().trim();
    if (normalised.isEmpty || _tags.contains(normalised)) return;
    setState(() => _tags.add(normalised));
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingReflectionId != null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            final auth = ref.read(authStateProvider).value;
            final creationTime = auth?.metadata.creationTime ?? DateTime.now().subtract(const Duration(days: 30));
            final initialDate = OrbitDateUtils.parseKey(_resolvedDate);
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(creationTime.year, creationTime.month, creationTime.day),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (selectedDate != null && mounted) {
              setState(() {
                _resolvedDate = OrbitDateUtils.dateKey(selectedDate);
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? 'Edit Reflection' : 'New Reflection'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resolvedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_calendar_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Text Input ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _textCtrl,
                onChanged: _onTextChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: "What's on your mind? Write freely...",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: theme.textTheme.bodyLarge,
                autofocus: true,
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Tags ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected tags
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _tags
                        .map((t) => ReflectionTagChip(
                              label: t,
                              selected: true,
                              onDeleted: () => _removeTag(t),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 6),
                // Preset tag suggestions
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _presetTags
                        .where((t) => !_tags.contains(t))
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ReflectionTagChip(
                                label: t,
                                onTap: () => _addTag(t),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Toolbar ──────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Voice-to-text button
                  if (_sttAvailable)
                    IconButton(
                      onPressed: _toggleListening,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          key: ValueKey(_isListening),
                          color: _isListening
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      tooltip: _isListening ? 'Stop listening' : 'Voice input',
                    ),

                  // Custom tag input
                  Expanded(
                    child: TextField(
                      controller: _tagInputCtrl,
                      decoration: InputDecoration(
                        hintText: 'Add custom tag…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        prefixIcon: Icon(
                          Icons.label_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: theme.textTheme.bodyMedium,
                      onSubmitted: (v) {
                        _addTag(v);
                        _tagInputCtrl.clear();
                      },
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
