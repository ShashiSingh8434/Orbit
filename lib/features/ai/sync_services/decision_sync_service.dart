import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../decision/data/decision_repository.dart';
import '../../decision/models/decision_model.dart';
import '../../../core/models/entity_metadata.dart';
import '../models/dtos/decision_dto.dart';

final decisionSyncServiceProvider = Provider<DecisionSyncService>((ref) {
  return DecisionSyncService(ref.read(decisionRepositoryProvider));
});

class DecisionSyncService {
  final DecisionRepository _repository;
  final _uuid = const Uuid();

  DecisionSyncService(this._repository);

  String _normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Future<void> syncDecisions(String uid, List<DecisionDto> extractedDecisions, String reflectionId, DateTime dayDate) async {
    final existingDecisions = await _repository.getDecisions(uid);

    for (final dto in extractedDecisions) {
      final normalizedNewDecision = _normalize(dto.decision);
      
      // Simple conflict detection based on similar text. 
      // In a production app, the AI would pass back the ID of the superseded decision.
      int conflictingIndex = existingDecisions.indexWhere((d) => 
          d.status == 'Active' && _normalize(d.decision) == normalizedNewDecision);

      if (conflictingIndex != -1) {
        var existingDecision = existingDecisions[conflictingIndex];
        
        var supersededDecision = existingDecision.copyWith(
          status: 'Superseded',
          updatedAt: DateTime.now(),
        );
        
        await _repository.updateDecision(uid, supersededDecision);
        existingDecisions[conflictingIndex] = supersededDecision;
      }

      final decision = DecisionModel(
        id: _uuid.v4(),
        decision: dto.decision,
        reason: dto.reason ?? '',
        status: 'Active',
        createdAt: dayDate,
        metadata: EntityMetadata(
          originReflectionId: reflectionId,
          aiConfidence: dto.aiConfidence,
          createdBy: 'ai',
        ),
      );
      await _repository.saveDecision(uid, decision);
      existingDecisions.add(decision);
    }
  }
}

