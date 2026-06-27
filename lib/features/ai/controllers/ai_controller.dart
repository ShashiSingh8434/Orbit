import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reflection/data/reflection_repository.dart';
import '../../knowledge/data/knowledge_repository.dart';
import '../../knowledge/engine/knowledge_merge_engine.dart';
import '../../knowledge/models/daily_knowledge_model.dart';
import '../data/ai_provider_interface.dart';
import '../data/gemini_provider.dart';
import '../models/ai_extraction_result.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final aiControllerProvider =
    AsyncNotifierProvider<AIController, AiExtractionResult?>(AIController.new);

// ── Controller ────────────────────────────────────────────────────────────────

class AIController extends AsyncNotifier<AiExtractionResult?> {
  late AIProvider _ai;
  late ReflectionRepository _reflectionRepo;
  late KnowledgeRepository _knowledgeRepo;

  @override
  Future<AiExtractionResult?> build() async {
    _ai = ref.watch(aiProviderProvider);
    _reflectionRepo = ref.watch(reflectionRepositoryProvider);
    _knowledgeRepo = ref.watch(knowledgeRepositoryProvider);
    return null;
  }

  Future<void> processReflections({
    required String uid,
    required String dateKey,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final reflections = await _reflectionRepo.getReflections(uid, dateKey);
      if (reflections.isEmpty) return null;

      final result = await _ai.extractKnowledge(reflections);

      final existing =
          await _knowledgeRepo.getKnowledge(uid, dateKey) ??
          const DailyKnowledgeModel();
      final merged = KnowledgeMergeEngine.merge(
        existing: existing,
        incoming: result,
        totalReflectionCount: reflections.length,
      );

      await _knowledgeRepo.saveKnowledge(uid, dateKey, merged);

      for (final r in reflections) {
        await _reflectionRepo.markAiProcessed(uid, dateKey, r.id);
      }

      return result;
    });
  }
}
