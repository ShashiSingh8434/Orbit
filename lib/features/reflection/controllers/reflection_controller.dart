import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../reflection/data/reflection_repository.dart';
import '../../reflection/data/reflection_local_draft_store.dart';
import '../../reflection/models/reflection_model.dart';
import '../../ai/engine/understanding_pipeline.dart';

// ── Stream Provider ───────────────────────────────────────────────────────────

final reflectionsProvider =
    StreamProvider.family<List<ReflectionModel>, String>((ref, dateKey) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const Stream.empty();
      return ref
          .watch(reflectionRepositoryProvider)
          .watchReflections(user.uid, dateKey);
    });

// ── Action Controller ─────────────────────────────────────────────────────────

final reflectionControllerProvider =
    NotifierProvider<ReflectionController, void>(ReflectionController.new);

class ReflectionController extends Notifier<void> {
  late ReflectionRepository _repo;
  late ReflectionDraftStore _draftStore;

  @override
  void build() {
    _repo = ref.watch(reflectionRepositoryProvider);
    _draftStore = ref.watch(reflectionDraftStoreProvider);
  }

  // ── CRUD ──

  Future<void> addReflection({
    required String text,
    List<String> tags = const [],
    String source = 'manual',
  }) async {
    final uid = _requireUid();
    final now = DateTime.now();
    final reflection = ReflectionModel(
      id: _generateId(),
      text: text.trim(),
      createdAt: now,
      updatedAt: now,
      tags: tags,
      source: source,
    );
    await _repo.saveReflection(uid, OrbitDateUtils.dateKey(now), reflection);

    // Trigger understanding pipeline (temporarily directly invoked for Phase 2 demo)
    ref.read(understandingPipelineProvider).onReflectionSaved(uid, reflection);
  }

  Future<void> editReflection({
    required ReflectionModel original,
    required String newText,
    required List<String> newTags,
    required String dateKey,
  }) async {
    final uid = _requireUid();
    final updated = original.copyWith(
      text: newText.trim(),
      tags: newTags,
      updatedAt: DateTime.now(),
      aiProcessed: false, // Re-queue for AI on next run
    );
    await _repo.saveReflection(uid, dateKey, updated);
    
    // Trigger understanding pipeline (temporarily directly invoked for Phase 2 demo)
    ref.read(understandingPipelineProvider).onReflectionSaved(uid, updated);
  }

  Future<void> deleteReflection({
    required String reflectionId,
    required String dateKey,
  }) async {
    final uid = _requireUid();
    await _repo.deleteReflection(uid, dateKey, reflectionId);
  }

  // ── Offline Drafts ──

  void saveDraft(String text, List<String> tags) {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    _draftStore.saveDraft(
      uid,
      ReflectionDraft(text: text, tags: tags, savedAt: DateTime.now()),
    );
  }

  ReflectionDraft? loadDraft() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return null;
    return _draftStore.loadDraft(uid);
  }

  Future<void> clearDraft() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) await _draftStore.clearDraft(uid);
  }

  // ── Private ──

  String _requireUid() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) throw StateError('User is not authenticated');
    return uid;
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${1000 + (DateTime.now().microsecond % 9000)}';
}
