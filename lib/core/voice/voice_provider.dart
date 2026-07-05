import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';
import 'voice_controller.dart';
import '../ai/analytics/ai_analytics_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService(
    analytics: ref.watch(aiAnalyticsServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceState>((ref) {
      final service = ref.watch(voiceServiceProvider);
      return VoiceController(service);
    });
