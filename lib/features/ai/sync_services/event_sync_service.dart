import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../event/data/event_repository.dart';
import '../../event/models/event_model.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/dtos/event_dto.dart';

final eventSyncServiceProvider = Provider<EventSyncService>((ref) {
  return EventSyncService(ref.read(eventRepositoryProvider));
});

class EventSyncService {
  final EventRepository _repository;
  final _uuid = const Uuid();

  EventSyncService(this._repository);

  Future<void> syncEvents(String uid, List<EventDto> extractedEvents, String reflectionId) async {
    for (final dto in extractedEvents) {
      final event = EventModel(
        id: _uuid.v4(),
        title: dto.title,
        description: dto.description ?? '',
        eventDate: DateTime.parse(dto.eventDate),
        time: dto.time,
        location: dto.location,
        createdAt: DateTime.now(),
        metadata: EntityMetadata(
          originReflectionId: reflectionId,
          aiConfidence: dto.aiConfidence,
          createdBy: 'ai',
        ),
      );
      await _repository.saveEvent(uid, event);
    }
  }
}
