import 'package:flutter/material.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to use Orbit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Icon(
            Icons.explore_rounded,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to your Orbit',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Orbit is your personal AI-powered journal. Instead of manually creating tasks or logging events, you just reflect on your day, and our AI automatically organizes your life.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'How to write effective reflections',
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            text: 'Speak or type naturally about your day. The AI listens for specific cues to extract data into your dashboard. For best results, use clear trigger phrases:',
            children: [
              _BulletPoint(
                icon: Icons.task_alt_rounded,
                title: 'Tasks',
                description: 'Use phrases like "I need to..." or "Remind me to...". For example: "I need to buy groceries tomorrow at 5 PM." (Orbit will automatically set the due date!)',
              ),
              _BulletPoint(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Learnings',
                description: 'Use phrases like "I learned..." or "Today I realized...". For example: "I learned that Flutter Riverpod is great for state management."',
              ),
              _BulletPoint(
                icon: Icons.check_circle_outline_rounded,
                title: 'Decisions',
                description: 'Use phrases like "I decided to..." or "I chose to...". For example: "I decided to start waking up at 6 AM everyday."',
              ),
              _BulletPoint(
                icon: Icons.event_rounded,
                title: 'Events',
                description: 'Mention things that happened. For example: "I had a great meeting with the design team today about the new logo."',
              ),
              _BulletPoint(
                icon: Icons.mood_rounded,
                title: 'Mood',
                description: 'Describe how you felt. For example: "I felt really productive today" or "I was a bit stressed in the morning."',
              ),
            ],
          ),

          const SizedBox(height: 40),

          _SectionHeader(
            icon: Icons.dashboard_rounded,
            title: 'Your Dashboard Sections',
            color: colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            text: 'Once you save a reflection, Orbit builds your daily dashboard:',
            children: [
              _BulletPoint(
                icon: Icons.auto_stories_rounded,
                title: 'Summary',
                description: 'A beautifully written, AI-generated summary of your entire day based on your reflection.',
              ),
              _BulletPoint(
                icon: Icons.calendar_month_rounded,
                title: 'Time Travel',
                description: 'Swipe left or right on the home page to view past days or future days. You can even add reflections for the future to plan ahead!',
              ),
              _BulletPoint(
                icon: Icons.mic_rounded,
                title: 'Voice to Text',
                description: 'When reflecting, tap the microphone icon to simply speak your thoughts. Orbit will transcribe it instantly.',
              ),
            ],
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;
  final List<Widget> children;

  const _InfoCard({required this.text, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BulletPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
