import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/event_model.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => FirebaseEventRepository(),
);

abstract class EventRepository {
  Stream<List<EventModel>> watchEvents(String uid);
  Future<void> saveEvent(String uid, EventModel event);
  Future<void> updateEvent(String uid, EventModel event);
  Future<void> deleteEvent(String uid, String eventId);
}

class FirebaseEventRepository implements EventRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('events');

  @override
  Stream<List<EventModel>> watchEvents(String uid) {
    return _col(uid)
        .orderBy('eventDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> saveEvent(String uid, EventModel event) async {
    await _col(uid).doc(event.id).set(_toMap(event));
  }

  @override
  Future<void> updateEvent(String uid, EventModel event) async {
    await _col(uid).doc(event.id).set(_toMap(event));
  }

  @override
  Future<void> deleteEvent(String uid, String eventId) async {
    await _col(uid).doc(eventId).delete();
  }

  EventModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return EventModel(
      id: d['id'] as String,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      eventDate: (d['eventDate'] as Timestamp).toDate(),
      time: d['time'] as String?,
      location: d['location'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : null,
      metadata: d['metadata'] != null 
          ? EntityMetadata.fromJson(Map<String, dynamic>.from(d['metadata'] as Map))
          : null,
    );
  }

  Map<String, dynamic> _toMap(EventModel e) => {
        'id': e.id,
        'title': e.title,
        'description': e.description,
        'eventDate': Timestamp.fromDate(e.eventDate),
        'time': e.time,
        'location': e.location,
        'createdAt': Timestamp.fromDate(e.createdAt),
        'updatedAt': e.updatedAt != null ? Timestamp.fromDate(e.updatedAt!) : null,
        if (e.metadata != null) 'metadata': e.metadata!.toJson(),
      };
}
