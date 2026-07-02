import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_logger.dart';
import '../models/app_config.dart';
import '../providers/app_update_provider.dart';

class UpdateDialog extends ConsumerWidget {
  final AppConfig config;
  final String installedVersionName;
  final int installedVersionCode;

  const UpdateDialog({
    super.key,
    required this.config,
    required this.installedVersionName,
    required this.installedVersionCode,
  });

  Future<void> _launchUpdateUrl(BuildContext context) async {
    final url = Uri.parse(config.downloadUrl);
    AppLogger.info('Launching download URL: ${config.downloadUrl}');
    try {
      if (await canLaunchUrl(url)) {
        final success = await launchUrl(url, mode: LaunchMode.externalApplication);
        AppLogger.info('URL launch result: success=$success');
      } else {
        AppLogger.error('Could not launch URL: ${config.downloadUrl}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the update link.')),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error launching update URL', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final forceUpdate = config.forceUpdate;

    return PopScope(
      canPop: !forceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 6,
        backgroundColor: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & Title
              Row(
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    forceUpdate ? 'Required Update' : 'Update Available',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Version details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VersionBadge(
                    label: 'Current',
                    version: '^$installedVersionName+$installedVersionCode',
                    color: colorScheme.outline,
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  _VersionBadge(
                    label: 'Latest',
                    version: '^${config.latestVersionName}+${config.latestVersionCode}',
                    color: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Release Notes Header
              if (config.releaseNotes.isNotEmpty) ...[
                Text(
                  'What\'s New',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Release Notes Body
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      config.releaseNotes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!forceUpdate) ...[
                    TextButton(
                      onPressed: () {
                        AppLogger.info('User clicked "Later" button.');
                        ref.read(appUpdateProvider.notifier).dismissOptionalUpdate();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: () => _launchUpdateUrl(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color color;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            version.isNotEmpty ? 'v$version' : 'Unknown',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
