import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/academic_schedule.dart';
import '../providers/academic_provider.dart';

/// Full-page form to add a new Course or edit an existing one.
class EditCoursePage extends ConsumerStatefulWidget {
  /// The course to edit, or null if creating a new one.
  final Course? course;

  const EditCoursePage({super.key, this.course});

  @override
  ConsumerState<EditCoursePage> createState() => _EditCoursePageState();
}

class _EditCoursePageState extends ConsumerState<EditCoursePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _facultyController;
  late TextEditingController _roomController;
  late TextEditingController _slotController;
  late TextEditingController _creditsController;
  late TextEditingController _typeController;
  late TextEditingController _categoryController;
  late TextEditingController _classNoController;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _nameController = TextEditingController(text: c?.name ?? '');
    _codeController = TextEditingController(text: c?.code ?? '');
    _facultyController = TextEditingController(text: c?.faculty ?? '');
    _roomController = TextEditingController(text: c?.room ?? '');
    _slotController = TextEditingController(text: c?.slot ?? '');
    _creditsController = TextEditingController(
      text: c?.credits.toString() ?? '4',
    );
    _typeController = TextEditingController(text: c?.type ?? 'Lecture');
    _categoryController = TextEditingController(text: c?.category ?? '');
    _classNoController = TextEditingController(text: c?.classNo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _facultyController.dispose();
    _roomController.dispose();
    _slotController.dispose();
    _creditsController.dispose();
    _typeController.dispose();
    _categoryController.dispose();
    _classNoController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final updatedCourse = Course(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        faculty: _facultyController.text.trim(),
        room: _roomController.text.trim(),
        slot: _slotController.text.trim().toUpperCase(),
        credits: int.tryParse(_creditsController.text.trim()) ?? 0,
        type: _typeController.text.trim(),
        category: _categoryController.text.trim(),
        classNo: _classNoController.text.trim(),
      );

      final notifier = ref.read(academicStateProvider.notifier);

      if (widget.course != null) {
        notifier.editCourse(widget.course!.code, updatedCourse);
      } else {
        notifier.addCourse(updatedCourse);
      }

      context.pop();
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to delete "${widget.course!.name}"? '
          'This will remove all associated weekly class sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(academicStateProvider.notifier)
          .deleteCourse(widget.course!.code);
      if (mounted) {
        context.pop();
      }
    }
  }

  Widget _buildFieldLabel(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withAlpha(204),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEdit = widget.course != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Course Details' : 'Add Registered Course'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete Course',
              color: colorScheme.error,
              onPressed: _handleDelete,
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save Course',
            onPressed: _handleSave,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel('Course Name*', theme),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Database Management Systems',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter course name'
                      : null,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Course Code*', theme),
                          TextFormField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. CSE3001',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter course code'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Slot Code(s)*', theme),
                          TextFormField(
                            controller: _slotController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. A11+A12+A13',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter slot code(s)'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Venue / Room', theme),
                          TextFormField(
                            controller: _roomController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. LC-002',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Credits', theme),
                          TextFormField(
                            controller: _creditsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 4',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return null;
                              }
                              if (int.tryParse(val.trim()) == null) {
                                return 'Must be an integer';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildFieldLabel('Faculty Name', theme),
                TextFormField(
                  controller: _facultyController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rajneesh Kumar Patel',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Course Type', theme),
                          TextFormField(
                            controller: _typeController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Lecture or Lab',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Class Number', theme),
                          TextFormField(
                            controller: _classNoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. BL2026270100478',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildFieldLabel('Category', theme),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Programme Core',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _handleSave,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    isEdit ? 'Save Course Changes' : 'Create Course',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
