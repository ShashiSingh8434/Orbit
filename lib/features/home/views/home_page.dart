import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/app_drawer.dart';
import '../../day/widgets/day_summary_section.dart';
import '../../tasks/widgets/task_section.dart';
import '../../learning/widgets/learning_section.dart';
import '../../decision/widgets/decision_section.dart';
import '../../event/widgets/event_section.dart';
import '../../mood/widgets/mood_section.dart';
import '../../day/providers/day_data_provider.dart';
import '../widgets/day_skeleton_loader.dart';
// Note: TaskSection, LearningSection, etc., will be added here in Phase 3.

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late PageController _pageController;
  late DateTime _initialDate;
  int _currentIndex = 0;

  // Assume 1000 pages, with 500 being "today".
  static const int _initialPage = 500;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _initialDate = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateForIndex(int index) {
    final offset = index - _initialPage;
    return _initialDate.add(Duration(days: offset));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final creationTime = user?.metadata.creationTime ?? DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName,style: Theme.of(context).textTheme.headlineLarge,),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _dateForIndex(_currentIndex),
                firstDate: DateTime(creationTime.year, creationTime.month, creationTime.day),
                lastDate: DateTime.now().add(const Duration(days: 365)),

              );
              if (selectedDate != null) {
                final targetIndex = _initialPage + selectedDate.difference(_initialDate).inDays;
                _pageController.animateToPage(
                  targetIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final date = _dateForIndex(index);
            final dayDataAsync = ref.watch(dayDataProvider(date));
            
            // Boundary logic
            if (date.isBefore(DateTime(creationTime.year, creationTime.month, creationTime.day))) {
              return const Center(child: Text("You weren't here yet! 😊"));
            }

            final isFuture = date.isAfter(DateTime.now());

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingSection(date: date, userDisplayName: user?.displayName),
                  const SizedBox(height: 16),
                  
                  _DelayedDataView(
                    asyncValue: dayDataAsync,
                    date: date,
                    isFuture: isFuture,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final dateKey = "${_dateForIndex(_currentIndex).year}-${_dateForIndex(_currentIndex).month.toString().padLeft(2, '0')}-${_dateForIndex(_currentIndex).day.toString().padLeft(2, '0')}";
          context.push('${AppRoutes.reflections}/edit', extra: {'dateKey': dateKey});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  final DateTime date;
  final String? userDisplayName;

  const _GreetingSection({required this.date, this.userDisplayName});

  static String? _extractFirstName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return null;
    return displayName.trim().split(' ').first;
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = _extractFirstName(userDisplayName);
    final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

    final dateLabel = isToday ? "Today" : _formatDate(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isToday 
            ? (firstName != null ? 'Hello, $firstName 👋' : 'Welcome 👋')
            : 'Your day on $dateLabel',
          style: theme.textTheme.headlineMedium,

        ),
        const SizedBox(height: 6),
        Text(
          'Reflect on your day, let AI organize the rest.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DelayedDataView extends StatefulWidget {
  final AsyncValue<DayData> asyncValue;
  final DateTime date;
  final bool isFuture;

  const _DelayedDataView({
    required this.asyncValue,
    required this.date,
    required this.isFuture,
  });

  @override
  State<_DelayedDataView> createState() => _DelayedDataViewState();
}

class _DelayedDataViewState extends State<_DelayedDataView> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    // If we already have data loaded, skip the artificial delay!
    if (widget.asyncValue.hasValue) {
      _minTimeElapsed = true;
    } else {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _minTimeElapsed = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.asyncValue.when(
      data: (data) {
        if (!_minTimeElapsed) {
          return DaySkeletonLoader(date: widget.date);
        }
        
        if (data.isEmpty) {
          final colorScheme = Theme.of(context).colorScheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 64,
                    color: colorScheme.primary.withAlpha(80),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "A blank canvas",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the + button to reflect on this day.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.day != null && data.day!.summary.isNotEmpty) ...[
              DaySummarySection(day: data.day, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
            if (data.tasks.isNotEmpty) ...[
              TaskSection(tasks: data.tasks, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
            if (data.learnings.isNotEmpty) ...[
              LearningSection(learnings: data.learnings, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
            if (data.decisions.isNotEmpty) ...[
              DecisionSection(decisions: data.decisions, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
            if (data.events.isNotEmpty) ...[
              EventSection(events: data.events, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
            if (data.moods.isNotEmpty) ...[
              MoodSection(moods: data.moods, isLoading: false, date: widget.date),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
      loading: () => DaySkeletonLoader(date: widget.date),
      error: (err, stack) => Center(child: Text('Error loading day data: $err')),
    );
  }
}
