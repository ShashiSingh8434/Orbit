import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../models/decision_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final decisionRepositoryProvider = Provider<DecisionRepository>(
  (ref) => FirebaseDecisionRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Plaintext fields kept outside the envelope:
/// - `id` — document addressing.
/// - `createdAt` — orderBy (newest first).
/// - `updatedAt` — secondary ordering / change detection.
const _kPlaintextFields = {'id', 'createdAt', 'updatedAt'};
const _kCollection = 'decisions';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class DecisionRepository {
  Stream<List<DecisionModel>> watchDecisions(String uid);
  Future<List<DecisionModel>> getDecisions(String uid);
  Future<PaginatedResult<DecisionModel>> getDecisionsPaginated(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  });
  Future<void> saveDecision(String uid, DecisionModel decision);
  Future<void> updateDecision(String uid, DecisionModel decision);
  Future<void> deleteDecision(String uid, String decisionId);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseDecisionRepository implements DecisionRepository {
  FirebaseDecisionRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection);

  // ── Watch ──

  @override
  Stream<List<DecisionModel>> watchDecisions(String uid) {
    return _col(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().asyncMap((snap) async {
      final futures = snap.docs.map((doc) => _fromDoc(uid, doc));
      return Future.wait(futures);
    });
  }

  // ── Get ──

  @override
  Future<List<DecisionModel>> getDecisions(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return Future.wait(snap.docs.map((doc) => _fromDoc(uid, doc)));
  }

  @override
  Future<PaginatedResult<DecisionModel>> getDecisionsPaginated(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _col(
      uid,
    ).orderBy('createdAt', descending: true).limit(limit);
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
  Future<void> saveDecision(String uid, DecisionModel decision) async {
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(decision),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid).doc(decision.id).set(encrypted);
  }

  @override
  Future<void> updateDecision(String uid, DecisionModel decision) =>
      saveDecision(uid, decision);

  // ── Delete ──

  @override
  Future<void> deleteDecision(String uid, String decisionId) async {
    await _col(uid).doc(decisionId).delete();
  }

  // ── Serialisation ──

  Future<DecisionModel> _fromDoc(
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

    return DecisionModel(
      id: plain['id'] as String? ?? doc.id,
      decision: plain['decision'] as String? ?? '',
      reason: plain['reason'] as String? ?? '',
      status: plain['status'] as String? ?? 'Active',
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

  Map<String, dynamic> _toPlainMap(DecisionModel d) => {
    'id': d.id,
    'decision': d.decision,
    'reason': d.reason,
    'status': d.status,
    'createdAt': Timestamp.fromDate(d.createdAt),
    'updatedAt': d.updatedAt != null
        ? Timestamp.fromDate(d.updatedAt!)
        : Timestamp.now(),
    if (d.metadata != null) 'metadata': d.metadata!.toJson(),
  };

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
