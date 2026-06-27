import '../../reflection/models/reflection_model.dart';
import '../models/ai_extraction_result.dart';

abstract class AIProvider {
  Future<AiExtractionResult> extractKnowledge(
    List<ReflectionModel> reflections,
  );
}
