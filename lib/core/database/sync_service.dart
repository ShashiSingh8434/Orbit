import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/repository/encryption_repository.dart';
import '../security/services/migration_service.dart';
import '../utils/app_logger.dart';
import '../utils/date_utils.dart';
import 'local_database.dart';

import '../../features/day/models/day_model.dart';
import '../../features/tasks/models/task_model.dart';
import '../../features/reflection/models/reflection_model.dart';
import '../../features/learning/models/learning_model.dart';
import '../../features/event/models/event_model.dart';
import '../../features/decision/models/decision_model.dart';
import '../../features/academic/models/academic_schedule.dart';
import '../../features/auth/controllers/auth_controller.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final enc = ref.watch(encryptionRepositoryProvider);
  final migration = ref.watch(migrationServiceProvider);
  return SyncService(ref: ref, db: db, enc: enc, migration: migration);
});

// A provider that exposes the local database database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final user = ref.watch(authStateProvider).value;
  final uid = user?.uid ?? 'default';
  final db = AppDatabase(uid);
  ref.onDispose(() {
    db.close();
  });
  return db;
});

class SyncService {
  final Ref ref;
  final AppDatabase db;
  final EncryptionRepository enc;
  final MigrationService migration;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SyncService({
    required this.ref,
    required this.db,
    required this.enc,
    required this.migration,
  });

  // Helper to get plaintext fields for a collection
  Set<String> _getPlaintextFields(String collection) {
    switch (collection) {
      case 'tasks':
        return {'id', 'createdAt', 'updatedAt'};
      case 'reflections':
        return {'id', 'createdAt', 'updatedAt', 'deleted', 'aiProcessed'};
      case 'learnings':
        return {'id', 'createdAt', 'updatedAt'};
      case 'events':
        return {'id', 'eventDate', 'createdAt', 'updatedAt'};
      case 'decisions':
        return {'id', 'createdAt', 'updatedAt'};
      case 'days':
        return {'createdAt', 'updatedAt'};
      default:
        return const {};
    }
  }

  // --- Queue pending operations ---
  Future<void> enqueue({
    required String collection,
    required String operation,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    AppLogger.info('SyncService: Enqueuing $operation on $collection ($id)');
    final companion = SyncQueueTableCompanion(
      id: Value(id),
      collection: Value(collection),
      operation: Value(operation),
      createdAt: Value(DateTime.now()),
      payload: Value(jsonEncode(payload)),
      retryCount: const Value(0),
      status: const Value('pending'),
    );
    await db.into(db.syncQueueTable).insertOnConflictUpdate(companion);
    // Process queue in the background
    unawaited(processQueue());
  }

  // --- Process Sync Queue (Uploads) ---
  Future<void> processQueue() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      AppLogger.warning('SyncService: User is null, cannot process queue');
      return;
    }
    final uid = user.uid;

    final pending =
        await (db.select(db.syncQueueTable)
              ..where(
                (tbl) =>
                    tbl.status.equals('pending') | tbl.status.equals('failed'),
              )
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
            .get();

    if (pending.isEmpty) {
      AppLogger.debug('SyncService: No pending items in sync queue');
      return;
    }

    AppLogger.info('SyncService: Processing ${pending.length} pending writes');

    for (final item in pending) {
      // Mark as processing
      await (db.update(db.syncQueueTable)
            ..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueTableCompanion(status: Value('processing')));

      try {
        final collection = item.collection;
        final operation = item.operation;
        final id = item.id;
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;

        final userDocRef = _firestore.collection('users').doc(uid);

        if (operation == 'DELETE') {
          if (collection == 'reflections') {
            final dateKey = payload['dateKey'] as String? ?? 'default';
            await userDocRef
                .collection(collection)
                .doc(dateKey)
                .collection('entries')
                .doc(id)
                .delete();
          } else if (collection == 'academic') {
            await userDocRef.collection(collection).doc('data').delete();
          } else {
            await userDocRef.collection(collection).doc(id).delete();
          }
        } else {
          // INSERT or UPDATE
          // Encrypt document
          final encrypted = await enc.encryptDocument(
            uid,
            collection,
            payload,
            plaintextFields: _getPlaintextFields(collection),
          );

          if (collection == 'reflections') {
            final dateKey = payload['dateKey'] as String? ?? 'default';
            await userDocRef
                .collection(collection)
                .doc(dateKey)
                .collection('entries')
                .doc(id)
                .set(encrypted);
          } else if (collection == 'academic') {
            await userDocRef.collection(collection).doc('data').set(encrypted);
          } else {
            await userDocRef.collection(collection).doc(id).set(encrypted);
          }
        }

        // Successfully synced, remove from queue
        await (db.delete(
          db.syncQueueTable,
        )..where((tbl) => tbl.id.equals(item.id))).go();
        AppLogger.info(
          'SyncService: Successfully processed $operation on $collection ($id)',
        );
      } catch (e, st) {
        AppLogger.error(
          'SyncService: Error processing queue item ${item.id}',
          e,
          st,
        );
        // Increment retry count
        final newRetryCount = item.retryCount + 1;
        await (db.update(
          db.syncQueueTable,
        )..where((tbl) => tbl.id.equals(item.id))).write(
          SyncQueueTableCompanion(
            retryCount: Value(newRetryCount),
            status: const Value('failed'),
          ),
        );
      }
    }
  }

