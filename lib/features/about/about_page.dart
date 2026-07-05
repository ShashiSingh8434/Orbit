import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../guide/widgets/guide_section_card.dart';
import '../guide/widgets/feature_row.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Orbit'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── App Identity Banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        cs.primaryContainer.withAlpha(120),
                        cs.surfaceContainerHigh,
                      ]
                    : [
                        cs.primary.withAlpha(20),
                        cs.primaryContainer.withAlpha(30),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                        'assets/orbit_logo.png',
                    width:75,
                    height: 75,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: cs.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version ${AppConstants.appVersion}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your personal AI companion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Welcome / Vision ──────────────────────────────────────────────
          GuideSectionCard(
            title: "Developer's Note",
            icon: Icons.tips_and_updates_outlined,
            iconColor: Colors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orbit is inspired by traditional diary entries but powered by a modern AI twist. Treat Orbit as your personal AI buddy. Think of it as sharing gossips, daily struggles, feelings, and ambitions with a close friend.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Pro Tip:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instead of writing one massive journal entry at the end of the day, log short reflections multiple times throughout the day as things happen. This keeps your dashboard dynamically updated and yields the most accurate parsed insights!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Core Features ─────────────────────────────────────────────────
          GuideSectionCard(
            title: 'Core Features',
            icon: Icons.featured_play_list_outlined,
            iconColor: Colors.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeatureRow(
                  icon: Icons.keyboard_voice_rounded,
                  title: 'Speech-to-Text (STT) Input',
                  description:
                      'Speak in natural English. Tap the microphone icon, say your reflections or tasks, and the app transcribes and parses it using advanced audio models.',
                ),
                const SizedBox(height: 12),
                const FeatureRow(
                  icon: Icons.key_rounded,
                  title: 'Custom User API Keys',
                  description:
                      'Add your own Gemini or Groq API keys in settings. If keys are present, Orbit prioritizes using your keys directly, eliminating rate limits and billing constraints.',
                ),
                const SizedBox(height: 12),
                const FeatureRow(
                  icon: Icons.cloud_off_rounded,
                  title: 'Offline-First Architecture',
                  description:
                      'All your diary logs, tasks, and data are saved to a local SQLite database immediately. If offline, AI parsing requests are queued and processed automatically when your internet connection resumes.',
                ),
                const SizedBox(height: 12),
                const FeatureRow(
                  icon: Icons.home_rounded,
                  title: 'Home Screen Widget',
                  description:
                      'Pin your academic timetable directly to your Android home screen for at-a-glance class schedules without opening the app.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Privacy & Security ────────────────────────────────────────────
          GuideSectionCard(
            title: 'Privacy & Security',
            icon: Icons.security_rounded,
            iconColor: Colors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeatureRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Local API Key Storage',
                  description:
                      'Your API keys are never sent to Orbit servers. They are stored safely and locally inside your device\'s secure keystore.',
                ),
                const SizedBox(height: 12),
                const FeatureRow(
                  icon: Icons.enhanced_encryption_rounded,
                  title: 'Zero-Knowledge Encryption',
                  description:
                      'All cloud database syncs are fully encrypted end-to-end on your device using AES-256-GCM. Orbit can never read your notes, tasks, or entries in plaintext.',
                ),
                const SizedBox(height: 12),
                const FeatureRow(
                  icon: Icons.delete_forever_rounded,
                  title: 'Right to Be Forgotten',
                  description:
                      'You can delete your account and instantly wipe all sync data from the cloud at any time. Simply use the delete account option in Settings.',
                ),
                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant, height: 1),
                const SizedBox(height: 12),
                Text(
                  'Orbit is fully open source. You can audit the security implementations directly on our GitHub repository. If you encounter any bugs or want to suggest features, feel free to open an issue—we resolve them as quickly as possible!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Developer Credits ─────────────────────────────────────────────
          GuideSectionCard(
            title: 'About the Developer',
            icon: Icons.person_outline_rounded,
            iconColor: cs.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orbit is developed by Shashi Singh.\n\nConnect, check out the portfolio, or audit/contribute to the open-source repository.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                _LinkRow(
                  icon: Icons.language_rounded,
                  label: 'Portfolio',
                  url: 'https://shashisingh8434.vercel.app/',
                  onTap: _launchUrl,
                ),
                const SizedBox(height: 10),
                _LinkRow(
                  icon: Icons.camera_alt_outlined,
                  label: 'Instagram',
                  url: 'https://www.instagram.com/shashisingh_8434/',
                  onTap: _launchUrl,
                ),
                const SizedBox(height: 10),
                _LinkRow(
                  icon: Icons.code_rounded,
                  label: 'Orbit GitHub Repository',
                  url: 'https://github.com/ShashiSingh8434/Orbit',
                  onTap: _launchUrl,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Footer ────────────────────────────────────────────────────────
          Center(
            child: Text(
              'Made with ❤️ · Open Source · ${AppConstants.appVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withAlpha(120),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Future<void> Function(String) onTap;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => onTap(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
