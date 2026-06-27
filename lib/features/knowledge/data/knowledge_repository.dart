import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_knowledge_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (ref) => FirebaseKnowledgeRepository(),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class KnowledgeRepository {
  /// Streams the knowledge document for [uid] on [dateKey].
  Stream<DailyKnowledgeModel?> watchKnowledge(String uid, String dateKey);

  /// One-shot read.
  Future<DailyKnowledgeModel?> getKnowledge(String uid, String dateKey);

  /// Writes (merges) a knowledge document for [dateKey].
  Future<void> saveKnowledge(String uid, String dateKey, DailyKnowledgeModel model);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseKnowledgeRepository implements KnowledgeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String dateKey) =>
      _db.collection('users').doc(uid).collection('dailyKnowledge').doc(dateKey);

  @override
  Stream<DailyKnowledgeModel?> watchKnowledge(String uid, String dateKey) {
    return _doc(uid, dateKey).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _fromDoc(snap);
    });
  }

  @override
  Future<DailyKnowledgeModel?> getKnowledge(String uid, String dateKey) async {
    final snap = await _doc(uid, dateKey).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  @override
  Future<void> saveKnowledge(
    String uid,
    String dateKey,
    DailyKnowledgeModel model,
  ) async {
    await _doc(uid, dateKey).set(_toMap(model));
  }

  // ── Serialisation ──

  DailyKnowledgeModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DailyKnowledgeModel(
      summary: d['summary'] as String? ?? '',
      summaryMode: d['summaryMode'] as String? ?? 'auto',
      mood: d['mood'] as int?,
      energy: d['energy'] as int?,
      tasks: _parseTasks(d['tasks']),
      learnings: List<String>.from(d['learnings'] as List? ?? []),
      decisions: List<String>.from(d['decisions'] as List? ?? []),
      events: List<String>.from(d['events'] as List? ?? []),
      tags: List<String>.from(d['tags'] as List? ?? []),
      reflectionCount: d['reflectionCount'] as int? ?? 0,
      lastUpdated: d['lastUpdated'] != null
          ? (d['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  List<KnowledgeTask> _parseTasks(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((t) {
      final m = Map<String, dynamic>.from(t as Map);
      return KnowledgeTask(
        title: m['title'] as String? ?? '',
        isDone: m['isDone'] as bool? ?? false,
        source: m['source'] as String? ?? 'ai',
        dueDate: m['dueDate'] != null
            ? (m['dueDate'] as Timestamp).toDate()
            : null,
      );
    }).toList();
  }

  Map<String, dynamic> _toMap(DailyKnowledgeModel m) => {
        'summary': m.summary,
        'summaryMode': m.summaryMode,
        'mood': m.mood,
        'energy': m.energy,
        'tasks': m.tasks
            .map((t) => {
                  'title': t.title,
                  'isDone': t.isDone,
                  'source': t.source,
                  'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
                })
            .toList(),
        'learnings': m.learnings,
        'decisions': m.decisions,
        'events': m.events,
        'tags': m.tags,
        'reflectionCount': m.reflectionCount,
        'lastUpdated': Timestamp.now(),
      };
}
