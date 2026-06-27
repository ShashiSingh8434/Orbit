import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../ai/controllers/ai_controller.dart';
import '../data/knowledge_repository.dart';
import '../models/daily_knowledge_model.dart';

// ── Stream Provider ───────────────────────────────────────────────────────────

final knowledgeProvider = StreamProvider.family<DailyKnowledgeModel?, String>(
  (ref, dateKey) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Stream.empty();
    return ref.watch(knowledgeRepositoryProvider).watchKnowledge(user.uid, dateKey);
  },
);

// ── Action Controller ─────────────────────────────────────────────────────────

final knowledgeControllerProvider =
    AsyncNotifierProvider<KnowledgeController, void>(KnowledgeController.new);

class KnowledgeController extends AsyncNotifier<void> {
  late KnowledgeRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.watch(knowledgeRepositoryProvider);
  }

  Future<void> refreshToday() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) throw StateError('Not authenticated');

      final dateKey = OrbitDateUtils.todayKey();
      await ref.read(aiControllerProvider.notifier).processReflections(
            uid: uid,
            dateKey: dateKey,
          );
    });
  }
}
