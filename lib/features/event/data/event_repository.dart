import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/database/sync_service.dart';
import '../../../core/models/paginated_result.dart';
import '../models/event_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => DriftEventRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class EventRepository {
  Stream<List<EventModel>> watchEvents(String uid);
  Future<List<EventModel>> getEvents(String uid);
  Future<PaginatedResult<EventModel>> getEventsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  });
  Future<void> saveEvent(String uid, EventModel event);
  Future<void> updateEvent(String uid, EventModel event);
  Future<void> deleteEvent(String uid, String eventId);
}

// ── Drift Implementation ─────────────────────────────────────────────────────

class DriftEventRepository implements EventRepository {
  DriftEventRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService sync;

  // ── Watch ──

  @override
  Stream<List<EventModel>> watchEvents(String uid) {
    return (db.select(db.eventsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.eventDate, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows.map((r) => r.toModel()).toList());
  }

  // ── Get ──

  @override
  Future<List<EventModel>> getEvents(String uid) async {
    final rows = await (db.select(db.eventsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.eventDate, mode: OrderingMode.desc)]))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  @override
  Future<PaginatedResult<EventModel>> getEventsPaginated(
    String uid, {
    Object? startAfter,
    int limit = 20,
  }) async {
    final offset = (startAfter is int) ? startAfter : 0;
    final rows = await (db.select(db.eventsTable)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.eventDate, mode: OrderingMode.desc)])
          ..limit(limit, offset: offset))
        .get();
    final items = rows.map((r) => r.toModel()).toList();
    final newOffset = offset + items.length;
    final hasMore = items.length == limit;

    return PaginatedResult(
      items: items,
      lastDoc: hasMore ? newOffset : null,
      hasMore: hasMore,
    );
  }

  // ── Save / Update ──

  @override
  Future<void> saveEvent(String uid, EventModel event) async {
    final eventToSave = event.updatedAt == null
        ? event.copyWith(updatedAt: DateTime.now())
        : event;
    await db.into(db.eventsTable).insertOnConflictUpdate(eventToSave.toCompanion());
    await sync.enqueue(
      collection: 'events',
      operation: 'INSERT',
      id: eventToSave.id,
      payload: eventToSave.toJson(),
    );
  }

  @override
  Future<void> updateEvent(String uid, EventModel event) async {
    final updated = event.copyWith(updatedAt: DateTime.now());
    await db.into(db.eventsTable).insertOnConflictUpdate(updated.toCompanion());
    await sync.enqueue(
      collection: 'events',
      operation: 'UPDATE',
      id: updated.id,
      payload: updated.toJson(),
    );
  }

  // ── Delete ──

  @override
  Future<void> deleteEvent(String uid, String eventId) async {
    await (db.delete(db.eventsTable)..where((tbl) => tbl.id.equals(eventId))).go();
    await sync.enqueue(
      collection: 'events',
      operation: 'DELETE',
      id: eventId,
      payload: {},
    );
  }
}
