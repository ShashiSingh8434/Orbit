import 'dart:async';
import 'package:flutter/material.dart';
import '../../day/widgets/day_summary_section.dart';
import '../../tasks/widgets/task_section.dart';
import '../../learning/widgets/learning_section.dart';
import '../../decision/widgets/decision_section.dart';
import '../../event/widgets/event_section.dart';
import '../../mood/widgets/mood_section.dart';

class DaySkeletonLoader extends StatelessWidget {
  const DaySkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HorizontalTextLoader(),
        SizedBox(height: 24),
        DaySummarySection(day: null, isLoading: true),
        SizedBox(height: 16),
        TaskSection(tasks: null, isLoading: true),
        SizedBox(height: 16),
        LearningSection(learnings: null, isLoading: true),
        SizedBox(height: 16),
        DecisionSection(decisions: null, isLoading: true),
        SizedBox(height: 16),
        EventSection(events: null, isLoading: true),
        SizedBox(height: 16),
        MoodSection(moods: null, isLoading: true),
      ],
    );
  }
}

class HorizontalTextLoader extends StatefulWidget {
  const HorizontalTextLoader({super.key});

  @override
  State<HorizontalTextLoader> createState() => _HorizontalTextLoaderState();
}

class _HorizontalTextLoaderState extends State<HorizontalTextLoader> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Timer _timer;
  int _textIndex = 0;

  final List<String> _loadingTexts = [
    'Synthesizing reflection details...',
    'Syncing with your personal Orbit...',
    'Updating task statuses...',
    'Extracting decisions and commitments...',
    'Compiling learnings and insights...',
    'Structuring emotional timeline...',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _loadingTexts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium horizontal sliding loader
        Container(
          width: double.infinity,
          height: 3,
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(1.5),
          ),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressController.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withAlpha(50),
                        colorScheme.primary,
                        colorScheme.primary.withAlpha(50),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Fading loading text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Text(
            _loadingTexts[_textIndex],
            key: ValueKey<int>(_textIndex),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
