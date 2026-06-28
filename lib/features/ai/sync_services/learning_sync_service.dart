import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/models/learning_model.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/dtos/learning_dto.dart';

final learningSyncServiceProvider = Provider<LearningSyncService>((ref) {
  return LearningSyncService(ref.read(learningRepositoryProvider));
});

class LearningSyncService {
  final LearningRepository _repository;
  final _uuid = const Uuid();

  LearningSyncService(this._repository);

  String _normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Future<void> syncLearnings(String uid, List<LearningDto> extractedLearnings, String reflectionId, DateTime dayDate) async {
    final existingLearnings = await _repository.getLearnings(uid);

    for (final dto in extractedLearnings) {
      final normalizedNewTitle = _normalize(dto.title);
      int existingIndex = existingLearnings.indexWhere((l) => _normalize(l.title) == normalizedNewTitle);

      if (existingIndex != -1) {
        var existingLearning = existingLearnings[existingIndex];
        
        var updatedLearning = existingLearning.copyWith(
          occurrenceCount: existingLearning.occurrenceCount + 1,
          lastSeen: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: existingLearning.metadata?.copyWith(
            aiConfidence: dto.aiConfidence, // Update with latest confidence
          ),
        );
        
        await _repository.updateLearning(uid, updatedLearning);
        existingLearnings[existingIndex] = updatedLearning;
      } else {
        final learning = LearningModel(
          id: _uuid.v4(),
          title: dto.title,
          description: dto.description ?? '',
          category: dto.category,
          createdAt: dayDate,
          lastSeen: DateTime.now(),
          metadata: EntityMetadata(
            originReflectionId: reflectionId,
            aiConfidence: dto.aiConfidence,
            createdBy: 'ai',
          ),
        );
        await _repository.saveLearning(uid, learning);
        existingLearnings.add(learning);
      }
    }
  }
}

