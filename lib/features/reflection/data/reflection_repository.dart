import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../models/reflection_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final reflectionRepositoryProvider = Provider<ReflectionRepository>(
  (ref) => FirebaseReflectionRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Fields kept as plaintext in Firestore for query / ordering support.
///
/// - `id` — needed to address the document directly.
/// - `createdAt` — ordering (newest first).
/// - `updatedAt` — ordering / change detection.
/// - `deleted` — soft-delete filter in queries.
/// - `aiProcessed` — AI pipeline filter.
const _kPlaintextFields = {
  'id',
  'createdAt',
  'updatedAt',
  'deleted',
  'aiProcessed',
};
const _kCollection = 'reflections';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class ReflectionRepository {
  /// Streams all non-deleted reflections for [uid] on [dateKey] (yyyy-MM-dd).
  Stream<List<ReflectionModel>> watchReflections(String uid, String dateKey);

  /// One-shot fetch (used for AI processing).
  Future<List<ReflectionModel>> getReflections(String uid, String dateKey);

  /// Creates or fully replaces a reflection document.
  Future<void> saveReflection(
    String uid,
    String dateKey,
    ReflectionModel reflection,
  );

  /// Soft-deletes a reflection by setting `deleted = true`.
  Future<void> deleteReflection(
    String uid,
    String dateKey,
    String reflectionId,
  );

  /// Marks a reflection's `aiProcessed` flag as true.
  Future<void> markAiProcessed(String uid, String dateKey, String reflectionId);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseReflectionRepository implements ReflectionRepository {
  FirebaseReflectionRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String dateKey) =>
      _db
          .collection('users')
          .doc(uid)
          .collection(_kCollection)
          .doc(dateKey)
          .collection('entries');

  // ── Watch ──

  @override
  Stream<List<ReflectionModel>> watchReflections(String uid, String dateKey) {
    return _col(
      uid,
      dateKey,
    ).orderBy('createdAt', descending: true).snapshots().asyncMap((snap) async {
      final futures = snap.docs.map((doc) => _fromDoc(uid, dateKey, doc));
      final all = await Future.wait(futures);
      return all.whereType<ReflectionModel>().where((r) => !r.deleted).toList();
    });
  }

  // ── Get ──

  @override
  Future<List<ReflectionModel>> getReflections(
    String uid,
    String dateKey,
  ) async {
    final snap = await _col(
      uid,
      dateKey,
    ).orderBy('createdAt', descending: true).get();
    final futures = snap.docs.map((doc) => _fromDoc(uid, dateKey, doc));
    final all = await Future.wait(futures);
    return all.whereType<ReflectionModel>().where((r) => !r.deleted).toList();
  }

  // ── Save ──

  @override
  Future<void> saveReflection(
    String uid,
    String dateKey,
    ReflectionModel reflection,
  ) async {
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(reflection),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid, dateKey).doc(reflection.id).set(encrypted);
  }

  // ── Delete (soft) ──

  /// Soft-deletes by reading the document, decrypting, setting deleted=true,
  /// re-encrypting, and writing back.
  ///
  /// This pattern is required because the entire payload is a single encrypted
  /// blob — targeted Firestore `.update()` cannot reach individual fields.
  @override
  Future<void> deleteReflection(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    final docRef = _col(uid, dateKey).doc(reflectionId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final plain = await _dec(uid, snap);
    plain['deleted'] = true;
    plain['updatedAt'] = Timestamp.now();

    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      plain,
      plaintextFields: _kPlaintextFields,
    );
    await docRef.set(encrypted);
  }

  // ── Mark AI Processed ──

  @override
  Future<void> markAiProcessed(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    final docRef = _col(uid, dateKey).doc(reflectionId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final plain = await _dec(uid, snap);
    plain['aiProcessed'] = true;
    plain['updatedAt'] = Timestamp.now();

    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      plain,
      plaintextFields: _kPlaintextFields,
    );
    await docRef.set(encrypted);
  }

  // ── Serialisation ──

  Future<ReflectionModel?> _fromDoc(
    String uid,
    String dateKey,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final raw = doc.data()!;

    final plain = await _migration.migrateIfNeeded(
      uid,
      _kCollection,
      raw,
      plaintextFields: _kPlaintextFields,
      writer: (encrypted) async =>
          _col(uid, dateKey).doc(doc.id).set(encrypted),
    );

    return ReflectionModel(
      id: plain['id'] as String? ?? doc.id,
      text: plain['text'] as String? ?? '',
      createdAt: _toDateTime(plain['createdAt']),
      updatedAt: _toDateTime(plain['updatedAt']),
      tags: List<String>.from(plain['tags'] as List? ?? []),
      source: plain['source'] as String? ?? 'manual',
      aiProcessed: plain['aiProcessed'] as bool? ?? false,
      deleted: plain['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toPlainMap(ReflectionModel r) => {
    'id': r.id,
    'text': r.text,
    'createdAt': Timestamp.fromDate(r.createdAt),
    'updatedAt': Timestamp.fromDate(r.updatedAt),
    'tags': r.tags,
    'source': r.source,
    'aiProcessed': r.aiProcessed,
    'deleted': r.deleted,
  };

  Future<Map<String, dynamic>> _dec(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    final raw = Map<String, dynamic>.from(snap.data()!);
    return _enc.decryptDocument(uid, _kCollection, raw);
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
