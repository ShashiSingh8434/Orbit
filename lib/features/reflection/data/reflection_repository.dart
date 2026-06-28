import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reflection_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final reflectionRepositoryProvider = Provider<ReflectionRepository>(
  (ref) => FirebaseReflectionRepository(),
);

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String dateKey) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('reflections')
          .doc(dateKey)
          .collection('entries');

  @override
  Stream<List<ReflectionModel>> watchReflections(String uid, String dateKey) {
    return _col(uid, dateKey).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).where((r) => !r.deleted).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<List<ReflectionModel>> getReflections(
    String uid,
    String dateKey,
  ) async {
    final snap = await _col(uid, dateKey).get();
    final list = snap.docs.map(_fromDoc).where((r) => !r.deleted).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> saveReflection(
    String uid,
    String dateKey,
    ReflectionModel reflection,
  ) async {
    await _col(uid, dateKey).doc(reflection.id).set(_toMap(reflection));
  }

  @override
  Future<void> deleteReflection(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    await _col(
      uid,
      dateKey,
    ).doc(reflectionId).update({'deleted': true, 'updatedAt': Timestamp.now()});
  }

  @override
  Future<void> markAiProcessed(
    String uid,
    String dateKey,
    String reflectionId,
  ) async {
    await _col(uid, dateKey).doc(reflectionId).update({'aiProcessed': true});
  }

  // ── Serialisation ──

  ReflectionModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ReflectionModel(
      id: data['id'] as String,
      text: data['text'] as String,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      tags: List<String>.from(data['tags'] as List? ?? []),
      source: data['source'] as String? ?? 'manual',
      aiProcessed: data['aiProcessed'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toMap(ReflectionModel r) => {
    'id': r.id,
    'text': r.text,
    'createdAt': Timestamp.fromDate(r.createdAt),
    'updatedAt': Timestamp.fromDate(r.updatedAt),
    'tags': r.tags,
    'source': r.source,
    'aiProcessed': r.aiProcessed,
    'deleted': r.deleted,
  };

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
