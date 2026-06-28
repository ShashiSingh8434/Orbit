import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../../../core/models/paginated_result.dart';
import '../models/learning_model.dart';

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => FirebaseLearningRepository(),
);

abstract class LearningRepository {
  Stream<List<LearningModel>> watchLearnings(String uid);
  Future<List<LearningModel>> getLearnings(String uid);
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(String uid, {DocumentSnapshot? startAfter, int limit = 20});
  Future<void> saveLearning(String uid, LearningModel learning);
  Future<void> updateLearning(String uid, LearningModel learning);
  Future<void> deleteLearning(String uid, String learningId);
}

class FirebaseLearningRepository implements LearningRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('learnings');

  @override
  Stream<List<LearningModel>> watchLearnings(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<List<LearningModel>> getLearnings(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(String uid, {DocumentSnapshot? startAfter, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _col(uid).orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final items = snap.docs.map(_fromDoc).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length == limit;
    return PaginatedResult(items: items, lastDoc: lastDoc, hasMore: hasMore);
  }

  @override
  Future<void> saveLearning(String uid, LearningModel learning) async {
    await _col(uid).doc(learning.id).set(_toMap(learning));
  }

  @override
  Future<void> updateLearning(String uid, LearningModel learning) async {
    await _col(uid).doc(learning.id).set(_toMap(learning));
  }

  @override
  Future<void> deleteLearning(String uid, String learningId) async {
    await _col(uid).doc(learningId).delete();
  }

  LearningModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return LearningModel(
      id: d['id'] as String,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'general',
      occurrenceCount: d['occurrenceCount'] as int? ?? 1,
      lastSeen: d['lastSeen'] != null ? (d['lastSeen'] as Timestamp).toDate() : null,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : null,
      metadata: d['metadata'] != null 
          ? EntityMetadata.fromJson(Map<String, dynamic>.from(d['metadata'] as Map))
          : null,
    );
  }

  Map<String, dynamic> _toMap(LearningModel l) => {
        'id': l.id,
        'title': l.title,
        'description': l.description,
        'category': l.category,
        'occurrenceCount': l.occurrenceCount,
        'lastSeen': l.lastSeen != null ? Timestamp.fromDate(l.lastSeen!) : null,
        'createdAt': Timestamp.fromDate(l.createdAt),
        'updatedAt': l.updatedAt != null ? Timestamp.fromDate(l.updatedAt!) : null,
        if (l.metadata != null) 'metadata': l.metadata!.toJson(),
      };
}
