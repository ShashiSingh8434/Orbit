import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/decision_model.dart';

final decisionRepositoryProvider = Provider<DecisionRepository>(
  (ref) => FirebaseDecisionRepository(),
);

abstract class DecisionRepository {
  Stream<List<DecisionModel>> watchDecisions(String uid);
  Future<void> saveDecision(String uid, DecisionModel decision);
  Future<void> updateDecision(String uid, DecisionModel decision);
  Future<void> deleteDecision(String uid, String decisionId);
}

class FirebaseDecisionRepository implements DecisionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('decisions');

  @override
  Stream<List<DecisionModel>> watchDecisions(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> saveDecision(String uid, DecisionModel decision) async {
    await _col(uid).doc(decision.id).set(_toMap(decision));
  }

  @override
  Future<void> updateDecision(String uid, DecisionModel decision) async {
    await _col(uid).doc(decision.id).set(_toMap(decision));
  }

  @override
  Future<void> deleteDecision(String uid, String decisionId) async {
    await _col(uid).doc(decisionId).delete();
  }

  DecisionModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DecisionModel(
      id: d['id'] as String,
      decision: d['decision'] as String,
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'Active',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : null,
      metadata: d['metadata'] != null 
          ? EntityMetadata.fromJson(Map<String, dynamic>.from(d['metadata'] as Map))
          : null,
    );
  }

  Map<String, dynamic> _toMap(DecisionModel d) => {
        'id': d.id,
        'decision': d.decision,
        'reason': d.reason,
        'status': d.status,
        'createdAt': Timestamp.fromDate(d.createdAt),
        'updatedAt': d.updatedAt != null ? Timestamp.fromDate(d.updatedAt!) : null,
        if (d.metadata != null) 'metadata': d.metadata!.toJson(),
      };
}
