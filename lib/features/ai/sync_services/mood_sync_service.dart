import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../mood/data/mood_repository.dart';
import '../../mood/models/mood_model.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/dtos/mood_dto.dart';

final moodSyncServiceProvider = Provider<MoodSyncService>((ref) {
  return MoodSyncService(ref.read(moodRepositoryProvider));
});

class MoodSyncService {
  final MoodRepository _repository;
  final _uuid = const Uuid();

  MoodSyncService(this._repository);

  Future<void> syncMoods(String uid, DateTime dayDate, List<MoodDto> extractedMoods, String reflectionId) async {
    for (final dto in extractedMoods) {
      final mood = MoodModel(
        id: _uuid.v4(),
        date: dayDate,
        timeOfDay: dto.timeOfDay,
        value: dto.value,
        inferredByAi: true,
        createdAt: DateTime.now(),
        metadata: EntityMetadata(
          originReflectionId: reflectionId,
          aiConfidence: dto.aiConfidence,
          createdBy: 'ai',
        ),
      );
      await _repository.saveMood(uid, mood);
    }
  }
}