  // --- Bidirectional Sync (All) ---
  Future<void> syncAll() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final uid = user.uid;

    AppLogger.info('SyncService: Starting bidirectional sync for uid=$uid');

    // 1. Process local writes first
    await processQueue();

    // 2. Sync each collection from remote
    try {
      await _syncDays(uid);
      await _syncTasks(uid);
      await _syncReflections(uid);
      await _syncLearnings(uid);
      await _syncEvents(uid);
      await _syncDecisions(uid);
      await _syncAcademic(uid);
      AppLogger.info('SyncService: Bidirectional sync completed successfully');
    } catch (e, st) {
      AppLogger.error('SyncService: Error during syncAll', e, st);
    }
  }

  // --- Collection Sync Helpers ---

  Future<void> _syncDays(String uid) async {
    final remoteSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('days')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('days');

    final remoteDays = <String, Map<String, dynamic>>{};
    for (final doc in remoteSnap.docs) {
      final decrypted = await enc.decryptDocument(uid, 'days', doc.data());
      remoteDays[doc.id] = decrypted;
    }

    // 1. Update/insert newer remote items
    for (final entry in remoteDays.entries) {
      final dateKey = entry.key;
      final remoteData = entry.value;

      if (localQueueIds.contains(dateKey)) {
        continue;
      }

      final localDoc = await (db.select(
        db.daysTable,
      )..where((tbl) => tbl.date.equals(dateKey))).getSingleOrNull();

      final remoteUpdatedAt =
          _toDateTime(remoteData['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final localUpdatedAt =
          localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final companion = DaysTableCompanion(
          date: Value(dateKey),
          summary: Value(remoteData['summary'] as String? ?? ''),
          summaryMode: Value(remoteData['summaryMode'] as String? ?? 'auto'),
          reflectionCount: Value(remoteData['reflectionCount'] as int? ?? 0),
          detailedSummary: Value(remoteData['detailedSummary'] as String?),
          detailedSummaryBullet: Value(
            remoteData['detailedSummaryBullet'] as String?,
          ),
          createdAt: Value(_toDateTime(remoteData['createdAt'])),
          updatedAt: Value(remoteUpdatedAt),
          aiVersion: Value(remoteData['aiVersion'] as String?),
        );
        await db.into(db.daysTable).insertOnConflictUpdate(companion);
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.daysTable).get();
    for (final local in localDocs) {
      if (!remoteDays.containsKey(local.date) &&
          !localQueueIds.contains(local.date)) {
        await (db.delete(
          db.daysTable,
        )..where((tbl) => tbl.date.equals(local.date))).go();
      }
    }
  }

  Future<void> _syncTasks(String uid) async {
    final remoteSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('tasks');

    final remoteTasks = <String, Map<String, dynamic>>{};
    for (final doc in remoteSnap.docs) {
      final decrypted = await enc.decryptDocument(uid, 'tasks', doc.data());
      remoteTasks[doc.id] = decrypted;
    }

    // 1. Update/insert newer remote items
    for (final entry in remoteTasks.entries) {
      final taskId = entry.key;
      final remoteData = entry.value;

      if (localQueueIds.contains(taskId)) continue;

      final localDoc = await (db.select(
        db.tasksTable,
      )..where((tbl) => tbl.id.equals(taskId))).getSingleOrNull();

      final remoteUpdatedAt =
          _toDateTime(remoteData['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final localUpdatedAt =
          localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final companion = TasksTableCompanion(
          id: Value(taskId),
          title: Value(remoteData['title'] as String? ?? ''),
          description: Value(remoteData['description'] as String? ?? ''),
          createdAt: Value(
            _toDateTime(remoteData['createdAt']) ?? DateTime.now(),
          ),
          updatedAt: Value(remoteUpdatedAt),
          dueDate: Value(_toDateTime(remoteData['dueDate'])),
          dueTime: Value(remoteData['dueTime'] as String?),
          priority: Value(remoteData['priority'] as String? ?? 'medium'),
          status: Value(remoteData['status'] as String? ?? 'pending'),
          completedAt: Value(_toDateTime(remoteData['completedAt'])),
          metadata: Value(
            remoteData['metadata'] != null
                ? Map<String, dynamic>.from(remoteData['metadata'] as Map)
                : null,
          ),
        );
        await db.into(db.tasksTable).insertOnConflictUpdate(companion);
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.tasksTable).get();
    for (final local in localDocs) {
      if (!remoteTasks.containsKey(local.id) &&
          !localQueueIds.contains(local.id)) {
        await (db.delete(
          db.tasksTable,
        )..where((tbl) => tbl.id.equals(local.id))).go();
      }
    }
  }

  Future<void> syncReflectionsForDate(String uid, String dateKey) async {
    try {
      final entriesSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('reflections')
          .doc(dateKey)
          .collection('entries')
          .get();

      final localQueueIds = await _getPendingIdsForCollection('reflections');

      for (final doc in entriesSnap.docs) {
        final decrypted = await enc.decryptDocument(
          uid,
          'reflections',
          doc.data(),
        );
        final refId = doc.id;

        if (localQueueIds.contains(refId)) continue;

        final localDoc = await (db.select(
          db.reflectionsTable,
        )..where((tbl) => tbl.id.equals(refId))).getSingleOrNull();

        final remoteUpdatedAt =
            _toDateTime(decrypted['updatedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final localUpdatedAt =
            localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
          final companion = ReflectionsTableCompanion(
            id: Value(refId),
            textContent: Value(decrypted['text'] as String? ?? ''),
            createdAt: Value(
              _toDateTime(decrypted['createdAt']) ?? DateTime.now(),
            ),
            updatedAt: Value(remoteUpdatedAt),
            tags: Value(List<String>.from(decrypted['tags'] as List? ?? [])),
            source: Value(decrypted['source'] as String? ?? 'manual'),
            aiProcessed: Value(decrypted['aiProcessed'] as bool? ?? false),
            deleted: Value(decrypted['deleted'] as bool? ?? false),
            dateKey: Value(dateKey),
          );
          await db.into(db.reflectionsTable).insertOnConflictUpdate(companion);
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'SyncService: Error syncing reflections for date $dateKey',
        e,
        st,
      );
    }
  }

  Future<void> _syncReflections(String uid) async {
    final daysSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('days')
        .get();
    final dates = daysSnap.docs.map((doc) => doc.id).toSet();

    // Always include today's key
    dates.add(OrbitDateUtils.dateKey(DateTime.now()));

    final localQueueIds = await _getPendingIdsForCollection('reflections');
    final remoteSeenIds = <String>{};

    for (final dateKey in dates) {
      try {
        final entriesSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('reflections')
            .doc(dateKey)
            .collection('entries')
            .get();

        for (final doc in entriesSnap.docs) {
          final decrypted = await enc.decryptDocument(
            uid,
            'reflections',
            doc.data(),
          );
          final refId = doc.id;
          remoteSeenIds.add(refId);

          if (localQueueIds.contains(refId)) continue;

          final localDoc = await (db.select(
            db.reflectionsTable,
          )..where((tbl) => tbl.id.equals(refId))).getSingleOrNull();

          final remoteUpdatedAt =
              _toDateTime(decrypted['updatedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final localUpdatedAt =
              localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

          if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
            final companion = ReflectionsTableCompanion(
              id: Value(refId),
              textContent: Value(decrypted['text'] as String? ?? ''),
              createdAt: Value(
                _toDateTime(decrypted['createdAt']) ?? DateTime.now(),
              ),
              updatedAt: Value(remoteUpdatedAt),
              tags: Value(List<String>.from(decrypted['tags'] as List? ?? [])),
              source: Value(decrypted['source'] as String? ?? 'manual'),
              aiProcessed: Value(decrypted['aiProcessed'] as bool? ?? false),
              deleted: Value(decrypted['deleted'] as bool? ?? false),
              dateKey: Value(dateKey),
            );
            await db
                .into(db.reflectionsTable)
                .insertOnConflictUpdate(companion);
          }
        }
      } catch (e, st) {
        AppLogger.error(
          'SyncService: Error syncing reflections for date $dateKey',
          e,
          st,
        );
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.reflectionsTable).get();
    for (final local in localDocs) {
      if (!remoteSeenIds.contains(local.id) &&
          !localQueueIds.contains(local.id)) {
        await (db.delete(
          db.reflectionsTable,
        )..where((tbl) => tbl.id.equals(local.id))).go();
      }
    }
  }

  Future<void> _syncLearnings(String uid) async {
    final remoteSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('learnings')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('learnings');

    final remoteLearnings = <String, Map<String, dynamic>>{};
    for (final doc in remoteSnap.docs) {
      final decrypted = await enc.decryptDocument(uid, 'learnings', doc.data());
      remoteLearnings[doc.id] = decrypted;
    }

    // 1. Update/insert newer remote items
    for (final entry in remoteLearnings.entries) {
      final learningId = entry.key;
      final remoteData = entry.value;

      if (localQueueIds.contains(learningId)) continue;

      final localDoc = await (db.select(
        db.learningsTable,
      )..where((tbl) => tbl.id.equals(learningId))).getSingleOrNull();

      final remoteUpdatedAt =
          _toDateTime(remoteData['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final localUpdatedAt =
          localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final companion = LearningsTableCompanion(
          id: Value(learningId),
          title: Value(remoteData['title'] as String? ?? ''),
          description: Value(remoteData['description'] as String? ?? ''),
          category: Value(remoteData['category'] as String? ?? 'general'),
          occurrenceCount: Value(remoteData['occurrenceCount'] as int? ?? 1),
          lastSeen: Value(_toDateTime(remoteData['lastSeen'])),
          createdAt: Value(
            _toDateTime(remoteData['createdAt']) ?? DateTime.now(),
          ),
          updatedAt: Value(remoteUpdatedAt),
          metadata: Value(
            remoteData['metadata'] != null
                ? Map<String, dynamic>.from(remoteData['metadata'] as Map)
                : null,
          ),
        );
        await db.into(db.learningsTable).insertOnConflictUpdate(companion);
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.learningsTable).get();
    for (final local in localDocs) {
      if (!remoteLearnings.containsKey(local.id) &&
          !localQueueIds.contains(local.id)) {
        await (db.delete(
          db.learningsTable,
        )..where((tbl) => tbl.id.equals(local.id))).go();
      }
    }
  }

  Future<void> _syncEvents(String uid) async {
    final remoteSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('events')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('events');

    final remoteEvents = <String, Map<String, dynamic>>{};
    for (final doc in remoteSnap.docs) {
      final decrypted = await enc.decryptDocument(uid, 'events', doc.data());
      remoteEvents[doc.id] = decrypted;
    }

    // 1. Update/insert newer remote items
    for (final entry in remoteEvents.entries) {
      final eventId = entry.key;
      final remoteData = entry.value;

      if (localQueueIds.contains(eventId)) continue;

      final localDoc = await (db.select(
        db.eventsTable,
      )..where((tbl) => tbl.id.equals(eventId))).getSingleOrNull();

      final remoteUpdatedAt =
          _toDateTime(remoteData['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final localUpdatedAt =
          localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final companion = EventsTableCompanion(
          id: Value(eventId),
          title: Value(remoteData['title'] as String? ?? ''),
          description: Value(remoteData['description'] as String? ?? ''),
          eventDate: Value(
            _toDateTime(remoteData['eventDate']) ?? DateTime.now(),
          ),
          time: Value(remoteData['time'] as String?),
          location: Value(remoteData['location'] as String?),
          createdAt: Value(
            _toDateTime(remoteData['createdAt']) ?? DateTime.now(),
          ),
          updatedAt: Value(remoteUpdatedAt),
          metadata: Value(
            remoteData['metadata'] != null
                ? Map<String, dynamic>.from(remoteData['metadata'] as Map)
                : null,
          ),
        );
        await db.into(db.eventsTable).insertOnConflictUpdate(companion);
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.eventsTable).get();
    for (final local in localDocs) {
      if (!remoteEvents.containsKey(local.id) &&
          !localQueueIds.contains(local.id)) {
        await (db.delete(
          db.eventsTable,
        )..where((tbl) => tbl.id.equals(local.id))).go();
      }
    }
  }

  Future<void> _syncDecisions(String uid) async {
    final remoteSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('decisions')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('decisions');

    final remoteDecisions = <String, Map<String, dynamic>>{};
    for (final doc in remoteSnap.docs) {
      final decrypted = await enc.decryptDocument(uid, 'decisions', doc.data());
      remoteDecisions[doc.id] = decrypted;
    }

    // 1. Update/insert newer remote items
    for (final entry in remoteDecisions.entries) {
      final decId = entry.key;
      final remoteData = entry.value;

      if (localQueueIds.contains(decId)) continue;

      final localDoc = await (db.select(
        db.decisionsTable,
      )..where((tbl) => tbl.id.equals(decId))).getSingleOrNull();

      final remoteUpdatedAt =
          _toDateTime(remoteData['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final localUpdatedAt =
          localDoc?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (localDoc == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final companion = DecisionsTableCompanion(
          id: Value(decId),
          decision: Value(remoteData['decision'] as String? ?? ''),
          reason: Value(remoteData['reason'] as String? ?? ''),
          status: Value(remoteData['status'] as String? ?? 'Active'),
          createdAt: Value(
            _toDateTime(remoteData['createdAt']) ?? DateTime.now(),
          ),
          updatedAt: Value(remoteUpdatedAt),
          metadata: Value(
            remoteData['metadata'] != null
                ? Map<String, dynamic>.from(remoteData['metadata'] as Map)
                : null,
          ),
        );
        await db.into(db.decisionsTable).insertOnConflictUpdate(companion);
      }
    }

    // 2. Remove local items not on remote
    final localDocs = await db.select(db.decisionsTable).get();
    for (final local in localDocs) {
      if (!remoteDecisions.containsKey(local.id) &&
          !localQueueIds.contains(local.id)) {
        await (db.delete(
          db.decisionsTable,
        )..where((tbl) => tbl.id.equals(local.id))).go();
      }
    }
  }

  Future<void> _syncAcademic(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('academic')
        .doc('data')
        .get();
    final localQueueIds = await _getPendingIdsForCollection('academic');

    if (localQueueIds.contains('academic')) return; // local change pending

    if (!doc.exists || doc.data() == null) {
      // Academic schedule deleted remotely
      await (db.delete(
        db.academicTable,
      )..where((tbl) => tbl.uid.equals(uid))).go();
      return;
    }

    final decrypted = await enc.decryptDocument(uid, 'academic', doc.data()!);
    final scheduleMap = Map<String, dynamic>.from(decrypted['schedule'] as Map);

    final companion = AcademicTableCompanion(
      uid: Value(uid),
      schedule: Value(scheduleMap),
    );
    await db.into(db.academicTable).insertOnConflictUpdate(companion);
  }

  // --- Helper to get pending IDs for a collection ---
  Future<Set<String>> _getPendingIdsForCollection(String collection) async {
    final pending = await (db.select(
      db.syncQueueTable,
    )..where((tbl) => tbl.collection.equals(collection))).get();
    return pending.map((item) => item.id).toSet();
  }

  // --- Timestamp helper ---
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }
}
