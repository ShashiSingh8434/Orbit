import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../features/event/data/event_repository.dart';
import '../../../features/event/models/event_model.dart';
import '../../models/entity_metadata.dart';
import '../models/dtos/event_dto.dart';
import '../../utils/app_logger.dart';

final eventSyncServiceProvider = Provider<EventSyncService>((ref) {
  return EventSyncService(ref.read(eventRepositoryProvider));
});

class EventSyncService {
  final EventRepository _repository;
  final _uuid = const Uuid();

  EventSyncService(this._repository);

  String _normalize(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Future<List<EventModel>> getUpcomingEvents(String uid) async {
    final allEvents = await _repository.getEvents(uid);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return allEvents
        .where(
          (e) => e.eventDate.isAfter(today.subtract(const Duration(days: 1))),
        )
        .toList();
  }

  Future<(int created, int updated)> syncEvents(
    String uid,
    List<EventDto> extractedEvents,
    String reflectionId,
  ) async {
    final existingEvents = await _repository.getEvents(uid);
    int created = 0;
    int updated = 0;

    for (final dto in extractedEvents) {
      // Parse eventDate safely, fallback to today
      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(dto.eventDate);
      } catch (e) {
        AppLogger.warning(
          'EventSyncService: Could not parse eventDate "${dto.eventDate}", using today.',
          e,
        );
        parsedDate = DateTime.now();
      }

      int existingIndex = -1;

      // 1. Check if AI matched an exact ID
      if (dto.originalId != null && dto.originalId!.isNotEmpty) {
        existingIndex = existingEvents.indexWhere(
          (e) => e.id == dto.originalId,
        );
      }

      // 2. Fallback to title and date matching
      if (existingIndex == -1) {
        final normalizedNewTitle = _normalize(dto.title);
        existingIndex = existingEvents.indexWhere((e) {
          return _normalize(e.title) == normalizedNewTitle &&
              e.eventDate.year == parsedDate.year &&
              e.eventDate.month == parsedDate.month &&
              e.eventDate.day == parsedDate.day;
        });
      }

      if (existingIndex != -1) {
        // Duplicate found. Update missing/changed info.
        var existingEvent = existingEvents[existingIndex];
        bool isUpdated = false;

        final newDesc = dto.description ?? existingEvent.description;
        final newTime = dto.time ?? existingEvent.time;
        final newLocation = dto.location ?? existingEvent.location;

        // Check if anything has actually changed to avoid redundant writes
        if (existingEvent.eventDate.year != parsedDate.year ||
            existingEvent.eventDate.month != parsedDate.month ||
            existingEvent.eventDate.day != parsedDate.day ||
            existingEvent.description != newDesc ||
            existingEvent.time != newTime ||
            existingEvent.location != newLocation) {
          isUpdated = true;
        }

        if (isUpdated) {
          var updatedEvent = existingEvent.copyWith(
            eventDate: parsedDate,
            description: dto.description != null && dto.description!.isNotEmpty
                ? dto.description!
                : existingEvent.description,
            time: dto.time ?? existingEvent.time,
            location: dto.location ?? existingEvent.location,
            updatedAt: DateTime.now(),
          );
          await _repository.updateEvent(uid, updatedEvent);
          existingEvents[existingIndex] = updatedEvent;
          updated++;
        }
      } else {
        // Create new
        final event = EventModel(
          id: _uuid.v4(),
          title: dto.title,
          description: dto.description ?? '',
          eventDate: parsedDate,
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
        existingEvents.add(event);
        created++;
      }
    }
    return (created, updated);
  }
}
