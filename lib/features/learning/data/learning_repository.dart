import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/entity_metadata.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../models/learning_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => FirebaseLearningRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Plaintext fields kept outside the envelope.
///
/// - `id` — document addressing.
/// - `createdAt` — primary ordering (newest first).
/// - `updatedAt` — secondary ordering / change detection.
///
/// Sensitive fields encrypted inside `_enc`:
/// `title`, `description`, `category`, `occurrenceCount`, `lastSeen`, `metadata`.
const _kPlaintextFields = {'id', 'createdAt', 'updatedAt'};
const _kCollection = 'learnings';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class LearningRepository {
  Stream<List<LearningModel>> watchLearnings(String uid);
  Future<List<LearningModel>> getLearnings(String uid);
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  });
  Future<void> saveLearning(String uid, LearningModel learning);
  Future<void> updateLearning(String uid, LearningModel learning);
  Future<void> deleteLearning(String uid, String learningId);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseLearningRepository implements LearningRepository {
  FirebaseLearningRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection);

  // ── Watch ──

  @override
  Stream<List<LearningModel>> watchLearnings(String uid) {
    return _col(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().asyncMap((snap) async {
      final futures = snap.docs.map((doc) => _fromDoc(uid, doc));
      return Future.wait(futures);
    });
  }

  // ── Get ──

  @override
  Future<List<LearningModel>> getLearnings(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return Future.wait(snap.docs.map((doc) => _fromDoc(uid, doc)));
  }

  @override
  Future<PaginatedResult<LearningModel>> getLearningsPaginated(
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
  Future<void> saveLearning(String uid, LearningModel learning) async {
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(learning),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid).doc(learning.id).set(encrypted);
  }

  @override
  Future<void> updateLearning(String uid, LearningModel learning) =>
      saveLearning(uid, learning);

  // ── Delete ──

  @override
  Future<void> deleteLearning(String uid, String learningId) async {
    await _col(uid).doc(learningId).delete();
  }

  // ── Serialisation ──

  Future<LearningModel> _fromDoc(
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

    return LearningModel(
      id: plain['id'] as String? ?? doc.id,
      title: plain['title'] as String? ?? '',
      description: plain['description'] as String? ?? '',
      category: plain['category'] as String? ?? 'general',
      occurrenceCount: plain['occurrenceCount'] as int? ?? 1,
      lastSeen: plain['lastSeen'] != null
          ? _toDateTime(plain['lastSeen'])
          : null,
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

  Map<String, dynamic> _toPlainMap(LearningModel l) => {
    'id': l.id,
    'title': l.title,
    'description': l.description,
    'category': l.category,
    'occurrenceCount': l.occurrenceCount,
    'lastSeen': l.lastSeen != null ? Timestamp.fromDate(l.lastSeen!) : null,
    'createdAt': Timestamp.fromDate(l.createdAt),
    'updatedAt': l.updatedAt != null
        ? Timestamp.fromDate(l.updatedAt!)
        : Timestamp.now(),
    if (l.metadata != null) 'metadata': l.metadata!.toJson(),
  };

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
