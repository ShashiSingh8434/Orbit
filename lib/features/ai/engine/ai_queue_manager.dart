import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/date_utils.dart';
import '../../reflection/data/reflection_repository.dart';
import 'understanding_pipeline.dart';

final aiQueueManagerProvider = Provider<AiQueueManager>((ref) {
  return AiQueueManager(
    reflectionRepo: ref.watch(reflectionRepositoryProvider),
    understandingPipeline: ref.watch(understandingPipelineProvider),
  );
});

class AiQueueManager {
  final ReflectionRepository reflectionRepo;
  final UnderstandingPipeline understandingPipeline;

  bool _isProcessing = false;

  AiQueueManager({
    required this.reflectionRepo,
    required this.understandingPipeline,
  });

  /// Scans the last [daysToLookBack] days for reflections that have not been
  /// processed by the AI (e.g. due to rate limits or offline scenarios)
  /// and queues them for processing sequentially.
  Future<void> scanAndProcessUnextracted(
    String uid, {
    int daysToLookBack = 7,
  }) async {
    if (_isProcessing) {
      AppLogger.debug('AiQueueManager: Already processing queue. Skipping.');
      return;
    }

    _isProcessing = true;
    int processedCount = 0;

    try {
      AppLogger.info(
        'AiQueueManager: Scanning for unextracted reflections over the last $daysToLookBack days...',
      );

      final now = DateTime.now();

      for (int i = 0; i < daysToLookBack; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final dateKey = OrbitDateUtils.dateKey(targetDate);

        final reflections = await reflectionRepo.getReflections(uid, dateKey);

        // Find reflections that are not yet processed and not deleted
        final unprocessed = reflections
            .where((r) => !r.aiProcessed && !r.deleted)
            .toList();

        for (final reflection in unprocessed) {
          AppLogger.info(
            'AiQueueManager: Pushing reflection ${reflection.id} ($dateKey) to pipeline.',
          );

          try {
            await understandingPipeline.onReflectionSaved(uid, reflection);
            processedCount++;

            // Add a small delay between processing multiple reflections to prevent immediate rate limit hits again
            await Future.delayed(const Duration(seconds: 2));
          } catch (e, s) {
            AppLogger.error(
              'AiQueueManager: Failed to process reflection ${reflection.id}',
              e,
              s,
            );
            // We continue processing others even if one fails
          }
        }
      }

      if (processedCount > 0) {
        AppLogger.info(
          'AiQueueManager: Finished processing $processedCount queued reflections.',
        );
      } else {
        AppLogger.info('AiQueueManager: No unextracted reflections found.');
      }
    } catch (e, s) {
      AppLogger.error('AiQueueManager: Error during queue scan', e, s);
    } finally {
      _isProcessing = false;
    }
  }
}
