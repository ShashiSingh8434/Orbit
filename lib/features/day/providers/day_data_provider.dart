import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../day/data/day_repository.dart';
import '../../day/models/day_model.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/models/task_model.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/models/learning_model.dart';
import '../../decision/data/decision_repository.dart';
import '../../decision/models/decision_model.dart';
import '../../event/data/event_repository.dart';
import '../../event/models/event_model.dart';
import '../../mood/data/mood_repository.dart';
import '../../mood/models/mood_model.dart';
import '../../../core/utils/date_utils.dart';

class DayData {
  final DayModel? day;
  final List<TaskModel> tasks;
  final List<LearningModel> learnings;
  final List<DecisionModel> decisions;
  final List<EventModel> events;
  final List<MoodModel> moods;

  DayData({
    required this.day,
    required this.tasks,
    required this.learnings,
    required this.decisions,
    required this.events,
    required this.moods,
  });

  bool get isEmpty =>
      (day == null || day!.summary.isEmpty) &&
      tasks.isEmpty &&
      learnings.isEmpty &&
      decisions.isEmpty &&
      events.isEmpty &&
      moods.isEmpty;
}

// Keep the individual day stream providers for clean dependency matching, but return typed lists:

final daySummaryStreamProvider = StreamProvider.family<DayModel?, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(dayRepositoryProvider).watchDay(user.uid, date);
});

final dayTasksStreamProvider = StreamProvider.family<List<TaskModel>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).watchTasks(user.uid).map((tasks) {
    final key = OrbitDateUtils.dateKey(date);
    return tasks.where((t) {
      if (t.dueDate != null) {
        return OrbitDateUtils.dateKey(t.dueDate!) == key;
      }
      return OrbitDateUtils.dateKey(t.createdAt) == key;
    }).toList();
  });
});

final dayLearningsStreamProvider = StreamProvider.family<List<LearningModel>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(learningRepositoryProvider).watchLearnings(user.uid).map((learnings) {
    final key = OrbitDateUtils.dateKey(date);
    return learnings.where((l) => OrbitDateUtils.dateKey(l.createdAt) == key).toList();
  });
});

final dayDecisionsStreamProvider = StreamProvider.family<List<DecisionModel>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(decisionRepositoryProvider).watchDecisions(user.uid).map((decisions) {
    final key = OrbitDateUtils.dateKey(date);
    return decisions.where((d) => OrbitDateUtils.dateKey(d.createdAt) == key).toList();
  });
});

final dayEventsStreamProvider = StreamProvider.family<List<EventModel>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(eventRepositoryProvider).watchEvents(user.uid).map((events) {
    final key = OrbitDateUtils.dateKey(date);
    return events.where((e) => OrbitDateUtils.dateKey(e.eventDate) == key).toList();
  });
});

final dayMoodsStreamProvider = StreamProvider.family<List<MoodModel>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(moodRepositoryProvider).watchMoods(user.uid).map((moods) {
    final key = OrbitDateUtils.dateKey(date);
    return moods.where((m) => OrbitDateUtils.dateKey(m.date) == key).toList();
  });
});

// Unified Day Data Provider
final dayDataProvider = Provider.family<AsyncValue<DayData>, DateTime>((ref, date) {
  final dayAsync = ref.watch(daySummaryStreamProvider(date));
  final tasksAsync = ref.watch(dayTasksStreamProvider(date));
  final learningsAsync = ref.watch(dayLearningsStreamProvider(date));
  final decisionsAsync = ref.watch(dayDecisionsStreamProvider(date));
  final eventsAsync = ref.watch(dayEventsStreamProvider(date));
  final moodsAsync = ref.watch(dayMoodsStreamProvider(date));

  if (dayAsync.isLoading ||
      tasksAsync.isLoading ||
      learningsAsync.isLoading ||
      decisionsAsync.isLoading ||
      eventsAsync.isLoading ||
      moodsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (dayAsync.hasError) return AsyncValue.error(dayAsync.error!, dayAsync.stackTrace!);
  if (tasksAsync.hasError) return AsyncValue.error(tasksAsync.error!, tasksAsync.stackTrace!);
  if (learningsAsync.hasError) return AsyncValue.error(learningsAsync.error!, learningsAsync.stackTrace!);
  if (decisionsAsync.hasError) return AsyncValue.error(decisionsAsync.error!, decisionsAsync.stackTrace!);
  if (eventsAsync.hasError) return AsyncValue.error(eventsAsync.error!, eventsAsync.stackTrace!);
  if (moodsAsync.hasError) return AsyncValue.error(moodsAsync.error!, moodsAsync.stackTrace!);

  return AsyncValue.data(DayData(
    day: dayAsync.value,
    tasks: tasksAsync.value ?? [],
    learnings: learningsAsync.value ?? [],
    decisions: decisionsAsync.value ?? [],
    events: eventsAsync.value ?? [],
    moods: moodsAsync.value ?? [],
  ));
});
