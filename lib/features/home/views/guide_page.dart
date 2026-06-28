import 'package:flutter/material.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Guide')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _Hero(cs: cs, theme: theme),

          const SizedBox(height: 40),

          // ── Section 1: Live reflection mock ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _EyebrowLabel(label: 'Writing a reflection', cs: cs),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Write naturally. Orbit reads your words and organises them automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          const _ReflectionMock(),

          const SizedBox(height: 48),

          // ── Section 2: Trigger phrases ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _EyebrowLabel(label: 'Trigger phrases', cs: cs),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'These phrases help Orbit extract the right type of entry.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          const _TriggerGrid(),

          const SizedBox(height: 48),

          // ── Section 3: Dashboard ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _EyebrowLabel(label: 'Your dashboard', cs: cs),
          ),
          const SizedBox(height: 16),
          const _DashboardFeatures(),

          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.cs, required this.theme});

  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 44),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.explore_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'Just reflect.\nOrbit does the rest.',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Write about your day in plain language — tasks, decisions, events, and lessons are extracted automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withAlpha(200),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eyebrow label ─────────────────────────────────────────────────────────────

class _EyebrowLabel extends StatelessWidget {
  const _EyebrowLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Live reflection mock ──────────────────────────────────────────────────────

class _ReflectionMock extends StatelessWidget {
  const _ReflectionMock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock "journal entry" header
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Your reflection',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Annotated sentences
          _AnnotatedSentence(
            text: 'I need to finish the project proposal by Thursday.',
            chipLabel: 'Task',
            chipColor: const Color(0xFF22C55E),
            cs: cs,
            theme: theme,
          ),
          const SizedBox(height: 14),
          _AnnotatedSentence(
            text: 'I had a great sync with the design team about the new flow.',
            chipLabel: 'Event',
            chipColor: const Color(0xFF3B82F6),
            cs: cs,
            theme: theme,
          ),
          const SizedBox(height: 14),
          _AnnotatedSentence(
            text: 'I decided to block 9–11 AM every morning for deep work.',
            chipLabel: 'Decision',
            chipColor: const Color(0xFFF59E0B),
            cs: cs,
            theme: theme,
          ),
          const SizedBox(height: 14),
          _AnnotatedSentence(
            text:
                'I learned that async/await in Dart is cleaner than I thought.',
            chipLabel: 'Learning',
            chipColor: const Color(0xFFF97316),
            cs: cs,
            theme: theme,
          ),

          const SizedBox(height: 20),
          Divider(color: cs.outlineVariant, height: 1),
          const SizedBox(height: 14),

          // Result hint
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Orbit creates 1 task, 1 decision, 1 event, and 1 learning from this.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnotatedSentence extends StatelessWidget {
  const _AnnotatedSentence({
    required this.text,
    required this.chipLabel,
    required this.chipColor,
    required this.cs,
    required this.theme,
  });

  final String text;
  final String chipLabel;
  final Color chipColor;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Chip label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            chipLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Trigger phrase grid ───────────────────────────────────────────────────────

class _TriggerGrid extends StatelessWidget {
  const _TriggerGrid();

  static const _triggers = [
    _TriggerData(
      icon: Icons.task_alt_rounded,
      color: Color(0xFF22C55E),
      category: 'Task',
      phrases: ['"I need to…"', '"Remind me to…"', '"Add a task to…"'],
    ),
    _TriggerData(
      icon: Icons.event_rounded,
      color: Color(0xFF3B82F6),
      category: 'Event',
      phrases: ['"I had a…"', '"Schedule an event…"', '"I attended…"'],
    ),
    _TriggerData(
      icon: Icons.gavel_rounded,
      color: Color(0xFFF59E0B),
      category: 'Decision',
      phrases: ['"I decided to…"', '"I chose to…"', '"I took a decision…"'],
    ),

    _TriggerData(
      icon: Icons.lightbulb_rounded,
      color: Color(0xFFF97316),
      category: 'Learning',
      phrases: ['"I learned…"', '"Today I realised…"', '"I discovered…"'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _triggers.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coloured icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.color.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(t.icon, color: t.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: t.phrases.map((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.color.withAlpha(22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: t.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TriggerData {
  final IconData icon;
  final Color color;
  final String category;
  final List<String> phrases;

  const _TriggerData({
    required this.icon,
    required this.color,
    required this.category,
    required this.phrases,
  });
}

// ── Dashboard features ────────────────────────────────────────────────────────

class _DashboardFeatures extends StatelessWidget {
  const _DashboardFeatures();

  static const _features = [
    _FeatureData(
      icon: Icons.auto_stories_rounded,
      title: 'AI Summary',
      body:
          'After saving, Orbit writes a concise narrative of your day — a readable overview, not just a list.',
    ),
    _FeatureData(
      icon: Icons.calendar_month_rounded,
      title: 'Time Travel',
      body:
          'Swipe left or right on the home page to move between days. Add reflections for future dates to plan ahead.',
    ),
    _FeatureData(
      icon: Icons.mic_rounded,
      title: 'Voice to text',
      body:
          'Tap the microphone in the reflection editor to speak your thoughts. Orbit transcribes instantly.',
    ),
    _FeatureData(
      icon: Icons.mood_rounded,
      title: 'Mood tracking',
      body:
          'Describe how you felt and Orbit logs your mood alongside your entries automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _features.map((f) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f.icon, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        f.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String body;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.body,
  });
}
