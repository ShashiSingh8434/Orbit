import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../models/academic_schedule.dart';
import '../providers/academic_alarm_provider.dart';

/// Card widget to display a single [ClassSession] with action buttons.
class ClassCard extends ConsumerWidget {
  /// The class session to render.
  final ClassSession session;

  /// The weekday of the session.
  final String day;

  /// Triggered when the card is tapped.
  final VoidCallback onTap;

  const ClassCard({
    super.key,
    required this.session,
    required this.day,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final activeAlarmKeys = ref.watch(academicAlarmProvider);
    final sessionKey = '${day}_${session.startTime}_${session.code}';
    final isAlarmSet = activeAlarmKeys.contains(sessionKey);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
      ),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timing & Edit/Delete Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${format24to12Hr(session.startTime)} - ${format24to12Hr(session.endTime)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isAlarmSet
                          ? Icons.alarm_on_rounded
                          : Icons.alarm_add_rounded,
                      color: isAlarmSet
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withAlpha(180),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: isAlarmSet ? 'Remove Reminder' : 'Add Reminder',
                    onPressed: () async {
                      final isConfigured = ref
                          .read(academicReminderSettingsProvider)
                          .isConfigured;
                      if (!isConfigured) {
                        context.push(AppRoutes.academicReminderSettings);
                      } else {
                        await ref
                            .read(academicAlarmProvider.notifier)
                            .toggleReminder(day, session, context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Course Name
              Text(
                session.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Course Code
              Text(
                session.code,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const Divider(height: 24, thickness: 0.5),

              // Instructor & Location Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatFacultyName(session.faculty),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        session.room.isNotEmpty
                            ? session.room
                            : 'Not specified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),

              if (session.slot.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Slot: ${session.slot}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatFacultyName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Not specified';
    return trimmed
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          if (word.length <= 2 && word.endsWith('.')) {
            return word.toUpperCase();
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static String format24to12Hr(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final upper = timeStr.toUpperCase();
      if (upper.contains('AM') || upper.contains('PM')) {
        return timeStr;
      }
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        final displayMin = minute.toString().padLeft(2, '0');
        return '$displayHour:$displayMin $period';
      }
    } catch (_) {}
    return timeStr;
  }
}
