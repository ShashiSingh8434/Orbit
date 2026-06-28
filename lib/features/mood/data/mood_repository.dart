import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/mood_model.dart';

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => FirebaseMoodRepository(),
);

abstract class MoodRepository {
  Stream<List<MoodModel>> watchMoods(String uid);
  Future<void> saveMood(String uid, MoodModel mood);
  Future<void> updateMood(String uid, MoodModel mood);
  Future<void> deleteMood(String uid, String moodId);
}

class FirebaseMoodRepository implements MoodRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('moods');

  @override
  Stream<List<MoodModel>> watchMoods(String uid) {
    return _col(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> saveMood(String uid, MoodModel mood) async {
    await _col(uid).doc(mood.id).set(_toMap(mood));
  }

  @override
  Future<void> updateMood(String uid, MoodModel mood) async {
    await _col(uid).doc(mood.id).set(_toMap(mood));
  }

  @override
  Future<void> deleteMood(String uid, String moodId) async {
    await _col(uid).doc(moodId).delete();
  }

  MoodModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MoodModel(
      id: d['id'] as String,
      date: (d['date'] as Timestamp).toDate(),
      timeOfDay: d['timeOfDay'] as String,
      value: d['value'] as int,
      inferredByAi: d['inferredByAi'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: d['metadata'] != null
          ? EntityMetadata.fromJson(
              Map<String, dynamic>.from(d['metadata'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> _toMap(MoodModel m) => {
    'id': m.id,
    'date': Timestamp.fromDate(m.date),
    'timeOfDay': m.timeOfDay,
    'value': m.value,
    'inferredByAi': m.inferredByAi,
    'createdAt': Timestamp.fromDate(m.createdAt),
    'updatedAt': m.updatedAt != null ? Timestamp.fromDate(m.updatedAt!) : null,
    if (m.metadata != null) 'metadata': m.metadata!.toJson(),
  };
}
