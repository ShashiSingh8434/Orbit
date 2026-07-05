import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/day/models/day_model.dart';
import '../../features/tasks/models/task_model.dart';
import '../../features/reflection/models/reflection_model.dart';
import '../../features/learning/models/learning_model.dart';
import '../../features/event/models/event_model.dart';
import '../../features/decision/models/decision_model.dart';
import '../models/entity_metadata.dart';
import '../utils/date_utils.dart';

part 'local_database.g.dart';

// ── Type Converters ──────────────────────────────────────────────────────────

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      final List<dynamic> decoded = jsonDecode(fromDb);
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

class MapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const MapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      return jsonDecode(fromDb) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}

// ── Tables ───────────────────────────────────────────────────────────────────

class DaysTable extends Table {
  TextColumn get date => text()(); // yyyy-MM-dd
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get summaryMode => text().withDefault(const Constant('auto'))();
  IntColumn get reflectionCount => integer().withDefault(const Constant(0))();
  TextColumn get detailedSummary => text().nullable()();
  TextColumn get detailedSummaryBullet => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get aiVersion => text().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}

class TasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get dueTime => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get metadata => text().map(const MapConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ReflectionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get textContent => text().named('text')();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  BoolColumn get aiProcessed => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get dateKey => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LearningsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant('general'))();
  IntColumn get occurrenceCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get metadata => text().map(const MapConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class EventsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get eventDate => dateTime()();
  TextColumn get time => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get metadata => text().map(const MapConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DecisionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get decision => text()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('Active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get metadata => text().map(const MapConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AcademicTable extends Table {
  TextColumn get uid => text()();
  TextColumn get schedule => text().map(const MapConverter())();

  @override
  Set<Column> get primaryKey => {uid};
}

class SyncQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get collection => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, processing, failed

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    DaysTable,
    TasksTable,
    ReflectionsTable,
    LearningsTable,
    EventsTable,
    DecisionsTable,
    AcademicTable,
    SyncQueueTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(String uid) : super(_openConnection(uid));

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection(String uid) {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'orbit_db_$uid.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

Future<void> deleteDatabaseFile(String uid) async {
  try {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'orbit_db_$uid.sqlite'));
    if (await file.exists()) {
      await file.delete();
    }
    // Drift also creates journals/WAL files, clean them up as well
    final walFile = File('${file.path}-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    final shmFile = File('${file.path}-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }
  } catch (_) {}
}

// ── Mapper Extensions ────────────────────────────────────────────────────────

extension DayModelMapper on DayModel {
  DaysTableCompanion toCompanion() => DaysTableCompanion(
    date: Value(OrbitDateUtils.dateKey(date)),
    summary: Value(summary),
    summaryMode: Value(summaryMode),
    reflectionCount: Value(reflectionCount),
    detailedSummary: Value(detailedSummary),
    detailedSummaryBullet: Value(detailedSummaryBullet),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    aiVersion: Value(aiVersion),
  );
}

extension DaysTableDataMapper on DaysTableData {
  DayModel toModel() => DayModel(
    date: OrbitDateUtils.parseKey(date),
    summary: summary,
    summaryMode: summaryMode,
    reflectionCount: reflectionCount,
    detailedSummary: detailedSummary,
    detailedSummaryBullet: detailedSummaryBullet,
    createdAt: createdAt,
    updatedAt: updatedAt,
    aiVersion: aiVersion,
  );
}

extension TaskModelMapper on TaskModel {
  TasksTableCompanion toCompanion() => TasksTableCompanion(
    id: Value(id),
    title: Value(title),
    description: Value(description),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    dueDate: Value(dueDate),
    dueTime: Value(dueTime),
    priority: Value(priority),
    status: Value(status),
    completedAt: Value(completedAt),
    metadata: Value(metadata?.toJson()),
  );
}

extension TasksTableDataMapper on TasksTableData {
  TaskModel toModel() => TaskModel(
    id: id,
    title: title,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
    dueDate: dueDate,
    dueTime: dueTime,
    priority: priority,
    status: status,
    completedAt: completedAt,
    metadata: metadata != null ? EntityMetadata.fromJson(metadata!) : null,
  );
}

extension ReflectionModelMapper on ReflectionModel {
  ReflectionsTableCompanion toCompanion() => ReflectionsTableCompanion(
    id: Value(id),
    textContent: Value(text),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    tags: Value(tags),
    source: Value(source),
    aiProcessed: Value(aiProcessed),
    deleted: Value(deleted),
    dateKey: Value(OrbitDateUtils.dateKey(createdAt)),
  );
}

extension ReflectionsTableDataMapper on ReflectionsTableData {
  ReflectionModel toModel() => ReflectionModel(
    id: id,
    text: textContent,
    createdAt: createdAt,
    updatedAt: updatedAt,
    tags: tags,
    source: source,
    aiProcessed: aiProcessed,
    deleted: deleted,
  );
}

extension LearningModelMapper on LearningModel {
  LearningsTableCompanion toCompanion() => LearningsTableCompanion(
    id: Value(id),
    title: Value(title),
    description: Value(description),
    category: Value(category),
    occurrenceCount: Value(occurrenceCount),
    lastSeen: Value(lastSeen),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    metadata: Value(metadata?.toJson()),
  );
}

extension LearningsTableDataMapper on LearningsTableData {
  LearningModel toModel() => LearningModel(
    id: id,
    title: title,
    description: description,
    category: category,
    occurrenceCount: occurrenceCount,
    lastSeen: lastSeen,
    createdAt: createdAt,
    updatedAt: updatedAt,
    metadata: metadata != null ? EntityMetadata.fromJson(metadata!) : null,
  );
}

extension EventModelMapper on EventModel {
  EventsTableCompanion toCompanion() => EventsTableCompanion(
    id: Value(id),
    title: Value(title),
    description: Value(description),
    eventDate: Value(eventDate),
    time: Value(time),
    location: Value(location),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    metadata: Value(metadata?.toJson()),
  );
}

extension EventsTableDataMapper on EventsTableData {
  EventModel toModel() => EventModel(
    id: id,
    title: title,
    description: description,
    eventDate: eventDate,
    time: time,
    location: location,
    createdAt: createdAt,
    updatedAt: updatedAt,
    metadata: metadata != null ? EntityMetadata.fromJson(metadata!) : null,
  );
}

extension DecisionModelMapper on DecisionModel {
  DecisionsTableCompanion toCompanion() => DecisionsTableCompanion(
    id: Value(id),
    decision: Value(decision),
    reason: Value(reason),
    status: Value(status),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    metadata: Value(metadata?.toJson()),
  );
}

extension DecisionsTableDataMapper on DecisionsTableData {
  DecisionModel toModel() => DecisionModel(
    id: id,
    decision: decision,
    reason: reason,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    metadata: metadata != null ? EntityMetadata.fromJson(metadata!) : null,
  );
}
