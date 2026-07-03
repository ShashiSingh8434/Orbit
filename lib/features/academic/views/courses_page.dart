import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../models/academic_schedule.dart';
import '../providers/academic_provider.dart';

/// Full page displaying detailed directory information for all unique [Course]s.
class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final academicState = ref.watch(academicStateProvider);
    final schedule = academicState.schedule;
    final courses = schedule?.courses ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Course',
            onPressed: () {
              context.push(AppRoutes.academicEditCourse);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: courses.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No unique courses found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(120),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.surfaceContainerLowest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                course.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                course.code,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          context,
                          Icons.person_outline_rounded,
                          'Faculty',
                          _formatFacultyName(course.faculty),
                        ),
                        _buildDetailRow(
                          context,
                          Icons.location_on_outlined,
                          'Location',
                          course.room,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.tag_rounded,
                          'Slot',
                          course.slot,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.badge_outlined,
                          'Class No.',
                          course.classNo,
                        ),
                        const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildBadge(
                                    context,
                                    Icons.stars_outlined,
                                    '${course.credits} Credits',
                                  ),
                                  if (course.type.isNotEmpty)
                                    _buildBadge(
                                      context,
                                      Icons.layers_outlined,
                                      course.type,
                                    ),
                                  if (course.category.isNotEmpty)
                                    _buildBadge(
                                      context,
                                      Icons.label_outline_rounded,
                                      course.category,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                context.push(
                                  AppRoutes.academicEditCourse,
                                  extra: {'course': course},
                                );
                              },
                              tooltip: 'Edit Course',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
