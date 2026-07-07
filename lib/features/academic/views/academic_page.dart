import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/image_picker_dialog.dart';
import '../models/academic_schedule.dart';
import '../providers/academic_provider.dart';
import '../widgets/class_card.dart';
import '../services/home_widget_pin_service.dart';

/// The main page representing the AI-powered Academic Timetable Planner.
class AcademicPage extends ConsumerStatefulWidget {
  const AcademicPage({super.key});

  @override
  ConsumerState<AcademicPage> createState() => _AcademicPageState();
}

class _AcademicPageState extends ConsumerState<AcademicPage> {
  late PageController _pageController;
  late int _currentPageIndex;

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const int _basePage = 5000 * 7;

  @override
  void initState() {
    super.initState();
    // Monday is index 0, Sunday is index 6. DateTime.now().weekday has Monday=1, Sunday=7.
    final todayWeekday = DateTime.now().weekday;
    final initialDayIndex = todayWeekday - 1;
    _currentPageIndex = initialDayIndex;
    _pageController = PageController(initialPage: _basePage + initialDayIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadPressed() async {
    final hasTimetable = ref.read(academicLoadedProvider);
    if (hasTimetable) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Timetable?'),
          content: const Text(
            'Uploading a new timetable will replace your existing schedule. '
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _triggerImagePicker();
  }

  Future<void> _triggerImagePicker() async {
    final images = await ImagePickerDialog.show(context, allowMultiple: true);
    if (images != null && images.isNotEmpty) {
      if (mounted) {
        await ref
            .read(academicStateProvider.notifier)
            .uploadAndParseTimetable(images);
      }
    }
  }

  List<ClassSession> _getSessionsForDay(WeekSchedule schedule, String day) {
    switch (day) {
      case 'Monday':
        return schedule.monday;
      case 'Tuesday':
        return schedule.tuesday;
      case 'Wednesday':
        return schedule.wednesday;
      case 'Thursday':
        return schedule.thursday;
      case 'Friday':
        return schedule.friday;
      case 'Saturday':
        return schedule.saturday;
      case 'Sunday':
        return schedule.sunday;
      default:
        return [];
    }
  }

  void _navigateToAddCourse() {
    context.push(AppRoutes.academicEditCourse);
  }

  void _showSampleImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sample Timetable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload a clear screenshot of your university schedule containing course codes, times, days, and slot names.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/timetable_sample.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePinWidget() async {
    final isSupported = await HomeWidgetPinService.isWidgetPinningSupported();
    if (!mounted) return;
    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Home screen widget pinning is not supported by your launcher.',
          ),
        ),
      );
      return;
    }
    await HomeWidgetPinService.requestWidgetPin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final academicState = ref.watch(academicStateProvider);
    final schedule = academicState.schedule;
    final isLoading = academicState.isLoading;
    final isUploading = academicState.isUploading;
    final isParsing = academicState.isParsing;
    final errorMessage = academicState.errorMessage;

    final hasTimetable = schedule != null;
    final weekSchedule = schedule?.schedule ?? const WeekSchedule();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Timetable'),
        actions: [
          if (hasTimetable && schedule.courses.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.folder_special_rounded),
              tooltip: 'Course Directory',
              onPressed: () {
                context.push(AppRoutes.academicCourses);
              },
            ),
          ],
          if (hasTimetable) ...[
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Delete Timetable',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Timetable?'),
                    content: const Text(
                      'This will delete your timetable and all custom edits. '
                      'This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(academicStateProvider.notifier).clearSchedule();
                }
              },
            ),
          ],
          IconButton(
            icon: Icon(
              hasTimetable ? Icons.refresh_rounded : Icons.upload_file_rounded,
            ),
            tooltip: hasTimetable ? 'Upload Again' : 'Upload Timetable',
            onPressed: _handleUploadPressed,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: () {
          // 1. Loading States (Upload or Parse in progress)
          if (isUploading) {
            return _buildProgressOverlay(
              'Reading upload images...',
              colorScheme,
            );
          }
          if (isParsing) {
            return _buildProgressOverlay(
              'AI is reading and structuring your timetable. Please wait...',
              colorScheme,
            );
          }

          // 2. Error State
          if (errorMessage != null) {
            return _buildErrorView(errorMessage, colorScheme);
          }

          // 3. Fallback loading indicator (initial loading)
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 4. Default View (Manually edited or AI parsed)
          return Column(
            children: [
              // Pin Widget Button for loaded timetable
              if (hasTimetable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: FilledButton.icon(
                    onPressed: _handlePinWidget,
                    icon: const Icon(Icons.widgets_outlined),
                    label: const Text('Pin Timetable Widget'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              // Reminder Settings Button for loaded timetable
              if (hasTimetable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.academicReminderSettings),
                    icon: const Icon(Icons.alarm_rounded),
                    label: const Text('Reminder Settings'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              // Prompt to upload timetable via AI at the top if not uploaded yet
              if (!hasTimetable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.primaryContainer.withAlpha(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.primary.withAlpha(60),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Timetable Parser',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Upload your timetable image to extract all classes automatically using AI.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showSampleImage(context),
                                  icon: const Icon(
                                    Icons.image_search_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('See Sample Image'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: _handleUploadPressed,
                            icon: const Icon(Icons.upload_file_rounded),
                            tooltip: 'Upload Timetable',
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.secondary,
                              foregroundColor: colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Horizontal Day Navigation Chips
              _buildDaySelector(colorScheme),

              // PageView swiper
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPageIndex = page % 7;
                    });
                  },
                  itemBuilder: (context, page) {
                    final index = page % 7;
                    final day = _weekdays[index];
                    final sessions = _getSessionsForDay(weekSchedule, day);

                    return _buildDaySchedule(day, sessions, colorScheme);
                  },
                ),
              ),
            ],
          );
        }(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCourse,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ── Helper UI Builders ──────────────────────────────────────────────────────

  Widget _buildProgressOverlay(String message, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Parsing Failed',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              onPressed: _triggerImagePicker,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(ColorScheme colorScheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = _weekdays[index];
          final isSelected = index == _currentPageIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  final currentPage =
                      _pageController.page?.round() ??
                      (_basePage + _currentPageIndex);
                  final currentDayIndex = currentPage % 7;
                  final difference = index - currentDayIndex;

                  _pageController.animateToPage(
                    currentPage + difference,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                }
              },
              selectedColor: colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySchedule(
    String day,
    List<ClassSession> sessions,
    ColorScheme colorScheme,
  ) {
    final schedule = ref.watch(academicStateProvider).schedule;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Day Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total Classes: ${sessions.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Session list
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No Classes Today',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enjoy your free time or add a class manually below!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ClassCard(
                        session: session,
                        day: day,
                        onTap: () {
                          final course = schedule?.courses.firstWhere(
                            (c) =>
                                c.code.trim().toUpperCase() ==
                                session.code.trim().toUpperCase(),
                            orElse: () => Course(
                              code: session.code,
                              name: session.name,
                              faculty: session.faculty,
                              room: session.room,
                              slot: session.slot,
                            ),
                          );
                          context.push(
                            AppRoutes.academicEditCourse,
                            extra: {'course': course},
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
