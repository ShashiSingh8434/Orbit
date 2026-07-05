import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../widgets/guide_section_card.dart';
import '../widgets/usage_accordion.dart';
import '../widgets/prompt_guide_card.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final PageController _promptPageController = PageController();
  int _currentPromptPage = 0;

  static const _promptCards = [
    (
      tag: 'TASKS',
      keywords: 'add task, I need to, finished, mark complete, reschedule to [date]',
      example:
          '"I need to complete the physics report by Friday. Also, mark the buy book task as completed."',
    ),
    (
      tag: 'EVENTS',
      keywords: 'schedule, event, went to, attending [event] on [date] at [time]',
      example: '"Schedule Chemistry Lab for Thursday at 2 PM in Room 302."',
    ),
    (
      tag: 'LEARNINGS',
      keywords: 'learned that, realized, discovered, lesson learned',
      example:
          '"I learned that coding in small chunks reduces syntax errors. Category: Tech."',
    ),
    (
      tag: 'DECISIONS',
      keywords: 'decided to, committing to, chose to, reason is',
      example:
          '"I decided to study at the library because it helps me avoid distractions."',
    ),
  ];

  @override
  void dispose() {
    _promptPageController.dispose();
    super.dispose();
  }

  void _showTimetableSample() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sample Timetable Screenshot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload a clear screenshot of your timetable. It should explicitly state class names, slot timings, days, and room locations.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── How to Use ────────────────────────────────────────────────────
          Text(
            'HOW TO USE THE APP',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),

          const UsageAccordion(
            title: 'Daily Reflection & All-in-One Parsing',
            icon: Icons.edit_note_rounded,
            details:
                'Write naturally in plain language about your day. Orbit\'s AI scans the entire text to extract all tasks, decisions, events, and learnings in one go. You don\'t have to structure it—just talk about what you did, what you need to do, what you decided, and what you learned.',
          ),
          const UsageAccordion(
            title: 'Tasks Module',
            icon: Icons.task_alt_rounded,
            details:
                'Track your to-do lists. You can add tasks manually or let Orbit extract them from your reflections. You can reschedule a task by saying "reschedule UI design task to tomorrow" or complete it by writing "I finished the UI design task". If no due date is provided, Orbit defaults the due date to today to keep you focused.',
          ),
          const UsageAccordion(
            title: 'Events Module',
            icon: Icons.calendar_month_rounded,
            details:
                'Log upcoming classes, meetings, gym sessions, or outings. Mention details like "Gym at 6 PM" or "Math Class on Monday at 10 AM". Orbit automatically structures these into a chronological calendar list. If you specify only a time (e.g. "meeting at 4pm"), it defaults the event date to today.',
          ),
          const UsageAccordion(
            title: 'Learnings Module',
            icon: Icons.lightbulb_outline_rounded,
            details:
                'Log real-time realizations, study lessons, or life observations. Describe what you learned (e.g., "I learned that recursion is easier with tree diagrams"). Orbit parses the content and classifies it into clean categories like Life, Tech, Career, Academic, Health, Relationships, or Finance.',
          ),
          const UsageAccordion(
            title: 'Decisions Module',
            icon: Icons.alt_route_rounded,
            details:
                'Document crucial choices or commitments you make, along with the reasoning (e.g., "I decided to wake up at 5am to get coding done early"). Recording these helps you look back and review your decision-making patterns over time.',
          ),

          const SizedBox(height: 16),

          // Academic with sample image
          GuideSectionCard(
            title: 'Academic Timetable Planner',
            icon: Icons.school_outlined,
            iconColor: cs.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload your semester course timetable screenshot. Orbit\'s multimodal AI reads the schedule, extracts course codes, slot timings, room numbers, and faculty details, and maps them to a beautiful daily timetable automatically. You can also pin this timetable as a widget to your home screen!',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showTimetableSample,
                  icon: const Icon(Icons.image_search_rounded),
                  label: const Text('See Sample Timetable Image'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Prompt Engineering Guide (horizontal swipeable cards) ─────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROMPT ENGINEERING',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Text(
                '${_currentPromptPage + 1} / ${_promptCards.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe the cards to explore keywords and examples for each module.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Swipeable card pager
          SizedBox(
            height: 290,
            child: PageView.builder(
              controller: _promptPageController,
              onPageChanged: (i) => setState(() => _currentPromptPage = i),
              itemCount: _promptCards.length,
              itemBuilder: (ctx, i) {
                final card = _promptCards[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: PromptGuideCard(
                    tag: card.tag,
                    keywords: card.keywords,
                    example: card.example,
                  ),
                );
              },
            ),
          ),

          // Dot indicators
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promptCards.length, (i) {
              final isActive = i == _currentPromptPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.primary
                      : cs.onSurfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // ── About Orbit Banner ────────────────────────────────────────────
          InkWell(
            onTap: () => context.push(AppRoutes.about),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(60),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Orbit',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Developer, features, privacy & open source',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
