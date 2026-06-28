import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../models/day_model.dart';

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => FirebaseDayRepository(),
);

abstract class DayRepository {
  Stream<DayModel?> watchDay(String uid, DateTime date);
  Future<DayModel?> getDay(String uid, DateTime date);
  Future<void> saveDay(String uid, DayModel day);
  Future<void> invalidateDayCache(String uid, DateTime date);
}

class FirebaseDayRepository implements DayRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('days');

  @override
  Stream<DayModel?> watchDay(String uid, DateTime date) {
    final key = OrbitDateUtils.dateKey(date);
    return _col(uid).doc(key).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _fromDoc(snap);
    });
  }

  @override
  Future<DayModel?> getDay(String uid, DateTime date) async {
    final key = OrbitDateUtils.dateKey(date);
    final snap = await _col(uid).doc(key).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  @override
  Future<void> saveDay(String uid, DayModel day) async {
    final key = OrbitDateUtils.dateKey(day.date);
    await _col(uid).doc(key).set(_toMap(day));
  }

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

  DayModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DayModel(
      date: OrbitDateUtils.parseKey(doc.id),
      summary: d['summary'] as String? ?? '',
      summaryMode: d['summaryMode'] as String? ?? 'auto',
      reflectionCount: d['reflectionCount'] as int? ?? 0,
      detailedSummary: d['detailedSummary'] as String?,
      detailedSummaryBullet: d['detailedSummaryBullet'] as String?,
      averageMood: (d['averageMood'] as num?)?.toDouble(),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
      aiVersion: d['aiVersion'] as String?,
    );
  }

  Map<String, dynamic> _toMap(DayModel d) => {
    'summary': d.summary,
    'summaryMode': d.summaryMode,
    'reflectionCount': d.reflectionCount,
    'detailedSummary': d.detailedSummary,
    'detailedSummaryBullet': d.detailedSummaryBullet,
    'averageMood': d.averageMood,
    'createdAt': d.createdAt != null ? Timestamp.fromDate(d.createdAt!) : null,
    'updatedAt': d.updatedAt != null ? Timestamp.fromDate(d.updatedAt!) : null,
    'aiVersion': d.aiVersion,
  };
}
