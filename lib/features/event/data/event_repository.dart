import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../models/event_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => FirebaseEventRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Plaintext fields kept outside the envelope.
///
/// - `id` — document addressing.
/// - `eventDate` — primary ordering (Firestore `orderBy('eventDate')`).
/// - `createdAt` — secondary ordering.
/// - `updatedAt` — change detection / ordering.
///
/// Note: `eventDate` must remain plaintext because the query sorts by it.
/// The event title, description, location, and time are fully encrypted.
const _kPlaintextFields = {'id', 'eventDate', 'createdAt', 'updatedAt'};
const _kCollection = 'events';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class EventRepository {
  Stream<List<EventModel>> watchEvents(String uid);
  Future<List<EventModel>> getEvents(String uid);
  Future<PaginatedResult<EventModel>> getEventsPaginated(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  });
  Future<void> saveEvent(String uid, EventModel event);
  Future<void> updateEvent(String uid, EventModel event);
  Future<void> deleteEvent(String uid, String eventId);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseEventRepository implements EventRepository {
  FirebaseEventRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection);

  // ── Watch ──

  @override
  Stream<List<EventModel>> watchEvents(String uid) {
    return _col(
      uid,
    ).orderBy('eventDate', descending: true).snapshots().asyncMap((snap) async {
      final futures = snap.docs.map((doc) => _fromDoc(uid, doc));
      return Future.wait(futures);
    });
  }

  // ── Get ──

  @override
  Future<List<EventModel>> getEvents(String uid) async {
    final snap = await _col(uid).orderBy('eventDate', descending: true).get();
    return Future.wait(snap.docs.map((doc) => _fromDoc(uid, doc)));
  }

  @override
  Future<PaginatedResult<EventModel>> getEventsPaginated(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _col(
      uid,
    ).orderBy('eventDate', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final items = await Future.wait(snap.docs.map((doc) => _fromDoc(uid, doc)));
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length == limit;
    return PaginatedResult(items: items, lastDoc: lastDoc, hasMore: hasMore);
  }

  // ── Save / Update ──

  @override
  Future<void> saveEvent(String uid, EventModel event) async {
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(event),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid).doc(event.id).set(encrypted);
  }

  @override
  Future<void> updateEvent(String uid, EventModel event) =>
      saveEvent(uid, event);

  // ── Delete ──

  @override
  Future<void> deleteEvent(String uid, String eventId) async {
    await _col(uid).doc(eventId).delete();
  }

  // ── Serialisation ──

  Future<EventModel> _fromDoc(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final raw = doc.data()!;

    final plain = await _migration.migrateIfNeeded(
      uid,
      _kCollection,
      raw,
      plaintextFields: _kPlaintextFields,
      writer: (encrypted) async => _col(uid).doc(doc.id).set(encrypted),
    );

    return EventModel(
      id: plain['id'] as String? ?? doc.id,
      title: plain['title'] as String? ?? '',
      description: plain['description'] as String? ?? '',
      eventDate: _toDateTime(plain['eventDate']),
      time: plain['time'] as String?,
      location: plain['location'] as String?,
      createdAt: _toDateTime(plain['createdAt']),
      updatedAt: plain['updatedAt'] != null
          ? _toDateTime(plain['updatedAt'])
          : null,
      metadata: plain['metadata'] != null
          ? EntityMetadata.fromJson(
              Map<String, dynamic>.from(plain['metadata'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> _toPlainMap(EventModel e) => {
    'id': e.id,
    'title': e.title,
    'description': e.description,
    'eventDate': Timestamp.fromDate(e.eventDate),
    'time': e.time,
    'location': e.location,
    'createdAt': Timestamp.fromDate(e.createdAt),
    'updatedAt': e.updatedAt != null
        ? Timestamp.fromDate(e.updatedAt!)
        : Timestamp.now(),
    if (e.metadata != null) 'metadata': e.metadata!.toJson(),
  };

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
