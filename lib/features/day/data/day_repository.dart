import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/migration_service.dart';
import '../../../core/utils/date_utils.dart';
import '../models/day_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => FirebaseDayRepository(
    enc: ref.watch(encryptionRepositoryProvider),
    migration: ref.watch(migrationServiceProvider),
  ),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// Fields kept plaintext for Firestore query / ordering support.
///
/// - `createdAt` / `updatedAt` — ordering.
const _kPlaintextFields = {'createdAt', 'updatedAt'};
const _kCollection = 'days';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class DayRepository {
  Stream<DayModel?> watchDay(String uid, DateTime date);
  Future<DayModel?> getDay(String uid, DateTime date);
  Future<void> saveDay(String uid, DayModel day);
  Future<void> invalidateDayCache(String uid, DateTime date);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseDayRepository implements DayRepository {
  FirebaseDayRepository({required this._enc, required this._migration});

  final EncryptionRepository _enc;
  final MigrationService _migration;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection);

  // ── Watch ──

  @override
  Stream<DayModel?> watchDay(String uid, DateTime date) {
    final key = OrbitDateUtils.dateKey(date);
    return _col(uid).doc(key).snapshots().asyncMap((snap) async {
      if (!snap.exists) return null;
      return _fromDoc(uid, key, snap);
    });
  }

  // ── Get ──

  @override
  Future<DayModel?> getDay(String uid, DateTime date) async {
    final key = OrbitDateUtils.dateKey(date);
    final snap = await _col(uid).doc(key).get();
    if (!snap.exists) return null;
    return _fromDoc(uid, key, snap);
  }

  // ── Save ──

  @override
  Future<void> saveDay(String uid, DayModel day) async {
    final key = OrbitDateUtils.dateKey(day.date);
    final encrypted = await _enc.encryptDocument(
      uid,
      _kCollection,
      _toPlainMap(day),
      plaintextFields: _kPlaintextFields,
    );
    await _col(uid).doc(key).set(encrypted);
  }

  // ── Invalidate Cache ──

  @override
  Future<void> invalidateDayCache(String uid, DateTime date) async {
    final day = await getDay(uid, date);
    if (day != null) {
      final updated = day.copyWith(
        detailedSummary: null,
        detailedSummaryBullet: null,
        updatedAt: DateTime.now(),
      );
      await saveDay(uid, updated);
    }
  }

  // ── Serialisation ──

  Future<DayModel> _fromDoc(
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
      writer: (encrypted) async => _col(uid).doc(dateKey).set(encrypted),
    );

    return DayModel(
      date: OrbitDateUtils.parseKey(dateKey),
      summary: plain['summary'] as String? ?? '',
      summaryMode: plain['summaryMode'] as String? ?? 'auto',
      reflectionCount: plain['reflectionCount'] as int? ?? 0,
      detailedSummary: plain['detailedSummary'] as String?,
      detailedSummaryBullet: plain['detailedSummaryBullet'] as String?,
      createdAt: _toDateTime(plain['createdAt']),
      updatedAt: _toDateTime(plain['updatedAt']),
      aiVersion: plain['aiVersion'] as String?,
    );
  }

  Map<String, dynamic> _toPlainMap(DayModel d) => {
    'summary': d.summary,
    'summaryMode': d.summaryMode,
    'reflectionCount': d.reflectionCount,
    'detailedSummary': d.detailedSummary,
    'detailedSummaryBullet': d.detailedSummaryBullet,
    'createdAt': d.createdAt != null ? Timestamp.fromDate(d.createdAt!) : null,
    'updatedAt': d.updatedAt != null
        ? Timestamp.fromDate(d.updatedAt!)
        : Timestamp.now(),
    'aiVersion': d.aiVersion,
  };

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }
}
